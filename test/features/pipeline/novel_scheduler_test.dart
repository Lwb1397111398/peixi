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
import 'package:peixi/features/pipeline/novel_scheduler.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';
import 'package:peixi/features/pipeline/project_status.dart';

/// 单可用渠道路由表：summary/analysis 双槽位显式绑定。
const _route = ChannelRoute(
    id: 0, name: 'legacy', baseUrl: 'https://x/v1', apiKey: 'k', enabled: true);

/// 按提示词特征分流三类趟的假适配器。
///
/// 跟随模式双泳道并发交错，HTTP 请求的全局次序不定——按"请求序"派发响应会
/// 把 map 响应喂给 digest 调用。改为按提示词锚点识别调用类型、各类型独立
/// 队列（耗尽后复用末条），对每类调用给出确定响应；[order] 记录请求类型序。
class LaneScriptedAdapter implements HttpClientAdapter {
  LaneScriptedAdapter({
    this.mapBodies = const [],
    this.digestBodies = const [],
    this.annotateBodies = const [],
  });
  final List<String> mapBodies;
  final List<String> digestBodies;
  final List<String> annotateBodies;

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

/// 全书 map 响应：_apply 只处理批内章、跳过已完成章——多给的条目被忽略，
/// 因此单条响应可安全复用于任意批组成（泳道交错下批边界不定）。
String mapResp([List<int>? idxs]) {
  final list = idxs ?? List.generate(10, (i) => i);
  return '{"chapters":[${[
    for (final i in list) '{"idx":$i,"summary":"地图摘要$i","cast":["林川"]}',
  ].join(',')}]}';
}

String digestResp() => '{"digest":"故事至今快照"}';

