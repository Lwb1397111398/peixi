import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/pipeline/pipeline_controller.dart';
import 'package:peixi/features/pipeline/project_status.dart';
import 'package:peixi/features/player/player_page.dart';
import 'package:peixi/features/reader/reader_page.dart';
import 'package:peixi/providers.dart';

/// 处理详情页：阶段时间线 + 进度 + 失败重试。
/// 处理期间保持屏幕唤醒（设计稿九.4）由 PipelineController 统一管理。
class ProcessingPage extends ConsumerWidget {
  const ProcessingPage({super.key, required this.projectId});
  final int projectId;

  static const _videoStages = [
    ('subtitle', '字幕提取（可选加速）'),
    ('audio', '音频抽取 16kHz 单声道'),
    ('upload', '上传 OSS 中转'),
    ('asr', '语音识别 paraformer-v2'),
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
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data!;
          final status = ProjectStatus.fromDb(p.status);
          final failedStage = p.failedStage;
          final busy = state?.busy ?? false;
          final isNovel = p.type == 'novel';
          final stages = isNovel ? _novelStages : _videoStages;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(p.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(_subtitleText(p),
                  style: Theme.of(context).textTheme.bodySmall),
              if (busy) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.bolt, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('处理中请勿关闭应用（屏幕将保持唤醒）',
                            style: TextStyle(fontSize: 13))),
                  ]),
                ),
              ],
              if (state?.progress != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: state!.progress, minHeight: 8),
              ],
              if (state?.detail != null) ...[
                const SizedBox(height: 8),
                Text(state!.detail!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade400)),
              ],
              const SizedBox(height: 16),
              ...stages.map((s) => _stageTile(s.$1, s.$2, status, state,
                  failedStage, isNovel)),
              if (status == ProjectStatus.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text('重试「${_failedStageLabel(p)}」'),
                    onPressed: () => ref
                        .read(pipelineControllerProvider.notifier)
                        .retry(projectId),
                  ),
                ),
              if (status == ProjectStatus.ready && !busy)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
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

  Widget _stageTile(String key, String label, ProjectStatus status,
      PipelineState? state, String? failedStage,
      [bool isNovel = false]) {
    final reached =
        _stageReached(key, status, failedStage, isNovel: isNovel);
    final active = state?.busy == true && state?.stage == key;
    final failed = failedStage == key && status == ProjectStatus.failed;
    final waitingGate =
        key == 'calibration' && status == ProjectStatus.waitCalibration;

    IconData icon;
    Color color;
    if (failed) {
      icon = Icons.error_outline;
      color = Colors.red;
    } else if (waitingGate) {
      icon = Icons.pan_tool_alt_outlined;
      color = Colors.orange;
    } else if (active) {
      icon = Icons.sync;
      color = Colors.blue;
    } else if (reached) {
      icon = Icons.check_circle_outline;
      color = Colors.green;
    } else {
      icon = Icons.circle_outlined;
      color = Colors.grey;
    }

    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(label),
      subtitle: active && state?.progress != null
          ? Text('${(state!.progress! * 100).toStringAsFixed(0)}%')
          : (waitingGate ? const Text('请在项目卡片上进入校准') : null),
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
