import 'dart:io';

import 'package:dio/dio.dart';

/// 应用内下载 sherpa-onnx 本地 ASR 模型（paraformer-zh-2024-03-09 int8）。
///
/// 与 tool/download-sherpa-model.sh 同源策略：hf-mirror 优先、失败回退
/// huggingface；流式落盘（写 .part 后原子改名，不整包进内存），完成后按
/// 大小粗校验（模型 ≥ [minModelBytes]，tokens 非空）。
class AsrModelDownloader {
  AsrModelDownloader({Dio? dio, List<String>? mirrors, int? minModelBytes})
      : dio = dio ?? Dio(),
        mirrors = mirrors ?? defaultMirrors,
        minModelBytes = minModelBytes ?? _defaultMinModelBytes;

  static const repo = 'csukuangfj/sherpa-onnx-paraformer-zh-2024-03-09';

  /// 与脚本一致：国内镜像优先
  static final defaultMirrors = <String>[
    'https://hf-mirror.com/$repo/resolve/main',
    'https://huggingface.co/$repo/resolve/main',
  ];

  static const files = ['tokens.txt', 'model.int8.onnx'];
  static const _defaultMinModelBytes = 10 * 1024 * 1024; // onnx 远大于 10MB

  final Dio dio;
  final List<String> mirrors;
  final int minModelBytes;

  /// 下载所有缺失文件到 [targetDir]（已存在且校验通过的文件跳过）。
  /// [onProgress] 按文件回报累计字节（total 可能为 -1：镜像未回 Content-Length）。
  /// 任一文件所有镜像均失败 → 抛 [AsrModelDownloadException]，.part 已清理。
  Future<void> download(
    String targetDir, {
    void Function(AsrModelDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await Directory(targetDir).create(recursive: true);
    for (final file in files) {
      final finalPath = '$targetDir/$file';
      if (_isValid(finalPath, file)) continue;
      await _fetchFile(targetDir, file, onProgress, cancelToken);
    }
  }

  Future<void> _fetchFile(
    String targetDir,
    String file,
    void Function(AsrModelDownloadProgress)? onProgress,
    CancelToken? cancelToken,
  ) async {
    final finalPath = '$targetDir/$file';
    final partPath = '$finalPath.part';
    Object? lastError;
    for (final mirror in mirrors) {
      try {
        await dio.download('$mirror/$file', partPath,
            cancelToken: cancelToken,
            onReceiveProgress: (received, total) => onProgress?.call(
                AsrModelDownloadProgress(
                    file: file, received: received, total: total)),
            options: Options(
              validateStatus: (s) => s != null && s >= 200 && s < 300,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            ));
        _validateOrThrow(partPath, file);
        File(partPath).renameSync(finalPath);
        return;
      } on DioException catch (e) {
        // 用户主动取消：直接上抛，不算镜像失败
        if (cancelToken?.isCancelled ?? false) rethrow;
        lastError = e;
      } on FileSystemException catch (e) {
        lastError = e;
      }
      _tryDelete(partPath);
    }
    throw AsrModelDownloadException(
        '下载 $file 失败（${mirrors.length} 个镜像均不可达）：$lastError');
  }

  /// 与 LocalAsrClient.isReady 同口径的存在性 + 大小校验
  bool _isValid(String path, String file) {
    try {
      _validateOrThrow(path, file);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  void _validateOrThrow(String path, String file) {
    final len = File(path).lengthSync();
    final ok = file == 'tokens.txt' ? len > 0 : len >= minModelBytes;
    if (!ok) {
      throw FileSystemException('下载内容不完整（$file 仅 $len 字节）', path);
    }
  }

  void _tryDelete(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}

/// 单文件下载进度（received 为该文件累计字节）
class AsrModelDownloadProgress {
  const AsrModelDownloadProgress(
      {required this.file, required this.received, required this.total});
  final String file;
  final int received;
  final int total;
}

class AsrModelDownloadException implements Exception {
  AsrModelDownloadException(this.message);
  final String message;
  @override
  String toString() => 'AsrModelDownloadException: $message';
}
