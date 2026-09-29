import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/novel/novel_parser.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/pipeline/novel_annotate_pass.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/novel_recall.dart';
import 'package:peixi/features/pipeline/novel_scheduler.dart';
import 'package:peixi/providers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

const _route = ChannelRoute(
    id: 0, name: 'legacy', baseUrl: 'https://x/v1', apiKey: 'k', enabled: true);

final _jsonHeaders = {
  'content-type': ['application/json']
};

/// 双模式假适配器：/embeddings 端点按请求序返回预置向量矩阵；chat 端点按
/// 提示词锚点分流 map/digest/annotate（同调度器测试基建）。
/// [order] 记录全部请求类型序（含 embed），[embedInputCounts] 记录每次
/// embed 请求的 input 条数（断言批量语义）。
class DualModeAdapter implements HttpClientAdapter {
  DualModeAdapter({
    this.mapBodies = const [],
    this.digestBodies = const [],
    this.annotateBodies = const [],
    this.embeddingPages = const [],
    this.failEmbeddings = false,
  });

  final List<String> mapBodies;
  final List<String> digestBodies;
  final List<String> annotateBodies;

  /// 每次 /embeddings 请求返回的向量矩阵（按请求序消费，耗尽后复用末条；
  /// 每页按请求 input 数循环补齐到等长）。
  final List<List<List<double>>> embeddingPages;
  final bool failEmbeddings; // /embeddings 一律 500（LlmException 静默降级用）

  final requests = <RequestOptions>[];
  final order = <String>[]; // 'map' | 'digest' | 'annotate' | 'embed'
  final embedInputCounts = <int>[];
  final _taken = <String, int>{'map': 0, 'digest': 0, 'annotate': 0, 'embed': 0};

  List<List<double>> _embedPage(int n) {
    if (embeddingPages.isEmpty) {
      return [for (var i = 0; i < n; i++) <double>[1, 0]];
    }
    final i = _taken['embed']!;
    _taken['embed'] = i + 1;
    final page =
        i < embeddingPages.length ? embeddingPages[i] : embeddingPages.last;
    return [for (var j = 0; j < n; j++) page[j % page.length]];
  }

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
    if (options.path.endsWith('/embeddings')) {
      final n = ((options.data as Map)['input'] as List).length;
      embedInputCounts.add(n);
      order.add('embed');
      if (failEmbeddings) {
        return ResponseBody.fromString(
            '{"error":{"message":"embed down"}}', 500,
            headers: _jsonHeaders);
      }
      final vecs = _embedPage(n);
      return ResponseBody.fromString(
          '{"data":[${[for (final v in vecs) '{"embedding":${jsonEncode(v)}}'].join(',')}],'
          '"usage":{}}',
          200,
          headers: _jsonHeaders);
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
        headers: _jsonHeaders);
  }

  @override
  void close({bool force = false}) {}
}

/// 注入批注趟的假回忆提供者：记录调用参数、返回固定文本。
class _FakeRecall implements NovelRecallProvider {
  _FakeRecall(this.text);
  final String text;
  final calls = <(int, String)>[]; // (beforeChapterIdx, query)

  @override
  Future<void> ensureIndexed(int projectId) async {}

  @override
  Future<String> recallContext(int projectId,
      {required int beforeChapterIdx, required String query}) async {
    calls.add((beforeChapterIdx, query));
    return text;
  }
}

/// 全书 map 响应（复用末条，对批组成不敏感）。
String mapRespAll([int n = 10]) => '{"chapters":[${[
      for (var i = 0; i < n; i++)
        '{"idx":$i,"summary":"第$i章地图摘要","cast":["林川"]}',
    ].join(',')}]}';

String digestResp() => '{"digest":"故事至今快照"}';

/// 全书批注响应（每章 1 条 L1，para_idx = 全局段落 idx）。
String annRespAll([int n = 10]) => '{"chapters":[${[
      for (var i = 0; i < n; i++)
        '{"idx":$i,"annotations":'
            '[{"para_idx":${i * 2},"type":"L1","content":"批注$i"}]}',
    ].join(',')}]}';

