// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:peixi/core/asr/asr_client.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/media/ffmpeg_service.dart';
import 'package:peixi/core/oss/oss_client.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/pipeline/project_meta.dart';
import 'package:peixi/features/pipeline/project_status.dart';

/// 进度事件（媒体库卡片 / 处理页监听）。
class PipelineEvent {
  const PipelineEvent({
    required this.projectId,
    required this.stage,
    required this.status,
    this.progress,
    this.detail,
  });
  final int projectId;
  final String stage; // subtitle|audio|upload|asr|map|segment|commentary|finalize
  final ProjectStatus status;
  final double? progress; // 0-1；null = 无进度概念（如轮询）
  final String? detail;
}

class PipelineException implements Exception {
  PipelineException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 视频处理状态机（设计稿第四节 S1-S10）。
/// projects.status 为唯一事实源：每阶段成功即落盘，任一阶段失败置
/// FAILED+failed_stage，retry 回退到该阶段入口状态重跑；ASR 提交后
/// meta_json.asr_task_id 持久化，App 被杀重启可续轮询。
class PipelineEngine {
  PipelineEngine({
    required AppDatabase db,
    required FFmpegService ffmpeg,
    required AsrClient asr,
    required SettingsRepository settings,
    required Directory audioDir,
    Dio? ossDio,
    this.pollInterval = const Duration(seconds: 5),
    this.pollTimeout = const Duration(minutes: 30),
  })  : _db = db,
        _ffmpeg = ffmpeg,
        _asr = asr,
        _settings = settings,
        _audioDir = audioDir,
        _ossDio = ossDio ?? Dio() {
    _audioDir.createSync(recursive: true);
  }

  final AppDatabase _db;
  final FFmpegService _ffmpeg;
  final AsrClient _asr;
  final SettingsRepository _settings;
  final Directory _audioDir;
  final Dio _ossDio;
  final Duration pollInterval;
  final Duration pollTimeout;

  final StreamController<PipelineEvent> _events =
      StreamController<PipelineEvent>.broadcast();
  Stream<PipelineEvent> get events => _events.stream;
  final Set<int> _busy = {};

  void _emit(int projectId, String stage, ProjectStatus status,
      {double? progress, String? detail}) {
    _events.add(PipelineEvent(
        projectId: projectId,
        stage: stage,
        status: status,
        progress: progress,
        detail: detail));
  }

