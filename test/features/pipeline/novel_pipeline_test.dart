import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/novel/novel_parser.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/novel_pipeline.dart';

/// 单可用渠道路由表：未显式绑定的槽位按默认模型回落（等价旧 updateConfig）。
const _route = ChannelRoute(
    id: 0, name: 'legacy', baseUrl: 'https://x/v1', apiKey: 'k', enabled: true);

/// 按请求顺序返回预置响应的假适配器（每次调用消耗一个脚本）。
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
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => db.close());

  final demoDoc = const NovelDoc(chapters: [
    NovelChapter(idx: 0, title: '第一章 山门', paragraphs: ['少年背剑而行。', '风起于青萍之末。']),
    NovelChapter(idx: 1, title: '第二章 客栈', paragraphs: ['店家压低了声音。']),
    NovelChapter(idx: 2, title: null, paragraphs: ['无标题块正文。', '第二段。', '第三段。']),
  ]);

  group('NovelImporter（N1 入库）', () {
    test('projects/chapters/paragraphs 落库，全局 idx 连续', () async {
      final id = await NovelImporter(db: db).import(
          title: '测试小说', sourcePath: 'C:/books/test.txt', doc: demoDoc);

      final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(p.type, 'novel');
      expect(p.status, 'IMPORTED');
      expect(p.title, '测试小说');
      final meta = NovelMeta.fromJson(p.metaJson);
      expect(meta.paraCount, 6);
      expect(meta.charCount, greaterThan(0));

      final chapters = await (db.select(db.chapters)
            ..where((t) => t.projectId.equals(id))
            ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
          .get();
      expect(chapters, hasLength(3));
      expect(chapters[0].title, '第一章 山门');
      expect(chapters[0].startPara, 0);
      expect(chapters[0].endPara, 1);
      expect(chapters[1].startPara, 2);
      expect(chapters[1].endPara, 2);
      expect(chapters[2].title, isNull);
      expect(chapters[2].startPara, 3);
      expect(chapters[2].endPara, 5);

      final paras = await (db.select(db.paragraphs)
            ..where((t) => t.projectId.equals(id))
            ..orderBy([(pp) => OrderingTerm.asc(pp.idx)]))
          .get();
      expect(paras.map((e) => e.content).toList(), [
        '少年背剑而行。',
        '风起于青萍之末。',
        '店家压低了声音。',
        '无标题块正文。',
        '第二段。',
        '第三段。',
      ]);
      expect(paras.map((e) => e.idx).toList(), [0, 1, 2, 3, 4, 5]);
      // chapterId 正确挂链
      expect(paras[2].chapterId, chapters[1].id);
      expect(paras[4].chapterId, chapters[2].id);
    });
  });

  group('NovelPipelineEngine（N2→N3→N4 状态机）', () {
    Future<int> seed() async => db.into(db.projects).insert(
        ProjectsCompanion.insert(
            type: 'novel',
            title: 't',
            sourcePath: '/x.txt',
            status: 'IMPORTED'));

    test('正常路径 IMPORTED→MAPPED→COMMENTARY_DONE→READY', () async {
      final id = await seed();
      final calls = <String>[];
      final e = NovelPipelineEngine(db: db);
      e.attachCollaborators(
        extractCast: (pid) async => calls.add('cast'),
        annotate: (pid) async => calls.add('annotate'),
      );
      final events = <String>[];
      e.events.listen((ev) => events.add('${ev.stage}:${ev.status.db}'));
      await e.run(id);

      expect(calls, ['cast', 'annotate']);
      final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(p.status, 'READY');
      // 阶段开始事件携带进入时的状态；状态落库在阶段成功后
      expect(events, ['map:IMPORTED', 'commentary:MAPPED', 'finalize:READY']);
    });

    test('annotate 失败 → FAILED+failed_stage，重试不重跑 N2', () async {
      final id = await seed();
      final calls = <String>[];
      final e = NovelPipelineEngine(db: db);
      e.attachCollaborators(
        extractCast: (pid) async => calls.add('cast'),
        annotate: (pid) async => throw Exception('LLM 超时'),
      );
      await e.run(id);
      var p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(p.status, 'FAILED');
      expect(p.failedStage, 'commentary');

      e.attachCollaborators(annotate: (pid) async => calls.add('annotate'));
      await e.retry(id);
      p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(p.status, 'READY');
      expect(calls, ['cast', 'annotate']); // cast 未被重跑
    });

    test('extractCast 失败 → FAILED+failed_stage=map', () async {
      final id = await seed();
      final e = NovelPipelineEngine(db: db);
      e.attachCollaborators(
        extractCast: (pid) async => throw Exception('配额不足'),
      );
      await e.run(id);
      final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(p.status, 'FAILED');
      expect(p.failedStage, 'map');
    });

    test('同项目防并发', () async {
      final id = await seed();
      final calls = <String>[];
      final e = NovelPipelineEngine(db: db);
      e.attachCollaborators(
        extractCast: (pid) async {
          calls.add('cast');
          await Future<void>.delayed(const Duration(milliseconds: 30));
        },
        annotate: (pid) async => calls.add('annotate'),
      );
      await Future.wait([e.run(id), e.run(id)]);
      expect(calls.where((c) => c == 'cast'), hasLength(1));
    });
  });

  group('NovelCharacterExtractor（N2 人物提取）', () {
    Future<(int, List<int>)> seedWithChapters() async {
      final id = await NovelImporter(db: db).import(
          title: '书', sourcePath: '/book.txt',
          doc: const NovelDoc(chapters: [
            NovelChapter(idx: 0, title: '第一章', paragraphs: ['甲拔剑指向乙。']),
            NovelChapter(idx: 1, title: '第二章', paragraphs: ['乙冷笑一声。', '丙从暗处走出。']),
          ]));
      final chapters = await (db.select(db.chapters)
            ..where((t) => t.projectId.equals(id))
            ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
          .get();
      return (id, chapters.map((c) => c.id).toList());
    }

    LlmService llm(ScriptedAdapter adapter) =>
        LlmService(db: db, dio: Dio()..httpClientAdapter = adapter)
          ..updateRouting(const RoutingTable(
            channels: [_route],
            slots: {LlmSlot.summary: SlotBinding(channelId: 0, model: 'flash')},
          ));

    test('逐章提取：人物落库、章摘要落库、名单滚动传递（指代一致）', () async {
      final (id, _) = await seedWithChapters();
      final adapter = ScriptedAdapter([
        '{"characters":['
        '{"name":"甲","profile":"热血少年剑客"},'
        '{"name":"乙","profile":"白衣剑派弟子"}],"chapter_summary":"甲向乙拔剑对峙。"}',
        '{"characters":[{"name":"丙","profile":"神秘暗探"}],"chapter_summary":"乙与丙现身。"}',
      ]);
      final progress = <int>[];
      await NovelCharacterExtractor(db: db, llm: llm(adapter),
              onProgress: (d, t) => progress.add(d))
          .extract(id);

      final chars = await (db.select(db.characters)
            ..where((t) => t.projectId.equals(id)))
          .get();
      final byName = {for (final c in chars) c.name: c};
      expect(byName['甲']!.aliasesJson, '热血少年剑客');
      expect(byName['乙']!.aliasesJson, '白衣剑派弟子');
      expect(byName['丙']!.aliasesJson, '神秘暗探');
      expect(byName['丙']!.source, 'auto');

      final chapters = await (db.select(db.chapters)
            ..where((t) => t.projectId.equals(id))
            ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
          .get();
      expect(chapters[0].summary, '甲向乙拔剑对峙。');
      expect(chapters[1].summary, '乙与丙现身。');

      // 第二次调用的提示词包含第一次提取出的人物名单（滚动名单）
      expect(adapter.requests, hasLength(2));
      final secondPrompt =
          (adapter.requests[1].data as Map)['messages'].last['content'] as String;
      expect(secondPrompt, contains('甲：热血少年剑客'));
      expect(secondPrompt, contains('乙：白衣剑派弟子'));
      // 分层：人物提取用 cheap 模型
      expect((adapter.requests[0].data as Map)['model'], 'flash');
      expect(progress, [1, 2]);
    });

    test('旧人物人设更新（同名更新不重复插入）', () async {
      final (id, _) = await seedWithChapters();
      final adapter = ScriptedAdapter([
        '{"characters":[{"name":"乙","profile":"伏低做小的卧底"}],"chapter_summary":"s1"}',
        '{"characters":[{"name":"乙","profile":"终于亮明身份的卧底"}],"chapter_summary":"s2"}',
      ]);
      final ext = NovelCharacterExtractor(db: db, llm: llm(adapter));
      await ext.extract(id);
      final chars = await db.select(db.characters).get();
      expect(chars, hasLength(1));
      expect(chars.single.name, '乙');
      expect(chars.single.aliasesJson, '终于亮明身份的卧底');
    });

    test('续跑：已有 summary 的章跳过（零 LLM 调用）', () async {
      final (id, chapterIds) = await seedWithChapters();
      await (db.update(db.chapters)..where((t) => t.id.equals(chapterIds[0])))
          .write(const ChaptersCompanion(summary: Value('已处理')));
      final adapter = ScriptedAdapter([
        '{"characters":[],"chapter_summary":"s2"}',
      ]);
      await NovelCharacterExtractor(db: db, llm: llm(adapter)).extract(id);
      expect(adapter.requests, hasLength(1)); // 只有第二章被调用
    });

    test('LLM 返回缺字段容错', () async {
      final (id, _) = await seedWithChapters();
      final adapter = ScriptedAdapter([
        '{"characters":[{"name":""},{"profile":"无名氏"}],"chapter_summary":"x"}',
        '{"chapter_summary":"y"}',
      ]);
      await NovelCharacterExtractor(db: db, llm: llm(adapter)).extract(id);
      final chars = await db.select(db.characters).get();
      expect(chars, isEmpty); // 空名跳过，无 profile 的条目也跳过
      final chapters = await db.select(db.chapters).get();
      expect(chapters.every((c) => c.summary != null), isTrue);
    });
  });
}
