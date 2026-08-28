import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/novel/novel_parser.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/features/pipeline/novel_commentary_generator.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';

/// 按请求顺序返回预置响应（每次调用消耗一个脚本）。
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

  LlmService llm(ScriptedAdapter adapter) =>
      LlmService(db: db, dio: Dio()..httpClientAdapter = adapter)
        ..updateConfig(const ApiConfig(
            baseUrl: 'https://x/v1',
            apiKey: 'k',
            modelCheap: 'flash',
            modelStandard: 'plus'));

  // 单章 3 段，blockChars=10 → 块1=[0,1]，块2=[2]
  Future<int> seed() async {
    const doc = NovelDoc(chapters: [
      NovelChapter(idx: 0, title: '第一章', paragraphs: [
        '一二三四五六七八',
        '九十甲乙丙丁',
        '戊己庚辛',
      ]),
    ]);
    return NovelImporter(db: db)
        .import(title: '书', sourcePath: '/book.txt', doc: doc);
  }

  List<({String model, String prompt})> sentOf(ScriptedAdapter a) => [
        for (final r in a.requests)
          (
            model: (r.data as Map)['model'] as String,
            prompt: (((r.data as Map)['messages'] as List).last['content'])
                as String,
          )
      ];

  test('逐块顺序生成：防剧透、分层模型、锚定落库、摘要滚动', () async {
    final id = await seed();
    final adapter = ScriptedAdapter([
      // 块1批注（standard）
      '{"para_range":[0,1],"block_summary":"少年出行遇风。",'
      '"annotations":[{"para_idx":1,"type":"L1","content":"少年表面平静实则紧张"},'
      '{"para_idx":99,"type":"L1","content":"越界锚点应被丢弃"}]}',
      // 块1摘要（cheap）
      '{"digest":"前情：少年初出山门"}',
      // 块2批注（standard）
      '{"para_range":[2,2],"block_summary":"乙丙现身对峙。",'
      '"annotations":[{"para_idx":2,"type":"L2","content":"乙的冷笑是防御"},'
      '{"para_idx":2,"type":"L3","content":{"term":"拜帖","text":"递帖求见的礼数","uncertain":false}},'
      '{"para_idx":2,"type":"L4","content":{"question":"若你是乙会硬刚吗","perspectives":["硬刚","周旋"]}}]}',
      // 块2摘要（cheap）
      '{"digest":"前情：对峙升级"}',
    ]);
    final progress = <double>[];
    await NovelCommentaryGenerator(
            db: db, llm: llm(adapter), blockChars: 10,
            onProgress: (d, t) => progress.add(d / t))
        .generate(id);

    final sent = sentOf(adapter);
    expect(sent, hasLength(4));
    // 防剧透：块1请求不含块2正文；块2请求含块2正文+滚动摘要+本章已读概要
    expect(sent[0].prompt, contains('一二三四五六七八'));
    expect(sent[0].prompt, isNot(contains('戊己庚辛')));
    expect(sent[2].prompt, contains('戊己庚辛'));
    expect(sent[2].prompt, contains('前情：少年初出山门'));
    expect(sent[2].prompt, contains('少年出行遇风。'));
    // Prompt D 密度指令与锚定范围
    expect(sent[0].prompt, contains('宁缺毋滥'));
    expect(sent[0].prompt, contains('"para_range":[0,1]'));
    // 分层：批注 standard、摘要 cheap
    expect(sent[0].model, 'plus');
    expect(sent[1].model, 'flash');

    // 批注落库：锚定 paraId 映射到正确段落，越界丢弃
    final paras = await (db.select(db.paragraphs)
          ..where((t) => t.projectId.equals(id))
          ..orderBy([(p) => OrderingTerm.asc(p.idx)]))
        .get();
    final anns = await (db.select(db.annotations)
          ..orderBy([(a) => OrderingTerm.asc(a.id)]))
        .get();
    expect(anns, hasLength(4));
    final annByPara = {for (final a in anns) a.paraId: a};
    final l1 = annByPara[paras[1].id]!;
    expect(l1.type, 'L1');
    expect(jsonDecode(l1.contentJson), {'text': '少年表面平静实则紧张'});
    final annForPara2 = anns.where((a) => a.paraId == paras[2].id).toList();
    expect(annForPara2.map((a) => a.type), containsAll(['L2', 'L3', 'L4']));
    final l2 = annForPara2.firstWhere((a) => a.type == 'L2');
    expect(jsonDecode(l2.contentJson), {'text': '乙的冷笑是防御'});
    final l4 = annForPara2.firstWhere((a) => a.type == 'L4');
    final l4Json = jsonDecode(l4.contentJson) as Map;
    expect(l4Json['question'], '若你是乙会硬刚吗');
    expect((l4Json['perspectives'] as List), hasLength(2));

    // L3 同时进知识卡片集
    final cards = await (db.select(db.knowledgeCards)
          ..where((t) => t.projectId.equals(id)))
        .get();
    expect(cards, hasLength(1));
    expect(cards.single.term, '拜帖');
    expect(cards.single.uncertain, isFalse);

    // 断点与前情摘要落库
    final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
        .getSingle();
    final meta = NovelMeta.fromJson(p.metaJson);
    expect(meta.annotatedPara, 2);
    expect(meta.digest, '前情：对峙升级');
    expect(progress.last, 1.0);
  });

  test('续跑：annotatedPara 之后的块才处理，重跑零请求且旧批注保留', () async {
    final id = await seed();
    final adapter = ScriptedAdapter([
      '{"para_range":[0,1],"block_summary":"s1","annotations":'
      '[{"para_idx":0,"type":"L1","content":"a"}]}',
      '{"digest":"d1"}',
      '{"para_range":[2,2],"block_summary":"s2","annotations":'
      '[{"para_idx":2,"type":"L1","content":"b"}]}',
      '{"digest":"d2"}',
    ]);
    final gen = NovelCommentaryGenerator(
        db: db, llm: llm(adapter), blockChars: 10);
    await gen.generate(id);
    final before = adapter.requests.length;

    await gen.generate(id); // 整本书已批注完
    expect(adapter.requests.length, before);
    final anns = await db.select(db.annotations).get();
    expect(anns, hasLength(2));
  });

  test('块级幂等：从块1重跑会覆盖旧批注而不重复', () async {
    final id = await seed();
    final adapter = ScriptedAdapter([
      '{"para_range":[0,1],"block_summary":"s1","annotations":'
      '[{"para_idx":0,"type":"L1","content":"旧批注"}]}',
      '{"digest":"d1"}',
    ]);
    await NovelCommentaryGenerator(
            db: db, llm: llm(adapter), blockChars: 10)
        .generate(id);
    expect(await (db.select(db.annotations).get()), hasLength(1));

    // 模拟 annotatedPara 回退到块0之前（如用户手动重置），重跑覆盖
    final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
        .getSingle();
    final meta = NovelMeta.fromJson(p.metaJson)..annotatedPara = -1;
    await (db.update(db.projects)..where((t) => t.id.equals(id)))
        .write(ProjectsCompanion(metaJson: Value(meta.encode())));

    final adapter2 = ScriptedAdapter([
      '{"para_range":[0,1],"block_summary":"s1","annotations":'
      '[{"para_idx":0,"type":"L2","content":"新批注"}]}',
      '{"digest":"d1"}',
    ]);
    await NovelCommentaryGenerator(
            db: db, llm: llm(adapter2), blockChars: 10)
        .generate(id);
    final anns = await db.select(db.annotations).get();
    expect(anns, hasLength(1)); // 旧的被清掉
    expect(anns.single.type, 'L2');
    expect(anns.single.contentJson, contains('新批注'));
  });

  test('摘要调用失败不阻塞批注主线（降级拼接）', () async {
    final id = await seed();
    // digest 首响应+修复响应都非法（各占 2 个脚本）→ 降级拼接旧摘要
    const bad = '脚本耗尽，这不是JSON';
    final adapter = ScriptedAdapter([
      '{"para_range":[0,1],"block_summary":"s1","annotations":[]}',
      bad,
      bad,
      '{"para_range":[2,2],"block_summary":"s2","annotations":[]}',
      bad,
      bad,
    ]);
    await NovelCommentaryGenerator(
            db: db, llm: llm(adapter), blockChars: 10)
        .generate(id);
    expect(adapter.requests, hasLength(6)); // 2 批注 + 2×(摘要+修复)
    final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
        .getSingle();
    final meta = NovelMeta.fromJson(p.metaJson);
    expect(meta.annotatedPara, 2);
    expect(meta.digest, contains('s1'));
    expect(meta.digest, contains('s2'));
  });
}
