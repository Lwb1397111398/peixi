import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// S1/S2/S3 的 ffmpeg 能力门面。真实实现走 ffmpeg_kit；测试用 Fake。
class MediaInfo {
  const MediaInfo(
      {required this.durationMs, required this.hasSubtitle, this.subtitleCodec});
  final int durationMs;
  final bool hasSubtitle;
  final String? subtitleCodec;
}

/// SRT 字幕条目（S2 解析产物，存 metaJson）
class SubtitleEntry {
  const SubtitleEntry(
      {required this.startMs, required this.endMs, required this.text});
  final int startMs;
  final int endMs;
  final String text;

  Map<String, dynamic> toJson() =>
      {'startMs': startMs, 'endMs': endMs, 'text': text};

  static SubtitleEntry fromJson(Map<String, dynamic> j) => SubtitleEntry(
      startMs: j['startMs'] as int,
      endMs: j['endMs'] as int,
      text: j['text'] as String);
}

/// 音频产出格式（S3）：按容器内可用编码器在运行时决定。
enum AudioFormat { mp3, m4a, wav }

extension AudioFormatX on AudioFormat {
  String get ext => name;
}

abstract class FFmpegService {
  Future<MediaInfo> probe(String path);
  Future<void> extractAudio(String input, String output,
      {void Function(double)? onProgress});
  Future<String?> extractSubtitle(String input, String outputSrt);
  Future<AudioFormat> pickAudioFormat();

  /// 抽取指定时间点的一帧 jpg（M3 实验性视觉辅助）
  Future<void> extractKeyframe(
      String input, int timeMs, String outputJpg);

  /// 中止当前所有进行中的会话（取消处理用）
  void cancelActive();
}

class FFmpegKitService implements FFmpegService {
  List<String>? _encodersCache;

