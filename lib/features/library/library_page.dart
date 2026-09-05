import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/media/drop_classifier.dart';
import 'package:peixi/features/backup/project_package.dart';
import 'package:peixi/features/pipeline/pipeline_controller.dart';
import 'package:peixi/features/pipeline/project_meta.dart';
import 'package:peixi/features/pipeline/project_status.dart';
import 'package:peixi/features/cards/cards_page.dart';
import 'package:peixi/features/calibration/calibration_page.dart';
import 'package:peixi/features/player/player_page.dart';
import 'package:peixi/features/processing/processing_page.dart';
import 'package:peixi/features/reader/reader_page.dart';
import 'package:peixi/features/review/review_page.dart';
import 'package:peixi/features/settings/settings_page.dart';
import 'package:peixi/providers.dart';

/// 媒体库（设计稿 8.1）：项目卡片网格 + 状态徽章 + 处理进度。
/// 桌面端支持拖拽导入（视频/小说/项目包）与卡片右键菜单。
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  int _dragging = 0;

  Future<void> _importPackage(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['zip', 'peixi']);
    if (picked.isEmpty) return;
    final ok = <String>[];
    final errors = <String>[];
    for (final file in picked) {
      try {
        final audioDir = await ref
            .read(pipelineControllerProvider.notifier)
            .audioDir();
        final newId = await ProjectPackage(ref.read(databaseProvider))
            .importProject(File(file.path!), audioDir: audioDir.path);
        ok.add('项目 $newId');
      } catch (e) {
        errors.add('${file.name}：$e');
      }
    }
    final msg = [
      if (ok.isNotEmpty) '已导入 ${ok.length} 个项目包',
      ...errors,
    ].join('\n');
    if (msg.isNotEmpty) messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _importVideos(BuildContext context, WidgetRef ref) async {
    final res =
        await ref.read(pipelineControllerProvider.notifier).importVideos();
    if (!context.mounted) return;
    await _handleBatchResult(context, res,
        singleDetail: '视频已导入，开始处理…',
        manyDetail: (n) => '已开始处理 $n 集视频，逐个排队处理…');
  }

  Future<void> _importNovels(BuildContext context, WidgetRef ref) async {
    final res =
        await ref.read(pipelineControllerProvider.notifier).importNovels();
    if (!context.mounted) return;
    await _handleBatchResult(context, res,
        singleDetail: '小说已导入，正在提取人物与生成批注…',
        manyDetail: (n) => '已开始处理 $n 本小说，逐个排队处理…');
  }

  /// 批量导入结果统一呈现：配置错误提示 / 失败清单弹窗 /
  /// 单个成功进处理页 / 多个成功 SnackBar 汇总。
  Future<void> _handleBatchResult(
      BuildContext context, ImportBatchResult res,
      {required String singleDetail,
      required String Function(int) manyDetail}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (res.configError != null) {
      messenger.showSnackBar(SnackBar(content: Text(res.configError!)));
      return;
    }
    if (res.failures.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('部分文件导入失败'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in res.failures)
                  ListTile(
                      dense: true,
                      title: Text(f.file,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(f.error)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))
          ],
        ),
      );
      if (!context.mounted) return;
    }
    if (res.okIds.isEmpty) return;
    if (res.okIds.length == 1) {
      messenger.showSnackBar(SnackBar(content: Text(singleDetail)));
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ProcessingPage(projectId: res.okIds.first)));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(manyDetail(res.okIds.length))));
    }
  }

  /// 拖拽导入：按扩展名分流到视频/小说/项目包，未知类型提示。
  Future<void> _onDrop(DropDoneDetails details) async {
    final videos = <String>[];
    final novels = <String>[];
    final packages = <String>[];
    final unknown = <String>[];
    for (final f in details.files) {
      switch (classifyDrop(f.path)) {
        case DropKind.video:
          videos.add(f.path);
        case DropKind.novel:
          novels.add(f.path);
        case DropKind.package:
          packages.add(f.path);
        case DropKind.unknown:
          unknown.add(f.name);
      }
    }
    if (unknown.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('无法识别的文件类型：${unknown.take(5).join('、')}'
              '${unknown.length > 5 ? ' 等' : ''}')));
    }

    final controller = ref.read(pipelineControllerProvider.notifier);
    final merged = ImportBatchResult();
    if (videos.isNotEmpty) {
      final r = await controller.importVideos(paths: videos);
      merged
        ..configError ??= r.configError
        ..okIds.addAll(r.okIds)
        ..failures.addAll(r.failures);
    }
    if (novels.isNotEmpty) {
      final r = await controller.importNovels(paths: novels);
      merged
        ..configError ??= r.configError
        ..okIds.addAll(r.okIds)
        ..failures.addAll(r.failures);
    }
    final pkgMsgs = <String>[];
    for (final path in packages) {
      try {
        final audioDir = await controller.audioDir();
        final newId = await ProjectPackage(ref.read(databaseProvider))
            .importProject(File(path), audioDir: audioDir.path);
        pkgMsgs.add('项目包已导入（项目 $newId）');
      } catch (e) {
        merged.failures.add(ImportFailure(
            path.split(RegExp(r'[\\/]')).last, '项目包导入失败：$e'));
      }
    }
    if (!mounted) return;
    await _handleBatchResult(context, merged,
        singleDetail: '已导入，开始处理…',
        manyDetail: (n) => '已开始处理 $n 个项目，逐个排队处理…');
    if (pkgMsgs.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pkgMsgs.join('\n'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final projects = db.select(db.projects).watch();
    final pipeline = ref.watch(pipelineControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('陪析 · 媒体库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.school_outlined),
            tooltip: '卡片集',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CardsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: '复盘',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReviewPage())),
          ),
          IconButton(
            icon: const Icon(Icons.unarchive_outlined),
            tooltip: '导入项目包',
            onPressed: () => _importPackage(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'import_video',
            icon: const Icon(Icons.video_file_outlined),
            label: const Text('导入视频'),
            onPressed: () => _importVideos(context, ref),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'import_novel',
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('导入小说'),
            onPressed: () => _importNovels(context, ref),
          ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dragging++),
        onDragExited: (_) =>
            setState(() => _dragging = (_dragging - 1).clamp(0, 1 << 30)),
        onDragDone: (details) {
          setState(() => _dragging = 0);
          _onDrop(details);
        },
        child: Stack(children: [
          StreamBuilder<List<Project>>(
            stream: projects,
            builder: (context, snap) {
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.movie_filter_outlined,
                          size: 72, color: Colors.grey.shade600),
                      const SizedBox(height: 12),
                      Text('还没有项目',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text('点右下角导入，或直接把视频/小说文件拖进窗口'),
                    ],
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  childAspectRatio: 1.6,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) =>
                    _ProjectCard(project: list[i], state: pipeline[list[i].id]),
              );
            },
          ),
          if (_dragging > 0)
            Positioned.fill(
              child: Container(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
                alignment: Alignment.center,
                child: Text('松手导入：视频 / 小说 / 项目包',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project, this.state});
  final Project project;
  final PipelineState? state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ProjectStatus.fromDb(project.status);
    final (badge, color) = statusBadge(status, project, state);

      return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, ref),
        onLongPress: () => _showActions(context, ref),
        // 桌面端右键 = 长按菜单
        onSecondaryTapUp: (_) => _showActions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                    project.type == 'video'
                        ? Icons.movie_outlined
                        : Icons.menu_book_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    project.title +
                        (_episodeSuffix() ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ]),
              const Spacer(),
              Text(status == ProjectStatus.failed
                  ? '失败：${stageLabelOf(project.failedStage, isNovel: project.type == 'novel')}'
                  : statusLabel(status, isNovel: project.type == 'novel'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade400)),
              const SizedBox(height: 6),
              if (state?.busy == true && state?.progress != null)
                Row(children: [
                  Expanded(
                    child: LinearProgressIndicator(
                        value: state!.progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  _cancelTap(context, ref),
                ])
              else if (state?.busy == true)
                Row(children: [
                  const Expanded(child: LinearProgressIndicator(minHeight: 6)),
                  _cancelTap(context, ref),
                ])
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600)),
                ),
              if (status == ProjectStatus.failed)
                TextButton.icon(
                  onPressed: () => ref
                      .read(pipelineControllerProvider.notifier)
                      .retry(project.id),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重试该阶段'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _episodeSuffix() {
    final m = project.metaJson;
    if (m == null) return null;
    final ep = RegExp(r'"episode":(\d+)').firstMatch(m)?.group(1);
    return ep == null ? null : ' · 第$ep集';
  }

  /// 卡片右上角紧凑取消入口（与进度条同排，避免撑破卡片高度）
  Widget _cancelTap(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: '取消处理',
      child: GestureDetector(
        onTap: () => ref
            .read(pipelineControllerProvider.notifier)
            .cancel(project.id),
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final meta = ProjectMeta.fromJson(project.metaJson);
    if (project.type == 'video' && meta.mediaMissing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('项目包迁移项目：视频文件缺失，解说/问答数据完好；'
              '重播需重新导入同一视频文件')));
      return;
    }
    final status = ProjectStatus.fromDb(project.status);
    if (status == ProjectStatus.waitCalibration) {
      final page = await buildCalibrationPage(
        projectId: project.id,
        ref: ref,
        onConfirm: (names) => ref
            .read(pipelineControllerProvider.notifier)
            .confirmCalibration(project.id, names),
      );
      if (!context.mounted) return;
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => page));
      return;
    }
    if (!context.mounted) return;
    if (status == ProjectStatus.ready) {
      // 小说进阅读器，视频进播放器（N4/设计稿 8.4）
      final page = project.type == 'novel'
          ? ReaderPage(projectId: project.id)
          : PlayerPage(projectId: project.id);
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => page));
      return;
    }
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProcessingPage(projectId: project.id)));
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('导出项目包'),
            subtitle: const Text('解说/卡片/问答/小说正文打包为 zip'),
            onTap: () {
              Navigator.pop(sheetCtx);
              _exportPackage(context, ref);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text('删除项目',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(sheetCtx);
              _confirmDelete(context, ref);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _exportPackage(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pkg = ProjectPackage(ref.read(databaseProvider));
      final audioDir = await ref
          .read(pipelineControllerProvider.notifier)
          .audioDir();
      final built =
          await pkg.buildPackage(project.id, audioDir: audioDir.path);
      String? savedPath;
      if (Platform.isAndroid) {
        // Android 无桌面式"另存为"：写入应用文档目录
        final docs = await getApplicationDocumentsDirectory();
        final f = File('${docs.path}/${built.fileName}');
        await f.writeAsBytes(built.bytes);
        savedPath = f.path;
      } else {
        final path = await FilePicker.saveFile(
            fileName: built.fileName,
            bytes: Uint8List.fromList(built.bytes));
        savedPath = path?.toFilePath(windows: Platform.isWindows);
      }
      messenger.showSnackBar(SnackBar(
          content: Text(savedPath == null ? '已取消导出' : '已导出：$savedPath')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final copyWarning = Platform.isAndroid
        ? '\n导入时复制进应用的源文件副本也将一并删除。'
        : '';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${project.title}」？'),
        content: Text('解说、卡片、问答记录将一并删除，且不可恢复。$copyWarning'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(pipelineControllerProvider.notifier)
                  .deleteProject(project.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 状态徽章文案与配色。
(String, Color) statusBadge(
    ProjectStatus status, Project project, PipelineState? state) {
  switch (status) {
    case ProjectStatus.ready:
      return project.type == 'novel' ? ('可阅读', Colors.green) : ('可观看', Colors.green);
    case ProjectStatus.waitCalibration:
      return ('待校准', Colors.orange);
    case ProjectStatus.failed:
      return ('处理失败', Colors.red);
    default:
      return ('处理中', Colors.blue);
  }
}

String statusLabel(ProjectStatus status, {bool isNovel = false}) => switch (status) {
      ProjectStatus.imported => isNovel ? '已导入 · 提取人物中' : '已导入 · 准备处理',
      ProjectStatus.audioReady => '音频已就绪',
      ProjectStatus.uploaded => '已上传 · 识别排队中',
      ProjectStatus.asrDone => '转录完成 · 角色映射中',
      ProjectStatus.mapped => isNovel ? '人物提取完成 · 生成批注中' : '映射完成',
      ProjectStatus.calibrated => '校准完成 · 切分场景中',
      ProjectStatus.segmented => '场景已切分 · 生成解说中',
      ProjectStatus.commentaryDone => isNovel ? '批注完成 · 收尾中' : '解说完成 · 收尾中',
      _ => '',
    };

String stageLabelOf(String? failedStage, {bool isNovel = false}) =>
    failedStage == null ? '未知阶段' : switch (failedStage) {
        'subtitle' => '字幕提取',
        'audio' => '音频抽取',
        'upload' => '上传中转',
        'asr' => '语音识别',
        'map' => isNovel ? '人物提取' : '角色映射',
        'segment' => '场景切分',
        'commentary' => isNovel ? '批注生成' : '解说生成',
        'finalize' => '收尾',
        _ => failedStage,
      };
