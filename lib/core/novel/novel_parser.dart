import 'dart:convert';

import 'package:peixi/core/novel/gbk_table.dart';

/// N1 小说解析：编码检测 + 段落切分 + 章节切分。
class NovelChapter {
  const NovelChapter({required this.idx, this.title, required this.paragraphs});
  final int idx;
  final String? title;
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

// 章标题：第X章/回/卷/节，或 楔子/序章/引子/尾声/终章/番外 等惯用标题。
final _chapterHeadingRe = RegExp(
    r'^(第[〇零一二三四五六七八九十百千两0-9]{1,7}[章回卷节]|楔子|序章|引子|尾声|终章|番外)([\s：:．.·—-].*)?$');

/// 章标题行不应是正文段落，限长防止误伤叙事句。
const _maxHeadingLength = 40;

/// 无章标题时的兜底分块目标大小。
const _fallbackChunkChars = 2000;

NovelDoc parseNovel(String raw) {
  final text = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceFirst('\uFEFF', '');
  final lines = text.split('\n');

  final paragraphs = <String>[];
  final isHeading = <bool>[];
  for (final line in lines) {
    final t = line.trim().replaceAll('\u3000', ' ').trim();
    if (t.isEmpty) continue;
    paragraphs.add(t);
    isHeading.add(_chapterHeadingRe.hasMatch(t) && t.length <= _maxHeadingLength);
  }

  final headingIdx = <int>[
    for (var i = 0; i < paragraphs.length; i++)
      if (isHeading[i]) i
  ];

  // 锚定正则 + 标题限长已足够防误切，单个标题也按章切（保留标题信息）
  if (headingIdx.isNotEmpty) {
    return NovelDoc(chapters: _splitByHeadings(paragraphs, headingIdx));
  }
  return NovelDoc(chapters: _chunkBySize(paragraphs));
}

List<NovelChapter> _splitByHeadings(
    List<String> paragraphs, List<int> headingIdx) {
  final chapters = <NovelChapter>[];
  // 首个章标题之前的引言单独成章（可能为空则跳过）
  final first = headingIdx.first;
  if (first > 0) {
    chapters.add(NovelChapter(
        idx: 0, title: null, paragraphs: paragraphs.sublist(0, first)));
  }
  for (var h = 0; h < headingIdx.length; h++) {
    final start = headingIdx[h];
    final end = h + 1 < headingIdx.length ? headingIdx[h + 1] : paragraphs.length;
    final body = paragraphs.sublist(start + 1, end);
    chapters.add(NovelChapter(
        idx: chapters.length,
        title: paragraphs[start],
        paragraphs: body));
  }
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
          paragraphs: [...last.paragraphs, ...buf]);
    } else {
      chapters.add(NovelChapter(
          idx: chapters.length, title: null, paragraphs: buf));
    }
  }
  return chapters;
}
