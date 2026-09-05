import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/settings/api_config.dart';

/// 恒定返回合法 JSON 的桩适配器（带调用计数）。
class StubAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {'content': '{"reply":"回答"}'}
          }
        ],
        'usage': {'prompt_tokens': 100, 'completion_tokens': 50},
      }),
      200,
      headers: {
        'content-type': ['application/json']
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

LlmService makeSvc(AppDatabase db, HttpClientAdapter adapter) =>
    LlmService(db: db, dio: Dio()..httpClientAdapter = adapter)
      ..updateConfig(const ApiConfig(
          baseUrl: 'https://llm.example/v1', apiKey: 'sk-test'));

void main() {
  late AppDatabase db;
  late LlmService llm;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    llm = LlmService(db: db)
      ..updateConfig(const ApiConfig(
          baseUrl: 'https://llm.example/v1', apiKey: 'sk-test'));
  });

  tearDown(() => db.close());

  Future<void> seedMonthTokens(int tokens) async {
    await db.into(db.llmLogs).insert(LlmLogsCompanion.insert(
        purpose: 'seed',
        model: 'm',
        promptTokens: Value(tokens),
        completionTokens: const Value(0)));
  }

  Future<void> seedBudget(int budget) async {
    await db.into(db.settings).insert(SettingsCompanion.insert(
        key: 'llm.monthly_budget_tokens', value: '$budget'));
  }

  test('未设预算时不拦截，请求正常发出', () async {
    final adapter = StubAdapter();
    final svc = makeSvc(db, adapter);
    final resp = await svc.chat([{'role': 'user', 'content': 'hi'}]);
    expect(resp, contains('回答'));
    expect(adapter.calls, 1);
  });

  test('本月用量达到预算上限时抛 LlmBudgetException 且不发请求', () async {
    await seedBudget(1000);
    await seedMonthTokens(1000);
    final adapter = StubAdapter();
    final svc = makeSvc(db, adapter);
    await expectLater(
      svc.chat([{'role': 'user', 'content': 'hi'}]),
      throwsA(isA<LlmBudgetException>()),
    );
    expect(adapter.calls, 0);
  });

  test('预算未超限时正常放行并计入日志', () async {
    await seedBudget(1000);
    await seedMonthTokens(200);
    final adapter = StubAdapter();
    final svc = makeSvc(db, adapter);
    await svc.chat([{'role': 'user', 'content': 'hi'}]);
    expect(adapter.calls, 1);
    final logs = await db.select(db.llmLogs).get();
    expect(logs.where((l) => l.purpose == 'seed'), hasLength(1));
  });

  test('相同请求第二次命中缓存，不再发 HTTP 也不记日志', () async {
    final adapter = StubAdapter();
    final svc = makeSvc(db, adapter);
    final msgs = [
      {'role': 'user', 'content': '第一集讲了什么'},
    ];
    final r1 = await svc.chatJson(msgs, purpose: 'commentary');
    final r2 = await svc.chatJson(msgs, purpose: 'commentary');
    expect(r1['reply'], '回答');
    expect(r2['reply'], '回答');
    expect(adapter.calls, 1);
    final logs = await db.select(db.llmLogs).get();
    expect(logs, hasLength(1), reason: '缓存命中不应重复记日志');
  });

  test('不同消息走不同缓存键，各自发请求', () async {
    final adapter = StubAdapter();
    final svc = makeSvc(db, adapter);
    await svc.chatJson([{'role': 'user', 'content': 'A'}]);
    await svc.chatJson([{'role': 'user', 'content': 'B'}]);
    expect(adapter.calls, 2);
  });

  test('解析失败的响应不入缓存，重跑可恢复', () async {
    // 第一次：返回垃圾 → chatJson 修复链耗尽抛异常
    final bad = BadThenGoodAdapter(good: false);
    final svc = makeSvc(db, bad);
    final msgs = [
      {'role': 'user', 'content': '解析失败恢复'},
    ];
    await expectLater(
      svc.chatJson(msgs),
      throwsA(isA<LlmJsonException>()),
    );
    // 第二次：返回合法 JSON → 成功且成功结果入缓存
    final good = BadThenGoodAdapter(good: true);
    final svc2 = makeSvc(db, good);
    final r = await svc2.chatJson(msgs);
    expect(r['reply'], '回答');
    // 第三次：直接命中缓存，不再发请求
    expect(await svc2.chatJson(msgs), r);
    expect(good.calls, 1);
  });

  test('缓存命中不花钱：预算用尽后仍可读缓存', () async {
    await seedBudget(1);
    final adapter = StubAdapter();
    final svc = makeSvc(db, adapter);
    final msgs = [
      {'role': 'user', 'content': '缓存优先于预算'},
    ];
    await svc.chatJson(msgs);
    await seedMonthTokens(1); // 达到上限
    final hit = await svc.chatJson(msgs);
    expect(hit['reply'], '回答', reason: '缓存命中不消耗预算');
    expect(adapter.calls, 1, reason: '第二次未发请求');
    await expectLater(
      svc.chatJson([{'role': 'user', 'content': '新请求'}]),
      throwsA(isA<LlmBudgetException>()),
    );
  });

  test('pruneOldEntries 只删 90 天前的日志与缓存', () async {
    final old = DateTime.now().subtract(const Duration(days: 100));
    await db.into(db.llmLogs).insert(LlmLogsCompanion.insert(
        purpose: 'old', model: 'm', createdAt: Value(old)));
    await db
        .into(db.llmLogs)
        .insert(LlmLogsCompanion.insert(purpose: 'new', model: 'm'));
    await db.into(db.llmCache).insertOnConflictUpdate(LlmCacheCompanion.insert(
        key: 'k-old', response: 'r', model: 'm', createdAt: Value(old)));
    await db.into(db.llmCache).insertOnConflictUpdate(
        LlmCacheCompanion.insert(key: 'k-new', response: 'r', model: 'm'));

    await llm.pruneOldEntries();

    final logs = await db.select(db.llmLogs).get();
    expect(logs, hasLength(1));
    expect(logs.single.purpose, 'new');
    final keys = (await db.select(db.llmCache).get()).map((e) => e.key);
    expect(keys, ['k-new']);
  });
}

/// 先坏后好的脚本适配器：good=false 恒返回垃圾；good=true 恒返回合法 JSON。
class BadThenGoodAdapter implements HttpClientAdapter {
  BadThenGoodAdapter({required this.good});
  final bool good;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    calls++;
    final content = good ? '{"reply":"回答"}' : '不是JSON{{{';
    return ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {'content': content}
          }
        ],
        'usage': {'prompt_tokens': 10, 'completion_tokens': 5},
      }),
      200,
      headers: {
        'content-type': ['application/json']
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
