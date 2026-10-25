// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:peixi/core/asr/asr_types.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/logging/crash_log.dart';
import 'package:peixi/core/media/ffmpeg_service.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/pipeline/project_meta.dart';
import 'package:peixi/features/pipeline/project_status.dart';
import 'package:peixi/features/pipeline/subtitle_aligner.dart';

/// 进度事件（媒体库卡片 / 处理页监听）。
class PipelineEvent {
  const PipelineEvent({
    required this.projectId,
    required this.stage,
    required this.status,
    this.progress,
    this.detail,
    this.cancelled = false,
  });
  final int projectId;
  final String stage; // subtitle|audio|asr|map|segment|commentary|finalize
  final ProjectStatus status;
  final double? progress; // 0-1；null = 无进度概念
  final String? detail;
  final bool cancelled; // 用户主动取消（区别于失败）
}

class PipelineException implements Exception {
  PipelineException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 用户取消（_stage 捕获后按"已取消"处理，不置 FAILED；
/// 进度均按阶段落盘，续跑/重试可无损恢复）。
class PipelineCancelled implements Exception {
  const PipelineCancelled();
  @override
  String toString() => '已取消';
}

/// 阶段级失败（调度器抛出）：引擎按 stage 落 FAILED + failed_stage。
class PipelineStageException implements Exception {
  PipelineStageException(this.stage, this.cause);
  final String stage;
  final Object cause;
  @override
  String toString() => '阶段 $stage 失败：$cause';
}

/// 视频处理状态机（设计稿第四节 S1-S10）。
/// projects.status 为唯一事实源：每阶段成功即落盘，任一阶段失败置
/// FAILED+failed_stage，retry 回退到该阶段入口状态重跑。
/// 语音识别只有本地 sherpa-onnx 离线模式（16k wav，无上传/轮询环节；
/// 云端 DashScope+OSS 中转已移除）。
class PipelineEngine {
  PipelineEngine({
    required AppDatabase db,
    required FFmpegService ffmpeg,
    required SettingsRepository settings,
    required Directory audioDir,
    Future<NormalizedAsr> Function(String audioPath)? localAsr,
  })  : _db = db,
        _ffmpeg = ffmpeg,
        _settings = settings,
        _audioDir = audioDir,
        _localAsr = localAsr {
    _audioDir.createSync(recursive: true);
  }

  final AppDatabase _db;
  final FFmpegService _ffmpeg;
  final SettingsRepository _settings;
  final Directory _audioDir;

  /// 本地 ASR 识别函数（null = 用库内默认装配，由 controller 注入）
  final Future<NormalizedAsr> Function(String audioPath)? _localAsr;

  final StreamController<PipelineEvent> _events =
      StreamController<PipelineEvent>.broadcast();
  Stream<PipelineEvent> get events => _events.stream;
  final Set<int> _busy = {};
  final Set<int> _cancelRequested = {};

  /// 请求取消（仅当项目正在运行时登记；同时中止进行中的 ffmpeg 抽取）。
  /// 取消是协作式：各阶段循环/轮询检查标记后抛 [PipelineCancelled]。
  /// 注：cancelActive 会中止所有 ffmpeg 会话，个人应用无并发抽取场景。
  void requestCancel(int projectId) {
    if (!_busy.contains(projectId)) return;
    _cancelRequested.add(projectId);
    _ffmpeg.cancelActive();
  }

  /// 供协作器循环（解说/批注）检查取消标记。
  bool isCancelled(int projectId) => _cancelRequested.contains(projectId);

