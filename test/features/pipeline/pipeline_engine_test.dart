import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/asr/asr_types.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/media/ffmpeg_service.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';
import 'package:peixi/features/pipeline/project_meta.dart';
import 'package:peixi/features/pipeline/project_status.dart';

import '../../fakes/fake_ffmpeg_service.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  late Directory audioDir;
  late Directory videoDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
    settings = SettingsRepository(db, const FlutterSecureStorage());
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

  PipelineEngine makeEngine({
    FakeFFmpegService? ffmpeg,
    required Future<NormalizedAsr> Function(String audioPath) localAsr,
  }) {
    return PipelineEngine(
      db: db,
      ffmpeg: ffmpeg ?? FakeFFmpegService(durationMs: 2700000),
      settings: settings,
      audioDir: audioDir,
      localAsr: localAsr,
    );
  }

  Future<Project> reload(int id) => (db.select(db.projects)
        ..where((t) => t.id.equals(id)))
      .getSingle();

  test('全链路（本地识别）S1→READY：校准闸门前停、确认后完成、segments 落库', () async {
    final id = await createProject();
    final engine = makeEngine(localAsr: (audioPath) async {
      return const NormalizedAsr(durationMs: 1500, sentences: [
        AsrSentence(
            beginMs: 0,
            endMs: 700,
            text: '站长，这件事恐怕没那么简单',
            speakerId: 'SPEAKER_00'),
        AsrSentence(
            beginMs: 700,
            endMs: 1500,
            text: '你先别急',
            speakerId: 'SPEAKER_00'),
      ]);
    });

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
    expect(meta.audioFormat, 'wav');
    expect(meta.asrNormalized!['sentences'].length, 2);
    // 时间线不应再出现上传阶段（云端识别已移除）
    expect(stages, isNot(contains('upload')));

    await engine.confirmCalibration(id, {});
    p = await reload(id);
    expect(p.status, ProjectStatus.ready.db);
    expect(File(meta.audioPath(audioDir.path, id)).existsSync(), isTrue,
        reason: '默认保留临时音频');
  });

  test('本地识别拿到的是 16k wav 路径，且缓存直接复用不重抽', () async {
    final id = await createProject();
    final received = <String>[];
    final ffmpeg = FakeFFmpegService(durationMs: 2700000);
    final engine = makeEngine(
        ffmpeg: ffmpeg,
        localAsr: (audioPath) async {
          received.add(audioPath);
          return const NormalizedAsr(durationMs: 100, sentences: []);
        });

    await engine.run(id);
    expect(received, hasLength(1));
    expect(received.single.endsWith('.wav'), isTrue);
    expect(ffmpeg.extractCalls, 1, reason: '仅音频抽取阶段抽一次');

    // 重跑（重试路径）：音频缓存存在，不再重抽
    final p = await reload(id);
    await (db.update(db.projects)..where((t) => t.id.equals(id))).write(
        ProjectsCompanion(
            status: Value(ProjectStatus.imported.db),
            metaJson: Value(ProjectMeta.fromJson(p.metaJson).encode())));
    await engine.run(id);
    expect(ffmpeg.extractCalls, 1, reason: 'wav 缓存存在时跳过重抽');
  });

  test('本地 ASR 失败后重试可恢复（asr→map 走到校准闸门）', () async {
    final id = await createProject();
    var calls = 0;
    final engine = makeEngine(localAsr: (audioPath) async {
      calls++;
      if (calls == 1) throw PipelineException('本地模型未加载');
      return const NormalizedAsr(durationMs: 1500, sentences: [
        AsrSentence(
            beginMs: 0,
            endMs: 1500,
            text: '重试成功文本',
            speakerId: 'SPEAKER_00'),
      ]);
    });

    await engine.run(id);
    var p = await reload(id);
    expect(p.status, ProjectStatus.failed.db);
    expect(p.failedStage, 'asr');

    await engine.retry(id);
    p = await reload(id);
    expect(p.status, ProjectStatus.waitCalibration.db,
        reason: '重试应走完 asr→map 到校准闸门，而不是停留在 FAILED');
    expect(calls, 2);
    final segs = await db.select(db.segments).get();
    expect(segs.single.content, '重试成功文本');
  });

  test('云端时代残留 UPLOADED 项目：本地管线接手，mp3 缓存补转 wav 识别', () async {
    final id = await createProject();
    final meta = ProjectMeta.fromJson((await reload(id)).metaJson)
      ..audioFormat = 'mp3';
    await (db.update(db.projects)..where((t) => t.id.equals(id))).write(
        ProjectsCompanion(
            status: Value(ProjectStatus.uploaded.db),
            metaJson: Value(meta.encode())));
    File('${audioDir.path}/$id.mp3').writeAsBytesSync(List.filled(64, 0));

    final received = <String>[];
    final engine = makeEngine(localAsr: (audioPath) async {
      received.add(audioPath);
      return const NormalizedAsr(durationMs: 100, sentences: []);
    });
    await engine.run(id);

    final p = await reload(id);
    expect(p.status, ProjectStatus.waitCalibration.db);
    expect(received.single.endsWith('.wav'), isTrue,
        reason: 'mp3 缓存不能直接喂本地识别，必须补转 wav');
  });

  test('本地识别中请求取消：不置 FAILED，进度保留可继续', () async {
    final id = await createProject();
    late PipelineEngine engine;
    engine = makeEngine(localAsr: (audioPath) async {
      // 模拟长任务：等取消标记命中后协作式退出
      while (!engine.isCancelled(id)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      throw const PipelineCancelled();
    });

    final events = <PipelineEvent>[];
    final sub = engine.events.listen(events.add);
    final runFuture = engine.run(id);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    engine.requestCancel(id);
    await runFuture;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    final p = await reload(id);
    expect(p.status, ProjectStatus.audioReady.db, reason: '取消保持当前落盘状态');
    expect(p.failedStage, isNull);
    expect(events.any((e) => e.cancelled), isTrue);

    // 继续处理：识别完成走完全程
    final engine2 = makeEngine(localAsr: (audioPath) async {
      return const NormalizedAsr(durationMs: 100, sentences: []);
    });
    await engine2.run(id);
    final p2 = await reload(id);
    expect(p2.status, ProjectStatus.waitCalibration.db);
  });

  test('内嵌字幕交叉纠错：高重叠句换字幕文本，低重叠句保留 ASR', () async {
    final meta = ProjectMeta(
        sourceFilename: '潜伏.S01E03.mkv',
        episode: 3,
        durationMs: 2700000,
        subtitle: [
          // 与 ASR 句1（72000-75800）几乎完全重叠 → 替换为字幕文本
          SubtitleEntry(
              startMs: 71800, endMs: 75900, text: '站长，这件事恐怕没那么简单啊'),
          // 与 ASR 句2（76000-77500）完全不重叠 → 保留 ASR 文本
          SubtitleEntry(startMs: 300000, endMs: 305000, text: '风马牛不相及'),
        ]);
    final video = File('${videoDir.path}/字幕.S01E01.mkv')
      ..writeAsBytesSync(List.filled(32, 1));
    final id = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video',
        title: '字幕',
        sourcePath: video.path,
        status: ProjectStatus.imported.db,
        metaJson: Value(meta.encode())));

    final engine = makeEngine(localAsr: (audioPath) async {
      return const NormalizedAsr(durationMs: 300000, sentences: [
        AsrSentence(
            beginMs: 72000,
            endMs: 75800,
            text: '站长，这件事恐怕没那么简单',
            speakerId: 'SPEAKER_00'),
        AsrSentence(
            beginMs: 76000,
            endMs: 77500,
            text: '你先别急',
            speakerId: 'SPEAKER_00'),
      ]);
    });
    await engine.run(id);

    final p = await reload(id);
    expect(p.status, ProjectStatus.waitCalibration.db);
    final segs = await db.select(db.segments).get();
    expect(segs[0].content, '站长，这件事恐怕没那么简单啊', reason: '高重叠 → 用字幕纠错');
    expect(segs[1].content, '你先别急', reason: '低重叠 → 保留 ASR');
    // 时间轴与说话人保持 ASR 原值（场景切分不受影响）
    expect(segs[0].startMs, 72000);
    expect(segs[0].endMs, 75800);
    expect(segs[1].startMs, 76000);
    // meta_json 里也纠错（角色映射读 normalized）
    final norm = ProjectMeta.fromJson(p.metaJson).asrNormalized!;
    expect((norm['sentences'] as List).first['text'],
        '站长，这件事恐怕没那么简单啊');
  });

  test('源视频丢失且缓存不是 wav：asr 阶段报可读错误', () async {
    final id = await createProject();
    final p0 = await reload(id);
    // 云端时代残留：mp3 缓存 + 源视频已被清理
    File(p0.sourcePath).deleteSync();
    final meta = ProjectMeta.fromJson(p0.metaJson)..audioFormat = 'mp3';
    await (db.update(db.projects)..where((t) => t.id.equals(id))).write(
        ProjectsCompanion(
            status: Value(ProjectStatus.audioReady.db),
            metaJson: Value(meta.encode())));

    final engine = makeEngine(localAsr: (audioPath) async {
      throw StateError('不应被调用');
    });
    final events = <PipelineEvent>[];
    final sub = engine.events.listen(events.add);
    await engine.run(id);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    final p = await reload(id);
    expect(p.status, ProjectStatus.failed.db);
    expect(p.failedStage, 'asr');
    expect(
        events.where((e) => e.status == ProjectStatus.failed).single.detail,
        contains('WAV'));
  });
}
