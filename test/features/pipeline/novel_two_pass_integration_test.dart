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
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/novel_pipeline.dart';
import 'package:peixi/features/pipeline/novel_scheduler.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';
import 'package:peixi/features/pipeline/project_status.dart';

/// 单可用渠道路由表：summary/analysis 双槽位显式绑定。
const _route = ChannelRoute(
    id: 0, name: 'legacy', baseUrl: 'https://x/v1', apiKey: 'k', enabled: true);

/// 按提示词特征分流三类趟的假适配器（模式同调度器测试基建），另支持
/// 从第 N 个请求起全部返回 HTTP 500（模拟 annotate 阶段服务端崩溃）。
///
/// 跟随模式双泳道并发交错，按"请求序"派发响应会把 map 响应喂给 digest
/// 调用；改为按提示词锚点识别调用类型、各类型独立队列（耗尽后复用末条）。
class LaneScriptedAdapter implements HttpClientAdapter {
  LaneScriptedAdapter({
    this.mapBodies = const [],
    this.digestBodies = const [],
    this.annotateBodies = const [],
    this.failAllFrom,
  });

  final List<String> mapBodies;
  final List<String> digestBodies;
  final List<String> annotateBodies;

  /// 第 N 个请求（0 起）起全部返回 500。
  final int? failAllFrom;

  final requests = <RequestOptions>[];
  final order = <String>[]; // 请求类型序：'map' | 'digest' | 'annotate'
  final _taken = <String, int>{'map': 0, 'digest': 0, 'annotate': 0};

  String _pick(String kind, List<String> bodies) {
    if (bodies.isEmpty) return '{"chapters":[]}';
    final i = _taken[kind] ?? 0;
    _taken[kind] = i + 1;
    return i < bodies.length ? bodies[i] : bodies.last;
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    requests.add(options);
    if (failAllFrom != null && requests.length > failAllFrom!) {
      return ResponseBody.fromString(
          '{"error":{"message":"服务器崩了"}}', 500,
          headers: {
            'content-type': ['application/json']
          });
    }
    final prompt =
        (options.data as Map)['messages'].last['content'] as String;
    final String kind;
    final String body;
    if (prompt.contains('[已知人物名单]')) {
      kind = 'map';
      body = _pick('map', mapBodies);
    } else if (prompt.contains('[旧摘要]')) {
      kind = 'digest';
      body = _pick('digest', digestBodies);
    } else if (prompt.contains('[本章正文')) {
      kind = 'annotate';
      body = _pick('annotate', annotateBodies);
    } else {
      throw StateError('未知提示词类型: ${prompt.substring(0, 60)}');
    }
    order.add(kind);
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

/// [start, end] 区间 5 章 map 响应：每章含摘要/cast/事件/人物增量
/// （林川 major=true 带人设、苏婉新人物）。
String mapResp5(int start, int end) => '{"chapters":[${[
      for (var i = start; i <= end; i++)
        '{"idx":$i,"summary":"第$i章地图摘要：林川继续前行。",'
            '"cast":["林川","苏婉"],'
            '"events":[{"name":"林川","event":"第$i章立誓变强"}],'
            '"characters":[{"name":"林川","profile":"坚毅少年主角","major":true},'
            '{"name":"苏婉","profile":"聪慧同行少女"}]}',
    ].join(',')}]}';

String digestResp() => '{"digest":"故事至今快照"}';

