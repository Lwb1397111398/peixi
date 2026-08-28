import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/novel/novel_parser.dart';

void main() {
  group('decodeNovelText', () {
    test('UTF-8 正常解码', () {
      final text = '第一章 试炼\n他睁开眼。';
      expect(decodeNovelText(utf8.encode(text)), text);
    });

    test('真实 GBK 字节流解码（回归：双字节必须合并查表）', () {
      // Python 标准编解码器导出的真实 GBK 字节：
      // "第一章 山门\n少年背剑而行。\n第二章 风起\n他握紧了剑柄。"
      const hex =
          'B5 DA D2 BB D5 C2 20 C9 BD C3 C5 0A C9 D9 C4 EA B1 B3 BD A3 B6 F8 '
          'D0 D0 A1 A3 0A B5 DA B6 FE D5 C2 20 B7 E7 C6 F0 0A CB FB CE D5 BD F4 '
          'C1 CB BD A3 B1 FA A1 A3';
      final bytes = hex
          .split(' ')
          .map((h) => int.parse(h, radix: 16))
          .toList();
      final decoded = decodeNovelText(bytes);
      expect(decoded, '第一章 山门\n少年背剑而行。\n第二章 风起\n他握紧了剑柄。');
    });

    test('UTF-8 优先：纯 UTF-8 中文不吃 GBK 误判', () {
      final bytes = utf8.encode('第一章 网络\n数据在云端。');
      expect(decodeNovelText(bytes), '第一章 网络\n数据在云端。');
    });

    test('非法字节以 U+FFFD 占位不抛异常', () {
      // 0xFF 不是合法 GBK lead 的合法组合开头（0xFF 无映射）
      final decoded = decodeNovelText([0xFF, 0x81, 0x40]);
      expect(decoded, contains('\uFFFD'));
    });
  });

  group('parseNovel 章节切分', () {
    test('标准 第X章 切分，标题行不进入正文', () {
      const raw = '''
第一章 初入江湖
　　少年背剑而行。
　　风起于青萍之末。

第二章 客栈风波
　　店家压低了声音。
　　"那位客人不简单。"
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[0].title, '第一章 初入江湖');
      expect(doc.chapters[0].paragraphs, hasLength(2));
      expect(doc.chapters[1].title, '第二章 客栈风波');
      expect(doc.chapters[1].paragraphs, hasLength(2));
      expect(doc.chapters[0].paragraphs.join(), isNot(contains('第一章')));
      expect(doc.paragraphCount, 4);
    });

    test('楔子/序章/番外 等惯用标题也切分', () {
      const raw = '''
楔子
　　天地初开。

第一章 觉醒
　　他睁开了眼睛。

番外 春日宴
　　多年以后。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters.map((c) => c.title).toList(),
          ['楔子', '第一章 觉醒', '番外 春日宴']);
    });

    test('首章之前的引言单独成章', () {
      const raw = '''
　　这是书前引言。

第一章 开始
　　正文。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[0].title, isNull);
      expect(doc.chapters[0].paragraphs, hasLength(1));
      expect(doc.chapters[1].title, '第一章 开始');
    });

    test('含数字章号 第03章', () {
      const raw = '''
第03章 夜行
　　夜色如墨。
第三章 天明
　　他数到三。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[0].title, '第03章 夜行');
    });

    test('正文中含"第X章"字样的叙事句不误切', () {
      const raw = '''
第一章 起
　　第一章的故事早已结束。
　　"第一章"这三个字刺痛了他。这句话超过四十个字的长度限制所以无论如何都不会被当作标题行来处理，它只是一句普普通通的台词罢了。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(1));
      expect(doc.chapters[0].title, '第一章 起');
      expect(doc.chapters[0].paragraphs, hasLength(2));
      expect(doc.chapters[0].paragraphs.first, '第一章的故事早已结束。');
    });

    test('只有一个标题时也按标题成章', () {
      const raw = '''
第一章 唯一
　　短文。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(1));
      expect(doc.chapters[0].title, '第一章 唯一');
      expect(doc.chapters[0].paragraphs, ['短文。']);
    });
  });

  group('parseNovel 无标题兜底', () {
    test('长文按约 2000 字段落边界分块', () {
      final para = '他沿着长街一直走，灯火渐次熄灭，唯有更楼的梆子声远远传来。' * 20; // ~540字
      final raw = List.filled(12, para).join('\n\n'); // ~6480字
      final doc = parseNovel(raw);
      expect(doc.chapters.length, inInclusiveRange(3, 4));
      expect(doc.paragraphCount, 12);
      for (final c in doc.chapters) {
        expect(c.title, isNull);
      }
    });

    test('短文整体一块', () {
      final doc = parseNovel('第一段。\n\n第二段。');
      expect(doc.chapters, hasLength(1));
      expect(doc.chapters[0].paragraphs, ['第一段。', '第二段。']);
    });
  });

  test('空输入', () {
    final doc = parseNovel('');
    expect(doc.chapters, isEmpty);
    expect(doc.paragraphCount, 0);
  });

  test('CRLF 与 BOM 处理', () {
    const raw = '第一章 甲\r\n正文一。\r\n\r\n第二章 乙\r\n正文二。\r\n';
    final doc = parseNovel('\uFEFF$raw');
    expect(doc.chapters, hasLength(2));
    expect(doc.chapters[0].paragraphs, ['正文一。']);
  });
}
