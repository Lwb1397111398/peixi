import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:peixi/core/update/update_checker.dart';

/// 更新流程失败的可读异常：message 直接给用户看（人话）。
class UpdateException implements Exception {
  UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 一条「有更新」的完整信息（由 checker 解析 + 本地比较后产出）。
class UpdateInfo {
  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.size,
    required this.notes,
  });
  final int versionCode;
  final String versionName;
  final String downloadUrl;

  /// 安装包字节数（元数据里带的；0 = 未知，跳过字节数校验）。
  final int size;
  final String notes;
}

/// 应用自更新服务（Windows 桌面端）：
/// 检查（GitHub Releases 匿名 API，24h 节流）→ 下载（.part 断点续传 +
/// 国内镜像兜底）→ 应用（解压 + 批处理等退出后替换安装目录并重启）。
class UpdateService {
  UpdateService({
    Dio? dio,
    this.apiBase = 'https://api.github.com',
    this.repo = 'Lwb1397111398/peixi',
    this.assetExtension = '.zip',
    List<String>? mirrors,
  })  : _dio = dio ?? Dio(),
        mirrors = mirrors ??
            const ['https://ghfast.top/', 'https://gh-proxy.com/'] {
    _dio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30);
  }

  final Dio _dio;

  /// Releases API 基址与仓库（测试注入本地假服务器用）。
  final String apiBase;
  final String repo;

  /// 安装包资产扩展名（Windows 打包为 zip）。
  final String assetExtension;

  /// 下载兜底镜像前缀列表（按序尝试；只对 github.com 地址生效）。
  /// 2026-10-25 实测存活：ghfast.top、gh-proxy.com；ghproxy.net 已死移除。
  final List<String> mirrors;

  /// 检查更新。远端 versionCode 更大时返回 [UpdateInfo]，否则 null。
  /// 失败抛 [UpdateException]（文案可直接展示）。
  Future<UpdateInfo?> check({required int currentVersionCode}) async {
    final Response<String> resp;
    try {
      resp = await _dio.get<String>('$apiBase/repos/$repo/releases/latest',
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'User-Agent': 'peixi-desktop-updater',
              'Accept': 'application/vnd.github+json',
            },
          ));
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403) {
        throw UpdateException(
            'GitHub 限流了（匿名 60 次/小时），请稍后再试；App 启动时会自动检查（24 小时节流），一般碰不到上限。');
      }
      if (code == 404) {
        throw UpdateException('还没有发布过任何版本，暂无更新可查。');
      }
      throw UpdateException('检查更新失败：连不上 GitHub（${e.type.name}），请检查网络后重试。');
    }
    final parsed = parseLatestReleaseJson(resp.data ?? '',
        assetExtension: assetExtension);
    if (parsed == null) return null;
    if (!isNewer(parsed, currentVersionCode)) return null;
    return UpdateInfo(
      versionCode: parsed.versionCode,
      versionName: parsed.versionName,
      downloadUrl: parsed.downloadUrl,
      size: parsed.size,
      notes: parsed.notes,
    );
  }

  /// 本地版本信息（version = versionName，buildNumber = versionCode；
  /// CI 以提交数注入构建号，本地 debug 构建为 1）。
  Future<PackageInfo> packageInfo() => PackageInfo.fromPlatform();

  Future<int> localVersionCode() async =>
      int.tryParse((await packageInfo()).buildNumber) ?? 0;

  Future<String> localVersionName() async => (await packageInfo()).version;

  /// 下载安装包，返回落盘文件。工作目录：<临时目录>/peixi_update/。
  /// - 同版本完整文件已存在 → 直接复用不重下；
  /// - .part 半截包保留作断点，下次带 Range 续拉（换镜像也续）；
  /// - 直连失败（超时/非 2xx/字节数不对）→ 依次换镜像前缀重试。
  Future<File> download(UpdateInfo info,
      {void Function(double progress)? onProgress, Directory? workDir}) async {
    final dir = workDir ?? await _updateWorkDir();
    await dir.create(recursive: true);
    final dest =
        File(p.join(dir.path, 'update-${info.versionCode}$assetExtension'));
    final part = File('${dest.path}.part');

    // 同版本完整文件复用
    if (dest.existsSync() &&
        info.size > 0 &&
        dest.lengthSync() == info.size) {
      onProgress?.call(1.0);
      return dest;
    }
    // 半截包已齐但没改名（上次收尾时被打断）→ 直接收用
    if (part.existsSync() && info.size > 0 && part.lengthSync() == info.size) {
      return _promotePart(part, dest);
    }
    // 半截包比预期还大 → 视为损坏，从头来
    if (part.existsSync() && info.size > 0 && part.lengthSync() > info.size) {
      part.deleteSync();
    }

    Object? lastError;
    for (final source in downloadCandidates(info.downloadUrl)) {
      try {
        await _downloadOne(source, dest, part, info, onProgress);
        await _cleanOldFiles(dir, keep: dest);
        return dest;
      } catch (e) {
        lastError = e; // .part 保留作断点，下一个源续拉
      }
    }
    throw UpdateException('下载失败：直连和镜像都拉不动（$lastError）。'
        '可稍后重试；或用浏览器打开下面的链接手动下载后覆盖安装：\n${info.downloadUrl}');
  }

  /// 下载候选源：直连在前，镜像按序兜底（测试可覆写指向本地假服务器）。
  List<String> downloadCandidates(String url) => [
        url,
        ...mirrors.map((m) => applyMirror(url, m)).nonNulls,
      ];

  Future<void> _downloadOne(String url, File dest, File part, UpdateInfo info,
      void Function(double)? onProgress) async {
    var existing = part.existsSync() ? part.lengthSync() : 0;
    final headers = <String, String>{'User-Agent': 'peixi-desktop-updater'};
    if (existing > 0) headers['Range'] = 'bytes=$existing-';

    final Response<ResponseBody> resp;
    try {
      resp = await _dio.get<ResponseBody>(url,
          options: Options(
            headers: headers,
            responseType: ResponseType.stream,
            // 收到非 2xx 直接抛（镜像挂了要换下一个，不能把错误页写进文件）
            validateStatus: (s) => s != null && s >= 200 && s < 300,
          ));
    } on DioException {
      rethrow;
    }
    if (resp.statusCode == 200 && existing > 0) {
      // 服务器不支持 Range（回了 200 全量）→ 丢弃旧断点从头下，自愈
      await part.writeAsBytes(const [], mode: FileMode.write);
      existing = 0;
    }

    var received = existing;
    final sink = part.openWrite(mode: FileMode.append);
    try {
      await for (final chunk in resp.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (info.size > 0) {
          onProgress?.call((received / info.size).clamp(0.0, 1.0));
        }
      }
    } finally {
      try {
        await sink.flush();
        await sink.close();
      } catch (_) {}
    }
    if (info.size > 0 && received != info.size) {
      throw UpdateException('收到的字节数不对（$received/${info.size}）');
    }
    _promotePart(part, dest);
  }

  File _promotePart(File part, File dest) {
    if (dest.existsSync()) dest.deleteSync();
    part.renameSync(dest.path);
    return dest;
  }

  /// 清理同目录下其他版本的安装包/断点，只留当前 [keep]。
  Future<void> _cleanOldFiles(Directory dir, {required File keep}) async {
    await for (final f in dir.list()) {
      if (f is! File) continue;
      final name = p.basename(f.path);
      if (f.path == keep.path) continue;
      if (name.startsWith('update-') &&
          (name.endsWith('.part') || name.endsWith(assetExtension))) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<Directory> _updateWorkDir() async {
    final tmp = await getTemporaryDirectory();
    return Directory(p.join(tmp.path, 'peixi_update'));
  }

  /// 应用更新（Windows）：解压到临时目录 → 生成替换批处理 → 分离进程执行。
  /// 批处理等待本程序退出后 robocopy 覆盖安装目录并重启；调用方随后 exit(0)。
  Future<void> applyUpdate(UpdateInfo info,
      {required File zip, String? installDir}) async {
    if (!Platform.isWindows) {
      throw UpdateException('当前平台暂不支持应用内更新，请手动安装新版本。');
    }
    final dir = installDir ?? p.dirname(Platform.resolvedExecutable);
    final exeName = p.basename(Platform.resolvedExecutable);
    final work = await _updateWorkDir();
    await work.create(recursive: true);
    final newDirPath = p.join(work.path, 'new-${info.versionCode}');
    final newDir = Directory(newDirPath);
    if (newDir.existsSync()) newDir.deleteSync(recursive: true);
    await extractFileToDisk(zip.path, newDirPath);

    // 归一化：若 zip 根只有一个子目录（整目录打包），进入那一层
    var root = newDirPath;
    final entries = await newDir.list().toList();
    final dirs = entries.whereType<Directory>().toList();
    final files = entries.whereType<File>().length;
    if (dirs.length == 1 && files == 0) root = dirs.single.path;

    final batPath = p.join(work.path, 'apply_update.bat');
    await File(batPath).writeAsString(buildUpdateBatScript(), flush: true);
    await Process.start('cmd.exe', ['/d', '/c', batPath, dir, root, exeName],
        mode: ProcessStartMode.detached, runInShell: false);
  }

  /// 替换批处理。内容必须纯 ASCII：cmd 按 GBK 解析批处理，中文会乱码；
  /// 路径经命令行参数（CreateProcessW，Unicode 安全）以 %~1 传入，不写进文件。
  @visibleForTesting
  static String buildUpdateBatScript() => '''
@echo off
setlocal enabledelayedexpansion
set "INSTALL_DIR=%~1"
set "NEW_DIR=%~2"
set "EXE=%~3"
set /a tries=0
:wait
tasklist /FI "IMAGENAME eq %EXE%" 2>nul | find /I "%EXE%" >nul
if errorlevel 1 goto apply
set /a tries+=1
if !tries! GEQ 120 goto fail
timeout /t 1 /nobreak >nul
goto wait
:apply
robocopy "%NEW_DIR%" "%INSTALL_DIR%" /MIR /R:2 /W:2 >nul
if errorlevel 8 goto fail
start "" "%INSTALL_DIR%\\%EXE%"
endlocal
exit /b 0
:fail
endlocal
exit /b 1
''';
}