/// 全书批注响应：同上，对批组成不敏感；缺章场景用 idxs 白名单表达。
/// para_idx 是全局段落编号：每章 2 段，第 i 章首段全局 idx = i*2。
String annResp([List<int>? idxs]) {
  final list = idxs ?? List.generate(10, (i) => i);
  return '{"chapters":[${[
    for (final i in list)
      '{"idx":$i,"annotations":[{"para_idx":${i * 2},"type":"L1","content":"批注$i"}]}',
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

  /// 10 章书（每章 2 段）；计划 Task 7 的标准参数：burst=4、map=2、digest=3、
  /// annotate=2、mapLead=3。
  Future<int> seedBook() async => NovelImporter(db: db).import(
      title: '书',
      sourcePath: '/book.txt',
      doc: NovelDoc(chapters: [
        for (var i = 0; i < 10; i++)
          NovelChapter(
              idx: i,
              title: '第${i + 1}章',
              paragraphs: ['第$i章段落甲。', '第$i章段落乙。']),
      ]));

  final params = const NovelParams(
      mapBatchChapters: 2,
      digestBatchChapters: 3,
      annotateBatchChapters: 2,
      initialBurstChapters: 4,
      mapLeadChapters: 3);

  Future<List<Chapter>> chaptersOf(int id) => (db.select(db.chapters)
        ..where((t) => t.projectId.equals(id))
        ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
      .get();

  Future<Project> projectOf(int id) => (db.select(db.projects)
        ..where((t) => t.id.equals(id)))
      .getSingle();

  group('NovelScheduler（首屏冲刺 + 双泳道跟随）', () {
    test('首屏冲刺：前 4 章 map→digest→annotate 顺序就绪；burst 事件后取消', () async {
      final id = await seedBook();
      final adapter = LaneScriptedAdapter(
          mapBodies: [mapResp()],
          digestBodies: [digestResp()],
          annotateBodies: [annResp()]);
      var cancelled = false;
      final events = <NovelSchedulerEvent>[];
      final scheduler = NovelScheduler(
          db: db,
          llm: llm(adapter),
          params: params,
          isCancelled: () => cancelled,
          onEvent: (ev) {
            events.add(ev);
            // burst 事件到达即取消：观察冲刺产物、截断跟随阶段
            if (ev.kind == 'burst') cancelled = true;
          });
      await expectLater(
          scheduler.run(id), throwsA(isA<PipelineCancelled>()));

      // 冲刺阶段调用序 = map,map,digest,digest,annotate,annotate
      final purposes =
          (await db.select(db.llmLogs).get()).map((l) => l.purpose).toList();
      expect(purposes, [
        'novel_map',
        'novel_map',
        'novel_digest',
        'novel_digest',
        'novel_annotate',
        'novel_annotate'
      ]);
      expect(events.map((e) => e.kind), contains('burst'));

      final chs = await chaptersOf(id);
      for (var i = 0; i < 4; i++) {
        expect(chs[i].mapDone, isTrue, reason: '章$i');
        expect(chs[i].digestBefore, isNotNull, reason: '章$i');
        expect(chs[i].annotDone, isTrue, reason: '章$i');
      }
      for (var i = 4; i < 10; i++) {
        expect(chs[i].mapDone, isFalse, reason: '章$i');
        expect(chs[i].digestBefore, isNull, reason: '章$i');
        expect(chs[i].annotDone, isFalse, reason: '章$i');
      }
      final p = await projectOf(id);
      expect(p.status, 'IMPORTED');
    });

    test('跟随推进到全书完成：里程碑 MAPPED→COMMENTARY_DONE→READY + 徽章 10', () async {
      final id = await seedBook();
      final adapter = LaneScriptedAdapter(
          mapBodies: [mapResp()],
          digestBodies: [digestResp()],
          annotateBodies: [annResp()]);
      final events = <NovelSchedulerEvent>[];
      final scheduler = NovelScheduler(
          db: db, llm: llm(adapter), params: params,
          isCancelled: () => false, onEvent: events.add);
      await scheduler.run(id);

      final chs = await chaptersOf(id);
      expect(chs.map((c) => c.mapDone), everyElement(isTrue));
      expect(chs.map((c) => c.annotDone), everyElement(isTrue));
      expect(chs.map((c) => c.digestBefore), everyElement(isNotNull));
      final p = await projectOf(id);
      expect(p.status, 'READY');
      final meta = NovelMeta.fromJson(p.metaJson);
      expect(meta.digest, isNotNull);
      expect(meta.digest, isNotEmpty);
      expect(meta.annotatedChapters, 10);
      // 批注真落库（每章 1 条 L1）
      final anns = await db.select(db.annotations).get();
      expect(anns, hasLength(10));
      // 里程碑事件只升不降、顺序正确
      final milestones = [
        for (final e in events)
          if (e.kind == 'milestone') e.status!,
      ];
      expect(milestones, [
        ProjectStatus.mapped,
        ProjectStatus.commentaryDone,
        ProjectStatus.ready
      ]);
      expect(events.map((e) => e.kind), contains('burst'));
    });

    test('地图领先保活：冲刺后首个请求是 map，地图先于批注收尾', () async {
      final id = await seedBook();
      final adapter = LaneScriptedAdapter(
          mapBodies: [mapResp()],
          digestBodies: [digestResp()],
          annotateBodies: [annResp()]);
      final scheduler = NovelScheduler(
          db: db, llm: llm(adapter), params: params, isCancelled: () => false);
      await scheduler.run(id);

      final order = adapter.order;
      // 冲刺段确定序
      expect(order.take(6),
          ['map', 'map', 'digest', 'digest', 'annotate', 'annotate']);
      // 首屏后第一个请求是 map（领先保活：地图泳道抢先补前沿）
      expect(order[6], 'map');
      // 全书地图恰好 5 批（mapBatch=2 × 10 章；批边界不受泳道交错影响）
      expect(order.where((k) => k == 'map'), hasLength(5));
      // 地图的最后一个请求发生在批注收尾之前（8-9 章的快照/批注依赖地图）
      expect(order.lastIndexOf('map'), lessThan(order.lastIndexOf('annotate')));
      // 全书完成
      final chs = await chaptersOf(id);
      expect(chs.map((c) => c.annotDone), everyElement(isTrue));
    });

    test('地图泳道失败传导：跟随阶段 map 持续坏 JSON → PipelineStageException(map)', () async {
      final id = await seedBook();
      final adapter = LaneScriptedAdapter(
          mapBodies: [mapResp(), mapResp(), '不是json'],
          digestBodies: [digestResp()],
          annotateBodies: [annResp()]);
      final scheduler = NovelScheduler(
          db: db, llm: llm(adapter), params: params, isCancelled: () => false);
      Object? caught;
      try {
        await scheduler.run(id);
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<PipelineStageException>());
      expect((caught as PipelineStageException).stage, 'map');
      // 冲刺段产物保留；跟随段地图前沿不再前进
      final chs = await chaptersOf(id);
      expect(chs.take(4).map((c) => c.mapDone), everyElement(isTrue));
      expect(chs.skip(4).map((c) => c.mapDone), everyElement(isFalse));
      // 调度器不落 FAILED（引擎外壳职责）
      final p = await projectOf(id);
      expect(p.status, 'IMPORTED');
    });

    test('批注持续零进度：上游停滞且连续 3 批无产出 → PipelineStageException(annotate)',
        () async {
      final id = await seedBook();
      // 批注响应只含已完成章（0-3）→ 跟随阶段批注零进展；
      // map 响应全量复用 → 地图泳道推进到领先约束处（mapDone=8）后停滞
      final adapter = LaneScriptedAdapter(
          mapBodies: [mapResp()],
          digestBodies: [digestResp()],
          annotateBodies: [annResp([0, 1, 2, 3])]);
      final scheduler = NovelScheduler(
          db: db, llm: llm(adapter), params: params, isCancelled: () => false);
      Object? caught;
      try {
        await scheduler.run(id);
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<PipelineStageException>());
      expect((caught as PipelineStageException).stage, 'annotate');
      // 已完成部分保留
      final chs = await chaptersOf(id);
      expect(chs.take(4).map((c) => c.annotDone), everyElement(isTrue));
      expect(chs.skip(4).map((c) => c.annotDone), everyElement(isFalse));
    });

    test('取消：首个 map 批完成后置取消 → PipelineCancelled，进度保留状态不变', () async {
      final id = await seedBook();
      final adapter = LaneScriptedAdapter(
          mapBodies: [mapResp()],
          digestBodies: [digestResp()],
          annotateBodies: [annResp()]);
      var cancelled = false;
      final scheduler = NovelScheduler(
          db: db,
          llm: llm(adapter),
          params: params,
          isCancelled: () => cancelled,
          onEvent: (ev) {
            // 首个地图进度事件（第一批完成）即置取消
            if (ev.kind == 'progress' && ev.detail.startsWith('地图')) {
              cancelled = true;
            }
          });
      await expectLater(
          scheduler.run(id), throwsA(isA<PipelineCancelled>()));
      expect(adapter.order, ['map']);
      final chs = await chaptersOf(id);
      expect(chs[0].mapDone, isTrue);
      expect(chs[1].mapDone, isTrue);
      expect(chs[2].mapDone, isFalse);
      expect(chs.every((c) => c.digestBefore == null), isTrue);
      expect(chs.every((c) => !c.annotDone), isTrue);
      final p = await projectOf(id);
      expect(p.status, 'IMPORTED');
    });

    test('里程碑只升不降：预置 MAPPED 后 run 不回写 IMPORTED，终态 READY', () async {
      final id = await seedBook();
      await (db.update(db.projects)..where((t) => t.id.equals(id)))
          .write(const ProjectsCompanion(status: Value('MAPPED')));
      final adapter = LaneScriptedAdapter(
          mapBodies: [mapResp()],
          digestBodies: [digestResp()],
          annotateBodies: [annResp()]);
      final events = <NovelSchedulerEvent>[];
      final scheduler = NovelScheduler(
          db: db, llm: llm(adapter), params: params,
          isCancelled: () => false, onEvent: events.add);
      await scheduler.run(id);

      final p = await projectOf(id);
      expect(p.status, 'READY');
      // 已是 MAPPED：不再发 mapped 里程碑事件，直接 commentaryDone → ready
      final milestones = [
        for (final e in events)
          if (e.kind == 'milestone') e.status!,
      ];
      expect(milestones, [
        ProjectStatus.commentaryDone,
        ProjectStatus.ready
      ]);
      // 全程无事件把状态写回 IMPORTED
      expect(
          milestones.any((s) => s == ProjectStatus.imported), isFalse);
    });

    test('模型漏章自愈：首个 map 批缺第 1 章 → 从第 1 章重试直至全书完成', () async {
      final id = await seedBook();
      // 首个 map 响应缺第 1 章；其后全量响应自愈（_apply 跳过已完成章）
      final adapter = LaneScriptedAdapter(
          mapBodies: [mapResp([0]), mapResp()],
          digestBodies: [digestResp()],
          annotateBodies: [annResp()]);
      final scheduler = NovelScheduler(
          db: db, llm: llm(adapter), params: params, isCancelled: () => false);
      await scheduler.run(id);

      final chs = await chaptersOf(id);
      expect(chs.map((c) => c.mapDone), everyElement(isTrue));
      expect(chs.map((c) => c.annotDone), everyElement(isTrue));
      expect(chs[1].summary, isNotEmpty); // 第 1 章在重试批中补齐
      final p = await projectOf(id);
      expect(p.status, 'READY');
    });

    test('冲刺零进展熔断：map 响应恒空 → 连续 10 批无法推进 → PipelineStageException(map)',
        () async {
      final id = await seedBook();
      final adapter = LaneScriptedAdapter(mapBodies: ['{"chapters":[]}']);
      final scheduler = NovelScheduler(
          db: db, llm: llm(adapter), params: params, isCancelled: () => false);
      Object? caught;
      try {
        await scheduler.run(id);
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<PipelineStageException>());
      expect((caught as PipelineStageException).stage, 'map');
      expect(adapter.order.where((k) => k == 'map'), hasLength(1)); // 缓存命中后不再发请求
    });

    test('digest 阶段失败：月度预算用尽原样落 PipelineStageException(digest)', () async {
      final id = await seedBook();
      // 每次调用记 30 token（10+20）：2 map（60）后首个 digest 放行（60 < 65）并
      // 记账至 90 → 第二个 digest 调用前检查 used=90 ≥ 65 → LlmBudgetException
      // 原样透传（无 HTTP 请求）
      await db.into(db.settings).insert(SettingsCompanion.insert(
          key: 'llm.monthly_budget_tokens', value: '65'));
      final adapter = LaneScriptedAdapter(
          mapBodies: [mapResp()],
          digestBodies: [digestResp()],
          annotateBodies: [annResp()]);
      final scheduler = NovelScheduler(
          db: db, llm: llm(adapter), params: params, isCancelled: () => false);
      Object? caught;
      try {
        await scheduler.run(id);
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<PipelineStageException>());
      expect((caught as PipelineStageException).stage, 'digest');
      expect(adapter.order, ['map', 'map', 'digest']);
      // 批注从未开始
      final chs = await chaptersOf(id);
      expect(chs.every((c) => !c.annotDone), isTrue);
    });
  });
}