/// 全书批注响应（复用末条，对批组成不敏感）：每章 L1+L3 各一条。
/// para_idx 是全局段落编号：每章 2 段，第 i 章首段全局 idx = i*2。
String annRespFull([List<int>? idxs]) {
  final list = idxs ?? List.generate(10, (i) => i);
  return '{"chapters":[${[
    for (final i in list)
      '{"idx":$i,"annotations":['
          '{"para_idx":${i * 2},"type":"L1","content":"第$i章批注"},'
          '{"para_idx":${i * 2 + 1},"type":"L3","content":'
          '{"term":"术语$i","text":"第$i章的知识","uncertain":false}}]}',
  ].join(',')}]}';
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  LlmService llm(LaneScriptedAdapter adapter) =>
      LlmService(db: db, dio: Dio()..httpClientAdapter = adapter,
          backoffBase: const Duration(milliseconds: 1))
        ..updateRouting(const RoutingTable(
          channels: [_route],
          slots: {
            LlmSlot.summary: SlotBinding(channelId: 0, model: 'flash'),
            LlmSlot.analysis: SlotBinding(channelId: 0, model: 'deep'),
          },
        ));

  /// 10 章书（每章 2 段）；默认参数 burst=10、map=5、digest=10、annotate=3。
  Future<int> seedBook([int n = 10]) async => NovelImporter(db: db).import(
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

  Future<Project> projectOf(int id) => (db.select(db.projects)
        ..where((t) => t.id.equals(id)))
      .getSingle();

  /// 全链路默认参数脚本：2 map + 1 digest + 4 annotate 全部合法。
  LaneScriptedAdapter happyAdapter() => LaneScriptedAdapter(
      mapBodies: [mapResp5(0, 4), mapResp5(5, 9)],
      digestBodies: [digestResp()],
      annotateBodies: [annRespFull()]);

  group('两遍式管线集成（真实三趟 + 调度器）', () {
    test('全链路：默认参数 10 章书一次 run 到 READY——三趟产物、调用序、知识卡、徽章',
        () async {
      final id = await seedBook();
      final adapter = happyAdapter();
      final scheduler = NovelScheduler(
          db: db,
          llm: llm(adapter),
          params: const NovelParams(),
          isCancelled: () => false);
      await scheduler.run(id);
      await Future<void>.delayed(const Duration(milliseconds: 50)); // 徽章 unawaited 落库

      final chs = await chaptersOf(id);
      expect(chs.map((c) => c.mapDone), everyElement(isTrue));
      expect(chs.map((c) => c.annotDone), everyElement(isTrue));
      expect(chs.map((c) => c.summary ?? ''), everyElement(isNotEmpty));

      // 人物增量：林川 major + 人设、苏婉新人物；castIds 解析为二人 id
      final chars = await (db.select(db.characters)
            ..where((t) => t.projectId.equals(id)))
          .get();
      final byName = {for (final c in chars) c.name: c};
      expect(byName['林川']!.major, isTrue);
      expect(byName['林川']!.aliasesJson, '坚毅少年主角');
      expect(byName['苏婉'], isNotNull);
      for (final ch in chs) {
        expect(jsonDecode(ch.castIds), [byName['林川']!.id, byName['苏婉']!.id],
            reason: '章${ch.idx} castIds');
      }
      // 人物事件线：每章 1 条林川事件
      final events = await (db.select(db.characterEvents)
            ..where((t) => t.projectId.equals(id)))
          .get();
      expect(events, hasLength(10));
      expect(events.every((e) => e.characterId == byName['林川']!.id), isTrue);

      // digestBefore：单批 10 章、批前快照占位，第 0-9 章一致
      expect(chs.map((c) => c.digestBefore),
          everyElement('（故事刚开始）'));

      // 批注落库（每章 L1+L3）+ L3 进知识卡
      final anns = await db.select(db.annotations).get();
      expect(anns, hasLength(20));
      final cards = await (db.select(db.knowledgeCards)
            ..where((t) => t.projectId.equals(id)))
          .get();
      expect(cards.map((c) => c.term),
          containsAll([for (var i = 0; i < 10; i++) '术语$i']));

      // 调用序：map×2 → digest×1 → annotate×4（冲刺覆盖全书，跟随段零调用）
      final purposes =
          (await db.select(db.llmLogs).get()).map((l) => l.purpose).toList();
      expect(purposes, [
        'novel_map',
        'novel_map',
        'novel_digest',
        'novel_annotate',
        'novel_annotate',
        'novel_annotate',
        'novel_annotate'
      ]);

      final p = await projectOf(id);
      expect(p.status, 'READY');
      expect(NovelMeta.fromJson(p.metaJson).annotatedChapters, 10);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('中途崩溃续跑：annotate 阶段 HTTP 500 → 换适配器续跑全书完成且零重复',
        () async {
      final id = await seedBook();
      // 2 map + 1 digest 成功（第 0-2 个请求），此后全部 500
      final bad = LaneScriptedAdapter(
          mapBodies: [mapResp5(0, 4), mapResp5(5, 9)],
          digestBodies: [digestResp()],
          annotateBodies: [annRespFull()],
          failAllFrom: 3);
      final scheduler = NovelScheduler(
          db: db,
          llm: llm(bad),
          params: const NovelParams(),
          isCancelled: () => false);
      Object? caught;
      try {
        await scheduler.run(id);
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<PipelineStageException>());
      expect((caught as PipelineStageException).stage, 'annotate');
      final chs = await chaptersOf(id);
      expect(chs.map((c) => c.mapDone), everyElement(isTrue));
      expect(chs.map((c) => c.digestBefore), everyElement(isNotNull));
      expect(chs.every((c) => !c.annotDone), isTrue);

      // 换新适配器补足 annotate：map/digest 因章节已完成直接跳过，零请求
      final good = LaneScriptedAdapter(
          mapBodies: [], digestBodies: [], annotateBodies: [annRespFull()]);
      final scheduler2 = NovelScheduler(
          db: db,
          llm: llm(good),
          params: const NovelParams(),
          isCancelled: () => false);
      await scheduler2.run(id);

      expect(good.order, ['annotate', 'annotate', 'annotate', 'annotate'],
          reason: '续跑只发 4 个 annotate 请求');
      final chs2 = await chaptersOf(id);
      expect(chs2.map((c) => c.annotDone), everyElement(isTrue));
      // annotations 无重复：每 paraId 每类型至多 1 行
      final anns = await db.select(db.annotations).get();
      expect(anns, hasLength(20));
      final seen = <String>{};
      for (final a in anns) {
        expect(seen.add('${a.paraId}:${a.type}'), isTrue,
            reason: 'para ${a.paraId} type ${a.type} 重复');
      }
      // characters 无重名（续跑未重跑地图趟）
      final names = await (db.select(db.characters)
            ..where((t) => t.projectId.equals(id)))
          .get();
      expect(names.map((c) => c.name).toSet(), hasLength(names.length));
      final p = await projectOf(id);
      expect(p.status, 'READY');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('取消：第 2 个 map 批完成后取消 → PipelineCancelled；再跑不取消可续完',
        () async {
      final id = await seedBook();
      var cancelled = false;
      final adapter = happyAdapter();
      final scheduler = NovelScheduler(
          db: db,
          llm: llm(adapter),
          params: const NovelParams(),
          isCancelled: () => cancelled,
          onEvent: (ev) {
            // 第二个地图批完成事件到达即置取消
            if (ev.kind == 'progress' && ev.detail == '地图 10/10 章') {
              cancelled = true;
            }
          });
      await expectLater(
          scheduler.run(id), throwsA(isA<PipelineCancelled>()));
      final chs = await chaptersOf(id);
      expect(chs.map((c) => c.mapDone), everyElement(isTrue),
          reason: '已完成的 map 章保留');
      expect(chs.every((c) => !c.annotDone), isTrue);
      final p = await projectOf(id);
      expect(p.status, 'IMPORTED');

      // 再跑（不取消）：map 已完成零请求，digest+annotate 补完全书
      final adapter2 = LaneScriptedAdapter(
          mapBodies: [],
          digestBodies: [digestResp()],
          annotateBodies: [annRespFull()]);
      final scheduler2 = NovelScheduler(
          db: db,
          llm: llm(adapter2),
          params: const NovelParams(),
          isCancelled: () => false);
      await scheduler2.run(id);
      expect(adapter2.order,
          ['digest', 'annotate', 'annotate', 'annotate', 'annotate']);
      final p2 = await projectOf(id);
      expect(p2.status, 'READY');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('失败语义（引擎外壳）：annotate 恒坏 JSON → FAILED(annotate) + failed 事件；'
        '修好重试恢复 READY', () async {
      final id = await seedBook();
      final adapter = LaneScriptedAdapter(
          mapBodies: [mapResp5(0, 4), mapResp5(5, 9)],
          digestBodies: [digestResp()],
          annotateBodies: ['这不是json']);
      final engine = NovelPipelineEngine(db: db);
      final scheduler = NovelScheduler(
          db: db,
          llm: llm(adapter),
          params: const NovelParams(),
          isCancelled: () => engine.isCancelled(id));
      engine.attachRun(scheduler.run);
      final events = <PipelineEvent>[];
      engine.events.listen(events.add);
      await engine.run(id);

      var p = await projectOf(id);
      expect(p.status, 'FAILED');
      expect(p.failedStage, 'annotate');
      expect(events.where((e) => e.status == ProjectStatus.failed), isNotEmpty);

      // 修复 annotate 响应后 retry：坏响应不入缓存，重跑发出全新合法调用
      final adapter2 = LaneScriptedAdapter(
          mapBodies: [], digestBodies: [], annotateBodies: [annRespFull()]);
      final scheduler2 = NovelScheduler(
          db: db,
          llm: llm(adapter2),
          params: const NovelParams(),
          isCancelled: () => engine.isCancelled(id));
      engine.attachRun(scheduler2.run);
      await engine.retry(id);

      expect(adapter2.order, ['annotate', 'annotate', 'annotate', 'annotate']);
      p = await projectOf(id);
      expect(p.status, 'READY');
      expect(p.failedStage, isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('里程碑只升不降：预置 MAPPED → 完整 run 终态 READY，过程中无回写 IMPORTED',
        () async {
      final id = await seedBook();
      await (db.update(db.projects)..where((t) => t.id.equals(id)))
          .write(const ProjectsCompanion(status: Value('MAPPED')));
      final adapter = happyAdapter();
      final events = <NovelSchedulerEvent>[];
      final scheduler = NovelScheduler(
          db: db,
          llm: llm(adapter),
          params: const NovelParams(),
          isCancelled: () => false,
          onEvent: events.add);
      await scheduler.run(id);

      final milestones = [
        for (final e in events)
          if (e.kind == 'milestone') e.status!,
      ];
      expect(milestones, [ProjectStatus.commentaryDone, ProjectStatus.ready]);
      expect(milestones.any((s) => s == ProjectStatus.imported), isFalse);
      final p = await projectOf(id);
      expect(p.status, 'READY');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('两遍式管线集成（调度器级补充）', () {
    test('FAILED 恢复：预置 FAILED 项目 run 后里程碑直接升到目标态并清 failedStage',
        () async {
      final id = await seedBook();
      await (db.update(db.projects)..where((t) => t.id.equals(id)))
          .write(const ProjectsCompanion(
              status: Value('FAILED'), failedStage: Value('annotate')));
      final adapter = happyAdapter();
      final events = <NovelSchedulerEvent>[];
      final scheduler = NovelScheduler(
          db: db,
          llm: llm(adapter),
          params: const NovelParams(),
          isCancelled: () => false,
          onEvent: events.add);
      await scheduler.run(id);

      // FAILED 视为重跑恢复：mapped 也允许直接写（调度器级 _setMilestone 分支）
      final milestones = [
        for (final e in events)
          if (e.kind == 'milestone') e.status!,
      ];
      expect(milestones, [
        ProjectStatus.mapped,
        ProjectStatus.commentaryDone,
        ProjectStatus.ready
      ]);
      final p = await projectOf(id);
      expect(p.status, 'READY');
      expect(p.failedStage, isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
