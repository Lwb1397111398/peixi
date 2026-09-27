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
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/novel_map_pass.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';

/// 单可用渠道路由表：summary/analysis 双槽位显式绑定（地图趟走 summary）。
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

  /// 第 i 次请求的 user 正文（chatJson 把 system 前缀插在最前）。
  String promptOf(ScriptedAdapter a, [int i = 0]) =>
      (a.requests[i].data as Map)['messages'].last['content'] as String;

  Future<int> seedBook(int n) async => NovelImporter(db: db).import(
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

  group('NovelMapPass（地图趟）', () {
    test('批量推进与落库：摘要/cast/人物事件/人物增量按批写入', () async {
      final id = await seedBook(5);
      final adapter = ScriptedAdapter([
        '{"chapters":['
            '{"idx":0,"summary":"地图摘要零","cast":["林川"],'
            '"events":[{"name":"林川","event":"立誓下山"}],'
            '"characters":[{"name":"林川","profile":"热血少年剑客","major":true}]},'
            '{"idx":1,"summary":"地图摘要一","cast":["林川","苏眉"],"events":[],'
            '"characters":[{"name":"苏眉","profile":"客栈老板娘","major":false}]}]}',
        '{"chapters":[{"idx":2,"summary":"地图摘要二"},{"idx":3,"summary":"地图摘要三"}]}',
        '{"chapters":[{"idx":4,"summary":"地图摘要四"}]}',
      ]);
      final progress = <String>[];
      final pass = NovelMapPass(db: db, llm: llm(adapter), batchChapters: 2,
          onProgress: (d, t) => progress.add('$d/$t'));

      // 第一批 = 第 0-1 章
      expect(await pass.step(id), 2);
      expect(promptOf(adapter), contains('[章0'));
      expect(promptOf(adapter), contains('[章1'));
      expect(promptOf(adapter), isNot(contains('[章2')));
      // 开头无已知人物
      expect(promptOf(adapter), contains('（尚无，本批为开头）'));
      // 地图走 summary 槽位
      expect((adapter.requests[0].data as Map)['model'], 'flash');
      final logs = await db.select(db.llmLogs).get();
      expect(logs.map((l) => l.purpose), everyElement('novel_map'));

      var chs = await chaptersOf(id);
      expect(chs[0].mapDone, isTrue);
      expect(chs[0].summary, '地图摘要零');
      expect(chs[1].mapDone, isTrue);
      expect(chs[2].mapDone, isFalse);
      final chars =
          await (db.select(db.characters)..where((t) => t.projectId.equals(id)))
              .get();
      final byName = {for (final c in chars) c.name: c};
      expect(byName['林川']!.major, isTrue);
      expect(byName['林川']!.aliasesJson, '热血少年剑客');
      expect(byName['苏眉']!.major, isFalse);
      expect(byName['苏眉']!.aliasesJson, '客栈老板娘');
      // cast_ids 解析为人物 id
      expect(jsonDecode(chs[0].castIds), [byName['林川']!.id]);
      expect(jsonDecode(chs[1].castIds),
          [byName['林川']!.id, byName['苏眉']!.id]);
      // 人物事件落库（chapter_idx 对应）
      final events = await (db.select(db.characterEvents)
            ..where((t) => t.projectId.equals(id)))
          .get();
      expect(events, hasLength(1));
      expect(events.single.characterId, byName['林川']!.id);
      expect(events.single.chapterIdx, 0);
      expect(events.single.event, '立誓下山');

      // 第二批 = 第 2-3 章；名单已滚动（含第 0-1 章出场者）
      expect(await pass.step(id), 2);
      expect(promptOf(adapter, 1), contains('[章2'));
      expect(promptOf(adapter, 1), contains('[章3'));
      expect(promptOf(adapter, 1), isNot(contains('[章4')));
      expect(promptOf(adapter, 1), contains('林川：热血少年剑客【主要】'));
      expect(promptOf(adapter, 1), contains('苏眉：客栈老板娘'));

      // 第三批 = 第 4 章（余量不足一批）
      expect(await pass.step(id), 1);
      expect(promptOf(adapter, 2), contains('[章4'));
      // 全书完成后返回 0，不再发起调用
      expect(await pass.step(id), 0);
      expect(adapter.requests, hasLength(3));
      expect(progress, ['2/5', '4/5', '5/5']);
    });

    test('名单窗口：窗口外出场者被排除，major 人物恒在名单', () async {
      final id = await seedBook(12);
      final chs = await chaptersOf(id);
      // 预置第 0-10 章已完成地图；处理第 10 章时窗口 = [5,10)
      for (final ch in chs.take(11)) {
        await (db.update(db.chapters)..where((t) => t.id.equals(ch.id)))
            .write(const ChaptersCompanion(mapDone: Value(true)));
      }
      final idA = await db.into(db.characters).insert(
          CharactersCompanion.insert(projectId: id, name: '窗内人',
              aliasesJson: const Value('近章出场')));
      final idB = await db.into(db.characters).insert(
          CharactersCompanion.insert(projectId: id, name: '窗外人',
              aliasesJson: const Value('早期出场')));
      await (db.update(db.chapters)..where((t) => t.id.equals(chs[6].id)))
          .write(ChaptersCompanion(castIds: Value('[$idA]')));
      await (db.update(db.chapters)..where((t) => t.id.equals(chs[0].id)))
          .write(ChaptersCompanion(castIds: Value('[$idB]')));

      final adapter = ScriptedAdapter(['{"chapters":[{"idx":10,"summary":"s10"}]}']);
      await NovelMapPass(db: db, llm: llm(adapter), batchChapters: 1,
              rosterWindowChapters: 5)
          .step(id);
      expect(promptOf(adapter), contains('窗内人：近章出场'));
      expect(promptOf(adapter), isNot(contains('窗外人')));

      // 窗外人升级为 major 后恒进名单
      await (db.update(db.characters)..where((t) => t.id.equals(idB)))
          .write(const CharactersCompanion(major: Value(true)));
      final adapter2 = ScriptedAdapter(['{"chapters":[{"idx":11,"summary":"s11"}]}']);
      await NovelMapPass(db: db, llm: llm(adapter2), batchChapters: 1,
              rosterWindowChapters: 5)
          .step(id);
      expect(promptOf(adapter2), contains('窗外人：早期出场【主要】'));
    });

    test('续跑确定性：从首个未 mapDone 章起批', () async {
      final id = await seedBook(6);
      final chs = await chaptersOf(id);
      for (final ch in chs.take(5)) {
        await (db.update(db.chapters)..where((t) => t.id.equals(ch.id)))
            .write(const ChaptersCompanion(mapDone: Value(true)));
      }
      final adapter = ScriptedAdapter(['{"chapters":[{"idx":5,"summary":"s5"}]}']);
      final n = await NovelMapPass(db: db, llm: llm(adapter)).step(id);
      expect(n, 1);
      expect(promptOf(adapter), contains('[章5'));
      expect(promptOf(adapter), isNot(contains('[章4')));
    });

    test('自适应降批：解析失败减半重试，两章均落库', () async {
      final id = await seedBook(2);
      final adapter = ScriptedAdapter([
        '不是json', '还不是json', // 首批(0,1)正文+修复均失败 → 触发降批
        '{"chapters":[{"idx":0,"summary":"补零"}]}',
        '{"chapters":[{"idx":1,"summary":"补一"}]}',
      ]);
      final degraded = <String>[];
      final n = await NovelMapPass(db: db, llm: llm(adapter), batchChapters: 2,
              onDegraded: (d) => degraded.add(d))
          .step(id);
      expect(n, 2);
      expect(degraded, hasLength(1));
      expect(degraded.single, contains('降批'));
      final chs = await chaptersOf(id);
      expect(chs.map((c) => c.mapDone), everyElement(isTrue));
      expect(chs[0].summary, '补零');
      expect(chs[1].summary, '补一');
      // 失败批 2 个请求（正文+修复链）+ 两个单章批各 1 个
      expect(adapter.requests, hasLength(4));
    });

    test('单章兜底：单章批解析两次失败 → 重抛 LlmJsonException', () async {
      final id = await seedBook(1);
      final adapter = ScriptedAdapter(['坏输出', '修复后还是坏']);
      await expectLater(
          NovelMapPass(db: db, llm: llm(adapter), batchChapters: 1).step(id),
          throwsA(isA<LlmJsonException>()));
      expect(adapter.requests, hasLength(2)); // 正文 + 修复链
      final chs = await chaptersOf(id);
      expect(chs.single.mapDone, isFalse);
    });

    test('返回值 = 新完成章数：模型漏章不计，洞口续批不重复落库', () async {
      final id = await seedBook(3);
      final adapter = ScriptedAdapter([
        '{"chapters":[{"idx":0,"summary":"s0","cast":["林川"],'
            '"events":[{"name":"林川","event":"零章事件"}]},'
            '{"idx":2,"summary":"s2","events":[{"name":"林川","event":"二章事件"}]}]}',
        // 洞口续批：脚本刻意重复包含已完成章（第 2 章）的 events/summary——
        // 修复前会重复插 events 并虚计 done，现在应整体跳过该章
        '{"chapters":[{"idx":1,"summary":"s1"},'
            '{"idx":2,"summary":"s2重写","events":[{"name":"林川","event":"二章事件"}]}]}',
      ]);
      final pass = NovelMapPass(db: db, llm: llm(adapter), batchChapters: 5);
      expect(await pass.step(id), 2); // 漏掉第 1 章
      var chs = await chaptersOf(id);
      expect(chs[0].mapDone, isTrue);
      expect(chs[1].mapDone, isFalse);
      expect(chs[1].summary, isNull);
      expect(chs[2].mapDone, isTrue);
      // 下轮批 = 首个未完成章（第 1 章）起连续批（第 2 章重复送审是设计意图）
      expect(await pass.step(id), 1); // done 只计新完成章
      expect(promptOf(adapter, 1), contains('[章1'));
      expect(promptOf(adapter, 1), contains('[章2'));
      chs = await chaptersOf(id);
      expect(chs.map((c) => c.mapDone), everyElement(isTrue));
      expect(chs[2].summary, 's2'); // 已完成章未被重写
      // events 表无重复行：洞口续批不把已完成章的 events 再插一份
      final events = await (db.select(db.characterEvents)
            ..where((t) => t.projectId.equals(id)))
          .get();
      expect(events.where((e) => e.chapterIdx == 0), hasLength(1));
      expect(events.where((e) => e.chapterIdx == 2), hasLength(1));
      // 洞补上后 step 归零推进
      expect(await pass.step(id), 0);
      expect(adapter.requests, hasLength(2));
    });

    test('事件先删后插：同章重写不重复落事件（幂等兜底）', () async {
      final id = await seedBook(1);
      final linId = await db.into(db.characters).insert(
          CharactersCompanion.insert(projectId: id, name: '林川'));
      // 脏状态：章 0 未完成地图却已有同章事件（模拟历史/中断残留）
      await db.into(db.characterEvents).insert(
          CharacterEventsCompanion.insert(
              projectId: id, characterId: linId,
              chapterIdx: 0, event: '旧事件'));
      final adapter = ScriptedAdapter([
        '{"chapters":[{"idx":0,"summary":"s0",'
            '"events":[{"name":"林川","event":"新事件"}]}]}',
      ]);
      await NovelMapPass(db: db, llm: llm(adapter), batchChapters: 1).step(id);
      final events = await (db.select(db.characterEvents)
            ..where((t) => t.projectId.equals(id)))
          .get();
      expect(events, hasLength(1));
      expect(events.single.event, '新事件');
    });

    test('毒响应降批：chapters 非数组转 LlmJsonException 走减半', () async {
      final id = await seedBook(2);
      final adapter = ScriptedAdapter([
        '{"chapters":"oops"}', // 合法 JSON 但形状错误（已入缓存），须走降批换新键重试
        '{"chapters":[{"idx":0,"summary":"补零"}]}',
        '{"chapters":[{"idx":1,"summary":"补一"}]}',
      ]);
      final degraded = <String>[];
      final n = await NovelMapPass(db: db, llm: llm(adapter), batchChapters: 2,
              onDegraded: (d) => degraded.add(d))
          .step(id);
      expect(n, 2); // 不冒 TypeError，降批后两章均完成
      expect(degraded, hasLength(1));
      final chs = await chaptersOf(id);
      expect(chs.map((c) => c.mapDone), everyElement(isTrue));
      expect(adapter.requests, hasLength(3)); // 毒响应 + 两个单章批（均未命中缓存）
    });

    test('毒响应跳过：元素非 Map 就地跳过不冒 TypeError', () async {
      final id = await seedBook(2);
      final adapter = ScriptedAdapter(['{"chapters":["not-a-map", 42]}']);
      final n = await NovelMapPass(db: db, llm: llm(adapter), batchChapters: 2)
          .step(id);
      expect(n, 0); // 无有效条目 → 视为漏章，零落库不崩溃
      final chs = await chaptersOf(id);
      expect(chs.map((c) => c.mapDone), everyElement(isFalse));
      expect(
          await (db.select(db.characterEvents)
                ..where((t) => t.projectId.equals(id)))
              .get(),
          isEmpty);
      expect(
          await (db.select(db.characters)
                ..where((t) => t.projectId.equals(id)))
              .get(),
          isEmpty);
    });

    test('UTF-16 截断不劈代理对：emoji 完整性', () async {
      // 'a'*5999 + 😀（2 码元）+ 后文：默认 6000 截断点恰落在 emoji 高低代理之间
      final id = await NovelImporter(db: db).import(
          title: '书',
          sourcePath: '/book.txt',
          doc: NovelDoc(chapters: [
            NovelChapter(
                idx: 0, title: '第1章', paragraphs: ['a' * 5999 + '😀' + '后文']),
          ]));
      final adapter = ScriptedAdapter(['{"chapters":[{"idx":0,"summary":"s0"}]}']);
      await NovelMapPass(db: db, llm: llm(adapter), batchChapters: 1).step(id);
      final prompt = promptOf(adapter);
      final marker = prompt.indexOf('……（本章其余内容截断');
      expect(marker, greaterThan(0));
      // 截断文本末码元是 'a'（0x61），而非被劈开的 emoji 高代理（0xD83D）；
      // marker-1 是换行符
      expect(prompt.codeUnitAt(marker - 2), 0x61);
    });

    test('取消：step 抛 PipelineCancelled 且零调用', () async {
      final id = await seedBook(2);
      final adapter = ScriptedAdapter([]);
      await expectLater(
          NovelMapPass(db: db, llm: llm(adapter), isCancelled: () => true)
              .step(id),
          throwsA(isA<PipelineCancelled>()));
      expect(adapter.requests, isEmpty);
    });
  });
}
