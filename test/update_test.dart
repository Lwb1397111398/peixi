import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peixi/core/update/update_checker.dart';
import 'package:peixi/core/update/update_service.dart';

void main() {
  group('parseUpdateMetadata', () {
    test('解析标准元数据行', () {
      final m = parseUpdateMetadata(
          '<!-- appupdate versionCode=21 versionName=0.1.21 -->\n\n更新内容');
      expect(m, isNotNull);
      expect(m!.versionCode, 21);
      expect(m.versionName, '0.1.21');
    });

    test('容忍多余空格', () {
      final m = parseUpdateMetadata(
          '<!--  appupdate  versionCode=3  versionName=0.1.3  -->');
      expect(m!.versionCode, 3);
    });

    test('元数据不在第一行则不认', () {
      expect(
          parseUpdateMetadata(
              '说明\n<!-- appupdate versionCode=9 versionName=x -->'),
          isNull);
    });

    test('空串/缺字段返回 null', () {
      expect(parseUpdateMetadata(''), isNull);
      expect(parseUpdateMetadata('<!-- appupdate versionName=0.1.1 -->'), isNull);
      expect(
          parseUpdateMetadata(
              '<!-- appupdate versionCode=abc versionName=x -->'),
          isNull);
    });
  });

  group('parseLatestReleaseJson', () {
    const fixture = '''
{
  "tag_name": "latest",
  "body": "<!-- appupdate versionCode=42 versionName=0.1.42 -->\\n\\n- 修复 A\\n- 新增 B",
  "assets": [
    {"name": "peixi-windows-x64.zip", "browser_download_url": "https://github.com/o/r/releases/download/latest/peixi-windows-x64.zip", "size": 123456},
    {"name": "notes.txt", "browser_download_url": "https://github.com/o/r/releases/download/latest/notes.txt", "size": 10}
  ]
}''';

    const androidFixture = '''
{
  "tag_name": "latest",
  "body": "<!-- appupdate versionCode=42 versionName=0.1.42 -->\\n\\n- 修复 A",
  "assets": [
    {"name": "peixi-windows-x64.zip", "browser_download_url": "https://github.com/o/r/releases/download/latest/peixi-windows-x64.zip", "size": 999999},
    {"name": "peixi-android-arm64.apk", "browser_download_url": "https://github.com/o/r/releases/download/latest/peixi-android-arm64.apk", "size": 654321}
  ]
}''';

    test('解析出版本与 zip 资产，说明里去掉元数据行', () {
      final r = parseLatestReleaseJson(fixture, assetExtension: '.zip');
      expect(r, isNotNull);
      expect(r!.versionCode, 42);
      expect(r.versionName, '0.1.42');
      expect(r.downloadUrl, contains('peixi-windows-x64.zip'));
      expect(r.size, 123456);
      expect(r.notes, isNot(contains('appupdate')));
      expect(r.notes, contains('新增 B'));
    });

    test('安卓按 .apk 挑资产：同 Release 里不串到 Windows zip', () {
      final r = parseLatestReleaseJson(androidFixture, assetExtension: '.apk');
      expect(r, isNotNull);
      expect(r!.downloadUrl, endsWith('peixi-android-arm64.apk'));
      expect(r.size, 654321);
      // 反向：Windows 客户端仍然只认 zip
      final w = parseLatestReleaseJson(androidFixture, assetExtension: '.zip');
      expect(w!.downloadUrl, endsWith('peixi-windows-x64.zip'));
    });

    test('没有 zip 资产 → null', () {
      const noAsset = '{"tag_name":"latest","body":"'
          '<!-- appupdate versionCode=1 versionName=0.1.1 -->",'
          '"assets":[{"name":"a.txt","browser_download_url":"https://x/a.txt"}]}';
      expect(parseLatestReleaseJson(noAsset, assetExtension: '.zip'), isNull);
    });

    test('没有元数据行 → null；非法 JSON → null', () {
      expect(
          parseLatestReleaseJson('{"body":"没有元数据"}', assetExtension: '.zip'),
          isNull);
      expect(parseLatestReleaseJson('not json{', assetExtension: '.zip'), isNull);
    });
  });

  group('isNewer / shouldAutoCheck / applyMirror', () {
    ParsedRelease rel(int code) => ParsedRelease(
        versionCode: code,
        versionName: '0.1.$code',
        downloadUrl: 'u',
        size: 0,
        notes: '');

    test('远端更大才算更新', () {
      expect(isNewer(rel(43), 42), isTrue);
      expect(isNewer(rel(42), 42), isFalse);
      expect(isNewer(rel(41), 42), isFalse);
    });

    test('从未检查过 → 查；24h 内 → 不查；超过 → 查', () {
      final now = DateTime(2026, 10, 25, 12);
      expect(shouldAutoCheck(null, now), isTrue);
      expect(
          shouldAutoCheck(
              now.subtract(const Duration(hours: 23)).millisecondsSinceEpoch,
              now),
          isFalse);
      expect(
          shouldAutoCheck(
              now.subtract(const Duration(hours: 25)).millisecondsSinceEpoch,
              now),
          isTrue);
    });

    test('镜像只拼 github.com 地址', () {
      expect(
          applyMirror('https://github.com/o/r/releases/download/latest/a.zip',
              'https://ghfast.top/'),
          'https://ghfast.top/https://github.com/o/r/releases/download/latest/a.zip');
      expect(applyMirror('http://127.0.0.1:8080/a.zip', 'https://ghfast.top/'),
          isNull);
      // 空镜像前缀 = 原样直连
      expect(applyMirror('http://127.0.0.1:8080/a.zip', ''),
          'http://127.0.0.1:8080/a.zip');
    });
  });

  group('buildUpdateBatScript', () {
    final s = UpdateService.buildUpdateBatScript();
    test('纯 ASCII（cmd 按 GBK 解析批处理，中文会乱码）', () {
      expect(s.codeUnits.every((c) => c < 128), isTrue);
    });
    test('等待退出 → robocopy /MIR 覆盖 → 重启', () {
      expect(s, contains('tasklist'));
      expect(s, contains('robocopy "%NEW_DIR%" "%INSTALL_DIR%" /MIR'));
      expect(s, contains('start "" "%INSTALL_DIR%\\%EXE%"'));
      expect(s, contains('exit /b 0'));
    });
  });

  group('平台资产与安卓安装分支', () {
    test('assetExtensionFor：Android=.apk，桌面=.zip', () {
      expect(UpdateService.assetExtensionFor(isAndroid: true), '.apk');
      expect(UpdateService.assetExtensionFor(isAndroid: false), '.zip');
    });

    test('applyUpdate 安卓分支：把 APK 交给安装器，不解压不退出', () async {
      final apk = File(
          '${Directory.systemTemp.createTempSync('peixi_apk').path}/update-42.apk')
        ..writeAsBytesSync(List.filled(64, 1));
      addTearDown(() => apk.parent.deleteSync(recursive: true));

      final received = <String>[];
      final svc = UpdateService(assetExtension: '.apk')
        ..androidInstaller = (f) async => received.add(f.path);
      await svc.applyUpdate(
          UpdateInfo(
              versionCode: 42,
              versionName: '0.1.42',
              downloadUrl: 'u',
              size: 0,
              notes: ''),
          zip: apk);
      expect(received.single, apk.path, reason: '下载落盘的 APK 原样交给系统安装器');
    });

    test('applyUpdate 安卓未授权：hook 抛出的提示原样透传给弹窗展示', () async {
      final apk = File(
          '${Directory.systemTemp.createTempSync('peixi_apk').path}/update-42.apk')
        ..writeAsBytesSync(List.filled(8, 1));
      addTearDown(() => apk.parent.deleteSync(recursive: true));

      final svc = UpdateService(assetExtension: '.apk')
        ..androidInstaller = (f) async =>
            throw UpdateException('需要先允许安装：请允许后回到应用，再点一次「安装」。');
      await expectLater(
          svc.applyUpdate(
              UpdateInfo(
                  versionCode: 42,
                  versionName: '0.1.42',
                  downloadUrl: 'u',
                  size: 0,
                  notes: ''),
              zip: apk),
          throwsA(isA<UpdateException>()
              .having((e) => e.message, 'msg', contains('允许安装'))));
    });
  });

  serviceTests();
}

