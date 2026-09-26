import 'dart:async';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';

class SlowAdapter implements HttpClientAdapter {
  SlowAdapter(this.status);
  final int status;
  int inflight = 0;
  int maxInflight = 0;
  final stops = <DateTime>[];

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? s, Future? f) async {
    inflight++;
    if (inflight > maxInflight) maxInflight = inflight;
    await Future.delayed(const Duration(milliseconds: 60));
    stops.add(DateTime.now());
    inflight--;
    return ResponseBody.fromString(
        '{"choices":[{"message":{"content":"ok"}}],"usage":{}}', status,
        headers: {
          'content-type': ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

RoutingTable routing() => const RoutingTable(
      channels: [
        ChannelRoute(id: 1, name: 'A', baseUrl: 'https://a/v1', apiKey: 'k', enabled: true)
      ],
      slots: {},
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('并发上限：8 路并发请求，峰值在途 ≤ maxConcurrent', () async {
    final adapter = SlowAdapter(200);
    final svc = LlmService(dio: Dio()..httpClientAdapter = adapter, db: db)
      ..updateRouting(routing())
      ..gate.updateLimits(maxConcurrent: 3);
    await Future.wait([
      for (var i = 0; i < 8; i++)
        svc.chat(const [
          {'role': 'user', 'content': 'hi'}
        ])
    ]);
    expect(adapter.maxInflight, lessThanOrEqualTo(3));
  });

  test('最小间隔：相邻请求发出时刻间隔 ≥ minInterval', () async {
    final adapter = SlowAdapter(200);
    final svc = LlmService(dio: Dio()..httpClientAdapter = adapter, db: db)
      ..updateRouting(routing())
      ..gate.updateLimits(maxConcurrent: 8, minInterval: const Duration(milliseconds: 80));
    await Future.wait([
      for (var i = 0; i < 3; i++)
        svc.chat(const [
          {'role': 'user', 'content': 'hi'}
        ])
    ]);
    final t = adapter.stops..sort();
    for (var i = 1; i < t.length; i++) {
      expect(t[i].difference(t[i - 1]).inMilliseconds, greaterThanOrEqualTo(70));
    }
  });

  test('429 冷却：首个 429 后下一请求被延后（重试成功，共 2 次 HTTP）', () async {
    var calls = 0;
    final adapter = SlowAdapter(200);
    final svc = LlmService(
        dio: Dio()..httpClientAdapter = _Flaky429(adapter, () => calls++),
        db: db,
        backoffBase: const Duration(milliseconds: 10))
      ..updateRouting(routing());
    final out = await svc.chat(const [
      {'role': 'user', 'content': 'hi'}
    ]);
    expect(out, 'ok');
    expect(calls, 2);
  });
}

/// 第一次返回 429，其余透传 SlowAdapter
class _Flaky429 implements HttpClientAdapter {
  _Flaky429(this.inner, this.onCall);
  final SlowAdapter inner;
  final int Function() onCall;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? s, Future? f) async {
    if (onCall() == 0) {
      return ResponseBody.fromString('{"error":{"message":"rate"}}', 429);
    }
    return inner.fetch(o, s, f);
  }

  @override
  void close({bool force = false}) {}
}
