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
import 'package:peixi/features/pipeline/novel_digest_pass.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';

/// 单可用渠道路由表（快照趟走 summary 槽位）。
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

  /// 造 n 章书并全部完成地图趟（summary='第i章摘要'）。
  Future<int> seedMappedBook(int n) async {
    final id = await NovelImporter(db: db).import(
        title: '书',
        sourcePath: '/book.txt',
        doc: NovelDoc(chapters: [
          for (var i = 0; i < n; i++)
            NovelChapter(idx: i, title: '第${i + 1}章', paragraphs: ['第$i章正文。']),
        ]));
    final chs = await (db.select(db.chapters)
          ..where((t) => t.projectId.equals(id))
          ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
        .get();
    for (final ch in chs) {
      await (db.update(db.chapters)..where((t) => t.id.equals(ch.id)))
          .write(ChaptersCompanion(
              mapDone: const Value(true),
              summary: Value('第${ch.idx}章摘要')));
    }
    return id;
  }

  Future<List<Chapter>> chaptersOf(int id) => (db.select(db.chapters)
        ..where((t) => t.projectId.equals(id))
        ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
      .get();

  Future<NovelMeta> metaOf(int id) async {
    final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
        .getSingle();
    return NovelMeta.fromJson(p.metaJson);
  }

  group('NovelDigestPass（快照趟）', () {
    test('整批合成：批内 digest_before=批前快照，滚动摘要写回 meta', () async {
      final id = await seedMappedBook(20);
      final adapter = ScriptedAdapter(
          ['{"digest":"新摘要一"}', '{"digest":"新摘要二"}']);
      final progress = <String>[];
      final pass = NovelDigestPass(db: db, llm: llm(adapter),
          batchChapters: 10, onProgress: (d, t) => progress.add('$d/$t'));

      // 第一批 = 第 0-9 章
      expect(await pass.step(id), 10);
      var prompt = promptOf(adapter);
      expect(prompt, contains('[旧摘要]（故事刚开始）'));
      for (var i = 0; i < 10; i++) {
        expect(prompt, contains('- 第$i章 第$i章摘要'));
      }
      expect(prompt, isNot(contains('- 第10章')));
      expect((adapter.requests[0].data as Map)['model'], 'flash');
      final logs = await db.select(db.llmLogs).get();
      expect(logs.map((l) => l.purpose), everyElement('novel_digest'));

      var chs = await chaptersOf(id);
      // 批内每章 digest_before = 批前快照（章内细粒度由批注趟[前文摘要]补足）
      for (final ch in chs.take(10)) {
        expect(ch.digestBefore, '（故事刚开始）');
      }
      for (final ch in chs.skip(10)) {
        expect(ch.digestBefore, isNull);
      }
      expect((await metaOf(id)).digest, '新摘要一');

      // 第二批 = 第 10-19 章，旧摘要 = 上一批产出
      expect(await pass.step(id), 10);
      prompt = promptOf(adapter, 1);
      expect(prompt, contains('[旧摘要]新摘要一'));
      expect(prompt, contains('- 第10章 第10章摘要'));
      expect(prompt, isNot(contains('- 第9章 第9章摘要')));
      chs = await chaptersOf(id);
      for (final ch in chs.skip(10)) {
        expect(ch.digestBefore, '新摘要一');
      }
      expect((await metaOf(id)).digest, '新摘要二');
      expect(progress, ['10/20', '20/20']);
      expect(await pass.step(id), 0);
      expect(adapter.requests, hasLength(2));
    });

    test('批在地图前沿截断：不吃进未映射章', () async {
      final id = await NovelImporter(db: db).import(
          title: '书',
          sourcePath: '/book.txt',
          doc: NovelDoc(chapters: [
            for (var i = 0; i < 6; i++)
              NovelChapter(idx: i, title: '第${i + 1}章', paragraphs: ['第$i章正文。']),
          ]));
      final chs = await chaptersOf(id);
      for (final ch in chs.take(3)) {
        await (db.update(db.chapters)..where((t) => t.id.equals(ch.id)))
            .write(ChaptersCompanion(
                mapDone: const Value(true), summary: Value('第${ch.idx}章摘要')));
      }
      final adapter = ScriptedAdapter(['{"digest":"新摘要"}']);
      final n = await NovelDigestPass(db: db, llm: llm(adapter),
          batchChapters: 5).step(id);
      expect(n, 3); // 第 3 章 mapDone=false → 批只含第 0-2 章
      final prompt = promptOf(adapter);
      expect(prompt, contains('- 第2章 第2章摘要'));
      expect(prompt, isNot(contains('- 第3章')));
      final after = await chaptersOf(id);
      expect(after.take(3).map((c) => c.digestBefore), everyElement(isNotNull));
      expect(after[3].digestBefore, isNull);
    });

    test('上游未就绪：首个无快照章未完成地图 → 返回 0 且零调用', () async {
      final id = await seedMappedBook(4);
      // 全部撤销地图完成态
      final chs = await chaptersOf(id);
      for (final ch in chs) {
        await (db.update(db.chapters)..where((t) => t.id.equals(ch.id)))
            .write(const ChaptersCompanion(mapDone: Value(false)));
      }
      final adapter = ScriptedAdapter(['{"digest":"不应被调用"}']);
      final n = await NovelDigestPass(db: db, llm: llm(adapter)).step(id);
      expect(n, 0);
      expect(adapter.requests, isEmpty);
    });

    test('续跑：从首个无快照章起批', () async {
      final id = await seedMappedBook(10);
      final chs = await chaptersOf(id);
      for (final ch in chs.take(5)) {
        await (db.update(db.chapters)..where((t) => t.id.equals(ch.id)))
            .write(const ChaptersCompanion(digestBefore: Value('已有快照')));
      }
      final adapter = ScriptedAdapter(['{"digest":"新快照"}']);
      final n = await NovelDigestPass(db: db, llm: llm(adapter)).step(id);
      expect(n, 5);
      final prompt = promptOf(adapter);
      expect(prompt, contains('- 第5章'));
      expect(prompt, isNot(contains('- 第4章')));
    });

    test('兜底：合成失败 → 拼接截断（≤400 字）且不阻塞', () async {
      final id = await seedMappedBook(10);
      final adapter = ScriptedAdapter(['不是json', '修复后仍不是json']);
      final degraded = <String>[];
      final n = await NovelDigestPass(db: db, llm: llm(adapter),
              onDegraded: (d) => degraded.add(d))
          .step(id);
      expect(n, 10); // 兜底照常落库，不阻塞批注主线
      expect(degraded, hasLength(1));
      expect(degraded.single, contains('兜底'));
      expect(adapter.requests, hasLength(2)); // 正文 + 修复链
      final meta = await metaOf(id);
      expect(meta.digest!.length, lessThanOrEqualTo(400));
      expect(meta.digest!, contains('（故事刚开始）'));
      expect(meta.digest!, contains('第0章摘要'));
      expect(meta.digest!, contains('第9章摘要'));
      final chs = await chaptersOf(id);
      expect(chs.map((c) => c.digestBefore), everyElement('（故事刚开始）'));
    });

    test('回填老项目：快照从首个未批注且无快照章续起，旧章不被触碰', () async {
      final id = await seedMappedBook(10);
      final chs = await chaptersOf(id);
      // 回填产物形态：章 0-4 annotDone=1 而 digestBefore=null；章 5 挂旧断点快照
      for (final ch in chs.take(5)) {
        await (db.update(db.chapters)..where((t) => t.id.equals(ch.id)))
            .write(const ChaptersCompanion(annotDone: Value(true)));
      }
      await (db.update(db.chapters)..where((t) => t.id.equals(chs[5].id)))
          .write(const ChaptersCompanion(digestBefore: Value('旧断点快照')));
      // meta.digest 预置旧摘要（回填保留）
      final p =
          await (db.select(db.projects)..where((t) => t.id.equals(id))).getSingle();
      final meta = NovelMeta.fromJson(p.metaJson)..digest = '旧摘要';
      await (db.update(db.projects)..where((t) => t.id.equals(id)))
          .write(ProjectsCompanion(metaJson: Value(meta.encode())));

      final adapter = ScriptedAdapter(['{"digest":"新摘要"}']);
      final n = await NovelDigestPass(db: db, llm: llm(adapter)).step(id);
      expect(n, 4); // 批 = 第 6-9 章（首个未批注且无快照章起），不从第 0 章重启
      final prompt = promptOf(adapter);
      expect(prompt, contains('[旧摘要]旧摘要')); // 快照链自旧摘要续起，无双计
      expect(prompt, contains('- 第6章'));
      expect(prompt, isNot(contains('- 第5章')));
      expect(prompt, isNot(contains('- 第0章')));
      final after = await chaptersOf(id);
      for (final ch in after.take(5)) {
        expect(ch.digestBefore, isNull); // 旧章不被触碰（无剧透快照写入）
        expect(ch.annotDone, isTrue);
      }
      expect(after[5].digestBefore, '旧断点快照');
      for (final ch in after.skip(6)) {
        expect(ch.digestBefore, '旧摘要');
      }
      expect((await metaOf(id)).digest, '新摘要'); // meta.digest 滚动推进而非重置
    });

    test('预算异常透传：LlmBudgetException 不被拼接兜底吞掉', () async {
      final id = await seedMappedBook(4);
      await db.into(db.settings).insert(SettingsCompanion.insert(
          key: 'llm.monthly_budget_tokens', value: '100'));
      await db.into(db.llmLogs).insert(LlmLogsCompanion.insert(
          purpose: '预热', model: 'flash', promptTokens: const Value(100)));
      final adapter = ScriptedAdapter(['{"digest":"不应被调用"}']);
      await expectLater(NovelDigestPass(db: db, llm: llm(adapter)).step(id),
          throwsA(isA<LlmBudgetException>()));
      expect(adapter.requests, isEmpty); // 预算闸门在 HTTP 之前拦截
      // 兜底拼接不得落库：快照与 meta.digest 均保持原状
      final chs = await chaptersOf(id);
      expect(chs.map((c) => c.digestBefore), everyElement(isNull));
      expect((await metaOf(id)).digest, isNull);
    });

    test('UTF-16 尾部截断不劈代理对：emoji 完整保留', () async {
      final id = await seedMappedBook(1);
      // oldDigest = 😀 + 'z'*393 → merged 长 401，start=1 恰落在 emoji 低代理上
      final p =
          await (db.select(db.projects)..where((t) => t.id.equals(id))).getSingle();
      final meta = NovelMeta.fromJson(p.metaJson)..digest = '😀${'z' * 393}';
      await (db.update(db.projects)..where((t) => t.id.equals(id)))
          .write(ProjectsCompanion(metaJson: Value(meta.encode())));
      final adapter = ScriptedAdapter(['不是json', '修复后仍不是json']); // 走拼接兜底
      await NovelDigestPass(db: db, llm: llm(adapter)).step(id);
      final digest = (await metaOf(id)).digest!;
      expect(digest.startsWith('😀'), isTrue); // emoji 成对保留，而非只剩低代理
      expect(digest.runes.length, 400);
    });

    test('取消：step 抛 PipelineCancelled 且零调用', () async {
      final id = await seedMappedBook(4);
      final adapter = ScriptedAdapter([]);
      await expectLater(
          NovelDigestPass(db: db, llm: llm(adapter), isCancelled: () => true)
              .step(id),
          throwsA(isA<PipelineCancelled>()));
      expect(adapter.requests, isEmpty);
    });
  });
}
