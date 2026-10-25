import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/media/drop_classifier.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/features/backup/project_package.dart';
import 'package:peixi/features/calibration/calibration_page.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/pipeline_controller.dart';
import 'package:peixi/features/pipeline/project_meta.dart';
import 'package:peixi/features/pipeline/project_status.dart';
import 'package:peixi/features/player/player_page.dart';
import 'package:peixi/features/processing/processing_page.dart';
import 'package:peixi/features/reader/reader_page.dart';
import 'package:peixi/ui/widgets/app_badge.dart';
import 'package:peixi/ui/widgets/confirm_dialog.dart';
import 'package:peixi/ui/widgets/empty_state.dart';
import 'package:peixi/ui/widgets/loading_view.dart';
import 'package:peixi/ui/widgets/page_header.dart';
import 'package:peixi/providers.dart';

/// 媒体库（设计稿 8.1）：项目卡片网格 + 状态徽章 + 处理进度。
/// 桌面端支持拖拽导入（视频/小说/项目包）与卡片右键菜单；
/// 全局导航由左侧 rail 承担，本页只负责"库"本身。
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  int _dragging = 0;

  /// 拖拽导入是桌面端能力，移动端空态文案不提
  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

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

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging++),
      onDragExited: (_) =>
          setState(() => _dragging = (_dragging - 1).clamp(0, 1 << 30)),
      onDragDone: (details) {
        setState(() => _dragging = 0);
        _onDrop(details);
      },
      child: StreamBuilder<List<Project>>(
        stream: projects,
        builder: (context, snap) {
          final list = snap.data;
          return Stack(
            children: [
              if (list == null)
                const LoadingView()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeader(
                      title: '媒体库',
                      subtitle: _statsText(list),
                      actions: [
                        OutlinedButton.icon(
                          onPressed: () => _importNovels(context, ref),
                          icon: const Icon(Icons.auto_stories_outlined,
                              size: 17),
                          label: const Text('导入小说'),
                        ),
                        FilledButton.icon(
                          onPressed: () => _importVideos(context, ref),
                          icon: const Icon(Icons.video_file_outlined,
                              size: 17),
                          label: const Text('导入视频'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.unarchive_outlined),
                          tooltip: '导入项目包',
                          onPressed: () => _importPackage(context, ref),
                        ),
                      ],
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? EmptyState(
                              icon: Icons.movie_filter_outlined,
                              title: '还没有项目',
                              message: _isDesktop
                                  ? '导入视频或小说，陪析会自动完成字幕提取、转录与解说；'
                                      '也可以把文件直接拖进窗口。'
                                  : '导入视频或小说，陪析会自动完成字幕提取、'
                                      '转录与解说。',
                              actionLabel: '导入视频',
                              onAction: () => _importVideos(context, ref),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  Space.xl, 0, Space.xl, Space.xl),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 340,
                                childAspectRatio: 1.5,
                                mainAxisSpacing: Space.m,
                                crossAxisSpacing: Space.m,
                              ),
                              itemCount: list.length,
                              itemBuilder: (context, i) => _ProjectCard(
                                  project: list[i],
                                  state: pipeline[list[i].id]),
                            ),
                    ),
                  ],
                ),
              if (_dragging > 0) const _DragOverlay(),
            ],
          );
        },
      ),
    );
  }

  String _statsText(List<Project> list) {
    if (list.isEmpty) return '把喜欢的剧集和小说交给陪析，边看边学';
    var ready = 0, processing = 0, waitCal = 0, failed = 0;
    for (final p in list) {
      switch (ProjectStatus.fromDb(p.status)) {
        case ProjectStatus.ready:
          ready++;
        case ProjectStatus.waitCalibration:
          waitCal++;
        case ProjectStatus.failed:
          failed++;
        default:
          processing++;
      }
    }
    return [
      '共 ${list.length} 个项目',
      if (processing > 0) '$processing 处理中',
      if (waitCal > 0) '$waitCal 待校准',
      if (ready > 0) '$ready 可学习',
      if (failed > 0) '$failed 失败',
    ].join(' · ');
  }
}

