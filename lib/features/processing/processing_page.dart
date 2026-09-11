import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/features/pipeline/pipeline_controller.dart';
import 'package:peixi/features/pipeline/project_status.dart';
import 'package:peixi/features/player/player_page.dart';
import 'package:peixi/features/reader/reader_page.dart';
import 'package:peixi/ui/widgets/loading_view.dart';
import 'package:peixi/providers.dart';

/// 处理详情页：阶段竖向时间线 + 进度 + 失败重试。
/// 处理期间保持屏幕唤醒（设计稿九.4）由 PipelineController 统一管理。
class ProcessingPage extends ConsumerWidget {
  const ProcessingPage({super.key, required this.projectId});
  final int projectId;

  static const _videoStages = [
    ('subtitle', '字幕提取'),
    ('audio', '音频抽取'),
    ('upload', '上传 OSS 中转'),
    ('asr', '语音识别'),
    ('map', '角色映射'),
    ('calibration', '人工校准'),
    ('segment', '场景切分'),
    ('commentary', '逐场景解说生成'),
    ('finalize', '收尾'),
  ];

  static const _novelStages = [
    ('map', '人物提取与章节摘要'),
    ('commentary', '逐段批注生成'),
    ('finalize', '收尾'),
  ];

  /// 非失败、非就绪、非校准闸门的中间态：可"继续处理"（含取消后恢复）
  static const _resumable = {
    ProjectStatus.imported,
    ProjectStatus.audioReady,
    ProjectStatus.uploaded,
    ProjectStatus.asrDone,
    ProjectStatus.mapped,
    ProjectStatus.calibrated,
    ProjectStatus.segmented,
    ProjectStatus.commentaryDone,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final projectFuture =
        (db.select(db.projects)..where((t) => t.id.equals(projectId)))
            .getSingle();
    final state = ref
        .watch(pipelineControllerProvider.select((m) => m[projectId]));

    return Scaffold(
      appBar: AppBar(title: const Text('处理进度')),
      body: FutureBuilder<Project>(
        future: projectFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const LoadingView();
          }
          final p = snap.data!;
          final status = ProjectStatus.fromDb(p.status);
          final failedStage = p.failedStage;
          final busy = state?.busy ?? false;
          final isNovel = p.type == 'novel';
          final stages = isNovel ? _novelStages : _videoStages;
          final semantic = context.semanticColors;
          final tt = Theme.of(context).textTheme;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                Space.xl, Space.l, Space.xl, Space.xxl),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: tt.headlineSmall),
                        const SizedBox(height: Space.xs),
                        Text(_subtitleText(p), style: tt.bodySmall),
                      ],
                    ),
                  ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                ],
              ),
              if (busy) ...[
                const SizedBox(height: Space.l),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Space.l, vertical: Space.m),
                  decoration: BoxDecoration(
                      color: semantic.infoBg,
                      borderRadius: AppRadius.rMd),
                  child: Row(children: [
                    Icon(Icons.bolt, color: semantic.info, size: 17),
                    const SizedBox(width: Space.s),
                    Expanded(
                        child: Text('处理中请勿关闭应用（屏幕将保持唤醒）',
                            style: tt.bodyMedium)),
                  ]),
                ),
                const SizedBox(height: Space.s),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 17),
                    label: const Text('取消处理'),
                    onPressed: () => ref
                        .read(pipelineControllerProvider.notifier)
                        .cancel(projectId),
                  ),
                ),
              ],
              if (state?.progress != null) ...[
                const SizedBox(height: Space.l),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: state!.progress, minHeight: 5),
                ),
              ],
              if (state?.detail != null) ...[
                const SizedBox(height: Space.xs),
                Text(state!.detail!, style: tt.bodySmall),
              ],
              const SizedBox(height: Space.xl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Space.xl, Space.l, Space.xl, Space.xs),
                  child: Column(
                    children: [
                      for (var i = 0; i < stages.length; i++)
                        _stageRow(
                          context,
                          stages[i].$1,
                          stages[i].$2,
                          status,
                          state,
                          failedStage,
                          isNovel,
                          isLast: i == stages.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
              if (status == ProjectStatus.failed)
                Padding(
                  padding: const EdgeInsets.only(top: Space.l),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.refresh, size: 17),
                    label: Text('重试「${_failedStageLabel(p)}」'),
                    onPressed: () => ref
                        .read(pipelineControllerProvider.notifier)
                        .retry(projectId),
                  ),
                ),
              if (status == ProjectStatus.ready && !busy)
                Padding(
                  padding: const EdgeInsets.only(top: Space.l),
                  child: FilledButton.icon(
                    icon: Icon(isNovel
                        ? Icons.auto_stories_outlined
                        : Icons.play_circle_fill_outlined),
                    label: Text(isNovel ? '开始阅读' : '开始观看'),
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => isNovel
                            ? ReaderPage(projectId: projectId)
                            : PlayerPage(projectId: projectId),
                      ),
                    ),
                  ),
                )
              else if (!busy && _resumable.contains(status))
                Padding(
                  padding: const EdgeInsets.only(top: Space.l),
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.play_arrow_outlined, size: 18),
                    label: const Text('继续处理'),
                    onPressed: () => ref
                        .read(pipelineControllerProvider.notifier)
                        .retry(projectId),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _subtitleText(Project p) => p.sourcePath;

  String _failedStageLabel(Project p) {
    final stage = p.failedStage ?? '';
    if (p.type == 'novel') {
      return switch (stage) {
        'map' => '人物提取',
        'commentary' => '批注生成',
        _ => stageLabel(stage),
      };
    }
    return stageLabel(stage);
  }

  /// 竖向时间线一行：左侧节点+连线，右侧标签与状态提示
  Widget _stageRow(
      BuildContext context,
      String key,
      String label,
      ProjectStatus status,
      PipelineState? state,
      String? failedStage,
      bool isNovel,
      {required bool isLast}) {
    final semantic = context.semanticColors;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final reached =
        _stageReached(key, status, failedStage, isNovel: isNovel);
    final active = state?.busy == true && state?.stage == key;
    final failed = failedStage == key && status == ProjectStatus.failed;
    final waitingGate =
        key == 'calibration' && status == ProjectStatus.waitCalibration;

    // 节点与连线颜色：已完成/失败/激活/闸门/待处理
    final nodeColor = failed
        ? semantic.error
        : waitingGate
            ? semantic.warning
            : active
                ? cs.primary
                : reached
                    ? semantic.success
                    : cs.outlineVariant;
    final lineColor = reached && !failed ? semantic.success : cs.outlineVariant;
    final labelColor = failed
        ? semantic.error
        : active
            ? cs.onSurface
            : reached
                ? cs.onSurface
                : cs.onSurfaceVariant;

    Widget node;
    if (failed) {
      node = Icon(Icons.error_outline, size: 20, color: nodeColor);
    } else if (waitingGate) {
      node = Icon(Icons.pan_tool_alt_outlined, size: 19, color: nodeColor);
    } else if (reached) {
      node = Icon(Icons.check_circle, size: 19, color: nodeColor);
    } else if (active) {
      node = Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerLowest,
          border: Border.all(color: nodeColor, width: 2.5),
        ),
      );
    } else {
      node = Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: nodeColor, width: 1.8),
        ),
      );
    }

    final hint = failed
        ? '处理失败，可重试该阶段'
        : waitingGate
            ? '请回到媒体库进入校准'
            : active && state?.progress != null
                ? '${(state!.progress! * 100).toStringAsFixed(0)}%'
                : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 20, child: Center(child: node)),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: lineColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(label,
                        style: tt.titleSmall!.copyWith(color: labelColor)),
                  ),
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(hint,
                          style: tt.bodySmall!.copyWith(
                              color: failed
                                  ? semantic.error
                                  : waitingGate
                                      ? semantic.warning
                                      : cs.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 该阶段是否已完成（按状态机位置推断）。
  bool _stageReached(String stage, ProjectStatus status, String? failedStage,
      {bool isNovel = false}) {
    const order = [
      ProjectStatus.imported,
      ProjectStatus.audioReady,
      ProjectStatus.uploaded,
      ProjectStatus.asrDone,
      ProjectStatus.mapped,
      ProjectStatus.waitCalibration,
      ProjectStatus.calibrated,
      ProjectStatus.segmented,
      ProjectStatus.commentaryDone,
      ProjectStatus.ready,
    ];
    final stageStatus = switch (stage) {
      'subtitle' || 'audio' => ProjectStatus.audioReady,
      'upload' => ProjectStatus.uploaded,
      'asr' => ProjectStatus.asrDone,
      // 小说 N2 完成即 MAPPED（视频的 map 完成同样落在 MAPPED）
      'map' => ProjectStatus.mapped,
      'calibration' => ProjectStatus.calibrated,
      'segment' => ProjectStatus.segmented,
      'commentary' => ProjectStatus.commentaryDone,
      'finalize' => ProjectStatus.ready,
      _ => ProjectStatus.ready,
    };
    final cur = status == ProjectStatus.failed
        ? (isNovel
            ? novelEntryStatusOfStage(failedStage ?? '')
            : entryStatusOfStage(failedStage ?? ''))
        : status;
    return order.indexOf(stageStatus) <= order.indexOf(cur);
  }
}