/// 本地假 GitHub：/releases/latest 返回 fixture，/file.zip 支持 Range 续传。
class _FakeServer {
  _FakeServer._(this.payload);

  final Uint8List payload;
  late final HttpServer server;
  late final String base;
  int latestHits = 0;
  final List<String> rangeHeaders = [];
  int fileHits = 0;
  int errHits = 0;

  /// latest 接口固定回这个状态码（测 403/404 文案用），null = 正常 200。
  int? latestStatus;

  /// true = 无视 Range 头永远回 200 全量（模拟不支持断点续传的服务器）。
  bool ignoreRange = false;

  static Future<_FakeServer> start(
      {required int versionCode, Uint8List? payload}) async {
    final s = _FakeServer._(
        payload ?? Uint8List.fromList(List.generate(4096, (i) => i % 256)));
    s.server = await HttpServer.bind('127.0.0.1', 0);
    s.base = 'http://127.0.0.1:${s.server.port}';
    final meta =
        '<!-- appupdate versionCode=$versionCode versionName=0.1.$versionCode -->';
    s.server.listen((req) async {
      final path = req.uri.path;
      // 真实路径为 /repos/{owner}/{repo}/releases/latest，按后缀匹配
      if (path.endsWith('/releases/latest')) {
        s.latestHits++;
        if (s.latestStatus != null) {
          req.response.statusCode = s.latestStatus!;
          req.response.write('{}');
          await req.response.close();
          return;
        }
        final body = '''{
  "tag_name": "latest",
  "body": "$meta\\n\\n- 更新内容",
  "assets": [
    {"name": "peixi-windows-x64.zip",
     "browser_download_url": "${s.base}/file.zip",
     "size": ${s.payload.length}}
  ]
}''';
        req.response.headers
            .set('content-type', 'application/json; charset=utf-8');
        req.response.write(body);
        await req.response.close();
      } else if (path == '/file.zip') {
        s.fileHits++;
        final range =
            s.ignoreRange ? null : req.headers.value('range');
        s.rangeHeaders.add(range ?? '');
        if (range != null && range.startsWith('bytes=')) {
          final start = int.parse(range.substring(6).split('-').first);
          final rest = s.payload.sublist(start);
          req.response.statusCode = 206;
          req.response.headers.set('content-length', '${rest.length}');
          req.response.add(rest);
          await req.response.close();
        } else {
          req.response.statusCode = 200;
          req.response.headers.set('content-length', '${s.payload.length}');
          req.response.add(s.payload);
          await req.response.close();
        }
      } else if (path == '/err.zip') {
        s.errHits++;
        req.response.statusCode = 500;
        await req.response.close();
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });
    return s;
  }

  Future<void> close() => server.close(force: true);
}

/// 把下载候选重定向到本地假服务器的服务子类（绕过真实 github.com）。
class _LocalUpdateService extends UpdateService {
  _LocalUpdateService(this.server) : super(apiBase: server.base);