/// 拖拽悬停遮罩：半透明纸面 + 中央投放说明卡
class _DragOverlay extends StatelessWidget {
  const _DragOverlay();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Container(
        color: scheme.surface.withValues(alpha: 0.78),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.xxl, vertical: Space.xl),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: AppRadius.rLg,
            border: Border.all(color: scheme.primary, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_for_offline_outlined,
                  size: 34, color: scheme.primary),
              const SizedBox(height: Space.m),
              Text('松手导入', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Space.xs),
              Text('视频 / 小说 / 项目包',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
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
    final (badge, tone) = statusBadge(status, project, state);
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final isNovel = project.type == 'novel';
    final typeTint = isNovel ? scheme.tertiaryContainer : scheme.primaryContainer;
    final typeFg = isNovel ? scheme.onTertiaryContainer : scheme.onPrimaryContainer;

    return Card(
      child: InkWell(
        onTap: () => _open(context, ref),
        onLongPress: () => _showActions(context, ref),
        // 桌面端右键 = 长按菜单
        onSecondaryTapUp: (_) => _showActions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: typeTint,
                      borderRadius: AppRadius.rSm,
                    ),
                    child: Icon(
                      isNovel
                          ? Icons.menu_book_outlined
                          : Icons.movie_outlined,
                      size: 19,
                      color: typeFg,
                    ),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        project.title + (_episodeSuffix() ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AppBadge(badge, tone: tone),
                  ),
                ],
              ),
              const Spacer(),
              if (isNovel && status != ProjectStatus.failed) ...[
                // 两遍式管线（§6.3）：导入即可读——处理中保留进度行，
                // 阅读入口与批注徽章常驻（批注随到随显）
                if (state?.busy == true) ...[
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: state?.progress,
                          minHeight: 5,
                        ),
                      ),
                    ),
                    _cancelTap(context, ref),
                  ]),
                  const SizedBox(height: Space.xs),
                ],
                Row(children: [
                  if (_annBadgeText != null) ...[
                    AppBadge(_annBadgeText!, tone: BadgeTone.info),
                    const SizedBox(width: Space.s),
                  ],
                  Expanded(
                    child: Text(
                      '${_readPctPrefix ?? ''}'
                      '${statusLabel(status, isNovel: true)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  _readEntry(context, ref),
                ]),
              ] else if (state?.busy == true) ...[
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: state?.progress,
                        minHeight: 5,
                      ),
                    ),
                  ),
                  _cancelTap(context, ref),
                ]),
              ] else if (status == ProjectStatus.failed) ...[
                Row(children: [
                  Icon(Icons.error_outline,
                      size: 14, color: semantic.error),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      '失败：${stageLabelOf(project.failedStage, isNovel: isNovel)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: semantic.error),
                    ),
                  ),
                  Tooltip(
                    message: '重试该阶段',
                    child: InkWell(
                      borderRadius: AppRadius.rSm,
                      onTap: () => ref
                          .read(pipelineControllerProvider.notifier)
                          .retry(project.id),
                      child: Padding(
                        padding: const EdgeInsets.all(Space.xs),
                        child: Icon(Icons.refresh,
                            size: 16, color: scheme.primary),
                      ),
                    ),
                  ),
                ]),
              ] else
                Text(
                  statusLabel(status, isNovel: isNovel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
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

  /// 批注徽章文案（v5 meta 计数，调度器 denormalized；chapterCount 未回填不显示）
  String? get _annBadgeText {
    if (project.type != 'novel') return null;
    final meta = NovelMeta.fromJson(project.metaJson);
    if (meta.chapterCount <= 0) return null;
    return '批注 ${meta.annotatedChapters}/${meta.chapterCount} 章';
  }

  /// 阅读进度前缀（v6：阅读器持久化 progressPercent，未读过为 null 不显示）
  String? get _readPctPrefix {
    if (project.type != 'novel') return null;
    final p = ProjectMeta.fromJson(project.metaJson).readingProgress;
    final pct = p?.progressPercent;
    if (pct == null || pct <= 0) return null;
    return '已读 ${(pct * 100).round()}% · ';
  }

  /// 「开始阅读」常驻入口（§6.3 导入即可读）：与卡片 onTap 走同一闸门
  Widget _readEntry(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.xs, vertical: Space.xs),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('开始阅读',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: cs.primary)),
          Icon(Icons.chevron_right, size: 14, color: cs.primary),
        ]),
      ),
    );
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
          padding: const EdgeInsets.only(left: Space.s),
          child: Icon(Icons.close,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => libraryEntryGate(project, status)));
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.s, 0, Space.s, Space.s),
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
                  color: context.semanticColors.error),
              title: Text('删除项目',
                  style:
                      TextStyle(color: context.semanticColors.error)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDelete(context, ref);
              },
            ),
          ]),
        ),
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
      String? savedPath;
      if (Platform.isAndroid) {
        // Android 无目录选择器：写入应用文档目录
        final docs = await getApplicationDocumentsDirectory();
        final f = await pkg.buildPackage(project.id,
            outputDir: docs.path, audioDir: audioDir.path);
        savedPath = f.path;
      } else {
        // 流式导出不走"带字节的另存为"对话框（那会整包进内存），
        // 让用户选目标目录，包直接写进去
        final dir = await FilePicker.getDirectoryPath(dialogTitle: '选择导出位置');
        if (dir == null) {
          messenger.showSnackBar(const SnackBar(content: Text('已取消导出')));
          return;
        }
        final f = await pkg.buildPackage(project.id,
            outputDir: dir, audioDir: audioDir.path);
        savedPath = f.path;
      }
      messenger.showSnackBar(SnackBar(content: Text('已导出：$savedPath')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final copyWarning = Platform.isAndroid
        ? '\n导入时复制进应用的源文件副本也将一并删除。'
        : '';
    final ok = await ConfirmDialog.show(
      context,
      title: '删除「${project.title}」？',
      message: '解说、卡片、问答记录将一并删除，且不可恢复。$copyWarning',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(pipelineControllerProvider.notifier)
        .deleteProject(project.id);
  }
}

/// 卡片入口闸门（设计文档 §6.3/§9）：小说非 failed 导入即可读（两遍式批注
/// 随到随显，不阻塞等 ready）；视频 READY 才进播放器；其余一律进处理页。
/// 待校准/媒体缺失两个前置分支在 [_ProjectCard._open] 里先行处理。
Widget libraryEntryGate(Project project, ProjectStatus status) {
  if (project.type == 'novel' && status != ProjectStatus.failed) {
    return ReaderPage(projectId: project.id);
  }
  if (status == ProjectStatus.ready) {
    return PlayerPage(projectId: project.id);
  }
  return ProcessingPage(projectId: project.id);
}

/// 状态徽章文案与语义色调（色值统一走 AppBadge/DESIGN.md token）
(String, BadgeTone) statusBadge(
    ProjectStatus status, Project project, PipelineState? state) {
  switch (status) {
    case ProjectStatus.ready:
      return project.type == 'novel'
          ? ('可阅读', BadgeTone.success)
          : ('可观看', BadgeTone.success);
    case ProjectStatus.waitCalibration:
      return ('待校准', BadgeTone.warning);
    case ProjectStatus.failed:
      return ('处理失败', BadgeTone.error);
    default:
      return ('处理中', BadgeTone.info);
  }
}

String statusLabel(ProjectStatus status, {bool isNovel = false}) => switch (status) {
      ProjectStatus.imported =>
        isNovel ? '处理中 · 可阅读' : '已导入 · 准备处理',
      ProjectStatus.audioReady => '音频已就绪',
      ProjectStatus.uploaded => '已上传 · 识别排队中',
      ProjectStatus.asrDone => '转录完成 · 角色映射中',
      ProjectStatus.mapped =>
        isNovel ? '地图完成 · 批注进行中 · 可阅读' : '映射完成',
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
        // 两遍式管线新口径：map/digest/annotate（§8 错误表）。
        // annotate 阶段与处理页统一叫「批注」（不叫"批注生成"）
        'map' => isNovel ? '地图' : '角色映射',
        'digest' => '摘要快照',
        'annotate' => '批注',
        'segment' => '场景切分',
        'commentary' => isNovel ? '批注' : '解说生成',
        'finalize' => '收尾',
        _ => failedStage,
      };
