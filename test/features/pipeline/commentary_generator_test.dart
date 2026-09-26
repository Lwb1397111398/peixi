import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/features/pipeline/commentary_generator.dart';
import 'package:peixi/features/pipeline/project_meta.dart';

/// 按调用序返回预设 JSON 的假 LLM 适配器。
class SeqAdapter implements HttpClientAdapter {
  SeqAdapter(this.bodies);
  final List<String> bodies;
  int calls = 0;
  final requests = <RequestOptions>[];

  String? next() => calls < bodies.length ? bodies[calls++] : null;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    requests.add(options);
    final content = next() ?? '脚本耗尽，这不是JSON';
    return ResponseBody.fromString(
        '{"choices":[{"message":{"role":"assistant","content":${jsonEncode(content)}}}],'
        '"usage":{"prompt_tokens":10,"completion_tokens":20}}',
        200,
        headers: {
          'content-type': ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

const commentary1 =
    '{"scene_summary":"余则成向站长汇报","importance":"high",'
    '"l1_subtext":"表面汇报，实则试探站长态度",'
    '"l2_psychology":[{"character":"余则成","analysis":"谨慎试探"}],'
    '"knowledge_needed":["军统"],'
    '"l4_question":{"question":"如果你是余则成会如何措辞？","perspectives":["A","B"]}}';
const card1 = '{"title":"军统","content":"国民政府军事委员会调查统计局","uncertain":false}';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Future<int> seed() async {
    final meta = ProjectMeta(
        sourceFilename: '潜伏.S01E03.mkv', episode: 3, durationMs: 100000);
    final id = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video',
        title: '潜伏',
        sourcePath: '/x.mkv',
        status: 'SEGMENTED',
        metaJson: Value(meta.encode())));
    final c1 = await db.into(db.characters).insert(CharactersCompanion.insert(
        projectId: id,
        name: '余则成',
        speakerKey: const Value('SPEAKER_00')));
    // 场景1：0-10s；场景2：60-80s（含独有台词"翠平来了"）
    await db.into(db.segments).insert(SegmentsCompanion.insert(
        projectId: id, idx: 0, startMs: 1000, endMs: 3000, content: '站长，出事了',
        speakerCharId: Value(c1)));
    await db.into(db.scenes).insert(ScenesCompanion.insert(
        projectId: id, idx: 0, startMs: 0, endMs: 10000));
    await db.into(db.segments).insert(SegmentsCompanion.insert(
        projectId: id, idx: 1, startMs: 61000, endMs: 64000, content: '翠平来了',
        speakerCharId: Value(c1)));
    await db.into(db.scenes).insert(ScenesCompanion.insert(
        projectId: id, idx: 1, startMs: 60000, endMs: 80000));
    return id;
  }

  test('防剧透：场景1 的请求绝不包含场景2 台词；逐场景落库+卡片去重', () async {
    final adapter = SeqAdapter([
      commentary1, card1, // 场景1 解说 + 卡片
      '{"digest":"余则成试探站长"}', // digest
      commentary1.replaceFirst('余则成向站长汇报', '翠平到来'), // 场景2 解说
      '{"digest":"..."}',
    ]);
    final llm = LlmService(db: db, dio: Dio()..httpClientAdapter = adapter)
      ..updateConfig(const ApiConfig(baseUrl: 'https://x/v1', apiKey: 'k'));
    final id = await seed();

    await CommentaryGenerator(db: db, llm: llm, modelStandard: () => 'qwen-plus')
        .generate(id);

    final userMsgs = adapter.requests
        .map((r) => ((r.data as Map<String, dynamic>)['messages'] as List)
            .last['content'] as String)
        .toList();
    expect(userMsgs[0], contains('[余则成]'));
    expect(userMsgs[0], isNot(contains('翠平来了')), reason: '防剧透红线');

    final commentaries = await db.select(db.commentaries).get();
    expect(commentaries.length, 2);
    expect(commentaries.every((c) => c.status == 'done'), isTrue);
    final scenes = await db.select(db.scenes).get();
    expect(scenes.first.importance, 'high');
    expect(scenes.first.summary, '余则成向站长汇报');

    final questions = await db.select(db.questions).get();
    expect(questions.length, 2);
    expect(questions.first.sceneId, isNotNull);

    final cards = await db.select(db.knowledgeCards).get();
    expect(cards.length, 1, reason: '同 term 两场景只生成一张卡');
    expect(cards.first.term, '军统');

    // digest 已写回 meta
    final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
        .getSingle();
    expect(ProjectMeta.fromJson(p.metaJson).digest, isNotNull);
  });

  test('单场景失败不阻塞后续；failed 占位可被续跑覆盖为 done', () async {
    final adapter = SeqAdapter([
      '不是JSON{{{', // 场景1 解说解析失败（兜底链耗尽）
    ]);
    final llm = LlmService(db: db, dio: Dio()..httpClientAdapter = adapter)
      ..updateConfig(const ApiConfig(baseUrl: 'https://x/v1', apiKey: 'k'));
    final id = await seed();

    await CommentaryGenerator(db: db, llm: llm, modelStandard: () => 'qwen-plus')
        .generate(id);

    var commentaries = await db.select(db.commentaries).get();
    expect(commentaries.where((c) => c.status == 'failed').length, 2,
        reason: '脚本耗尽后两场景都失败占位，但流程未中断');

    // 续跑：给足成功应答
    final adapter2 = SeqAdapter([
      commentary1, card1, '{"digest":"d1"}',
      commentary1.replaceFirst('余则成向站长汇报', '第二景'), '{"digest":"d2"}',
    ]);
    final llm2 = LlmService(db: db, dio: Dio()..httpClientAdapter = adapter2)
      ..updateConfig(const ApiConfig(baseUrl: 'https://x/v1', apiKey: 'k'));
    await CommentaryGenerator(db: db, llm: llm2, modelStandard: () => 'qwen-plus')
        .generate(id);

    commentaries = await db.select(db.commentaries).get();
    expect(commentaries.every((c) => c.status == 'done'), isTrue,
        reason: 'failed 占位被覆盖');
    final questions = await db.select(db.questions).get();
    expect(questions.length, 2, reason: 'questions 不因重跑翻倍');
  });

  test('进度回调按场景推进', () async {
    final adapter = SeqAdapter([
      commentary1, card1, '{"digest":"d"}',
      commentary1, '{"digest":"d"}',
    ]);
    final llm = LlmService(db: db, dio: Dio()..httpClientAdapter = adapter)
      ..updateConfig(const ApiConfig(baseUrl: 'https://x/v1', apiKey: 'k'));
    final id = await seed();
    final progress = <int>[];
    await CommentaryGenerator(
            db: db,
            llm: llm,
            modelStandard: () => 'qwen-plus',
            onProgress: (done, total) => progress.add(done))
        .generate(id);
    expect(progress, [1, 2]);
  });
}
