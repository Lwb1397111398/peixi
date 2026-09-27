import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/novel/novel_parser.dart';
import 'package:peixi/features/pipeline/novel_annotate_pass.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';

/// 单可用渠道路由表（批注趟走 analysis 槽位）。
const _route = ChannelRoute(
    id: 0, name: 'legacy', baseUrl: 'https://x/v1', apiKey: 'k', enabled: true);

/// 按请求顺序返回预置响应的假适配器（每次调用消耗一个脚本；耗尽后复用最后一条）。
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.bodies);
  final List<String> bodies;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    final i = requests.length;
    requests.add(options);
    final body = i < bodies.length ? bodies[i] : bodies.last;
    return ResponseBody.fromString(
        '{"choices":[{"message":{"role":"assistant","content":${jsonEncode(body)}}}],'
        '"usage":{"prompt_tokens":10,"completion_tokens":20}}',
        200,
        headers: {
          'content-type': ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  LlmService llm(ScriptedAdapter adapter) =>
      LlmService(db: db, dio: Dio()..httpClientAdapter = adapter,
          backoffBase: const Duration(milliseconds: 1))
        ..updateRouting(const RoutingTable(
          channels: [_route],
          slots: {
            LlmSlot.summary: SlotBinding(channelId: 0, model: 'flash'),
            LlmSlot.analysis: SlotBinding(channelId: 0, model: 'deep'),
          },
        ));

  String promptOf(ScriptedAdapter a, [int i = 0]) =>
      (a.requests[i].data as Map)['messages'].last['content'] as String;

  /// 造 n 章书（每章 2 段，全局段落 idx = 章号*2 与 +1）。
  Future<int> seedBook(int n) => NovelImporter(db: db).import(
      title: '书',
      sourcePath: '/book.txt',
      doc: NovelDoc(chapters: [
        for (var i = 0; i < n; i++)
          NovelChapter(
              idx: i,
              title: '第${i + 1}章',
              paragraphs: ['第$i章段落甲。', '第$i章段落乙。']),
      ]));

  Future<List<Chapter>> chaptersOf(int id) => (db.select(db.chapters)
        ..where((t) => t.projectId.equals(id))
        ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
      .get();

  /// 章就绪：mapDone + summary + digestBefore（批注趟的入批条件）。
  Future<void> markReady(Chapter ch, {bool annotDone = false}) async {
    await (db.update(db.chapters)..where((t) => t.id.equals(ch.id))).write(
        ChaptersCompanion(
            mapDone: const Value(true),
            summary: Value('第${ch.idx}章摘要'),
            digestBefore: Value('快照${ch.idx}'),
            annotDone: Value(annotDone)));
  }

  Future<List<Annotation>> annsOfPara(int paraId) =>
      (db.select(db.annotations)..where((t) => t.paraId.equals(paraId))).get();

  /// 全书段落按全局 idx 索引（批注锚定 para_idx = 全局段落 idx）。
  Future<Map<int, Paragraph>> parasByGlobalIdx(int projectId) async {
    final rows = await (db.select(db.paragraphs)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    return {for (final p in rows) p.idx: p};
  }

  group('NovelAnnotatePass（批注趟）', () {
    test('上下文装配：五层拼装、事件线只取批前、recall 缺席整体省略', () async {
      final id = await seedBook(7);
      final chs = await chaptersOf(id);
      // 第 0-3 章已批注完成 → 批 = 第 4-6 章
      for (final ch in chs.take(4)) {
        await markReady(ch, annotDone: true);
      }
      for (final ch in chs.skip(4)) {
        await markReady(ch);
      }
      final linId = await db.into(db.characters).insert(
          CharactersCompanion.insert(projectId: id, name: '林川',
              aliasesJson: const Value('热血少年剑客'), major: const Value(true)));
      final suId = await db.into(db.characters).insert(
          CharactersCompanion.insert(projectId: id, name: '苏眉',
              aliasesJson: const Value('客栈老板娘')));
      Future<void> ev(int charId, int chapterIdx, String event) =>
          db.into(db.characterEvents).insert(
              CharacterEventsCompanion.insert(
                  projectId: id, characterId: charId,
                  chapterIdx: chapterIdx, event: event));
      // 林川批前 4 条事件 → 只取最近 3 条（时间正序）；批内/批后事件不进上下文
      await ev(linId, 0, '立誓复仇');
      await ev(linId, 1, '获得残剑');
      await ev(linId, 2, '身份揭晓');
      await ev(linId, 3, '接掌门派');
      await ev(suId, 2, '收留林川');
      await ev(suId, 5, '暗中盘账'); // >= 批首章 idx，必须被排除
      await (db.update(db.chapters)..where((t) => t.id.equals(chs[4].id)))
          .write(ChaptersCompanion(castIds: Value('[$linId,$suId]')));
      await (db.update(db.chapters)..where((t) => t.id.equals(chs[5].id)))
          .write(ChaptersCompanion(castIds: Value('[$linId]')));
      await (db.update(db.chapters)..where((t) => t.id.equals(chs[6].id)))
          .write(ChaptersCompanion(castIds: Value('[$suId]')));

      final adapter = ScriptedAdapter([
        '{"chapters":['
            '{"idx":4,"annotations":[{"para_idx":8,"type":"L1","content":"四之批注"}]},'
            '{"idx":5,"annotations":[{"para_idx":10,"type":"L1","content":"五之批注"}]},'
            '{"idx":6,"annotations":[{"para_idx":12,"type":"L1","content":"六之批注"}]}]}',
      ]);
      final pass = NovelAnnotatePass(db: db, llm: llm(adapter), batchChapters: 3);
      expect(await pass.step(id), 3);

      final prompt = promptOf(adapter);
      // [故事至今] = 批首章 digest_before
      expect(prompt, contains('[故事至今]快照4'));
      // [出场人物]：人设 + 批前事件线（每人物最近 3 条，时间正序），major 标注
      expect(prompt, contains('林川【主要人物】：热血少年剑客；前文：获得残剑；身份揭晓；接掌门派'));
      expect(prompt, contains('苏眉：客栈老板娘；前文：收留林川'));
      expect(prompt, isNot(contains('立誓复仇'))); // 第 4 条更早事件被裁剪
      expect(prompt, isNot(contains('暗中盘账'))); // 批内事件不进上下文
      // [前文摘要] = 前两章摘要
      expect(prompt, contains('[前文摘要]第2章：第2章摘要\n第3章：第3章摘要'));
      // [本章正文]：批内段落带全局 para_idx，批外段落不出现
      expect(prompt, contains('[本章正文（第4~6章'));
      expect(prompt, contains('[8] 第4章段落甲。'));
      expect(prompt, contains('[13] 第6章段落乙。'));
      expect(prompt, isNot(contains('[0] ')));
      expect(prompt, isNot(contains('[2] ')));
      // recall=null → 回忆节整体缺席
      expect(prompt, isNot(contains('[相关前文回忆]')));
      // 批注走 analysis 槽位
      expect((adapter.requests[0].data as Map)['model'], 'deep');
      final logs = await db.select(db.llmLogs).get();
      expect(logs.map((l) => l.purpose), everyElement('novel_annotate'));
    });

    test('落库：L1-L4 归一、越界/未知/空丢弃、知识卡去重、幂等重批', () async {
      final id = await seedBook(3);
      final chs = await chaptersOf(id);
      for (final ch in chs) {
        await markReady(ch);
      }
      final paras = await parasByGlobalIdx(id); // 段落全局 idx = 章号*2(+1)
      // 预置旧批注：重批后必须被清除（幂等）
      await db.into(db.annotations).insert(AnnotationsCompanion.insert(
          paraId: paras[0]!.id,
          type: 'L2',
          contentJson: jsonEncode({'text': '旧批注'})));

      final adapter = ScriptedAdapter([
        '{"chapters":['
            '{"idx":0,"annotations":['
            '{"para_idx":0,"type":"L1","content":"潜台词文本"},'
            '{"para_idx":1,"type":"L2","content":"心理文本"},'
            '{"para_idx":0,"type":"L3","content":{"term":"残剑","text":"上古兵器","uncertain":true}},'
            '{"para_idx":1,"type":"L4","content":{"question":"你会怎么选？","perspectives":["角度一","角度二"]}},'
            '{"para_idx":99,"type":"L1","content":"越界丢弃"},'
            '{"para_idx":0,"type":"L9","content":"未知类型丢弃"},'
            '{"para_idx":0,"type":"L1","content":"   "},'
            '{"para_idx":0,"type":"L3","content":{"term":"","text":"无术语"}}'
            ']},'
            '{"idx":1,"annotations":[{"para_idx":2,"type":"L1","content":"一章批注"}]},'
            '{"idx":2,"annotations":[{"para_idx":4,"type":"L3","content":{"term":"残剑","text":"重复术语","uncertain":false}}]}'
            ']}',
      ]);
      final progress = <String>[];
      final pass = NovelAnnotatePass(db: db, llm: llm(adapter),
          onProgress: (d, t) => progress.add('$d/$t'));
      expect(await pass.step(id), 3);
      expect(progress, ['3/3']);

      // para0：旧 L2 被清除，新 L1 + L3（无效项全部丢弃）
      final para0 = await annsOfPara(paras[0]!.id);
      expect(para0.map((a) => a.type), ['L1', 'L3']);
      expect(jsonDecode(para0[0].contentJson), {'text': '潜台词文本'});
      expect(jsonDecode(para0[1].contentJson),
          {'term': '残剑', 'text': '上古兵器', 'uncertain': true});
      // para1：L2 字符串归一 + L4 对象归一
      final para1 = await annsOfPara(paras[1]!.id);
      expect(para1.map((a) => a.type).toSet(), {'L2', 'L4'});
      expect(jsonDecode(para1.firstWhere((a) => a.type == 'L2').contentJson),
          {'text': '心理文本'});
      expect(jsonDecode(para1.firstWhere((a) => a.type == 'L4').contentJson),
          {'question': '你会怎么选？', 'perspectives': ['角度一', '角度二']});
      // 越界 para_idx/未知类型/空白文本/空术语都不落库
      final all = await db.select(db.annotations).get();
      expect(all, hasLength(6)); // 2+2+1+1
      // 知识卡按 projectId+term 去重，首见胜出
      final cards = await (db.select(db.knowledgeCards)
            ..where((t) => t.projectId.equals(id)))
          .get();
      expect(cards, hasLength(1));
      expect(cards.single.term, '残剑');
      expect(cards.single.content, '上古兵器');
      expect(cards.single.uncertain, isTrue);
      // annotDone 按章落库
      final after = await chaptersOf(id);
      expect(after.map((c) => c.annotDone), everyElement(isTrue));
    });

    test('批在上游前沿截断：快照缺口前的章先行', () async {
      final id = await seedBook(4);
      final chs = await chaptersOf(id);
      await markReady(chs[0]);
      await markReady(chs[1]);
      // 第 2 章地图完成但快照未就绪 → 截断
      await (db.update(db.chapters)..where((t) => t.id.equals(chs[2].id)))
          .write(ChaptersCompanion(
              mapDone: const Value(true), summary: Value('第2章摘要')));
      final adapter = ScriptedAdapter(
          ['{"chapters":[{"idx":0,"annotations":[]},{"idx":1,"annotations":[]}]}']);
      final n = await NovelAnnotatePass(db: db, llm: llm(adapter),
          batchChapters: 3).step(id);
      expect(n, 2);
      expect(promptOf(adapter), contains('[本章正文（第0~1章'));
      expect(promptOf(adapter), isNot(contains('[第2章')));
      expect(adapter.requests, hasLength(1));
    });

    test('上游未就绪：首个未批注章缺地图/快照 → 返回 0 且零调用', () async {
      final id = await seedBook(2);
      final adapter = ScriptedAdapter(['{"chapters":[]}']);
      final n = await NovelAnnotatePass(db: db, llm: llm(adapter)).step(id);
      expect(n, 0);
      expect(adapter.requests, isEmpty);
    });

    test('自适应降批：3 章批解析失败减半重试成功', () async {
      final id = await seedBook(3);
      final chs = await chaptersOf(id);
      for (final ch in chs) {
        await markReady(ch);
      }
      final adapter = ScriptedAdapter([
        '不是json', '修复后仍不是json', // 首批(0,1,2)失败
        '{"chapters":[{"idx":0,"annotations":[{"para_idx":0,"type":"L1","content":"单章成"}]}]}',
        '{"chapters":['
            '{"idx":1,"annotations":[{"para_idx":2,"type":"L1","content":"一章成"}]},'
            '{"idx":2,"annotations":[{"para_idx":4,"type":"L1","content":"二章成"}]}]}',
      ]);
      final degraded = <String>[];
      final n = await NovelAnnotatePass(db: db, llm: llm(adapter),
              onDegraded: (d) => degraded.add(d))
          .step(id);
      expect(n, 3);
      expect(degraded, hasLength(1));
      expect(degraded.single, contains('降批'));
      expect(adapter.requests, hasLength(4)); // 失败批 2 次 + 单章 1 次 + 双章 1 次
      final paras = await parasByGlobalIdx(id);
      final para0 = await annsOfPara(paras[0]!.id);
      expect(jsonDecode(para0.single.contentJson), {'text': '单章成'});
      final after = await chaptersOf(id);
      expect(after.map((c) => c.annotDone), everyElement(isTrue));
    });

    test('单章兜底：单章批连续解析失败 → 重抛 LlmJsonException', () async {
      final id = await seedBook(1);
      final chs = await chaptersOf(id);
      await markReady(chs.single);
      final adapter = ScriptedAdapter(['坏输出', '修复后还是坏']);
      await expectLater(
          NovelAnnotatePass(db: db, llm: llm(adapter), batchChapters: 1)
              .step(id),
          throwsA(isA<LlmJsonException>()));
      expect(adapter.requests, hasLength(2));
      final after = await chaptersOf(id);
      expect(after.single.annotDone, isFalse);
    });

    test('模型漏章不计 annot_done，下轮从洞口重试', () async {
      final id = await seedBook(2);
      final chs = await chaptersOf(id);
      for (final ch in chs) {
        await markReady(ch);
      }
      final adapter = ScriptedAdapter([
        '{"chapters":[{"idx":0,"annotations":[{"para_idx":0,"type":"L1","content":"零章批注"}]}]}',
        '{"chapters":[{"idx":1,"annotations":[{"para_idx":2,"type":"L1","content":"一章批注"}]}]}',
      ]);
      final pass = NovelAnnotatePass(db: db, llm: llm(adapter), batchChapters: 3);
      expect(await pass.step(id), 1); // 漏第 1 章
      var after = await chaptersOf(id);
      expect(after[0].annotDone, isTrue);
      expect(after[1].annotDone, isFalse);
      // 下轮批 = 首个未批注章起（第 1 章单章批）
      expect(await pass.step(id), 1);
      expect(promptOf(adapter, 1), contains('[本章正文（第1~1章'));
      after = await chaptersOf(id);
      expect(after.map((c) => c.annotDone), everyElement(isTrue));
      expect(await pass.step(id), 0);
    });

    test('单章重批：reannotateChapter 只发一次调用且只影响该章', () async {
      final id = await seedBook(3);
      final chs = await chaptersOf(id);
      for (final ch in chs) {
        await markReady(ch);
      }
      final adapter = ScriptedAdapter([
        '{"chapters":['
            '{"idx":0,"annotations":[{"para_idx":0,"type":"L1","content":"零章首批"}]},'
            '{"idx":1,"annotations":[{"para_idx":2,"type":"L1","content":"一章首批"}]},'
            '{"idx":2,"annotations":[{"para_idx":4,"type":"L1","content":"二章首批"}]}]}',
      ]);
      final pass = NovelAnnotatePass(db: db, llm: llm(adapter), batchChapters: 3);
      expect(await pass.step(id), 3);

      final adapter2 = ScriptedAdapter([
        '{"chapters":[{"idx":1,"annotations":[{"para_idx":3,"type":"L2","content":"重批内容"}]}]}',
      ]);
      await NovelAnnotatePass(db: db, llm: llm(adapter2))
          .reannotateChapter(id, 1);
      expect(adapter2.requests, hasLength(1));
      expect(promptOf(adapter2), contains('[本章正文（第1~1章'));
      // 第 1 章旧批注被清除、新批注落位（段落全局 idx 2/3 属第 1 章）
      final paras = await parasByGlobalIdx(id);
      expect(await annsOfPara(paras[2]!.id), isEmpty);
      final para3 = await annsOfPara(paras[3]!.id);
      expect(para3.single.type, 'L2');
      expect(jsonDecode(para3.single.contentJson), {'text': '重批内容'});
      // 其他章不受影响
      final para0 = await annsOfPara(paras[0]!.id);
      expect(jsonDecode(para0.single.contentJson), {'text': '零章首批'});
      final para4 = await annsOfPara(paras[4]!.id);
      expect(jsonDecode(para4.single.contentJson), {'text': '二章首批'});
    });

    test('reannotateChapter：章不存在或未就绪 → PipelineException', () async {
      final id = await seedBook(2);
      final pass = NovelAnnotatePass(db: db, llm: llm(ScriptedAdapter([])));
      await expectLater(pass.reannotateChapter(id, 99),
          throwsA(isA<PipelineException>()));
      await expectLater(pass.reannotateChapter(id, 0),
          throwsA(isA<PipelineException>())); // 地图未就绪
    });

    test('取消：step 抛 PipelineCancelled 且零调用', () async {
      final id = await seedBook(2);
      final chs = await chaptersOf(id);
      for (final ch in chs) {
        await markReady(ch);
      }
      final adapter = ScriptedAdapter([]);
      await expectLater(
          NovelAnnotatePass(db: db, llm: llm(adapter), isCancelled: () => true)
              .step(id),
          throwsA(isA<PipelineCancelled>()));
      expect(adapter.requests, isEmpty);
    });
  });
}
