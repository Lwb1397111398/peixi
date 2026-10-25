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

  group('parseNovel 卷/章两级', () {
    test('第X卷 归属卷，卷标题不占章', () {
      const raw = '''
第一卷 风起
第一章 山门
　　少年入门。

第二章 试炼
　　他踏上石阶。

第二卷 云涌
第三章 变故
　　夜里起了风。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(3));
      expect(doc.chapters.map((c) => c.title).toList(),
          ['第一章 山门', '第二章 试炼', '第三章 变故']);
      expect(doc.chapters[0].volume, '第一卷 风起');
      expect(doc.chapters[1].volume, '第一卷 风起');
      expect(doc.chapters[2].volume, '第二卷 云涌');
      // 卷标题行不得混入任何章正文
      expect(doc.chapters.map((c) => c.paragraphs.join()).join(),
          isNot(contains('第一卷')));
      expect(doc.chapters.map((c) => c.paragraphs.join()).join(),
          isNot(contains('第二卷')));
    });

    test('卷标题下直接接正文：以卷标题为章名成章', () {
      const raw = '''
上卷
　　混沌初开。

第一章 天光
　　故事开始。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[0].title, '上卷');
      expect(doc.chapters[0].volume, '上卷');
      expect(doc.chapters[0].paragraphs, ['混沌初开。']);
      expect(doc.chapters[1].title, '第一章 天光');
      expect(doc.chapters[1].volume, '上卷');
    });

    test('第X部/第X册 同样按卷归属', () {
      const raw = '''
第一部 少年
第一章 启程
　　出发。

第二部 江湖
第二章 风波
　　客栈人声鼎沸。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[0].volume, '第一部 少年');
      expect(doc.chapters[1].volume, '第二部 江湖');
    });

    test('叙事句以「第X卷」开头但不切（后接非空白标点）', () {
      const raw = '''
第一章 起
　　第二卷的故事还在继续，但他没有翻开。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(1));
      expect(doc.chapters[0].paragraphs.first, startsWith('第二卷的故事'));
    });

    test('第X话/第X話 也按章切（日系轻小说）', () {
      const raw = '''
第1话 转生
　　他睁开了眼。

第2話 修行
　　剑道场的清晨。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[0].title, '第1话 转生');
      expect(doc.chapters[1].title, '第2話 修行');
    });
  });

  group('parseNovel 英文原版书', () {
    test('Chapter 数字/罗马/英文数词 + 副题', () {
      const raw = '''
Chapter 1
The boy woke up.

Chapter II: The Journey
They left the village.

Chapter Five - Awakening
Power stirred within him.
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(3));
      expect(doc.chapters.map((c) => c.title).toList(),
          ['Chapter 1', 'Chapter II: The Journey', 'Chapter Five - Awakening']);
      expect(doc.chapters[0].paragraphs, ['The boy woke up.']);
    });

    test('全大写 CHAPTER 5 与 Prologue/Epilogue', () {
      const raw = '''
PROLOGUE
The storm was coming.

CHAPTER 5
Everything changed.

Epilogue: Years Later
Peace at last.
''';
      final doc = parseNovel(raw);
      expect(doc.chapters.map((c) => c.title).toList(),
          ['PROLOGUE', 'CHAPTER 5', 'Epilogue: Years Later']);
    });

    test('Part/Book 作为卷归属', () {
      const raw = '''
Part I
Chapter 1
Morning.

Chapter 2
Evening.

Book Two
Chapter 3
Night.
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(3));
      expect(doc.chapters[0].volume, 'Part I');
      expect(doc.chapters[1].volume, 'Part I');
      expect(doc.chapters[2].volume, 'Book Two');
      expect(doc.chapters.map((c) => c.title).toList(),
          ['Chapter 1', 'Chapter 2', 'Chapter 3']);
    });

    test('英文叙事句不误切', () {
      const raw = '''
Chapter 1 Beginnings
　　Part of him wanted to stay, but the chapter was closed forever and ever.
　　The prologue was over; what came next nobody could tell for certain.
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(1));
      expect(doc.chapters[0].title, 'Chapter 1 Beginnings');
      expect(doc.chapters[0].paragraphs, hasLength(2));
    });
  });

  group('parseNovel 数字裸标题兜底', () {
    test('全书无卷/章锚点时「1.」「一、」切章', () {
      const raw = '''
1. 初见
　　巷口的猫。

2. 重逢
　　还是那只猫。

一、尾声
　　猫走了。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters.map((c) => c.title).toList(),
          ['1. 初见', '2. 重逢', '一、尾声']);
      expect(doc.chapters[0].paragraphs, ['巷口的猫。']);
    });

    test('已有 第X章 锚点时数字裸标题不启用（正文列表项安全）', () {
      const raw = '''
第一章 清晨
　　他列了清单：
1. 买米
2. 打水
　　然后出门。
''';
      final doc = parseNovel(raw);
      expect(doc.chapters, hasLength(1));
      expect(doc.chapters[0].paragraphs, hasLength(4));
      expect(doc.chapters[0].paragraphs[1], '1. 买米');
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
