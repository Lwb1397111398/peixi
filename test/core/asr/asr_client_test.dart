
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/asr/asr_client.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.script);
  final List<(int, String)> script;
  int calls = 0;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    requests.add(options);
    final (status, body) = script[calls++];
    return ResponseBody.fromString(body, status,
        headers: {
          'content-type': ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

const resultJson = '''
{
  "file_url": "https://oss/x.mp3",
  "transcripts": [
    {"file_url":"https://oss/x.mp3","sentences":[
      {"begin_time":72000,"end_time":75800,"text":"站长，这件事恐怕没那么简单","speaker_id":0},
      {"begin_time":76000,"end_time":77500,"text":"你先别急","speaker_id":1}
    ]},
    {"file_url":"https://oss/x.mp3","sentences":[
      {"begin_time":61000,"end_time":63500,"text":"前面一句","speaker_id":0}
    ]}
  ]
}
''';

void main() {
  test('提交任务：端点/头/体', () async {
    final adapter = FakeAdapter([
      (200, '{"output":{"task_id":"tid-1","task_status":"PENDING"}}'),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = AsrClient(dio);
    final taskId = await client.submit('sk-1',
        'https://b.oss.example/k.mp3?Expires=1&Signature=%2Babc');
    expect(taskId, 'tid-1');
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.uri.toString(),
        'https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription');
    expect(req.headers['X-DashScope-Async'], 'enable');
    expect(req.headers['Authorization'], 'Bearer sk-1');
    final body = req.data as Map<String, dynamic>;
    expect(body['model'], 'paraformer-v2');
    final params = body['parameters'] as Map<String, dynamic>;
    expect(params['diarization_enabled'], true);
    expect(params['timestamp_alignment_enabled'], true);
    expect((body['input']['file_urls'] as List).single,
        contains('Signature='));
  });

  test('轮询四态', () async {
    final adapter = FakeAdapter([
      (200, '{"output":{"task_id":"t","task_status":"PENDING"}}'),
      (200, '{"output":{"task_id":"t","task_status":"RUNNING"}}'),
      (200,
          '{"output":{"task_id":"t","task_status":"FAILED","message":"bad audio"}}'),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = AsrClient(dio);
    expect((await client.poll('k', 't')).phase, AsrTaskPhase.pending);
    expect((await client.poll('k', 't')).phase, AsrTaskPhase.running);
    final failed = await client.poll('k', 't');
    expect(failed.phase, AsrTaskPhase.failed);
    expect(failed.message, 'bad audio');
    expect(adapter.requests.last.uri.toString(),
        'https://dashscope.aliyuncs.com/api/v1/tasks/t');
  });

  test('下载结果并规范化：跨 transcripts 合并排序 + 说话人补零', () async {
    final adapter = FakeAdapter([
      (200,
          '{"output":{"task_id":"t","task_status":"SUCCEEDED","transcription_url":"https://res/x.json"}}'),
      (200, resultJson),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = AsrClient(dio);
    final ok = await client.poll('k', 't');
    expect(ok.phase, AsrTaskPhase.succeeded);
    final norm = await client.downloadResult(ok.transcriptionUrl!);
    expect(norm.sentences.length, 3);
    expect(norm.sentences.first.text, '前面一句'); // 61s < 72s 排序后在前
    expect(norm.sentences.first.speakerId, 'SPEAKER_00');
    expect(norm.sentences[2].speakerId, 'SPEAKER_01');
    expect(norm.durationMs, 77500); // 无 duration_ms 字段时取 max end
  });

  test('normalizeSpeakerId', () {
    expect(normalizeSpeakerId(0), 'SPEAKER_00');
    expect(normalizeSpeakerId(12), 'SPEAKER_12');
    expect(normalizeSpeakerId('SPEAKER_03'), 'SPEAKER_03');
    expect(normalizeSpeakerId(null), 'SPEAKER_00');
  });

  test('空结果抛异常', () {
    expect(() => parseAsrResultJson('{"transcripts":[]}'),
        throwsA(isA<AsrException>()));
  });
}
