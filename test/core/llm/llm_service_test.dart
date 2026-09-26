import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/settings/api_config.dart';

/// 可编程假适配器：按顺序消费预设响应
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.responses);
  final List<TestResp> responses;
  int calls = 0;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    requests.add(options);
    final r = responses[calls++];
    if (r.body != null) {
      return ResponseBody.fromString(r.body!, r.status, headers: {
        'content-type': ['application/json']
      });
    }
    throw r.error!;
  }

  @override
  void close({bool force = false}) {}
}

class TestResp {
  TestResp(this.status, this.body, {this.error});
  final int status;
  final String? body;
  final Object? error;
}

String chatBody(String content, {int pt = 10, int ct = 20}) =>
    '{"choices":[{"message":{"role":"assistant","content":${jsonEncode(content)}}}],'
    '"usage":{"prompt_tokens":$pt,"completion_tokens":$ct}}';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  ApiConfig cfg() => const ApiConfig(
      baseUrl: 'https://example.com/v1',
      apiKey: 'sk-x',
      modelCheap: 'qwen-flash',
      modelStandard: 'qwen-plus');

  (Dio, FakeAdapter) dioWith(List<TestResp> rs) {
    final adapter = FakeAdapter(rs);
    return (Dio()..httpClientAdapter = adapter, adapter);
  }

  test('chat 成功：Bearer 头、模型分层、usage 落 llm_logs', () async {
    final (dio, adapter) = dioWith([TestResp(200, chatBody('你好'))]);
    final svc = LlmService(dio: dio, db: db)..updateConfig(cfg());
    final out = await svc.chat(const [
      {'role': 'user', 'content': 'hi'}
    ], purpose: '测试');
    expect(out, '你好');
    final req = adapter.requests.single;
    expect(req.path, 'https://example.com/v1/chat/completions');
    expect(req.headers['Authorization'], 'Bearer sk-x');
    final log = await db.select(db.llmLogs).getSingle();
    expect(log.model, 'qwen-plus');
    expect(log.promptTokens, 10);
    expect(log.completionTokens, 20);
    expect(log.purpose, '测试');
  });

  test('cheap 分层用 qwen-flash，jsonMode 带 response_format', () async {
    final (dio, adapter) = dioWith([TestResp(200, chatBody('{}'))]);
    final svc = LlmService(dio: dio, db: db)..updateConfig(cfg());
    await svc.chatJson(const [
      {'role': 'user', 'content': '输出 json'}
    ], slot: LlmSlot.summary, purpose: '映射');
    final req = adapter.requests.single;
    expect((req.data as Map)['model'], 'qwen-flash');
    expect((req.data as Map)['response_format'], {'type': 'json_object'});
  });

  test('429 退避重试后成功', () async {
    final (dio, _) = dioWith([
      TestResp(429, '{"error":"rate"}'),
      TestResp(200, chatBody('ok')),
    ]);
    final svc = LlmService(dio: dio, db: db, backoffBase: Duration.zero)
      ..updateConfig(cfg());
    expect(
        await svc.chat(const [
          {'role': 'user', 'content': 'x'}
        ], purpose: 't'),
        'ok');
  });

  test('非重试错误直接抛 LlmException', () async {
    final (dio, _) = dioWith([TestResp(401, '{"error":{"message":"bad key"}}')]);
    final svc = LlmService(dio: dio, db: db, backoffBase: Duration.zero)
      ..updateConfig(cfg());
    await expectLater(
        svc.chat(const [
          {'role': 'user', 'content': 'x'}
        ], purpose: 't'),
        throwsA(isA<LlmException>()
            .having((e) => e.message, 'message', contains('bad key'))));
  });

  test('chatJson 兜底链：剥围栏与前后杂质直接解析', () async {
    final (dio, _) = dioWith([
      TestResp(200, chatBody('好的，结果如下：\n```json\n{"a":1}\n```\n完毕'))
    ]);
    final svc = LlmService(dio: dio, db: db)..updateConfig(cfg());
    expect(
        await svc.chatJson(const [
          {'role': 'user', 'content': 'x'}
        ], purpose: 't'),
        {'a': 1});
  });

  test('chatJson 修复链：坏 JSON 回传 LLM 修复一次后成功', () async {
    final (dio, adapter) = dioWith([
      TestResp(200, chatBody('{"a": ')), // 截断的 JSON，本地无法解析
      TestResp(200, chatBody('{"a": 1}')), // 修复后的合法 JSON
    ]);
    final svc = LlmService(dio: dio, db: db, backoffBase: Duration.zero)
      ..updateConfig(cfg());
    expect(
        await svc.chatJson(const [
          {'role': 'user', 'content': 'x'}
        ], purpose: 't'),
        {'a': 1});
    expect(adapter.calls, 2);
  });

  test('修复后仍失败 → 抛 LlmJsonException', () async {
    final (dio, _) = dioWith([
      TestResp(200, chatBody('not-json')),
      TestResp(200, chatBody('still-not-json')),
    ]);
    final svc = LlmService(dio: dio, db: db, backoffBase: Duration.zero)
      ..updateConfig(cfg());
    await expectLater(
        svc.chatJson(const [
          {'role': 'user', 'content': 'x'}
        ], purpose: 't'),
        throwsA(isA<LlmJsonException>()));
  });

  test('testConnection 走 GET /models', () async {
    final (dio, _) = dioWith([TestResp(200, '{"data":[{"id":"qwen-plus"}]}')]);
    final svc = LlmService(dio: dio, db: db)..updateConfig(cfg());
    expect(await svc.testConnection(), contains('qwen-plus'));
  });

  test('槽位解析：请求发到绑定渠道的 baseUrl/模型/key', () async {
    final (dio, adapter) = dioWith([TestResp(200, chatBody('ok'))]);
    final svc = LlmService(dio: dio, db: db)
      ..updateRouting(const RoutingTable(
        channels: [
          ChannelRoute(id: 1, name: 'B', baseUrl: 'https://b/v1', apiKey: 'sk-b', enabled: true),
        ],
        slots: {LlmSlot.analysis: SlotBinding(channelId: 1, model: 'deepseek-v3')},
      ));
    await svc.chat(const [
      {'role': 'user', 'content': 'hi'}
    ], slot: LlmSlot.analysis);
    expect(adapter.requests.single.path, 'https://b/v1/chat/completions');
    expect((adapter.requests.single.data as Map)['model'], 'deepseek-v3');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer sk-b');
  });

  test('槽位解析失败：抛可读异常', () async {
    final svc = LlmService(dio: Dio(), db: db);
    await expectLater(
        svc.chat(const [
          {'role': 'user', 'content': 'hi'}
        ], slot: LlmSlot.analysis),
        throwsA(isA<LlmException>()));
  });
}
