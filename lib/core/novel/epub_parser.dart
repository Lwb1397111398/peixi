import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:peixi/core/novel/novel_parser.dart';

/// 轻量 EPUB 解析（M3）。
/// 偏离说明：设计稿建议 epubx，但其与 media_kit 存在 image 3/4 版本冲突，
/// 改为基于 archive+xml 的内置实现。支持标准文本型 EPUB2/3（无 DRM），
/// 图片/封面不提取。流程：container.xml → OPF → manifest/spine 顺序
/// → 逐章 XHTML 剥标签 + 实体解码 → NovelDoc（复用 N1 后续全链路）。
NovelDoc parseEpubBytes(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    throw FormatException('EPUB 文件损坏或不是合法 zip：$e');
  }

  String readText(String name) {
    final f = archive.findFile(name);
    if (f == null) return '';
    var s = utf8.decode(f.content, allowMalformed: true);
    if (s.startsWith('\uFEFF')) s = s.substring(1);
    return s;
  }

  // 1) container.xml → OPF 路径
  final containerXml = readText('META-INF/container.xml');
  if (containerXml.isEmpty) {
    throw const FormatException('EPUB 缺少 META-INF/container.xml');
  }
  final opfPath = _firstAttr(
      XmlDocument.parse(containerXml), 'rootfile', 'full-path');
  if (opfPath == null || opfPath.isEmpty) {
    throw const FormatException('container.xml 中没有 rootfile（OPF 路径）');
  }

  // 2) OPF → manifest 与 spine
  final opfDir = opfPath.contains('/')
      ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
      : '';
  final opfXml = readText(opfPath);
  if (opfXml.isEmpty) {
    throw FormatException('EPUB 缺少 OPF 文件：$opfPath');
  }
  final opf = XmlDocument.parse(opfXml);
  final hrefById = <String, String>{};
  final typeById = <String, String>{};
  for (final item in _all(opf, 'item')) {
    final id = _attrOf(item, 'id');
    final href = _attrOf(item, 'href');
    if (id != null && href != null) {
      hrefById[id] = href;
      typeById[id] = _attrOf(item, 'media-type') ?? '';
    }
  }
  final spineIds = [
    for (final ref in _all(opf, 'itemref')) _attrOf(ref, 'idref')
  ].whereType<String>().toList();
  if (spineIds.isEmpty) {
    throw const FormatException('OPF spine 为空（EPUB 无阅读顺序）');
  }

  // 3) spine 顺序 → 各章文本
  final chapters = <NovelChapter>[];
  for (final idref in spineIds) {
    final href = hrefById[idref];
    if (href == null) continue;
    final type = typeById[idref] ?? '';
    final isHtml = type.contains('html') ||
        href.toLowerCase().endsWith('.xhtml') ||
        href.toLowerCase().endsWith('.html');
    if (!isHtml) continue;
    final docPath = resolveZipPath(opfDir, Uri.decodeComponent(href));
    final (:title, :paragraphs) = extractChapter(readText(docPath));
    if (paragraphs.isEmpty) continue; // 封面/纯目录页跳过
    chapters.add(NovelChapter(
        idx: chapters.length, title: title, paragraphs: paragraphs));
  }
  if (chapters.isEmpty) {
    throw const FormatException('EPUB 中未解析出任何正文（可能含 DRM 或非文本内容）');
  }
  return NovelDoc(chapters: chapters);
}

NovelDoc parseEpubFile(String path) =>
    parseEpubBytes(File(path).readAsBytesSync());

/// zip 内路径解析（处理 ../ 与重复斜杠）
String resolveZipPath(String baseDir, String href) {
  final parts = <String>[];
  for (final seg in '$baseDir$href'.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(seg);
  }
  return parts.join('/');
}

/// 从 XHTML 提取 (章标题, 段落列表)。标题优先 <h1>-<h3>，其次 <title>。
({String? title, List<String> paragraphs}) extractChapter(String html) {
  String? title;
  final heading =
      RegExp(r'<h[1-3][^>]*>([\s\S]*?)</h[1-3]>', caseSensitive: false)
          .firstMatch(html)
          ?.group(1);
  final titleTag =
      RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
          .firstMatch(html)
          ?.group(1);
  final rawTitle = (heading?.trim().isNotEmpty ?? false)
      ? heading
      : (titleTag?.trim().isNotEmpty ?? false)
          ? titleTag
          : null;
  if (rawTitle != null) {
    final t = _decodeEntities(rawTitle.replaceAll(RegExp(r'<[^>]+>'), '')).trim();
    if (t.isNotEmpty) title = t;
  }

  final body = RegExp(r'<body[^>]*>([\s\S]*?)</body>', caseSensitive: false)
          .firstMatch(html)
          ?.group(1) ??
      html;
  // 标题行已作为章标题，不再重复出现在正文段落里
  final headingInBody = RegExp(r'<h[1-3][^>]*>[\s\S]*?</h[1-3]>',
          caseSensitive: false)
      .firstMatch(body);
  final bodyText = headingInBody != null
      ? body.replaceRange(headingInBody.start, headingInBody.end, '')
      : body;
  var text = bodyText
      .replaceAllMapped(
          RegExp(r'<(script|style)[\s\S]*?</(script|style)>',
              caseSensitive: false),
          (_) => '')
      .replaceAll(
          RegExp(r'<br\s*/?>|</p>|</div>|</h[1-6]>|</li>',
              caseSensitive: false),
          '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  text = _decodeEntities(text);

  final paragraphs = [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) line.trim()
  ];
  return (title: title, paragraphs: paragraphs);
}

String _decodeEntities(String s) => s
    .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
    .replaceAllMapped(RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)))
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

String? _firstAttr(XmlDocument doc, String localName, String attr) {
  for (final e in _all(doc, localName)) {
    final v = _attrOf(e, attr);
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

/// 命名空间无关的元素/属性访问（EPUB 各版本默认 ns 不同）
Iterable<XmlElement> _all(XmlDocument doc, String localName) =>
    doc.descendantElements.where((e) => e.name.local == localName);

String? _attrOf(XmlElement e, String localName) {
  for (final a in e.attributes) {
    if (a.name.local == localName) return a.value;
  }
  return null;
}
