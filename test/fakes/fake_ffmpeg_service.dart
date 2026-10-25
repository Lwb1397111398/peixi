import 'dart:io';

import 'package:peixi/core/media/ffmpeg_service.dart';

/// 管线测试用假 ffmpeg：跳过真实转码，直接生成占位音频文件。
class FakeFFmpegService implements FFmpegService {
  FakeFFmpegService({this.durationMs = 2700000, this.hasSubtitle = false});

  final int durationMs;
  final bool hasSubtitle;
  int extractCalls = 0;
  Object? Function(String input, String output)? onExtract;
  Object? Function(String path)? onProbe;

  @override
  Future<MediaInfo> probe(String path) async {
    final err = onProbe?.call(path);
    if (err != null) throw err;
    return MediaInfo(durationMs: durationMs, hasSubtitle: hasSubtitle);
  }

  @override
  Future<void> extractAudio(String input, String output,
      {void Function(double)? onProgress}) async {
    extractCalls++;
    final err = onExtract?.call(input, output);
    if (err != null) throw err;
    final f = File(output);
    f.createSync(recursive: true);
    f.writeAsBytesSync(List.filled(1024, 0));
    onProgress?.call(1.0);
  }

  @override
  Future<String?> extractSubtitle(String input, String outputSrt) async {
    if (!hasSubtitle) return null;
    final f = File(outputSrt);
    f.createSync(recursive: true);
    f.writeAsStringSync('1\n00:00:01,000 --> 00:00:02,000\n测试字幕\n');
    return f.readAsStringSync();
  }

  int keyframeCalls = 0;
  final keyframeTimes = <int>[];

  @override
  void cancelActive() {
    cancelCalls++;
  }

  int cancelCalls = 0;

  @override
  Future<void> extractKeyframe(
      String input, int timeMs, String outputJpg) async {
    keyframeCalls++;
    keyframeTimes.add(timeMs);
    File(outputJpg)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(32, 3));
  }
}
