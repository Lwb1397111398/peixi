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
import 'package:peixi/features/pipeline/character_mapper.dart';
import 'package:peixi/features/pipeline/project_meta.dart';

/// 单可用渠道路由表：未显式绑定的槽位按默认模型回落（等价旧 updateConfig）。
const _route = ChannelRoute(
    id: 0, name: 'legacy', baseUrl: 'https://x/v1', apiKey: 'k', enabled: true);
const _testRouting = RoutingTable(channels: [_route], slots: {});

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.body);
  final String body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    requests.add(options);
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

  Future<int> seed() async {
    final meta = ProjectMeta(
        sourceFilename: '潜伏.S01E03.mkv',
        episode: 3,
        asrNormalized: {
          'duration_ms': 120000,
          'sentences': [
            {'begin_ms': 1000, 'end_ms': 3000, 'text': '站长，出事了', 'speaker_id': 'SPEAKER_00'},
            {'begin_ms': 4000, 'end_ms': 6000, 'text': '别慌，慢慢说', 'speaker_id': 'SPEAKER_01'},
            {'begin_ms': 7000, 'end_ms': 9000, 'text': '文件被调包了', 'speaker_id': 'SPEAKER_00'},
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
    await db.into(db.segments).insert(SegmentsCompanion.insert(
        projectId: id, idx: 1, startMs: 4000, endMs: 6000, content: '别慌，慢慢说'));
    await db.into(db.segments).insert(SegmentsCompanion.insert(
        projectId: id, idx: 2, startMs: 7000, endMs: 9000, content: '文件被调包了'));
    return id;
  }

  test('映射落库 + speaker 回填 + 提示词包含对白与文件名', () async {
    final adapter = FakeAdapter(
        '{"characters":['
        '{"speaker_id":"SPEAKER_00","name":"余则成","confidence":0.9,"evidence":"自称","is_major":true},'
        '{"speaker_id":"SPEAKER_01","name":"未知·声音1","confidence":0.3,"evidence":"语气","is_major":false}]}');
    final llm = LlmService(db: db, dio: Dio()..httpClientAdapter = adapter)
      ..updateRouting(const RoutingTable(
        channels: [_route],
        slots: {LlmSlot.summary: SlotBinding(channelId: 0, model: 'flash')},
      ));
    final id = await seed();
    await CharacterMapper(db: db, llm: llm).map(id);

    final chars = await db.select(db.characters).get();
    expect(chars.length, 2);
    final yu = chars.firstWhere((c) => c.speakerKey == 'SPEAKER_00');
    expect(yu.name, '余则成');
    expect(yu.confidence, 0.9);
    expect(yu.source, 'auto');

    final segs = await db.select(db.segments).get();
    final seg0 = segs.firstWhere((sg) => sg.idx == 0);
    final seg1 = segs.firstWhere((sg) => sg.idx == 1);
    expect(seg0.speakerCharId, yu.id);
    expect(seg1.speakerCharId, chars.firstWhere((c) => c.speakerKey == 'SPEAKER_01').id);

    // 提示词：文件名 + [SPEAKER_XX][hh:mm:ss] 格式对白
    final sent = (adapter.requests.single.data
        as Map<String, dynamic>)['messages'] as List;
    final user = sent.last['content'] as String;
    expect(user, contains('潜伏.S01E03.mkv'));
    expect(user, contains('[SPEAKER_00][00:00:01]站长，出事了'));
  });

  test('LLM 返回缺字段容错（confidence 默认、无效条目跳过）', () async {
    final adapter = FakeAdapter(
        '{"characters":['
        '{"speaker_id":"SPEAKER_00","name":"余则成"},'
        '{"speaker_id":"","name":"无名"}]}');
    final llm = LlmService(db: db, dio: Dio()..httpClientAdapter = adapter)
      ..updateRouting(_testRouting);
    final id = await seed();
    await CharacterMapper(db: db, llm: llm).map(id);
    final chars = await db.select(db.characters).get();
    expect(chars.length, 1);
    expect(chars.first.confidence, isNull);
  });

  test('空结果抛异常（引擎置 FAILED 可重试）', () async {
    final adapter = FakeAdapter('{"characters":[]}');
    final llm = LlmService(db: db, dio: Dio()..httpClientAdapter = adapter)
      ..updateRouting(_testRouting);
    final id = await seed();
    await expectLater(
        CharacterMapper(db: db, llm: llm).map(id), throwsException);
  });
}
