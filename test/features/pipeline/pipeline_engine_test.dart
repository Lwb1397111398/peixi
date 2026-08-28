import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/asr/asr_client.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';
import 'package:peixi/features/pipeline/project_meta.dart';
import 'package:peixi/features/pipeline/project_status.dart';

import '../../fakes/fake_ffmpeg_service.dart';

/// 可变脚本适配器：队列可被测试中途改写（模拟"修复后重试"）。
class ScriptAdapter implements HttpClientAdapter {
  final List<Object> script; // (int,String) 或异常对象
  final requests = <RequestOptions>[];
  int calls = 0;
  ScriptAdapter(this.script);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    requests.add(options);
    if (calls >= script.length) {
      throw DioException(requestOptions: options, error: '脚本耗尽');
    }
    final r = script[calls++];
    if (r is (int, String)) {
      return ResponseBody.fromString(r.$2, r.$1, headers: {
        'content-type': ['application/json']
      });
    }
    throw r as DioException;
  }

  @override
  void close({bool force = false}) {}
}

const asrResultJson =
    '{"transcripts":[{"sentences":['
    '{"begin_time":72000,"end_time":75800,"text":"站长，这件事恐怕没那么简单","speaker_id":0},'
    '{"begin_time":76000,"end_ms":77500,"end_time":77500,"text":"你先别急","speaker_id":1}]}]}';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  late Directory audioDir;
  late Directory videoDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
    settings = SettingsRepository(db, const FlutterSecureStorage());
    await settings.saveApiConfig(const ApiConfig(
        baseUrl: 'https://llm.example/v1', apiKey: 'sk-test'));
    await settings.saveOssConfig(const OssConfig(
        bucket: 'b',
        endpoint: 'oss-cn-beijing.aliyuncs.com',
        accessKeyId: 'ak',
        accessKeySecret: 'sk'));
    audioDir = Directory.systemTemp.createTempSync('peixi_audio');
    videoDir = Directory.systemTemp.createTempSync('peixi_video');
  });
  tearDown(() async {
    await db.close();
    audioDir.deleteSync(recursive: true);
    videoDir.deleteSync(recursive: true);
  });

  Future<int> createProject() async {
    final video = File('${videoDir.path}/潜伏.S01E03.mkv')
      ..writeAsBytesSync(List.filled(32, 1));
    final meta = ProjectMeta(
        sourceFilename: '潜伏.S01E03.mkv', episode: 3, durationMs: 2700000);
    return db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video',
        title: '潜伏',
        sourcePath: video.path,
        status: ProjectStatus.imported.db,
        metaJson: Value(meta.encode())));
  }

  (PipelineEngine, ScriptAdapter, ScriptAdapter) makeEngine(
      List<Object> ossScript, List<Object> asrScript,
      {FakeFFmpegService? ffmpeg}) {
    final ossAdapter = ScriptAdapter(ossScript);
    final asrAdapter = ScriptAdapter(asrScript);
    final engine = PipelineEngine(
        db: db,
        ffmpeg: ffmpeg ?? FakeFFmpegService(durationMs: 2700000),
        asr: AsrClient(Dio()..httpClientAdapter = asrAdapter),
        settings: settings,
        audioDir: audioDir,
        ossDio: Dio()..httpClientAdapter = ossAdapter,
        pollInterval: const Duration(milliseconds: 10));
    return (engine, ossAdapter, asrAdapter);
  }

  Future<Project> reload(int id) => (db.select(db.projects)
        ..where((t) => t.id.equals(id)))
      .getSingle();

  test('全链路 S1→READY：校准闸门前停、确认后完成、segments 落库、OSS 用后即删',
      () async {
    final id = await createProject();
    final (engine, ossAdapter, asrAdapter) = makeEngine([
      (200, ''), // PUT 音频
      (200, ''), // DELETE 对象
    ], [
      (200, '{"output":{"task_id":"t-1","task_status":"PENDING"}}'), // 提交
      (200,
          '{"output":{"task_id":"t-1","task_status":"SUCCEEDED","transcription_url":"https://res/1.json"}}'), // 轮询
      (200, asrResultJson), // 下载结果
    ]);

    final stages = <String>[];
    engine.events.listen((e) => stages.add(e.stage));
    await engine.run(id);

    var p = await reload(id);
    expect(p.status, ProjectStatus.waitCalibration.db,
        reason: 'S7 闸门前必须停');
    final segs = await db.select(db.segments).get();
    expect(segs.length, 2);
    expect(segs.first.content, '站长，这件事恐怕没那么简单');
    final meta = ProjectMeta.fromJson(p.metaJson);
    expect(meta.asrTaskId, 't-1');
    expect(meta.asrNormalized!['sentences'].length, 2);

    await engine.confirmCalibration(id, {});
    p = await reload(id);
    expect(p.status, ProjectStatus.ready.db);
    expect(File(meta.audioPath(audioDir.path, id)).existsSync(), isTrue,
        reason: '默认保留临时音频');

    // OSS：一次 PUT + 一次 DELETE；ASR：提交/轮询/下载各一次
    expect(ossAdapter.requests.map((r) => r.method).toList(),
        containsAll(['PUT', 'DELETE']));
    expect(
        asrAdapter.requests
            .where((r) => r.path.contains('transcription') && r.method == 'POST')
            .length,
        1);
  });

  test('上传失败 → FAILED+failed_stage，修复后 retry 走完全程', () async {
    final id = await createProject();
    final (engine, ossAdapter, asrAdapter) = makeEngine([
      DioException(requestOptions: RequestOptions(path: '/')), // PUT 网络错
    ], [
      (200, '{"output":{"task_id":"t-2","task_status":"PENDING"}}'),
      (200,
          '{"output":{"task_id":"t-2","task_status":"SUCCEEDED","transcription_url":"https://res/2.json"}}'),
      (200, asrResultJson),
    ]);

    await engine.run(id);
    var p = await reload(id);
    expect(p.status, ProjectStatus.failed.db);
    expect(p.failedStage, 'upload');

    // 修复网络：补上 PUT/DELETE
    ossAdapter.script
      ..clear()
      ..addAll([(200, ''), (200, '')]);
    await engine.retry(id);
    p = await reload(id);
    expect(p.status, ProjectStatus.waitCalibration.db);
  });

  test('ASR 断点续跑：提交后中断，新引擎凭 task_id 续轮询且不重复提交', () async {
    final id = await createProject();
    // 第一次运行：PUT 成功、提交成功、轮询一次 RUNNING 后网络断
    final (engine1, oss1, asr1) = makeEngine([
      (200, ''),
    ], [
      (200, '{"output":{"task_id":"t-9","task_status":"PENDING"}}'),
      (200, '{"output":{"task_id":"t-9","task_status":"RUNNING"}}'),
      DioException(requestOptions: RequestOptions(path: '/')), // 轮询断网
    ]);
    await engine1.run(id);
    var p = await reload(id);
    expect(p.status, ProjectStatus.failed.db);
    expect(p.failedStage, 'asr');
    expect(ProjectMeta.fromJson(p.metaJson).asrTaskId, 't-9',
        reason: 'task_id 必须已落盘');

    // "重启"：新引擎新适配器，直接续轮询
    final (engine2, oss2, asr2) = makeEngine([
      (200, ''), // ASR 完成后的 DELETE
    ], [
      (200,
          '{"output":{"task_id":"t-9","task_status":"SUCCEEDED","transcription_url":"https://res/9.json"}}'),
      (200, asrResultJson),
    ]);
    await engine2.retry(id);
    p = await reload(id);
    expect(p.status, ProjectStatus.waitCalibration.db);
    // 断言两次运行合计只提交了一次任务
    final submits = asr1.requests
            .where((r) => r.path.contains('asr/transcription'))
            .length +
        asr2.requests.where((r) => r.path.contains('asr/transcription')).length;
    expect(submits, 1);
  });

  test('未配置 OSS 时在 upload 阶段失败并给出可读信息', () async {
    // 清空 OSS 配置
    await settings.saveOssConfig(const OssConfig(
        bucket: '', endpoint: '', accessKeyId: '', accessKeySecret: ''));
    final id = await createProject();
    final (engine, _, _) = makeEngine([], []);
    await engine.run(id);
    final p = await reload(id);
    expect(p.status, ProjectStatus.failed.db);
    expect(p.failedStage, 'upload');

    final events = <PipelineEvent>[];
    final sub = engine.events.listen(events.add);
    await engine.retry(id);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(events.last.detail, contains('OSS'));
  });

  test('本地 ASR 模式：跳过 OSS 直接识别，segments/normalized 落库', () async {
    await settings.saveAsrMode(AsrMode.local);
    final id = await createProject();
    final localPaths = <String>[];
    final engine = PipelineEngine(
        db: db,
        ffmpeg: FakeFFmpegService(durationMs: 2700000),
        asr: AsrClient(Dio()),
        settings: settings,
        audioDir: audioDir,
        pollInterval: const Duration(milliseconds: 10),
        localAsr: (audioPath) async {
          localPaths.add(audioPath);
          return const NormalizedAsr(durationMs: 1500, sentences: [
            AsrSentence(
                beginMs: 0,
                endMs: 1500,
                text: '本地识别文本',
                speakerId: 'SPEAKER_00'),
          ]);
        });
    final stages = <String>[];
    engine.events.listen((e) => stages.add(e.stage));
    await engine.run(id);

    // 无 OSS 配置也能走到闸门 = upload 阶段被跳过
    final p = await reload(id);
    expect(p.status, ProjectStatus.waitCalibration.db);
    expect(stages, isNot(contains('upload')));
    // 本地识别拿到的是 wav 路径
    expect(localPaths, hasLength(1));
    expect(localPaths.single.endsWith('.wav'), isTrue);
    // meta 强制 wav、无 asr_task_id（不走云端任务）
    final meta = ProjectMeta.fromJson(p.metaJson);
    expect(meta.audioFormat, 'wav');
    expect(meta.asrTaskId, isNull);
    expect(meta.asrNormalized!['sentences'], hasLength(1));
    final segs = await db.select(db.segments).get();
    expect(segs.single.content, '本地识别文本');
    expect(segs.single.speakerCharId, isNull); // 映射阶段尚未执行
  });
}
