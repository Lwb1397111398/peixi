import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/novel/epub_parser.dart';

Archive buildEpub() {
  final container = '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''';
  final opf = '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
  <manifest>
    <item id="c1" href="text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="text/ch2.xhtml" media-type="application/xhtml+xml"/>
    <item id="css" href="style.css" media-type="text/css"/>
  </manifest>
  <spine><itemref idref="c1"/><itemref idref="c2"/></spine>
</package>''';
  final ch1 = '''
<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>第一章 起航</title></head>
<body><h1>第一章 起航</h1>
<p>少年背剑而行。</p>
<p>风起于青萍之末，浪成于微澜之间 &amp; 江湖夜雨。</p>
<p>「&#x5929;&#x4E0B;&#x8C01;&#x4EBA;手，ke&#036; &#x4E0D;&#x53EF;　说。」</p>
</body></html>''';
  final ch2 = '''
<html><head><title>第二章 客栈</title></head>
<body><div><p>店家压低了声音。</p><p>那位客人不简单。</p></div></body></html>''';

  return Archive()
    ..addFile(ArchiveFile.string('mimetype', 'application/epub+zip'))
    ..addFile(ArchiveFile.string('META-INF/container.xml', container))
    ..addFile(ArchiveFile.string('OEBPS/content.opf', opf))
    ..addFile(ArchiveFile.string('OEBPS/text/ch1.xhtml', ch1))
    ..addFile(ArchiveFile.string('OEBPS/text/ch2.xhtml', ch2));
}

void main() {
  test('标准 EPUB：spine 顺序切章、标题、实体解码、../ 路径解析', () {
    final doc = parseEpubBytes(buildEpubBytes());
    expect(doc.chapters, hasLength(2));
    expect(doc.chapters[0].title, '第一章 起航');
    expect(doc.chapters[0].paragraphs, hasLength(3));
    expect(doc.chapters[0].paragraphs[0], '少年背剑而行。');
    // 实体解码：&amp; → &，&#xNNNN; → 汉字，&#NNN; → 汉字
    expect(doc.chapters[0].paragraphs[1], contains('& 江湖夜雨'));
    expect(doc.chapters[0].paragraphs[2], contains('天下谁人手'));
    // 第二章
    expect(doc.chapters[1].title, '第二章 客栈');
    expect(doc.chapters[1].paragraphs.first, '店家压低了声音。');
    // 全局段落计数
    expect(doc.paragraphCount, 5);
  });

  test('非 HTML 资源（css）被跳过', () {
    final doc = parseEpubBytes(buildEpubBytes());
    // css 不在 spine；即便在，media-type text/css 也不会成为章
    expect(doc.chapters.every((c) => c.title != 'style.css'), isTrue);
  });

  test('封面/无正文页跳过（空段落）', () {
    final archive = buildEpub()
      ..addFile(ArchiveFile.string(
          'OEBPS/text/cover.xhtml',
          '<html><body><img src="cover.jpg"/></body></html>'))
      ..addFile(ArchiveFile.string('OEBPS/content.opf', '''
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <manifest>
    <item id="cov" href="text/cover.xhtml" media-type="application/xhtml+xml"/>
    <item id="c1" href="text/ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="cov"/><itemref idref="c1"/></spine>
</package>'''));
    final doc = parseEpubBytes(archiveToBytes(archive));
    expect(doc.chapters, hasLength(1));
    expect(doc.chapters.single.title, '第一章 起航');
  });

  test('损坏文件抛 FormatException', () {
    expect(() => parseEpubBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<FormatException>()));
  });

  test('缺 container.xml 抛 FormatException', () {
    final archive = Archive()
      ..addFile(ArchiveFile.string('random.txt', 'hello'));
    expect(() => parseEpubBytes(archiveToBytes(archive)),
        throwsA(isA<FormatException>()));
  });

  test('extractChapter：无 body 标签时整页兜底', () {
    final (:title, :paragraphs) = extractChapter('<p>只有段落。</p>');
    expect(title, isNull);
    expect(paragraphs, ['只有段落。']);
  });

  test('resolveZipPath 处理 ../ 与多余斜杠', () {
    expect(resolveZipPath('OEBPS/', '../text/ch1.xhtml'), 'text/ch1.xhtml');
    expect(resolveZipPath('', 'OEBPS//text/ch1.xhtml'), 'OEBPS/text/ch1.xhtml');
  });
}

Uint8List buildEpubBytes() => archiveToBytes(buildEpub());

Uint8List archiveToBytes(Archive archive) =>
    Uint8List.fromList(ZipEncoder().encode(archive));
