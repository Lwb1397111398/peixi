import 'dart:convert';
import 'dart:io';

import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/media/ffmpeg_service.dart';

/// M3 实验性视觉辅助（设计稿 M3："抽关键帧交 qwen-vl 判断谁在说话，
/// 用于降低校准率"）。
/// 对每个声音簇：取其最长代表台词的中点时刻抽 1 帧 jpg → base64 →
/// 视觉模型（chatVision）在候选名单内判断画面人物 → 建议（不自动改名）。
/// 任何一簇失败都跳过，不影响其他簇。
class VisualAssistant {
  VisualAssistant({
    required this.db,
    required this.llm,
    required this.ffmpeg,
    required this.videoPath,
    required this.frameDir,
  });

  final AppDatabase db;
  final LlmService llm;
  final FFmpegService ffmpeg;
  final String videoPath;
  final String frameDir;

  Future<({int charId, String name, String? suggestion, String? reason})>
      suggestFor({
    required int charId,
    required String name,
    required Segment sampleLine,
    required List<String> candidates,
  }) async {
    Directory(frameDir).createSync(recursive: true);
    final framePath = '$frameDir/va_$charId.jpg';
    try {
      final mid = (sampleLine.startMs + sampleLine.endMs) ~/ 2;
      await ffmpeg.extractKeyframe(videoPath, mid, framePath);
      final b64 = base64Encode(File(framePath).readAsBytesSync());
      final ts = _formatTs(mid);
      final result = await llm.chatVision(
        prompt:
            '你是影视画面分析助手。这是剧集在第 $ts 的一帧画面。\n'
            '[候选角色名单]\n${candidates.join('\n')}\n'
            '[声音簇当前名字]$name\n'
            '任务：判断这一帧画面中最显眼、正在说话可能性最高的人物最像名单中的谁。\n'
            '输出：{"name":"名单中的名字","reason":"30字内依据"}\n'
            '要求：若画面中没有人、多人无法区分或无把握，输出 {"name":"无法判断","reason":"..."}。'
            '禁止编造名单之外的名字。',
        imageDataUri: 'data:image/jpeg;base64,$b64',
        purpose: 'visual_assist',
        projectId: sampleLine.projectId,
      );
      final parsed = _parseJson(result);
      final suggestion = (parsed?['name'] ?? '').toString().trim();
      final reason = (parsed?['reason'] ?? '').toString().trim();
      final valid = suggestion.isNotEmpty &&
          suggestion != '无法判断' &&
          candidates.contains(suggestion);
      return (
        charId: charId,
        name: name,
        suggestion: valid ? suggestion : null,
        reason: valid ? reason : '无法判断',
      );
    } catch (e) {
      return (charId: charId, name: name, suggestion: null, reason: '分析失败：$e');
    } finally {
      final f = File(framePath);
      if (f.existsSync()) f.deleteSync();
    }
  }

  Map<String, dynamic>? _parseJson(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        return jsonDecode(raw.substring(start, end + 1))
            as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  String _formatTs(int ms) {
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
