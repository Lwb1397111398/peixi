import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/llm/prompts.dart';

/// 三个新 Prompt 模板（设计文档 §7.1/§7.2/§7.3）的关键锚点断言。
/// 锚点措辞是管线测试与 LLM 输出解析的契约，改动须同步评估。
void main() {
  group('novelMap（地图趟，§7.1）', () {
    final p = Prompts.novelMap(
        roster: '林晚：主角', chapterBlocks: const ['[章0 正文]', '[章1 正文]']);

    test('含已知人物名单锚点', () => expect(p, contains('[已知人物名单]')));
    test('含 chapters 输出结构', () => expect(p, contains('"chapters"')));
    test('含禁止编造要求', () => expect(p, contains('禁止编造')));
    test('含出场人物与人物事件输出字段', () {
      expect(p, contains('"cast"'));
      expect(p, contains('"events"'));
      expect(p, contains('"characters"'));
      expect(p, contains('"summary"'));
      expect(p, contains('"major"'));
    });
  });

  group('digestMerge（快照趟，§7.2）', () {
    final p = Prompts.digestMerge(
        oldDigest: '旧摘要', chapterSummaries: const ['第一章摘要', '第二章摘要']);

    test('含 400 字上限', () => expect(p, contains('400字')));
    test('含未回收伏笔保留要求', () => expect(p, contains('未回收伏笔')));
    test('含 digest 输出结构', () => expect(p, contains('{"digest"')));
    test('旧摘要与各章摘要有占位', () {
      expect(p, contains('[旧摘要]旧摘要'));
      expect(p, contains('- 第一章摘要'));
      expect(p, contains('- 第二章摘要'));
    });
  });

  group('novelAnnotateV2（批注趟，§7.3）', () {
    final p = Prompts.novelAnnotateV2(
        digest: '故事至今',
        cast: '林晚【主要人物】',
        recall: '第三章伏笔回忆',
        recentSummaries: '第0章：开篇',
        chaptersText: '[第1章 标题]\n[0] 段落',
        chapterStart: 1,
        chapterEnd: 3);

    test('含五层上下文锚点', () {
      expect(p, contains('[故事至今]'));
      expect(p, contains('[出场人物]'));
      expect(p, contains('[相关前文回忆]'));
      expect(p, contains('[前文摘要]'));
      expect(p, contains('[本章正文'));
    });

    test('三条硬规则原文', () {
      expect(p, contains('绝不透露后文走向与结局'));
      expect(p, contains('在酝酿什么'));
      expect(p, contains('具体事实'));
    });

    test('含宁缺毋滥与 L1-L4 输出结构', () {
      expect(p, contains('宁缺毋滥'));
      expect(p, contains('"type":"L3"'));
      expect(p, contains('"perspectives"'));
      expect(p, contains('"para_idx"'));
    });

    test('recall 为空串时不出现相关前文回忆段', () {
      final pNoRecall = Prompts.novelAnnotateV2(
          digest: '故事至今',
          cast: '林晚',
          recall: '',
          recentSummaries: '',
          chaptersText: '[第1章 标题]\n[0] 段落',
          chapterStart: 1,
          chapterEnd: 1);
      expect(pNoRecall, isNot(contains('[相关前文回忆]')));
      expect(pNoRecall, contains('（本章即故事开头）'),
          reason: 'recentSummaries 为空时用占位提示');
    });

    test('章号注入输出模板', () {
      expect(p, contains('"idx":1'));
      expect(p, contains('第1~3章'));
    });
  });
}
