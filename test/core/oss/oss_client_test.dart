import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/oss/oss_client.dart';
import 'package:peixi/core/settings/api_config.dart';

class RecordingAdapter implements HttpClientAdapter {
  final responses = <(int, String)>[];
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    requests.add(options);
    final (status, body) = responses.isEmpty ? (200, '') : responses.removeAt(0);
    return ResponseBody.fromString(body, status);
  }

  @override
  void close({bool force = false}) {}
}

OssConfig ossCfg() => const OssConfig(
    bucket: 'peixi-relay',
    endpoint: 'oss-cn-beijing.aliyuncs.com',
    accessKeyId: 'AKID123',
    accessKeySecret: 'SECRET456');

void main() {
  final fixedTime = DateTime.utc(2026, 8, 23, 12, 0, 0);

  test('PUT 签名头符合 OSS V1 规范', () async {
    final adapter = RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final client = OssClient(dio, ossCfg(), clock: () => fixedTime);

    final tmp = File(
        '${Directory.systemTemp.path}/oss_test_${DateTime.now().millisecondsSinceEpoch}.bin');
    tmp.writeAsBytesSync(List.filled(16, 7));
    addTearDown(() => tmp.deleteSync());

    await client.putFile(tmp, 'peixi/asr/1.mp3');

    final req = adapter.requests.single;
    expect(req.method, 'PUT');
    expect(req.uri.toString(),
        'https://peixi-relay.oss-cn-beijing.aliyuncs.com/peixi/asr/1.mp3');
    expect(req.headers['Date'], HttpDate.format(fixedTime));
    expect(req.headers['Content-Type'], 'audio/mpeg');

    // 独立复算签名比对
    final sts = 'PUT\n\naudio/mpeg\n${HttpDate.format(fixedTime)}\n'
        '/peixi-relay/peixi/asr/1.mp3';
    final expected = base64Encode(
        Hmac(sha1, utf8.encode('SECRET456')).convert(utf8.encode(sts)).bytes);
    expect(req.headers['Authorization'], 'OSS AKID123:$expected');
  });

  test('签名 GET URL 含过期时间与签名参数', () {
    final client = OssClient(Dio(), ossCfg(), clock: () => fixedTime);
    final url = client.signedGetUrl('peixi/asr/1.mp3');
    final expires = fixedTime.add(const Duration(hours: 24))
        .millisecondsSinceEpoch ~/ 1000;
    expect(url, startsWith(
        'https://peixi-relay.oss-cn-beijing.aliyuncs.com/peixi/asr/1.mp3?'));
    expect(url, contains('Expires=$expires'));
    expect(url, contains('OSSAccessKeyId=AKID123'));
    expect(url, contains('Signature='));
  });

  test('DELETE 调用与 404 容忍', () async {
    final adapter = RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final client = OssClient(dio, ossCfg(), clock: () => fixedTime);

    await client.deleteObject('peixi/asr/1.mp3');
    expect(adapter.requests.single.method, 'DELETE');

    adapter.responses.add((404, ''));
    await client.deleteObject('peixi/asr/1.mp3'); // 不抛
  });

  test('PUT 非 200 抛异常', () async {
    final adapter = RecordingAdapter()..responses.add((403, 'denied'));
    final dio = Dio()..httpClientAdapter = adapter;
    final client = OssClient(dio, ossCfg(), clock: () => fixedTime);
    final tmp = File(
        '${Directory.systemTemp.path}/oss_test2_${DateTime.now().millisecondsSinceEpoch}.bin');
    tmp.writeAsBytesSync([1, 2, 3]);
    addTearDown(() => tmp.deleteSync());
    await expectLater(
        client.putFile(tmp, 'k.mp3'), throwsA(isA<OssException>()));
  });
}
