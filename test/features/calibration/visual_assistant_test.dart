import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/features/calibration/visual_assistant.dart';

import '../../fakes/fake_ffmpeg_service.dart';

class VisionAdapter implements HttpClientAdapter {
  VisionAdapter(this.bodies);
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
  late Directory tmp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('peixi_va');
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<(int, Segment)> seed() async {
    final id = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video', title: '潜伏', sourcePath: '${tmp.path}/v.mkv',
        status: 'MAPPED',
        metaJson: const Value('{"sourceFilename":"v.mkv"}')));
    final charId = await db.into(db.characters).insert(
        CharactersCompanion.insert(projectId: id, name: '未知·声音0',
            speakerKey: const Value('SPEAKER_00'), confidence: const Value(0.3)));
    final segId = await db.into(db.segments).insert(SegmentsCompanion.insert(
        projectId: id, idx: 0, startMs: 72000, endMs: 75800,
        content: '站长，这件事恐怕没那么简单', speakerCharId: Value(charId)));
    final seg = await (db.select(db.segments)
          ..where((t) => t.id.equals(segId)))
        .getSingle();
    return (charId, seg);
  }

  LlmService llm(VisionAdapter adapter) =>
      LlmService(db: db, dio: Dio()..httpClientAdapter = adapter)
        ..updateConfig(const ApiConfig(
            baseUrl: 'https://x/v1', apiKey: 'k', modelVision: 'qwen-vl-test'));

  test('抽帧时刻取台词中点；vision 请求体含图片 data URI 与候选名单；模型用 vision 配置', () async {
    final (charId, seg) = await seed();
    final ffmpeg = FakeFFmpegService();
    final adapter = VisionAdapter(
        ['{"name":"余则成","reason":"军装男子"}']);
    final va = VisualAssistant(
        db: db, llm: llm(adapter), ffmpeg: ffmpeg,
        videoPath: '${tmp.path}/v.mkv', frameDir: '${tmp.path}/frames');

    final r = await va.suggestFor(
        charId: charId, name: '未知·声音0', sampleLine: seg,
        candidates: ['余则成', '站长']);

    // 建议 + 采纳值
    expect(r.suggestion, '余则成');
    expect(r.reason, '军装男子');
    // 抽帧：中点 (72000+75800)/2 = 73900
    expect(ffmpeg.keyframeTimes, [73900]);
    // 帧临时文件用完即删
    expect(File('${tmp.path}/frames/va_$charId.jpg').existsSync(), isFalse);

    // 请求体：vision 模型名、多模态 content、data URI、候选名单
    expect(adapter.requests, hasLength(1));
    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect(body['model'], 'qwen-vl-test');
    final messages = body['messages'] as List;
    final content = (messages.single as Map)['content'] as List;
    expect((content[0] as Map)['type'], 'text');
    final prompt = (content[0] as Map)['text'] as String;
    expect(prompt, contains('余则成'));
    expect(prompt, contains('站长'));
    expect(prompt, contains('01:13'), reason: '中点时刻 73900ms → 01:13');
    expect((content[1] as Map)['type'], 'image_url');
    final uri = ((((content[1] as Map)['image_url']) as Map)['url']) as String;
    expect(uri.startsWith('data:image/jpeg;base64,'), isTrue);
    expect(uri.length, greaterThan(40));

    // 视觉调用也写 llm_logs（purpose=visual_assist）
    final logs = await db.select(db.llmLogs).get();
    expect(logs.single.purpose, 'visual_assist');
    expect(logs.single.model, 'qwen-vl-test');
  });

  test('模型输出"无法判断"或名单外名字 → 不产生建议', () async {
    final (charId, seg) = await seed();
    final adapter = VisionAdapter([
      '{"name":"无法判断","reason":"画面模糊"}',
      '{"name":"翠平","reason":"编造的名字"}',
    ]);
    final va = VisualAssistant(
        db: db, llm: llm(adapter), ffmpeg: FakeFFmpegService(),
        videoPath: '${tmp.path}/v.mkv', frameDir: '${tmp.path}/frames');
    final r1 = await va.suggestFor(
        charId: charId, name: '未知', sampleLine: seg, candidates: ['余则成']);
    final r2 = await va.suggestFor(
        charId: charId, name: '未知', sampleLine: seg, candidates: ['余则成']);
    expect(r1.suggestion, isNull);
    expect(r2.suggestion, isNull);
  });

  test('单簇 LLM 失败静默降级（返回 null 建议，不抛异常）', () async {
    final (charId, seg) = await seed();
    final adapter = VisionAdapter(['脚本耗尽，这不是JSON']);
    final va = VisualAssistant(
        db: db, llm: llm(adapter), ffmpeg: FakeFFmpegService(),
        videoPath: '${tmp.path}/v.mkv', frameDir: '${tmp.path}/frames');
    final r = await va.suggestFor(
        charId: charId, name: '未知', sampleLine: seg, candidates: ['余则成']);
    expect(r.suggestion, isNull);
    // 垃圾输出（vision 无修复链）按"无法判断"处理；抛错路径按"分析失败"处理
    expect(
        r.reason == '无法判断' || (r.reason?.startsWith('分析失败') ?? false),
        isTrue);
  });

  test('抽帧失败也静默降级', () async {
    final (charId, seg) = await seed();
    final failingFfmpeg = _FailingKeyframeFfmpeg();
    final va = VisualAssistant(
        db: db, llm: llm(VisionAdapter(['{"name":"余则成"}'])),
        ffmpeg: failingFfmpeg,
        videoPath: '${tmp.path}/v.mkv', frameDir: '${tmp.path}/frames');
    final r = await va.suggestFor(
        charId: charId, name: '未知', sampleLine: seg, candidates: ['余则成']);
    expect(r.suggestion, isNull);
    expect(r.reason, startsWith('分析失败'));
  });
}

class _FailingKeyframeFfmpeg extends FakeFFmpegService {
  @override
  Future<void> extractKeyframe(
      String input, int timeMs, String outputJpg) async {
    throw Exception('抽帧失败：视频损坏');
  }
}
