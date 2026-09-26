import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:peixi/core/asr/asr_client.dart';
import 'package:peixi/core/asr/asr_model_controller.dart';
import 'package:peixi/core/asr/local_asr_client.dart';
import 'package:drift/drift.dart' show Expression, Value;
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/media/ffmpeg_service.dart';
import 'package:peixi/core/media/filename_parser.dart';
import 'package:peixi/core/novel/epub_parser.dart';
import 'package:peixi/core/novel/novel_parser.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/providers.dart';
import 'package:peixi/features/pipeline/character_mapper.dart';
import 'package:peixi/features/pipeline/commentary_generator.dart';
import 'package:peixi/features/pipeline/novel_commentary_generator.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/novel_pipeline.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';
import 'package:peixi/features/pipeline/pipeline_queue.dart';
import 'package:peixi/features/pipeline/scene_segmenter.dart';
import 'package:peixi/features/pipeline/project_meta.dart';
import 'package:peixi/features/pipeline/project_status.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 单项目当前处理状态（UI 卡片/处理页展示）。
class PipelineState {
  const PipelineState(
      {required this.stage, this.progress, this.detail, this.busy = true});
  final String stage;
  final double? progress;
  final String? detail;
  final bool busy;
}

/// 导入结果：成功返回项目 id，失败返回可读错误。
class ImportResult {
  const ImportResult({this.projectId, this.error});
  final int? projectId;
  final String? error;
}

/// 批量导入的单文件失败记录（file 为文件名，供 UI 展示）。
class ImportFailure {
  const ImportFailure(this.file, this.error);
  final String file;
  final String error;
}

/// 一次批量导入的汇总：成功的项目 id、逐文件失败清单、前置校验错误。
class ImportBatchResult {
  ImportBatchResult({this.configError});
  String? configError; // 可变：拖拽导入合并多路结果时填入
  final List<int> okIds = [];
  final List<ImportFailure> failures = [];
}

/// 管线后台运行与进度广播。共享一个 PipelineEngine（引擎按 projectId
/// 防并发），App 启动时自动续跑中间状态的项目（含 ASR 轮询续跑）。
class PipelineController extends Notifier<Map<int, PipelineState>> {
  PipelineEngine? _engine;
  NovelPipelineEngine? _novelEngine;
  Directory? _audioDir;
  final _queue = PipelineQueue();

  @override
  Map<int, PipelineState> build() {
    Future.microtask(() async {
      await _resumeAll();
    });
    return {};
  }

  Future<Directory> audioDir() async =>
      _audioDir ??= Directory('${(await getApplicationSupportDirectory()).path}/audio');

  Future<PipelineEngine> engine() async {
    if (_engine != null) return _engine!;
    final e = PipelineEngine(
      db: ref.read(databaseProvider),
      ffmpeg: ref.read(ffmpegServiceProvider),
      asr: AsrClient(ref.read(dioProvider)),
      settings: ref.read(settingsRepoProvider),
      audioDir: await audioDir(),
      localAsr: (audioPath) async {
        final modelDir = await LocalAsrClient.defaultLocalModelDir();
        if (!LocalAsrClient(modelDir: modelDir).isReady) {
          // 手机端无法跑下载脚本：缺模型时应用内自动补齐（失败则本阶段报错）
          final ok = await ref.read(asrModelStateProvider.notifier).download();
          if (!ok) {
            final st = ref.read(asrModelStateProvider);
            throw AsrException('本地 ASR 模型自动下载失败：${st.error ?? '未知原因'}'
                '。可在设置 → 语音识别（ASR）中手动重试。');
          }
        }
        return LocalAsrClient.recognizeInBackground(
            modelDir: modelDir, audioPath: audioPath);
      },
    );
    // S6/S8/S9 协作器装配（偏离：引擎不直接依赖 LLM，保持可测）
    final llm = ref.read(llmServiceProvider);
    final db = ref.read(databaseProvider);
    e.attachCollaborators(
      map: (id) => CharacterMapper(db: db, llm: llm).map(id),
      segment: (id) => SceneWriter(db).writeScenes(id),
      commentary: (id) => CommentaryGenerator(
        db: db,
        llm: llm,
        modelStandard: () =>
            llm.modelOf(LlmSlot.analysis) ??
            RoutingTable.fallbackModelFor(LlmSlot.analysis),
        isCancelled: () => e.isCancelled(id),
        onProgress: (done, total) => _onEvent(PipelineEvent(
            projectId: id,
            stage: 'commentary',
            status: ProjectStatus.segmented,
            progress: total == 0 ? 0 : done / total)),
      ).generate(id),
    );
    e.events.listen(_onEvent);
    _engine = e;
    return e;
  }