  void _emit(int projectId, String stage, ProjectStatus status,
      {double? progress, String? detail, bool cancelled = false}) {
    _events.add(PipelineEvent(
        projectId: projectId,
        stage: stage,
        status: status,
        progress: progress,
        detail: detail,
        cancelled: cancelled));
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
      // asr 阶段接受 audioReady；UPLOADED 是云端时代残留状态，同样放行重跑
      // （本地识别会按需补转 wav），否则旧项目重试会空转
      if (st == ProjectStatus.audioReady || st == ProjectStatus.uploaded) {
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

  /// 包裹单阶段：异常 → FAILED + failed_stage 落盘 + 事件；
  /// 取消（标记命中或 [PipelineCancelled]）→ 事件标注 cancelled，状态保持当前落盘值。
  Future<bool> _stage(
      int id, String name, Future<void> Function(int) step) async {
    final p = await _project(id);
    _emit(id, name, ProjectStatus.fromDb(p.status));
    try {
      await step(id);
      if (_cancelRequested.remove(id)) {
        await _emitCancelled(id, name);
        return false;
      }
      return true;
    } catch (e) {
      if (_cancelRequested.remove(id) || e is PipelineCancelled) {
        await _emitCancelled(id, name);
        return false;
      }
      await _setStatus(id, ProjectStatus.failed, failedStage: name);
      _emit(id, name, ProjectStatus.failed, detail: '$e');
      return false;
    }
  }

  Future<void> _emitCancelled(int id, String name) async {
    final p = await _project(id);
    _emit(id, name, ProjectStatus.fromDb(p.status),
        detail: '已取消（进度已保存，可继续）', cancelled: true);
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
    } catch (e, st) {
      // S2 任何失败都不阻塞主线（设计稿：提取失败则跳过），但留痕便于排查
      // 字幕为何缺失——它同时影响播放器字幕轨与 ASR 交叉纠错
      CrashLog.write('subtitle-extract', e, st);
    }
  }

  // ---------- S3 音频抽取（固定 16k 单声道 wav，本地识别直接可用） ----------
  Future<void> _extractAudio(int id) async {
    final p = await _project(id);
    final meta = ProjectMeta.fromJson(p.metaJson);
    if (meta.audioFormat == null) {
      meta.audioFormat = 'wav';
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

  // ---------- S5 ASR：本地 sherpa-onnx 离线识别 ----------
  Future<void> _runAsrTask(int id) async {
    final p = await _project(id);
    final meta = ProjectMeta.fromJson(p.metaJson);

    final localFn = _localAsr;
    if (localFn == null) {
      throw PipelineException('本地 ASR 未初始化（需下载模型）');
    }
    final norm = await localFn(await _ensureWavAudio(p, id, meta));

    await _persistAsrResult(id, meta, norm);
    await _setStatus(id, ProjectStatus.asrDone);
  }

  /// 音频：缓存是 wav 直接用；否则从源视频补转一份 16k wav
  /// （云端时代缓存过 mp3/m4a 的旧项目走补转路径）。
  Future<String> _ensureWavAudio(Project p, int id, ProjectMeta meta) async {
    if (meta.audioFormat == 'wav') {
      final f = File(meta.audioPath(_audioDir.path, id));
      if (f.existsSync()) return f.path;
    }
    final wavPath = '${_audioDir.path}/$id.wav';
    if (!File(wavPath).existsSync()) {
      if (!File(p.sourcePath).existsSync()) {
        throw PipelineException('源视频不存在且缓存音频不是 WAV，无法识别');
      }
      await _ffmpeg.extractAudio(p.sourcePath, wavPath, onProgress: (r) {
        _emit(id, 'audio', ProjectStatus.audioReady, progress: r);
      });
    }
    return wavPath;
  }

  /// 规范化结果 → meta_json；对白行 → segments（幂等：先清旧）。
  /// 有内嵌字幕时先做交叉纠错（字幕文本更可靠，时间轴/说话人不变）。
  Future<void> _persistAsrResult(
      int id, ProjectMeta meta, NormalizedAsr norm) async {
    final subs = meta.subtitle;
    if (subs != null && subs.isNotEmpty) {
      norm = NormalizedAsr(
          durationMs: norm.durationMs,
          sentences: correctWithSubtitles(norm.sentences, subs));
    }
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