  Future<Project> _project(int id) async {
    final p = await (_db.select(_db.projects)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (p == null) throw PipelineException('项目不存在: $id');
    return p;
  }

  Future<void> _setStatus(int id, ProjectStatus s, {String? failedStage}) async {
    await (_db.update(_db.projects)..where((t) => t.id.equals(id))).write(
        ProjectsCompanion(
            status: Value(s.db),
            failedStage: Value(failedStage),
            updatedAt: Value(DateTime.now())));
  }

  Future<ProjectMeta> _saveMeta(int id, ProjectMeta meta) async {
    await (_db.update(_db.projects)..where((t) => t.id.equals(id)))
        .write(ProjectsCompanion(
            metaJson: Value(meta.encode()), updatedAt: Value(DateTime.now())));
    return meta;
  }

  /// 从当前状态推进，直到 WAIT_CALIBRATION（人工闸门）或 READY 或 FAILED。
  Future<void> run(int projectId) async {
    if (!_busy.add(projectId)) return; // 同项目防并发
    try {
      var p = await _project(projectId);
      var st = ProjectStatus.fromDb(p.status);
      if (st == ProjectStatus.failed) {
        st = entryStatusOfStage(p.failedStage ?? '');
      }
      if (st == ProjectStatus.imported) {
        if (!await _stage(projectId, 'subtitle', _extractSubtitle)) return;
        if (!await _stage(projectId, 'audio', _extractAudio)) return;
        st = ProjectStatus.audioReady;
      }
      if (st == ProjectStatus.audioReady) {
        if (!await _stage(projectId, 'upload', _uploadOss)) return;
        st = ProjectStatus.uploaded;
      }
      if (st == ProjectStatus.uploaded) {
        if (!await _stage(projectId, 'asr', _runAsrTask)) return;
        st = ProjectStatus.asrDone;
      }
      if (st == ProjectStatus.asrDone) {
        if (!await _stage(projectId, 'map', _mapCharacters)) return;
        st = ProjectStatus.mapped;
      }
      if (st == ProjectStatus.mapped) {
        // S7 人工校准闸门：必须经 confirmCalibration() 继续
        await _setStatus(projectId, ProjectStatus.waitCalibration);
        _emit(projectId, 'calibration', ProjectStatus.waitCalibration);
        return;
      }
      if (st == ProjectStatus.waitCalibration || st == ProjectStatus.calibrated) {
        if (st == ProjectStatus.waitCalibration) return;
        if (!await _stage(projectId, 'segment', _segmentScenes)) return;
        st = ProjectStatus.segmented;
      }
      if (st == ProjectStatus.segmented) {
        if (!await _stage(projectId, 'commentary', _generateCommentary)) return;
        st = ProjectStatus.commentaryDone;
      }
      if (st == ProjectStatus.commentaryDone) {
        if (!await _stage(projectId, 'finalize', _finalize)) return;
      }
    } finally {
      _busy.remove(projectId);
    }
  }

  /// 失败重试：状态机已按 failed_stage 回退入口，直接 run。
  Future<void> retry(int projectId) => run(projectId);

  /// S7 校准确认：写入用户修正的角色名后继续 S8-S10。
  Future<void> confirmCalibration(
      int projectId, Map<int, String> charIdToName) async {
    for (final e in charIdToName.entries) {
      await (_db.update(_db.characters)..where((t) => t.id.equals(e.key)))
          .write(CharactersCompanion(
              name: Value(e.value), source: const Value('manual')));
    }
    await _setStatus(projectId, ProjectStatus.calibrated);
    _emit(projectId, 'calibration', ProjectStatus.calibrated);
    await run(projectId);
  }

  /// 包裹单阶段：异常 → FAILED + failed_stage 落盘 + 事件。
  Future<bool> _stage(
      int id, String name, Future<void> Function(int) step) async {
    final p = await _project(id);
    _emit(id, name, ProjectStatus.fromDb(p.status));
    try {
      await step(id);
      return true;
    } catch (e) {
      await _setStatus(id, ProjectStatus.failed, failedStage: name);
      _emit(id, name, ProjectStatus.failed, detail: '$e');
      return false;
    }
  }

  // ---------- S2 字幕提取（可选，失败不阻塞） ----------
  Future<void> _extractSubtitle(int id) async {
    try {
      final p = await _project(id);
      final meta = ProjectMeta.fromJson(p.metaJson);
      if (!meta.hasSubtitle || meta.subtitle != null) return;
      final srtPath = '${_audioDir.path}/$id.srt';
      final text = await _ffmpeg.extractSubtitle(p.sourcePath, srtPath);
      if (text != null) {
        meta.subtitle = parseSrt(text);
        await _saveMeta(id, meta);
        _emit(id, 'subtitle', ProjectStatus.imported,
            detail: '字幕 ${meta.subtitle!.length} 条');
      }
    } catch (_) {
      // S2 任何失败都不阻塞主线（设计稿：提取失败则跳过）
    }
  }

  // ---------- S3 音频抽取 ----------
  Future<void> _extractAudio(int id) async {
    final p = await _project(id);
    final meta = ProjectMeta.fromJson(p.metaJson);
    if (meta.audioFormat == null) {
      meta.audioFormat = (await _ffmpeg.pickAudioFormat()).ext;
      await _saveMeta(id, meta);
    }
    final out = meta.audioPath(_audioDir.path, id);
    if (!File(out).existsSync()) {
      await _ffmpeg.extractAudio(p.sourcePath, out, onProgress: (r) {
        _emit(id, 'audio', ProjectStatus.imported, progress: r);
      });
    }
    await _setStatus(id, ProjectStatus.audioReady);
  }

  // ---------- S4 上传 OSS ----------
  Future<void> _uploadOss(int id) async {
    final p = await _project(id);
    final meta = ProjectMeta.fromJson(p.metaJson);
    final ossCfg = await _settings.loadOssConfig();
    if (ossCfg == null || !ossCfg.isComplete) {
      throw PipelineException('未配置 OSS 中转桶（设置页填写 bucket/endpoint/AK/SK）');
    }
    final file = File(meta.audioPath(_audioDir.path, id));
    if (!file.existsSync()) {
      // 音频文件丢了（如清理过缓存）：退回重抽
      await _setStatus(id, ProjectStatus.imported);
      throw PipelineException('临时音频不存在，已重置到导入状态');
    }
    final key = meta.ossKey ?? 'peixi/asr/$id.${meta.audioFormat ?? 'mp3'}';
    final contentType = switch (meta.audioFormat) {
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      _ => 'audio/mpeg',
    };
    final oss = OssClient(_ossDio, ossCfg);
    await oss.putFile(file, key, contentType: contentType, onProgress: (r) {
      _emit(id, 'upload', ProjectStatus.audioReady, progress: r);
    });
    meta.ossKey = key;
    await _saveMeta(id, meta);
    await _setStatus(id, ProjectStatus.uploaded);
  }

  // ---------- S5 ASR：提交 + 轮询 + 下载 + 删对象 ----------
  Future<void> _runAsrTask(int id) async {
    var p = await _project(id);
    var meta = ProjectMeta.fromJson(p.metaJson);
    final apiCfg = await _settings.loadApiConfig();
    if (!apiCfg.isComplete) {
      throw PipelineException('未配置 LLM/ASR API Key（设置页）');
    }
    final ossCfg = await _settings.loadOssConfig();
    if (ossCfg == null || !ossCfg.isComplete) {
      throw PipelineException('未配置 OSS 中转桶');
    }
    final oss = OssClient(_ossDio, ossCfg);

    if (meta.asrTaskId == null) {
      if (meta.ossKey == null) {
        throw PipelineException('缺少 OSS 对象键，请重试');
      }
      final url = oss.signedGetUrl(meta.ossKey!);
      meta.asrTaskId = await _asr.submit(apiCfg.apiKey, url);
      // 立即落盘：之后任意时刻被杀都能凭 task_id 续轮询
      meta = await _saveMeta(id, meta);
      p = await _project(id);
    }

    final deadline = DateTime.now().add(pollTimeout);
    String? transcriptionUrl;
    while (true) {
      final r = await _asr.poll(apiCfg.apiKey, meta.asrTaskId!);
      if (r.phase == AsrTaskPhase.succeeded) {
        transcriptionUrl = r.transcriptionUrl;
        break;
      }
      if (r.phase == AsrTaskPhase.failed) {
        throw PipelineException('ASR 任务失败: ${r.message ?? '未知原因'}');
      }
      if (DateTime.now().isAfter(deadline)) {
        throw PipelineException('ASR 轮询超时（${pollTimeout.inMinutes} 分钟）');
      }
      await Future<void>.delayed(pollInterval);
    }

    final norm = await _asr.downloadResult(transcriptionUrl!);
    // 识别完成即删 OSS 对象（设计稿：用后即删；失败不影响主线）
    try {
      if (meta.ossKey != null) await oss.deleteObject(meta.ossKey!);
    } catch (_) {}

    // 规范化结果 → meta_json；对白行 → segments（幂等：先清旧）
    meta.asrNormalized = {
      'duration_ms': norm.durationMs,
      'sentences': [
        for (final s in norm.sentences)
          {
            'begin_ms': s.beginMs,
            'end_ms': s.endMs,
            'text': s.text,
            'speaker_id': s.speakerId,
          }
      ],
    };
    await (_db.delete(_db.segments)..where((t) => t.projectId.equals(id)))
        .go();
    await _db.batch((batch) {
      for (var i = 0; i < norm.sentences.length; i++) {
        final s = norm.sentences[i];
        batch.insert(
            _db.segments,
            SegmentsCompanion.insert(
                projectId: id,
                idx: i,
                startMs: s.beginMs,
                endMs: s.endMs,
                content: s.text));
      }
    });
    await _saveMeta(id, meta);
    await _setStatus(id, ProjectStatus.asrDone);
  }

  // ---------- S6 角色映射（实现由 attachCollaborators 注入，Phase 3） ----------
  Future<void> Function(int projectId)? _mapCharactersFn;
  Future<void> _mapCharacters(int id) async {
    await _mapCharactersFn?.call(id);
    await _setStatus(id, ProjectStatus.mapped);
  }

  // ---------- S8 场景切分（注入同上） ----------
  Future<void> Function(int projectId)? _segmentScenesFn;
  Future<void> _segmentScenes(int id) async {
    await _segmentScenesFn?.call(id);
    await _setStatus(id, ProjectStatus.segmented);
  }

  // ---------- S9 解说生成（注入同上） ----------
  Future<void> Function(int projectId)? _generateCommentaryFn;
  Future<void> _generateCommentary(int id) async {
    await _generateCommentaryFn?.call(id);
    await _setStatus(id, ProjectStatus.commentaryDone);
  }

  // ---------- S10 收尾 ----------
  Future<void> _finalize(int id) async {
    final prefs = await _settings.loadPlayPrefs();
    if (!prefs.keepTempAudio) {
      final p = await _project(id);
      final meta = ProjectMeta.fromJson(p.metaJson);
      final f = File(meta.audioPath(_audioDir.path, id));
      if (f.existsSync()) f.deleteSync();
    }
    await _setStatus(id, ProjectStatus.ready);
    _emit(id, 'finalize', ProjectStatus.ready);
  }

  /// Phase 3 协作器注入点（CharacterMapper/SceneSegmenter/CommentaryGenerator）。
  /// 引擎不依赖 LLM 细节，保持 S1-S5 可独立测试。
  void attachCollaborators({
    Future<void> Function(int)? map,
    Future<void> Function(int)? segment,
    Future<void> Function(int)? commentary,
  }) {
    _mapCharactersFn = map;
    _segmentScenesFn = segment;
    _generateCommentaryFn = commentary;
  }
}