  final _FakeServer server;

  @override
  List<String> downloadCandidates(String url) => _candidates;

  List<String> _candidates = [];

  void useDefaultCandidate() => _candidates = ['${server.base}/file.zip'];
}

/// 服务层测试（由 main 末尾调用注册到测试框架）。
void serviceTests() {
  late _FakeServer server;
  late _LocalUpdateService svc;
  late Directory workDir;

  setUp(() async {
    server = await _FakeServer.start(versionCode: 42);
    svc = _LocalUpdateService(server);
    svc.useDefaultCandidate();
    workDir = await Directory.systemTemp.createTemp('peixi_update_test');
  });

  tearDown(() async {
    await server.close();
    await workDir.delete(recursive: true);
  });

  UpdateInfo infoOf(String url, {int size = 0, int versionCode = 42}) =>
      UpdateInfo(
          versionCode: versionCode,
          versionName: '0.1.$versionCode',
          downloadUrl: url,
          size: size,
          notes: '');


  test('check：远端更大 → 返回更新信息', () async {
    final info = await svc.check(currentVersionCode: 41);
    expect(info, isNotNull);
    expect(info!.versionCode, 42);
    expect(info.versionName, '0.1.42');
    expect(info.size, server.payload.length);
    expect(info.downloadUrl, '${server.base}/file.zip');
    expect(server.latestHits, 1);
  });

  test('check：远端不比本地新 → null', () async {
    expect(await svc.check(currentVersionCode: 42), isNull);
    expect(await svc.check(currentVersionCode: 43), isNull);
  });

  test('check：403 → 人话限流提示', () async {
    server.latestStatus = 403;
    await expectLater(svc.check(currentVersionCode: 1),
        throwsA(isA<UpdateException>().having((e) => e.message, 'msg', contains('限流'))));
  });

  test('check：404 → 人话「暂无发布」提示', () async {
    server.latestStatus = 404;
    await expectLater(svc.check(currentVersionCode: 1),
        throwsA(isA<UpdateException>().having((e) => e.message, 'msg', contains('暂无'))));
  });

  test('download：全量下载落盘，.part 不残留，进度到 1.0', () async {
    final maxProgress = <double>[];
    final f = await svc.download(
        infoOf('https://github.com/o/r/releases/download/latest/a.zip',
            size: server.payload.length),
        onProgress: maxProgress.add,
        workDir: workDir);
    expect(f.readAsBytesSync(), server.payload);
    expect(File('${f.path}.part').existsSync(), isFalse);
    expect(maxProgress.last, 1.0);
  });

  test('download：半截包带 Range 续传，拼回完整文件', () async {
    final half = server.payload.length ~/ 2;
    final part = File('${workDir.path}/update-42.zip.part');
    await part.writeAsBytes(server.payload.sublist(0, half));
    final f = await svc.download(
        infoOf('https://github.com/o/r/releases/download/latest/a.zip',
            size: server.payload.length),
        workDir: workDir);
    expect(f.readAsBytesSync(), server.payload);
    expect(server.rangeHeaders.single, 'bytes=$half-');
  });

  test('download：服务器不支持 Range（回 200 全量）→ 从头下自愈', () async {
    final half = server.payload.length ~/ 2;
    server.ignoreRange = true; // 有断点也不认，回 200 全量
    final part = File('${workDir.path}/update-42.zip.part');
    await part.writeAsBytes(server.payload.sublist(0, half));
    final f = await svc.download(
        infoOf('https://github.com/o/r/releases/download/latest/a.zip',
            size: server.payload.length),
        workDir: workDir);
    expect(f.readAsBytesSync(), server.payload); // 没把断点拼在全量后面
  });

  test('download：同版本完整文件已存在 → 复用不联网', () async {
    final dest = File(p.join(workDir.path, 'update-42.zip'));
    await dest.writeAsBytes(server.payload);
    final f = await svc.download(
        infoOf('https://github.com/o/r/releases/download/latest/a.zip',
            size: server.payload.length),
        workDir: workDir);
    expect(f.path, dest.path);
    expect(server.fileHits, 0);
  });

  test('download：直连 500 → 兜底候选接手', () async {
    svc._candidates = ['${server.base}/err.zip', '${server.base}/file.zip'];
    final f = await svc.download(
        infoOf('https://github.com/o/r/releases/download/latest/a.zip',
            size: server.payload.length),
        workDir: workDir);
    expect(f.readAsBytesSync(), server.payload);
    expect(server.errHits, 1);
  });

  test('download：全部源失败 → 人话汇总异常，.part 保留', () async {
    svc._candidates = ['${server.base}/err.zip'];
    await expectLater(
        svc.download(
            infoOf('https://github.com/o/r/releases/download/latest/a.zip',
                size: server.payload.length),
            workDir: workDir),
        throwsA(isA<UpdateException>()
            .having((e) => e.message, 'msg', contains('下载失败'))));
    expect(server.errHits, 1);
  });
}