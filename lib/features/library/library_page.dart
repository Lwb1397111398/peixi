import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/pipeline/pipeline_controller.dart';
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
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onPressed: () async {
              final res = await ref
                  .read(pipelineControllerProvider.notifier)
                  .importVideo();
              if (!context.mounted) return;
              if (res.error != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(res.error!)));
              }
            },
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'import_novel',
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('导入小说'),
            onPressed: () async {
              final res = await ref
                  .read(pipelineControllerProvider.notifier)
                  .importNovel();
              if (!context.mounted) return;
              if (res.error != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(res.error!)));
              } else if (res.projectId != null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('小说已导入，正在提取人物与生成批注…')));
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Project>>(
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
                  const Text('点右下角导入一集视频或一本 TXT 小说'),
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
        onLongPress: () => _confirmDelete(context, ref),
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
                LinearProgressIndicator(
                    value: state!.progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3))
              else if (state?.busy == true)
                const LinearProgressIndicator(minHeight: 6)
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

  Future<void> _open(BuildContext context, WidgetRef ref) async {
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

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${project.title}」？'),
        content: const Text('解说、卡片、问答记录将一并删除，且不可恢复。'),
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
