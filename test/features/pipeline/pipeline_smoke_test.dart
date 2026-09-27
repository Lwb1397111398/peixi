import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/features/pipeline/commentary_generator.dart';
import 'package:peixi/features/pipeline/character_mapper.dart';
import 'package:peixi/features/pipeline/project_meta.dart';

/// 单可用渠道路由表：未显式绑定的槽位按默认模型回落（等价旧 updateConfig）。
const _route = ChannelRoute(
    id: 0, name: 'legacy', baseUrl: 'https://x/v1', apiKey: 'k', enabled: true);
const _testRouting = RoutingTable(channels: [_route], slots: {});

class SeqAdapter implements HttpClientAdapter {
  SeqAdapter(this.bodies);
  final List<String> bodies;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    final content = calls < bodies.length ? bodies[calls++] : '耗尽非JSON';
    return ResponseBody.fromString(
        '{"choices":[{"message":{"role":"assistant","content":${jsonEncode(content)}}}],"usage":{}}',
        200,
        headers: {
          'content-type': ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('冒烟：S6→S9 协作器在内存库上跑通（不经过引擎）', () async {
    final db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
    addTearDown(db.close);

    final meta = ProjectMeta(sourceFilename: '潜伏.S01E03.mkv', asrNormalized: {
      'duration_ms': 9000,
      'sentences': [
        {'begin_ms': 1000, 'end_ms': 3000, 'text': '站长，出事了', 'speaker_id': 'SPEAKER_00'},
      ]
    });
    final id = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video',
        title: '潜伏',
        sourcePath: '/x.mkv',
        status: 'ASR_DONE',
        metaJson: Value(meta.encode())));
    await db.into(db.segments).insert(SegmentsCompanion.insert(
        projectId: id, idx: 0, startMs: 1000, endMs: 3000, content: '站长，出事了'));
    await db.into(db.scenes).insert(ScenesCompanion.insert(
        projectId: id, idx: 0, startMs: 0, endMs: 5000));

    final adapter = SeqAdapter([
      '{"characters":[{"speaker_id":"SPEAKER_00","name":"余则成","confidence":0.9,"evidence":"e"}]}',
      '{"scene_summary":"汇报","importance":"normal","l1_subtext":"试探","l2_psychology":[],"knowledge_needed":[],"l4_question":{"question":"Q?","perspectives":["A"]}}',
      '{"digest":"d"}',
    ]);
    final llm = LlmService(db: db, dio: Dio()..httpClientAdapter = adapter)
      ..updateRouting(_testRouting);

    await CharacterMapper(db: db, llm: llm).map(id);
    await CommentaryGenerator(
            db: db,
            llm: llm,
            modelStandard: () => 'qwen-plus')
        .generate(id);

    expect((await db.select(db.characters).get()).single.name, '余则成');
    final cm = await (db.select(db.commentaries)).get();
    expect(cm.single.status, 'done');
  });
}
