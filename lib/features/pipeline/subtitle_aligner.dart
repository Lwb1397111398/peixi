import 'package:peixi/core/asr/asr_types.dart';
import 'package:peixi/core/media/ffmpeg_service.dart';

/// 内嵌字幕 ↔ ASR 语句的交叉纠错（纯函数）。
///
/// 内嵌字幕（尤其人工校对过的）文本质量通常高于 ASR，按时间重叠把
/// 字幕文本替换进 ASR 句子；时间轴与说话人 id 保持 ASR 原值，
/// 因此场景切分与角色映射不受影响、只提升后续 LLM 输入质量。
///
/// 守卫（避免"英文替换中文"式的灾难性纠错）：
/// - 配对门槛：字幕与 ASR 句的交集时长 / ASR 句时长 ≥ 0.7；
/// - CJK 比例守卫：ASR 侧以中日韩为主而候选字幕几乎无 CJK 时跳过
///   （单句级 + 整体级两层判断）；
/// - 多行字幕合并成一行、剔除空白后为空则不替换。
List<AsrSentence> correctWithSubtitles(
    List<AsrSentence> sentences, List<SubtitleEntry> subtitles,
    {double minOverlap = 0.7}) {
  if (sentences.isEmpty || subtitles.isEmpty) return sentences;

  // 整体级 CJK 守卫：全片字幕几乎无 CJK 而 ASR 以 CJK 为主 → 英文字幕，整体放弃
  final subCjk = _avgCjk([for (final e in subtitles) e.text]);
  final asrCjk = _avgCjk([for (final s in sentences) s.text]);
  if (asrCjk > 0.3 && subCjk < 0.1) return sentences;

  return [
    for (final s in sentences) _correctOne(s, subtitles, minOverlap),
  ];
}

AsrSentence _correctOne(
    AsrSentence s, List<SubtitleEntry> subs, double minOverlap) {
  final duration = s.endMs - s.beginMs;
  if (duration <= 0) return s;
  SubtitleEntry? best;
  var bestRatio = 0.0;
  for (final e in subs) {
    final overlap = _overlapMs(s.beginMs, s.endMs, e.startMs, e.endMs);
    final ratio = overlap / duration;
    if (ratio > bestRatio) {
      bestRatio = ratio;
      best = e;
    }
  }
  if (best == null || bestRatio < minOverlap) return s;
  final text = best.text.replaceAll('\n', '').trim();
  if (text.isEmpty) return s;
  if (_cjkRatio(s.text) > 0.3 && _cjkRatio(text) < 0.1) return s;
  return AsrSentence(
      beginMs: s.beginMs, endMs: s.endMs, text: text, speakerId: s.speakerId);
}

int _overlapMs(int aStart, int aEnd, int bStart, int bEnd) {
  final lo = aStart > bStart ? aStart : bStart;
  final hi = aEnd < bEnd ? aEnd : bEnd;
  return hi > lo ? hi - lo : 0;
}

double _cjkRatio(String s) {
  if (s.isEmpty) return 0;
  var count = 0;
  for (final r in s.runes) {
    // CJK 统一表意文字 + 扩展A + 兼容表意文字
    if ((r >= 0x4E00 && r <= 0x9FFF) ||
        (r >= 0x3400 && r <= 0x4DBF) ||
        (r >= 0xF900 && r <= 0xFAFF)) {
      count++;
    }
  }
  return count / s.length;
}

double _avgCjk(List<String> texts) {
  if (texts.isEmpty) return 0;
  return texts.map(_cjkRatio).fold(0.0, (a, b) => a + b) / texts.length;
}