  /// 小说管线（N2-N4）。
  Future<NovelPipelineEngine> novelEngine() async {
    if (_novelEngine != null) return _novelEngine!;
    final e = NovelPipelineEngine(db: ref.read(databaseProvider));
    final llm = ref.read(llmServiceProvider);
    final db = ref.read(databaseProvider);
    e.attachCollaborators(
      extractCast: (id) => NovelCharacterExtractor(
        db: db,
        llm: llm,
        isCancelled: () => e.isCancelled(id),
      ).extract(id),
      annotate: (id) => NovelCommentaryGenerator(db: db, llm: llm,
          isCancelled: () => e.isCancelled(id),
          onProgress: (done, total) => _onEvent(PipelineEvent(
              projectId: id,
              stage: 'commentary',
              status: ProjectStatus.mapped,
              progress: total == 0 ? 0 : done / total))).generate(id),
    );
    e.events.listen(_onEvent);
    _novelEngine = e;
    return e;
  }

  /// 入队串行推进管线（见 PipelineQueue 注释）。
  void _startRun(String type, int projectId) {
    _queue.add(projectId, () async {
      if (type == 'novel') {
        await (await novelEngine()).run(projectId);
      } else {
        await (await engine()).run(projectId);
      }
    });
  }

  /// 等待串行队列清空（测试用：确保全部落盘完成）。
  Future<void> waitPipelineIdle() => _queue.waitIdle();

  Future<void> _resumeAll() async {
    final db = ref.read(databaseProvider);
    // 视频/小说各自状态机互不兼容，按 type 分流续跑
    final videos = await (db.select(db.projects)
          ..where((t) => Expression.and([
                t.type.equals('video'),
                t.status.isIn([
                  ProjectStatus.imported.db,
                  ProjectStatus.audioReady.db,
                  ProjectStatus.uploaded.db,
                  ProjectStatus.asrDone.db,
                  ProjectStatus.mapped.db,
                  ProjectStatus.calibrated.db,
                  ProjectStatus.segmented.db,
                  ProjectStatus.commentaryDone.db,
                ]),
              ])))
        .get();
    final novels = await (db.select(db.projects)
          ..where((t) => Expression.and([
                t.type.equals('novel'),
                t.status.isIn([
                  ProjectStatus.imported.db,
                  ProjectStatus.mapped.db,
                  ProjectStatus.commentaryDone.db,
                ]),
              ])))
        .get();
    for (final p in videos) {
      _startRun('video', p.id);
    }
    for (final p in novels) {
      _startRun('novel', p.id);
    }
  }

  void _onEvent(PipelineEvent e) {
    final busy = !e.cancelled &&
        e.status != ProjectStatus.failed &&
        e.status != ProjectStatus.ready &&
        e.status != ProjectStatus.waitCalibration;
    state = {
      ...state,
      e.projectId: PipelineState(
          stage: e.stage,
          progress: e.progress,
          detail: e.detail,
          busy: busy),
    };
    _syncWakelock();
  }

  void _syncWakelock() {
    final anyBusy = state.values.any((s) => s.busy);
    WakelockPlus.toggle(enable: anyBusy);
  }

