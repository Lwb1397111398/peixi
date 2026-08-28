import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:peixi/core/asr/asr_client.dart';
import 'package:peixi/core/asr/local_asr_client.dart';
import 'package:drift/drift.dart' show Expression, Value;
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/media/ffmpeg_service.dart';
import 'package:peixi/core/media/filename_parser.dart';
import 'package:peixi/core/novel/epub_parser.dart';
import 'package:peixi/core/novel/novel_parser.dart';
import 'package:peixi/providers.dart';
import 'package:peixi/features/pipeline/character_mapper.dart';
import 'package:peixi/features/pipeline/commentary_generator.dart';
import 'package:peixi/features/pipeline/novel_commentary_generator.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/novel_pipeline.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';
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

/// 管线后台运行与进度广播。共享一个 PipelineEngine（引擎按 projectId
/// 防并发），App 启动时自动续跑中间状态的项目（含 ASR 轮询续跑）。
class PipelineController extends Notifier<Map<int, PipelineState>> {
  PipelineEngine? _engine;
  NovelPipelineEngine? _novelEngine;
  Directory? _audioDir;

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
      ffmpeg: FFmpegKitService(),
      asr: AsrClient(ref.read(dioProvider)),
      settings: ref.read(settingsRepoProvider),
      audioDir: await audioDir(),
      localAsr: (audioPath) async {
        final modelDir = await LocalAsrClient.defaultLocalModelDir();
        return LocalAsrClient(modelDir: modelDir).recognize(audioPath);
      },
    );
    // S6/S8/S9 协作器装配（偏离：引擎不直接依赖 LLM，保持可测）
    final llm = ref.read(llmServiceProvider);
    final db = ref.read(databaseProvider);
    final fallback = await ref.read(settingsRepoProvider).loadApiConfig();
    e.attachCollaborators(
      map: (id) => CharacterMapper(db: db, llm: llm).map(id),
      segment: (id) => SceneWriter(db).writeScenes(id),
      commentary: (id) => CommentaryGenerator(
        db: db,
        llm: llm,
        apiConfig: () => llm.config ?? fallback,
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
      extractCast: (id) =>
          NovelCharacterExtractor(db: db, llm: llm).extract(id),
      annotate: (id) => NovelCommentaryGenerator(db: db, llm: llm,
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
    if (videos.isEmpty && novels.isEmpty) return;
    if (videos.isNotEmpty) {
      final e = await engine();
      for (final p in videos) {
        unawaitedGuard(() => e.run(p.id));
      }
    }
    if (novels.isNotEmpty) {
      final e = await novelEngine();
      for (final p in novels) {
        unawaitedGuard(() => e.run(p.id));
      }
    }
  }

  void unawaitedGuard(Future<void> Function() f) {
    f().catchError((Object e) {
      // run 内部已把失败落盘；此处仅防未捕获异步异常
    });
  }

  void _onEvent(PipelineEvent e) {
    final busy = e.status != ProjectStatus.failed &&
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

  /// S1 导入：选文件（Android 复制进应用目录）→ 探测 → 建 project → 开跑。
  Future<ImportResult> importVideo() async {
    final picked = await FilePicker.pickFiles(type: FileType.video);
    if (picked.isEmpty) return const ImportResult();
    final path = picked.single.path;
    if (path == null) return const ImportResult();

    final ffmpeg = FFmpegKitService();
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
    final filename = path.split(Platform.pathSeparator).last;
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

    final e = await engine();
    unawaitedGuard(() => e.run(id));
    return ImportResult(projectId: id);
  }

  /// N1 小说导入：选 txt/epub → 编码检测/切章 → 一个事务入库 → 开跑 N2。
  Future<ImportResult> importNovel() async {
    final picked = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['txt', 'epub']);
    if (picked.isEmpty) return const ImportResult();
    final path = picked.single.path;
    if (path == null) return const ImportResult();

    var sourcePath = path;
    final filename = path.split(Platform.pathSeparator).last;
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

    final e = await novelEngine();
    unawaitedGuard(() => e.run(id));
    return ImportResult(projectId: id);
  }

  Future<void> retry(int projectId) async {
    final e = await engine();
    unawaitedGuard(() => e.retry(projectId));
  }

  Future<void> confirmCalibration(
      int projectId, Map<int, String> names) async {
    final e = await engine();
    unawaitedGuard(() => e.confirmCalibration(projectId, names));
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
      for (final f in [
        File(meta.audioPath(dir.path, projectId)),
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