  @override
  Future<MediaInfo> probe(String path) async {
    final MediaInformationSession session =
        await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) {
      throw Exception('无法读取媒体信息（文件损坏或格式不支持）：$path');
    }
    final durationSec = double.tryParse(info.getDuration() ?? '') ?? 0;
    var hasSubtitle = false;
    String? subtitleCodec;
    for (final s in info.getStreams()) {
      if (s.getType() == 'subtitle') {
        hasSubtitle = true;
        subtitleCodec ??= s.getCodec();
      }
    }
    return MediaInfo(
        durationMs: (durationSec * 1000).round(),
        hasSubtitle: hasSubtitle,
        subtitleCodec: subtitleCodec);
  }

  @override
  Future<AudioFormat> pickAudioFormat() async {
    // ffmpeg-kit 变体可能裁掉 libmp3lame；探测后按优先级选（设计稿允许 48-64kbps 压缩音频）。
    final encoders = await _encoders();
    if (encoders.contains('libmp3lame')) return AudioFormat.mp3;
    if (encoders.any((e) => e.startsWith('aac'))) return AudioFormat.m4a;
    return AudioFormat.wav;
  }

  Future<List<String>> _encoders() async {
    if (_encodersCache != null) return _encodersCache!;
    final session = await FFmpegKit.execute('-hide_banner -encoders');
    final logs = await session.getAllLogsAsString();
    final lines = logs?.split('\n') ?? const <String>[];
    // 每行形如 " A..... libmp3lame   ... MP3 (MPEG audio layer 3)"
    _encodersCache = [
      for (final line in lines)
        if (line.length > 8 && RegExp(r'^ [A-Z.]{6} \S+').hasMatch(line))
          line.substring(8).trim().split(RegExp(r'\s+')).first,
    ];
    return _encodersCache!;
  }

  @override
  Future<void> extractAudio(String input, String output,
      {void Function(double)? onProgress}) async {
    final encoders = await _encoders();
    final ext = output.split('.').last;
    final codecArgs = switch (ext) {
      'mp3' => ['-c:a', 'libmp3lame', '-b:a', '48k'],
      'm4a' => ['-c:a', 'aac', '-b:a', '48k'],
      _ => ['-c:a', 'pcm_s16le'],
    };
    if (ext == 'mp3' && !encoders.contains('libmp3lame')) {
      throw Exception('当前 ffmpeg 构建缺少 mp3 编码器');
    }
    final totalMs = await _durationOf(input);
    final done = Completer<void>();
    // 先写 .part 临时文件、成功后改名：中途被杀/失败只留 .part，
    // 不会让下游 existsSync() 把半截音频当成完整缓存。
    // .part 不是已知容器后缀，必须用 -f 显式指定封装格式
    final format = switch (ext) {
      'mp3' => 'mp3',
      'm4a' => 'ipod', // aac 的 m4a 封装 muxer 名
      _ => 'wav',
    };
    final part = '$output.part';
    try {
      final args =
          '-y -i "$input" -vn -ac 1 -ar 16000 ${codecArgs.join(' ')} '
          '-f $format "$part"';
      await FFmpegKit.executeAsync(
        args,
        (s) {
          s.getReturnCode().then((code) {
            if (done.isCompleted) return;
            if (code != null && ReturnCode.isSuccess(code)) {
              done.complete();
            } else {
              done.completeError(
                  Exception('音频抽取失败 rc=${code?.getValue()}'));
            }
          });
        },
        null,
        (onProgress != null && totalMs > 0)
            ? (stats) {
                final t = stats.getTime();
                if (t > 0) onProgress((t / totalMs).clamp(0.0, 1.0));
              }
            : null,
      );
      await done.future;
      await File(part).rename(output);
    } catch (e) {
      final f = File(part);
      if (f.existsSync()) f.deleteSync();
      rethrow;
    }
  }

  Future<int> _durationOf(String input) async {
    try {
      return (await probe(input)).durationMs;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> extractKeyframe(
      String input, int timeMs, String outputJpg) async {
    final done = Completer<void>();
    final seconds = (timeMs / 1000).toStringAsFixed(2);
    await FFmpegKit.executeAsync(
      '-y -ss $seconds -i "$input" -frames:v 1 -q:v 3 "$outputJpg"',
      (s) {
        s.getReturnCode().then((code) {
          if (done.isCompleted) return;
          if (code != null && ReturnCode.isSuccess(code)) {
            done.complete();
          } else {
            done.completeError(
                Exception('抽帧失败 rc=${code?.getValue()}'));
          }
        });
      },
      null,
      null,
    );
    return done.future;
  }

  @override
  void cancelActive() => FFmpegKit.cancel();

  @override
  Future<String?> extractSubtitle(String input, String outputSrt) async {
    // S2：无字幕流或提取失败均返回 null，不阻塞主线
    final session = await FFmpegKit
        .execute('-y -i "$input" -map 0:s:0 -c:s srt "$outputSrt"');
    final code = await session.getReturnCode();
    if (code == null || !ReturnCode.isSuccess(code)) return null;
    final f = File(outputSrt);
    if (!f.existsSync()) return null;
    final text = f.readAsStringSync();
    return text.isEmpty ? null : text;
  }
}

/// 标准 SRT → 条目列表。容错：CRLF/BOM。
List<SubtitleEntry> parseSrt(String srt) {
  final text = srt.replaceFirst('\uFEFF', '');
  final blocks = text.split(RegExp(r'\r?\n\r?\n'));
  final result = <SubtitleEntry>[];
  final ts = RegExp(
      r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})');
  int ms(int h, int mi, int s, int ms_) => ((h * 60 + mi) * 60 + s) * 1000 + ms_;
  for (final b in blocks) {
    final m = ts.firstMatch(b);
    if (m == null) continue;
    final start = ms(int.parse(m.group(1)!), int.parse(m.group(2)!),
        int.parse(m.group(3)!), int.parse(m.group(4)!));
    final end = ms(int.parse(m.group(5)!), int.parse(m.group(6)!),
        int.parse(m.group(7)!), int.parse(m.group(8)!));
    final body =
        b.substring(m.end).trim().replaceAll(RegExp(r'\r?\n'), '\n');
    if (body.isNotEmpty) {
      result.add(SubtitleEntry(startMs: start, endMs: end, text: body));
    }
  }
  return result;
}