  /// 导入前的配置校验：避免选完文件、抽完音频才在 upload/asr 阶段失败。
  /// 返回 null 表示通过。
  Future<String?> _precheck({bool needOss = false}) async {
    final repo = ref.read(settingsRepoProvider);
    final api = await repo.loadApiConfig();
    if (!api.isComplete) return '尚未配置 LLM API Key，请先到设置页配置';
    if (needOss && await repo.loadAsrMode() == AsrMode.cloud) {
      final oss = await repo.loadOssConfig();
      if (oss == null || !oss.isComplete) {
        return '云端识别需先在设置页配置 OSS 中转桶，或切换为本地识别模式';
      }
    }
    return null;
  }

  /// S1 批量导入视频（可整季多选）：paths 为空时打开文件选择器。
  /// 前置校验只做一次；单个文件失败只记录、不中断批次；
  /// 成功的逐个入队串行开跑。
  Future<ImportBatchResult> importVideos({List<String>? paths}) async {
    final selected = await _resolvePaths(
        paths: paths,
        picker: () async {
          final picked = await FilePicker.pickFiles(type: FileType.video);
          return [for (final f in picked) if (f.path != null) f.path!];
        });
    if (selected == null || selected.isEmpty) return ImportBatchResult();
    final cfgErr = await _precheck(needOss: true);
    if (cfgErr != null) return ImportBatchResult(configError: cfgErr);

    final out = ImportBatchResult();
    for (final path in selected) {
      try {
        final res = await _importOneVideo(path);
        if (res.projectId != null) {
          out.okIds.add(res.projectId!);
          _startRun('video', res.projectId!);
        } else {
          out.failures.add(ImportFailure(_baseName(path), res.error ?? '未知错误'));
        }
      } catch (e) {
        out.failures.add(ImportFailure(_baseName(path), '导入异常：$e'));
      }
    }
    return out;
  }

