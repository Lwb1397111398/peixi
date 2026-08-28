import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:peixi/core/novel/novel_parser.dart';

void main() {
  group('decodeNovelText', () {
    test('UTF-8 正常解码', () {
      final text = '第一章 试炼\n他睁开眼。';
      expect(decodeNovelText(utf8.encode(text)), text);
    });

    test('GBK 字节兜底解码', () {
      const text = '第一章 山门\n少年抬头望月。';
      final gbkBytes = <int>[];
      for (final unit in text.codeUnits) {
        final enc = gbk.encoder.convert(String.fromCharCode(unit));
        gbkBytes.addAll(enc);
      }
      final decoded = decodeNovelText(gbkBytes);
      expect(decoded, contains('第一章'));
      expect(decoded, contains('少年抬头望月'));
    });

    test('非法字节不抛异常（GBK 永不失败）', () {
      // 0x80 起头在 UTF-8 非法，GBK 侧映射不到则原样输出
      expect(() => decodeNovelText([0xFF, 0x81, 0x40]), returnsNormally);
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
