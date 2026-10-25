import 'dart:convert';

import 'package:peixi/core/novel/gbk_table.dart';

/// N1 小说解析：编码检测 + 段落切分 + 章节切分（卷/章两级）。
class NovelChapter {
  const NovelChapter({
    required this.idx,
    this.title,
    this.volume,
    required this.paragraphs,
  });
  final int idx;

  /// 章标题（兜底分块时为 null）。
  final String? title;

  /// 所属卷标题（「第一卷 风起」「Part II」等；无卷结构为 null）。
  final String? volume;
  final List<String> paragraphs;
}

class NovelDoc {
  const NovelDoc({required this.chapters});
  final List<NovelChapter> chapters;
  int get paragraphCount =>
      chapters.fold(0, (n, c) => n + c.paragraphs.length);
  int get charCount => chapters.fold(
      0,
      (n, c) =>
          n + c.paragraphs.fold(0, (m, p) => m + p.length));
}

/// 编码检测：UTF-8 严格解码，失败则按 GBK（表驱动，覆盖 GB18030 常用字）。
/// （偏离：gbk_codec 0.4.0 解码器逐单字节查表、双字节合并逻辑缺失，实测对真实
/// GBK 文件输出乱码，已替换为按 Python 标准编解码器导出的精确映射表。）
String decodeNovelText(List<int> bytes) {
  try {
    return utf8.decode(bytes); // 严格模式，非法字节抛 FormatException
  } on FormatException {
    return gbkDecodeBytes(bytes);
  }
}

/// GBK 字节流解码：ASCII 直取，双字节查 [kGbkTable]，
/// 非法序列以 U+FFFD 占位（不抛异常，尽量保留可读内容）。
String gbkDecodeBytes(List<int> bytes) {
  final sb = StringBuffer();
  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b < 0x80) {
      sb.writeCharCode(b);
      i++;
      continue;
    }
    if (b == 0x80) {
      // CP936 单字节欧元符
      sb.writeCharCode(0x20AC);
      i++;
      continue;
    }
    if (i + 1 < bytes.length) {
      final ch = kGbkTable[(b << 8) | bytes[i + 1]];
      if (ch != null) {
        sb.write(ch);
        i += 2;
        continue;
      }
    }
    sb.writeCharCode(0xFFFD);
    i++;
  }
  return sb.toString();
}

// ---------- 行分类正则（均 ^ 锚定 + 限长防误切叙事句） ----------

// 卷标题：第X卷/部/册、上/中/下卷册部；副题需以空白或标点开头（「第二卷的故事」不匹配）。
final _volumeHeadingRe = RegExp(
    r'^(第[〇零一二三四五六七八九十百千两0-9]{1,7}[卷部册]|[上中下][卷册部])'
    r'([\s：:．.·—-].*)?$');

// 英文数词（卷/章号用，one~twenty + first~twelfth 覆盖绝大多数原版书）。
const _enNumberWords = 'One|Two|Three|Four|Five|Six|Seven|Eight|Nine|Ten|'
    'Eleven|Twelve|Thirteen|Fourteen|Fifteen|Sixteen|Seventeen|Eighteen|'
    'Nineteen|Twenty|'
    'First|Second|Third|Fourth|Fifth|Sixth|Seventh|Eighth|Ninth|Tenth|'
    'Eleventh|Twelfth';

// 英文标题行结构探测：Part/Book/Chapter + 号（数字/罗马/英文数词），或
// Prologue/Epilogue 等惯用词。caseInsensitive 兼容 CHAPTER/chapter。
// 注意：raw 字符串里 $ 插值不生效，数词表须用普通字符串插值单独拼接。
final _enHeadingProbeRe = RegExp(
    r'^(Part|Book|Chapter)\s+'
    r'([0-9]{1,4}|[IVXLCDMivxlcdm]{1,7}|'
    '$_enNumberWords'
    r')(.*)$'
    r'|^(Prologue|Epilogue|Preface|Foreword|Afterword|Introduction)(.*)$',
    caseSensitive: false);

// 副题合法形态：空、标点开头（「Chapter 5: The End」）、或空格+大写字母/
// 数字/连字符开头（「Chapter 1 The Boy」/「Chapter Five - Dawn」，标题词
// 首字母大写）。空格+小写开头是叙事句（「Part Two of the trilogy was
// better」），不认——大小写检查须敏感，故与 probe 分开。
final _enHeadingSuffixPunct = RegExp(r'^[：:．.·—\-－]');
final _enHeadingSuffixTitle = RegExp(r'^ [A-Z0-9\-—]');

/// 英文标题行分类：Part/Book → 卷；Chapter/Prologue 等 → 章；非标题 → null。
_LineKind? _enHeadingKind(String t) {
  final m = _enHeadingProbeRe.firstMatch(t);
  if (m == null) return null;
  final suffix = m.group(3) ?? m.group(5)!;
  final suffixOk = suffix.isEmpty ||
      _enHeadingSuffixPunct.hasMatch(suffix) ||
      _enHeadingSuffixTitle.hasMatch(suffix);
  if (!suffixOk) return null;
  final head = m.group(1);
  if (head == null) return _LineKind.chapter; // Prologue/Epilogue 等
  final h = head.toLowerCase();
  return (h == 'part' || h == 'book') ? _LineKind.volume : _LineKind.chapter;
}