  Future<ImportResult> _importOneVideo(String path) async {
    final ffmpeg = ref.read(ffmpegServiceProvider);
    final MediaInfo info;
    try {
      info = await ffmpeg.probe(path);
    } catch (e) {
      return ImportResult(error: '无法读取视频：$e');
    }
    if (info.durationMs <= 0) {
      return const ImportResult(error: '视频时长为 0，文件可能损坏');
    }

    var sourcePath = path;
    final filename = _baseName(path);
    if (Platform.isAndroid) {
      // SAF 返回的缓存路径不可长期依赖，复制进应用目录（偏离#4）
      final dir = await getApplicationDocumentsDirectory();
      final videos = Directory('${dir.path}/video')..createSync(recursive: true);
      final dest = '${videos.path}/${DateTime.now().millisecondsSinceEpoch}_$filename';
      await File(path).copy(dest);
      sourcePath = dest;
    }

    final parsed = FilenameParser.parse(filename);
    final meta = ProjectMeta(
        sourceFilename: filename,
        episode: parsed.episode,
        durationMs: info.durationMs,
        hasSubtitle: info.hasSubtitle);
    final db = ref.read(databaseProvider);
    final id = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video',
        title: parsed.title,
        sourcePath: sourcePath,
        status: ProjectStatus.imported.db,
        metaJson: Value(meta.encode())));
    return ImportResult(projectId: id);
  }

  /// N1 批量导入小说（txt/epub）：结构与 importVideos 对称。
  Future<ImportBatchResult> importNovels({List<String>? paths}) async {
    final selected = await _resolvePaths(
        paths: paths,
        picker: () async {
          final picked = await FilePicker.pickFiles(
              type: FileType.custom, allowedExtensions: ['txt', 'epub']);
          return [for (final f in picked) if (f.path != null) f.path!];
        });
    if (selected == null || selected.isEmpty) return ImportBatchResult();
    final cfgErr = await _precheck();
    if (cfgErr != null) return ImportBatchResult(configError: cfgErr);

    final out = ImportBatchResult();
    for (final path in selected) {
      try {
        final res = await _importOneNovel(path);
        if (res.projectId != null) {
          out.okIds.add(res.projectId!);
          _startRun('novel', res.projectId!);
        } else {
          out.failures.add(ImportFailure(_baseName(path), res.error ?? '未知错误'));
        }
      } catch (e) {
        out.failures.add(ImportFailure(_baseName(path), '导入异常：$e'));
      }
    }
    return out;
  }

  Future<ImportResult> _importOneNovel(String path) async {
    var sourcePath = path;
    final filename = _baseName(path);
    if (Platform.isAndroid) {
      // 同视频：SAF 缓存路径不可长期依赖，复制进应用目录
      final dir = await getApplicationDocumentsDirectory();
      final novels = Directory('${dir.path}/novel')..createSync(recursive: true);
      final dest =
          '${novels.path}/${DateTime.now().millisecondsSinceEpoch}_$filename';
      await File(path).copy(dest);
      sourcePath = dest;
    }

    final NovelDoc doc;
    try {
      if (filename.toLowerCase().endsWith('.epub')) {
        doc = parseEpubFile(sourcePath);
      } else {
        doc = parseNovel(decodeNovelText(await File(sourcePath).readAsBytes()));
      }
    } catch (e) {
      return ImportResult(error: '无法读取小说文件：$e');
    }
    if (doc.chapters.isEmpty) {
      return const ImportResult(error: '文件为空或无法解析出任何段落');
    }

    final title = filename
        .replaceAll(RegExp(r'\.(txt|epub)$', caseSensitive: false), '');
    final id = await NovelImporter(db: ref.read(databaseProvider)).import(
        title: title, sourcePath: sourcePath, doc: doc);
    return ImportResult(projectId: id);
  }

  /// paths 为 null 时调用选择器；否则直接使用外部路径（拖拽导入复用）。
  Future<List<String>?> _resolvePaths(
      {List<String>? paths,
      required Future<List<String>> Function() picker}) async {
    if (paths != null) return paths;
    return picker();
  }

  /// Windows 路径分隔符可能混用 \ 与 /（外部工具传入的路径常见），两者都要处理。
  String _baseName(String path) =>
      path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;

  /// 请求取消处理（协作式：当前阶段循环/轮询命中标记即中断，
  /// 已落盘进度保留，处理页/库卡片可"继续处理"）。
  /// 同时剔除串行队列里尚未开跑的该任务。
  Future<void> cancel(int projectId) async {
    _queue.cancelPending(projectId);
    final db = ref.read(databaseProvider);
    final p = await (db.select(db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingleOrNull();
    if (p == null) return;
    if (p.type == 'novel') {
      (await novelEngine()).requestCancel(projectId);
    } else {
      (await engine()).requestCancel(projectId);
    }
  }

  Future<void> retry(int projectId) async {
    // 视频/小说状态机互不兼容，必须按 type 分流到各自引擎
    final db = ref.read(databaseProvider);
    final p = await (db.select(db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingleOrNull();
    if (p == null) return;
    _startRun(p.type, projectId);
  }

  Future<void> confirmCalibration(
      int projectId, Map<int, String> names) async {
    _queue.add(projectId, () async {
      await (await engine()).confirmCalibration(projectId, names);
    });
  }

  /// 删除项目：DB 级联 + 临时音频/字幕文件。
  Future<void> deleteProject(int projectId) async {
    final db = ref.read(databaseProvider);
    final p = await (db.select(db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingleOrNull();
    if (p != null) {
      final meta = ProjectMeta.fromJson(p.metaJson);
      final dir = await audioDir();
      // $id.wav 是本地模式从 mp3/m4a 缓存补转的副本，不在 audioPath() 命名内
      for (final f in [
        File(meta.audioPath(dir.path, projectId)),
        File('${dir.path}/$projectId.wav'),
        File('${dir.path}/$projectId.srt'),
      ]) {
        if (f.existsSync()) f.deleteSync();
      }
      if (Platform.isAndroid && p.sourcePath.contains('/video/')) {
        final f = File(p.sourcePath);
        if (f.existsSync()) f.deleteSync();
      }
      if (Platform.isAndroid && p.sourcePath.contains('/novel/')) {
        final f = File(p.sourcePath);
        if (f.existsSync()) f.deleteSync();
      }
      await (db.delete(db.projects)..where((t) => t.id.equals(projectId)))
          .go();
    }
    state = {...state}..remove(projectId);
    _syncWakelock();
  }
}