class _NoWakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  LlmService llm(DualModeAdapter adapter, {bool withEmbedding = true}) {
    final svc = LlmService(db: db, dio: Dio()..httpClientAdapter = adapter,
        backoffBase: const Duration(milliseconds: 1));
    svc.updateRouting(RoutingTable(
      channels: [_route],
      slots: {
        LlmSlot.summary: const SlotBinding(channelId: 0, model: 'flash'),
        LlmSlot.analysis: const SlotBinding(channelId: 0, model: 'deep'),
        if (withEmbedding)
          LlmSlot.embedding: const SlotBinding(channelId: 0, model: 'embed-v1'),
      },
    ));
    return svc;
  }

  Future<int> seedBook([int n = 4]) async => NovelImporter(db: db).import(
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

  /// 预置第 0..through 章地图完成（摘要就绪；mapDone 是 ensureIndexed 的选批条件）。
  Future<void> markSummarized(int id, {required int through}) async {
    for (final ch in await chaptersOf(id)) {
      if (ch.idx > through) continue;
      await (db.update(db.chapters)..where((t) => t.id.equals(ch.id)))
          .write(ChaptersCompanion(
              mapDone: const Value(true),
              summary: Value('第${ch.idx}章摘要')));
    }
  }

  group('cosineSimilarity', () {
    test('正交=0、同向=1（1e-9 容差）、反向=-1、零向量=0、维度不等=0', () {
      expect(cosineSimilarity([1, 0], [0, 1]), 0);
      expect(cosineSimilarity([1, 1], [1, 1]), closeTo(1, 1e-9));
      expect(cosineSimilarity([1, 0], [-1, 0]), -1);
      expect(cosineSimilarity([0, 0], [1, 1]), 0);
      expect(cosineSimilarity([1], [1, 2]), 0);
      expect(cosineSimilarity([], []), 0);
    });
  });

  group('NovelRecallService.ensureIndexed（摘要向量索引）', () {
    test('摘要就绪章批量 embed 落库（dim/vectorJson/章关联正确）；无摘要章跳过', () async {
      final id = await seedBook(3);
      await markSummarized(id, through: 1); // 章 0-1 有摘要，章 2 无
      final adapter = DualModeAdapter(embeddingPages: [
        <List<double>>[[0.6, 0.8], [1, 0]],
      ]);
      final svc = NovelRecallService(db: db, llm: llm(adapter));
      await svc.ensureIndexed(id);

      expect(adapter.order, ['embed']);
      expect(adapter.embedInputCounts, [2], reason: '两章摘要合并为一次批量调用');
      final rows = await (db.select(db.chapterEmbeddings)
            ..where((t) => t.projectId.equals(id)))
          .get();
      expect(rows, hasLength(2));
      final chs = await chaptersOf(id);
      final byChapterId = {for (final r in rows) r.chapterId: r};
      expect(byChapterId[chs[0].id]!.dim, 2);
      expect(jsonDecode(byChapterId[chs[0].id]!.vectorJson), [0.6, 0.8]);
      expect(jsonDecode(byChapterId[chs[1].id]!.vectorJson), [1, 0]);
    });

    test('幂等：重复调用不重复 embed、不重复落库', () async {
      final id = await seedBook(2);
      await markSummarized(id, through: 1);
      final adapter = DualModeAdapter();
      final svc = NovelRecallService(db: db, llm: llm(adapter));
      await svc.ensureIndexed(id);
      await svc.ensureIndexed(id);
      expect(adapter.order, ['embed'], reason: '已有向量的章不再 embed');
      expect(await db.select(db.chapterEmbeddings).get(), hasLength(2));
    });

    test('embedding 槽位未绑定 / 端点 500 → LlmException 静默返回，不抛、不落库',
        () async {
      final id = await seedBook(2);
      await markSummarized(id, through: 1);

      final bare = DualModeAdapter();
      await NovelRecallService(db: db, llm: llm(bare, withEmbedding: false))
          .ensureIndexed(id);
      expect(bare.requests, isEmpty, reason: '槽位解析失败发生在 HTTP 之前');
      expect(await db.select(db.chapterEmbeddings).get(), isEmpty);

      final down = DualModeAdapter(failEmbeddings: true);
      await NovelRecallService(db: db, llm: llm(down)).ensureIndexed(id);
      expect(down.order, ['embed']);
      expect(await db.select(db.chapterEmbeddings).get(), isEmpty);
    });
  });

  group('NovelRecallService.recallContext（cos top3 前文回忆）', () {
    test('命中按分数降序、排除 beforeChapterIdx 及之后、低于阈值与无前文返回空', () async {
      final id = await seedBook(4);
      await markSummarized(id, through: 3);
      // 索引页（4 章向量两两可辨）+ 查询页 [0.6,0.8]（|q|=1）
      final adapter = DualModeAdapter(embeddingPages: [
        <List<double>>[
          [1, 0],
          [0, 1],
          [0.6, 0.8],
          [-1, 0],
        ],
        <List<double>>[[0.6, 0.8]],
      ]);
      final svc = NovelRecallService(db: db, llm: llm(adapter));
      await svc.ensureIndexed(id);

      // q=[0.6,0.8]：ch0=0.6 ✓ ch1=0.8 ✓ ch2=1.0 但 idx>=2 被排除 ch3=-0.6 低于阈值
      expect(
          await svc.recallContext(id, beforeChapterIdx: 2, query: '查询'),
          '- 第1章摘要：第1章摘要\n- 第0章摘要：第0章摘要');
      // beforeChapterIdx=1：只有 ch0 是前文
      expect(await svc.recallContext(id, beforeChapterIdx: 1, query: '查询'),
          '- 第0章摘要：第0章摘要');
      // beforeChapterIdx=0：无前文候选 → 空串
      expect(await svc.recallContext(id, beforeChapterIdx: 0, query: '查询'), '');
    });

    test('minScore 过滤 + topK 截断（可手算：1.0 / 0.96 / 0.8 / -1.0）', () async {
      final id = await seedBook(4);
      await markSummarized(id, through: 3);
      final adapter = DualModeAdapter(embeddingPages: [
        <List<double>>[
          [1, 0],
          [0.96, 0.28], // 单位向量，cos(q)=0.96
          [0.8, 0.6], // cos=0.8
          [-1, 0], // cos=-1
        ],
        <List<double>>[[1, 0]],
      ]);
      final svc = NovelRecallService(
          db: db, llm: llm(adapter), topK: 2, minScore: 0.35);
      await svc.ensureIndexed(id);

      // 4 章里 3 章过阈值，topK=2 只取前两名
      expect(await svc.recallContext(id, beforeChapterIdx: 4, query: '查询'),
          '- 第0章摘要：第0章摘要\n- 第1章摘要：第1章摘要');
    });

    test('无索引直接空串（零 embed 调用）；embed 失败静默返回空串', () async {
      final id = await seedBook(2);
      await markSummarized(id, through: 1);
      final adapter = DualModeAdapter(embeddingPages: [
        <List<double>>[[1, 0]],
      ]);
      final svc = NovelRecallService(db: db, llm: llm(adapter));
      expect(await svc.recallContext(id, beforeChapterIdx: 2, query: 'q'), '');
      expect(adapter.order, isEmpty, reason: '无索引时不浪费查询向量调用');

      final down = DualModeAdapter(failEmbeddings: true);
      expect(
          await NovelRecallService(db: db, llm: llm(down))
              .recallContext(id, beforeChapterIdx: 2, query: 'q'),
          '');
    });
  });

  group('NovelAnnotatePass 注入集成（[相关前文回忆] 节）', () {
    Future<void> markReady(int id) async {
      for (final ch in await chaptersOf(id)) {
        await (db.update(db.chapters)..where((t) => t.id.equals(ch.id)))
            .write(ChaptersCompanion(
                mapDone: const Value(true),
                summary: Value('第${ch.idx}章摘要'),
                digestBefore: Value('快照${ch.idx}')));
      }
    }

    test('recall 返回文本 → 请求含回忆节；调用参数 beforeChapterIdx=批首章、query=快照',
        () async {
      final id = await seedBook(3);
      await markReady(id);
      final adapter = DualModeAdapter(annotateBodies: [annRespAll(3)]);
      final fake = _FakeRecall('林川在第0章立誓变强');
      final pass =
          NovelAnnotatePass(db: db, llm: llm(adapter), batchChapters: 3, recall: fake);
      expect(await pass.step(id), 3);

      final prompt = (adapter.requests.single.data as Map)['messages'].last['content']
          as String;
      expect(prompt, contains('[相关前文回忆]\n林川在第0章立誓变强'));
      expect(fake.calls.single, (0, '快照0'));
    });

    test('recall 返回空串 → 回忆节整体缺席', () async {
      final id = await seedBook(3);
      await markReady(id);
      final adapter = DualModeAdapter(annotateBodies: [annRespAll(3)]);
      final pass = NovelAnnotatePass(
          db: db, llm: llm(adapter), batchChapters: 3, recall: _FakeRecall(''));
      expect(await pass.step(id), 3);

      final prompt = (adapter.requests.single.data as Map)['messages'].last['content']
          as String;
      expect(prompt, isNot(contains('[相关前文回忆]')));
    });
  });

  group('调度器三态（recall 可选层）', () {
    final params = const NovelParams(
        mapBatchChapters: 2,
        digestBatchChapters: 3,
        annotateBatchChapters: 2,
        initialBurstChapters: 4,
        mapLeadChapters: 3);

    test('recall=null：全程零 embed 调用、零向量行（关闭零影响）', () async {
      final id = await seedBook(10);
      final adapter = DualModeAdapter(
          mapBodies: [mapRespAll()],
          digestBodies: [digestResp()],
          annotateBodies: [annRespAll()]);
      final scheduler = NovelScheduler(
          db: db, llm: llm(adapter), params: params, isCancelled: () => false);
      await scheduler.run(id);

      expect(adapter.order.where((k) => k == 'embed'), isEmpty);
      expect(await db.select(db.chapterEmbeddings).get(), isEmpty);
      final p = await projectOf(id);
      expect(p.status, 'READY');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('recall 注入：冲刺地图后 + 地图泳道每步后 ensureIndexed（摘要就绪即向量化）',
        () async {
      final id = await seedBook(10);
      final adapter = DualModeAdapter(
          mapBodies: [mapRespAll()],
          digestBodies: [digestResp()],
          annotateBodies: [annRespAll()]);
      final svc = llm(adapter);
      final scheduler = NovelScheduler(
          db: db,
          llm: svc,
          params: params,
          recall: NovelRecallService(db: db, llm: svc),
          isCancelled: () => false);
      await scheduler.run(id);

      // 冲刺段确定序：2 map → embed(章 0-3 索引) → 2 digest → 首个 annotate
      // 批先 recallContext（embed 查询向量）再发批注调用
      expect(adapter.order.take(7),
          ['map', 'map', 'embed', 'digest', 'digest', 'embed', 'annotate']);
      // ensureIndexed 恰 4 次（冲刺后 1 + 地图泳道每步后 3，批量 4/2/2/2）；
      // 每个批注批恰好 1 次查询向量 embed。批注批会在快照前沿截断（如
      // 6~6、9~9），批数随双泳道时序浮动 → 用不变式断言：
      // embed 总数 = 4 次索引 + 批注批数
      final annotateCalls =
          adapter.order.where((k) => k == 'annotate').length;
      expect(annotateCalls, greaterThanOrEqualTo(5));
      expect(adapter.order.where((k) => k == 'embed'),
          hasLength(4 + annotateCalls));
      expect(adapter.embedInputCounts.where((c) => c > 1).toList(),
          [4, 2, 2, 2]);
      // 全书完成后所有章都有向量
      expect(await db.select(db.chapterEmbeddings).get(), hasLength(10));
      final p = await projectOf(id);
      expect(p.status, 'READY');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('控制器接线（pipeline_controller 占位替换）', () {
    late ProviderContainer container;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      wakelockPlusPlatformInstance = _NoWakelock();
    });

    tearDown(() async {
      container.dispose();
    });

    Future<void> untilReady(int id) async {
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(deadline)) {
        final p = await (db.select(db.projects)
              ..where((t) => t.id.equals(id)))
            .getSingle();
        if (p.status == 'READY') return;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      fail('项目未在时限内完成');
    }

    test('vectorRecall 开 + embedding 槽位绑定 → 构造 NovelRecallService：调用序含 embed、向量落库',
        () async {
      final adapter = DualModeAdapter(
          mapBodies: [mapRespAll()],
          digestBodies: [digestResp()],
          annotateBodies: [annRespAll()]);
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepoProvider.overrideWithValue(
            SettingsRepository(db, const FlutterSecureStorage())),
        llmServiceProvider.overrideWithValue(llm(adapter)),
      ]);
      // 先让启动续跑微任务在空库上跑完，避免与本次导入竞态
      container.read(pipelineControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final id = await seedBook(10);
      await SettingsRepository(db, const FlutterSecureStorage())
          .saveNovelParams(const NovelParams(vectorRecall: true));
      final controller = container.read(pipelineControllerProvider.notifier);
      await controller.retry(id);
      await untilReady(id);
      await controller.waitPipelineIdle();

      // 默认参数 burst=10=全书：map×2 → embed(10 章索引) → digest →
      // 每个 annotate 批先 recallContext（查询向量 embed 1 条）再发批注调用
      expect(adapter.order, [
        'map', 'map', 'embed', 'digest', //
        'embed', 'annotate', //
        'embed', 'annotate', //
        'embed', 'annotate', //
        'embed', 'annotate',
      ]);
      expect(adapter.embedInputCounts, [10, 1, 1, 1, 1]);
      expect(await db.select(db.chapterEmbeddings).get(), hasLength(10));
      final p = await projectOf(id);
      expect(p.status, 'READY');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('vectorRecall 关（默认）→ 零构造零调用：无 embed 请求、无向量行', () async {
      final adapter = DualModeAdapter(
          mapBodies: [mapRespAll()],
          digestBodies: [digestResp()],
          annotateBodies: [annRespAll()]);
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepoProvider.overrideWithValue(
            SettingsRepository(db, const FlutterSecureStorage())),
        llmServiceProvider.overrideWithValue(llm(adapter)),
      ]);
      container.read(pipelineControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final id = await seedBook(10);
      final controller = container.read(pipelineControllerProvider.notifier);
      await controller.retry(id);
      await untilReady(id);
      await controller.waitPipelineIdle();

      expect(adapter.order.where((k) => k == 'embed'), isEmpty);
      expect(await db.select(db.chapterEmbeddings).get(), isEmpty);
      final p = await projectOf(id);
      expect(p.status, 'READY');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