// 中文章标题：第X章/回/节/话（含日文「話」），或 楔子/序章/引子/尾声/终章/
// 番外/正文/序言/前言/后记/完结 等惯用单行标题。
final _chapterHeadingRe = RegExp(
    r'^(第[〇零一二三四五六七八九十百千两0-9]{1,7}[章回节话話]'
    r'|楔子|序章|引子|尾声|终章|番外|正文|序言|前言|后记|完结)'
    r'([\s：:．.·—-].*)?$');

// 数字裸标题（「1.」「一、」「01.」）：误切风险高（正文列表项同形），
// 仅当全书找不到任何卷/章锚点时才作为兜底切分。
final _bareNumberHeadingRe =
    RegExp(r'^([0-9]{1,4}|[〇零一二三四五六七八九十百]{1,4})[.、．].{0,38}$');

/// 章标题行不应是正文段落，限长防止误伤叙事句。
const _maxHeadingLength = 40;

/// 无章标题时的兜底分块目标大小。
const _fallbackChunkChars = 2000;

enum _LineKind { plain, volume, chapter }

/// 卷/章标题行统一在这里分类（卷优先于章：「第一卷」只当卷，不当章切）。
_LineKind _classifyHeadingLine(String t) {
  if (t.length > _maxHeadingLength) return _LineKind.plain;
  if (_volumeHeadingRe.hasMatch(t)) return _LineKind.volume;
  if (_chapterHeadingRe.hasMatch(t)) return _LineKind.chapter;
  return _enHeadingKind(t) ?? _LineKind.plain;
}

NovelDoc parseNovel(String raw) {
  final text = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceFirst('\uFEFF', '');
  final lines = text.split('\n');

  final paragraphs = <String>[];
  final kinds = <_LineKind>[];
  for (final line in lines) {
    final t = line.trim().replaceAll('\u3000', ' ').trim();
    if (t.isEmpty) continue;
    paragraphs.add(t);
    kinds.add(_classifyHeadingLine(t));
  }

  final hasAnchor =
      kinds.contains(_LineKind.volume) || kinds.contains(_LineKind.chapter);
  if (!hasAnchor) {
    // 全书无卷/章锚点：数字裸标题降级为章锚点，避免整本走 2000 字盲切
    for (var i = 0; i < paragraphs.length; i++) {
      if (_bareNumberHeadingRe.hasMatch(paragraphs[i])) {
        kinds[i] = _LineKind.chapter;
      }
    }
  }

  if (kinds.contains(_LineKind.volume) ||
      kinds.contains(_LineKind.chapter)) {
    return NovelDoc(chapters: _splitByHeadings(paragraphs, kinds));
  }
  return NovelDoc(chapters: _chunkBySize(paragraphs));
}

/// 按卷/章锚点切分：卷标题行只更新归属卷（不占章）；卷标题下直接接正文时，
/// 以卷标题为章名生成一章。章标题下无正文也保留空章（保留标题信息）。
List<NovelChapter> _splitByHeadings(
    List<String> paragraphs, List<_LineKind> kinds) {
  final chapters = <NovelChapter>[];
  String? currentVolume;
  var buf = <String>[];
  String? pendingTitle;
  var pendingIsVolume = false;

  void flush() {
    if (pendingTitle == null && buf.isEmpty) return;
    if (pendingIsVolume && buf.isEmpty) return; // 纯卷头不生成章
    chapters.add(NovelChapter(
        idx: chapters.length,
        title: pendingTitle,
        volume: currentVolume,
        paragraphs: buf));
    buf = <String>[];
    pendingTitle = null;
    pendingIsVolume = false;
  }

  for (var i = 0; i < paragraphs.length; i++) {
    switch (kinds[i]) {
      case _LineKind.volume:
        flush();
        currentVolume = paragraphs[i];
        pendingTitle = paragraphs[i];
        pendingIsVolume = true;
      case _LineKind.chapter:
        flush();
        pendingTitle = paragraphs[i];
        pendingIsVolume = false;
      case _LineKind.plain:
        buf.add(paragraphs[i]);
    }
  }
  flush();
  return chapters;
}

List<NovelChapter> _chunkBySize(List<String> paragraphs) {
  if (paragraphs.isEmpty) return const [];
  final chapters = <NovelChapter>[];
  var buf = <String>[];
  var bufChars = 0;
  for (final para in paragraphs) {
    buf.add(para);
    bufChars += para.length;
    if (bufChars >= _fallbackChunkChars) {
      chapters.add(NovelChapter(
          idx: chapters.length, title: null, paragraphs: buf));
      buf = <String>[];
      bufChars = 0;
    }
  }
  if (buf.isNotEmpty) {
    if (bufChars < _fallbackChunkChars ~/ 5 && chapters.isNotEmpty) {
      // 尾块太小并入上一章
      final last = chapters.last;
      chapters[chapters.length - 1] = NovelChapter(
          idx: last.idx,
          title: last.title,
          volume: last.volume,
          paragraphs: [...last.paragraphs, ...buf]);
    } else {
      chapters.add(NovelChapter(
          idx: chapters.length, title: null, paragraphs: buf));
    }
  }
  return chapters;
}
