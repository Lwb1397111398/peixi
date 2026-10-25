import 'package:drift/drift.dart' show ArithmeticAggregates;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/features/pipeline/pipeline_controller.dart';
import 'package:peixi/features/pipeline/project_meta.dart';
import 'package:peixi/features/pipeline/project_status.dart';
import 'package:peixi/features/player/player_page.dart';
import 'package:peixi/features/reader/reader_page.dart';
import 'package:peixi/ui/widgets/app_badge.dart';
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
    ('asr', '语音识别'),
    ('map', '角色映射'),
    ('calibration', '人工校准'),
    ('segment', '场景切分'),
    ('commentary', '逐场景解说生成'),
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
              if (!isNovel && state?.detail != null) ...[
                const SizedBox(height: Space.xs),
                Text(state!.detail!, style: tt.bodySmall),
              ],
              const SizedBox(height: Space.xl),
              if (isNovel)
                // 两遍式管线（§9）：小说泳道以 DB 为真相源，事件流只触发重查
                _NovelSwimlanes(project: p)
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Space.xl, Space.l, Space.xl, Space.xs),
                    child: Column(
                      children: [
                        for (var i = 0; i < _videoStages.length; i++)
                          _stageRow(
                            context,
                            _videoStages[i].$1,
                            _videoStages[i].$2,
                            status,
                            state,
                            failedStage,
                            isLast: i == _videoStages.length - 1,
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

  /// 小说失败阶段为两遍式新口径 map/digest/annotate（§8 错误表）；
  /// 旧存量的 commentary/finalize 走通用 stageLabel 兜底。
  String _failedStageLabel(Project p) {
    final stage = p.failedStage ?? '';
    if (p.type == 'novel') {
      return switch (stage) {
        'map' => '地图',
        'digest' => '摘要快照',
        'annotate' => '批注',
        _ => stageLabel(stage),
      };
    }
    return stageLabel(stage);
  }

  /// 竖向时间线一行：左侧节点+连线，右侧标签与状态提示（仅视频分支使用）
  Widget _stageRow(
      BuildContext context,
      String key,
      String label,
      ProjectStatus status,
      PipelineState? state,
      String? failedStage,
      {required bool isLast}) {
    final semantic = context.semanticColors;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final reached = _stageReached(key, status, failedStage);
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
    final lineColor = reached ? semantic.success : cs.outlineVariant;
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
  bool _stageReached(String stage, ProjectStatus status, String? failedStage) {
    // uploaded 是云端识别时代的残留状态，仅保留排序位兼容旧数据展示
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
      'asr' => ProjectStatus.asrDone,
      'map' => ProjectStatus.mapped,
      'calibration' => ProjectStatus.calibrated,
      'segment' => ProjectStatus.segmented,
      'commentary' => ProjectStatus.commentaryDone,
      'finalize' => ProjectStatus.ready,
      _ => ProjectStatus.ready,
    };
    final cur = status == ProjectStatus.failed
        ? entryStatusOfStage(failedStage ?? '')
        : status;
    return order.indexOf(stageStatus) <= order.indexOf(cur);
  }
}

/// 小说双泳道进度卡（设计文档 §9；DB 为真相源，管线事件流只当刷新信号）：
/// 地图/批注两泳道按章实时聚合、领先阅读徽章、token 花费、降批/取消提示、
/// 单章重批入口。重试按钮（FAILED）仍由页面级既有路径承担。
class _NovelSwimlanes extends ConsumerStatefulWidget {
  const _NovelSwimlanes({required this.project});
  final Project project;

  @override
  ConsumerState<_NovelSwimlanes> createState() => _NovelSwimlanesState();
}

class _NovelSwimlanesState extends ConsumerState<_NovelSwimlanes> {
  final _chapterCtrl = TextEditingController();
  bool _loading = true;
  bool _reannotating = false;
  int _total = 0;
  int _mapDone = 0;
  int _annotDone = 0;
  int _tokens = 0;
  int _readingIdx = 0;

  /// 重载序号：每次 _reload 自增，await 返回后不一致说明已有更新的一次
  /// 重载在途（事件流/重批完成都会触发），旧快照直接丢弃不回写。
  int _reloadSeq = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _chapterCtrl.dispose();
    super.dispose();
  }

  /// 页面加载与每次 controller state 变化时重查（事件只当刷新信号，
  /// 显示数值一律以 DB 复算为准，不信任事件里的文案/计数）。
  /// 并发守卫：每个 await 后校验 seq 与 mounted，被更新的重载取代或页面
  /// 已销毁时立即返回，避免 initState 的 fire-and-forget 在 dispose 后空跑、
  /// 也避免慢查询的旧快照覆盖新数据。
  Future<void> _reload() async {
    final seq = ++_reloadSeq;
    final db = ref.read(databaseProvider);
    final pid = widget.project.id;
    final chapters = await (db.select(db.chapters)
          ..where((t) => t.projectId.equals(pid)))
        .get();
    if (seq != _reloadSeq || !mounted) return;
    final p = await (db.select(db.projects)..where((t) => t.id.equals(pid)))
        .getSingleOrNull();
    if (seq != _reloadSeq || !mounted) return;
    final promptSum = db.llmLogs.promptTokens.sum();
    final completionSum = db.llmLogs.completionTokens.sum();
    final tokenRow = await (db.selectOnly(db.llmLogs)
          ..addColumns([promptSum, completionSum])
          ..where(db.llmLogs.projectId.equals(pid)))
        .getSingle();
    if (seq != _reloadSeq || !mounted) return;
    setState(() {
      _total = chapters.length;
      _mapDone = chapters.where((c) => c.mapDone).length;
      _annotDone = chapters.where((c) => c.annotDone).length;
      _tokens =
          (tokenRow.read(promptSum) ?? 0) + (tokenRow.read(completionSum) ?? 0);
      _readingIdx = p == null
          ? 0
          : (ProjectMeta.fromJson(p.metaJson).readingProgress?.chapterIdx ?? 0);
      _loading = false;
    });
  }

  Future<void> _reannotate(int chapterIdx) async {
    // 重批期间 controller 不发进度事件、busy 恒 false：不在这里置位禁用，
    // 双击会穿透到 controller 并发重批同一章（双倍 token）。
    if (_reannotating) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reannotating = true);
    try {
      await ref
          .read(pipelineControllerProvider.notifier)
          .reannotateChapter(widget.project.id, chapterIdx);
      await _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('重批失败：$e')));
    } finally {
      if (mounted) setState(() => _reannotating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 事件流只触发重查（防抖不必要：重查是本地 DB 读，代价远低于 LLM 调用）
    ref.listen(pipelineControllerProvider, (prev, next) {
      if (prev?[widget.project.id] != next[widget.project.id]) _reload();
    });
    final state = ref.watch(pipelineControllerProvider)[widget.project.id];
    final busy = state?.busy ?? false;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lead = _annotDone - _readingIdx;
    // 章号输入即时校验：reannotateChapter 的 n 是章号（chapters.idx，0 起，
    // 导入器按 0..total-1 连续编号），越界章 controller 侧会抛"章不存在"，
    // 这里直接禁用按钮给出前置反馈。digitsOnly 挡非数字，负号进不来。
    final chapterNum = int.tryParse(_chapterCtrl.text.trim());

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, Space.l, Space.xl, Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Space.l),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              _swimlane(context, '地图', _mapDone, _total),
              const SizedBox(height: Space.m),
              _swimlane(context, '批注', _annotDone, _total),
              const SizedBox(height: Space.m),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (lead > 0) AppBadge('领先阅读 $lead 章', tone: BadgeTone.success),
                  Text('本书已耗 token $_tokens',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ],
            if (state?.detail != null) ...[
              const SizedBox(height: Space.xs),
              Text(state!.detail!,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: Space.l),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _chapterCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '章号（0 起）',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Space.s),
              FilledButton(
                // 调度器运行中/重批进行中/章号非法（空、非数字、越界
                // >=_total）都禁用（controller 侧同样有防线）
                onPressed:
                    busy ||
                        _reannotating ||
                        chapterNum == null ||
                        chapterNum >= _total
                    ? null
                    : () => _reannotate(chapterNum),
                child: const Text('重新批注此章'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /// 泳道一行：标签 + 完成度 + 进度条（沿用视频时间线的视觉密度）
  Widget _swimlane(BuildContext context, String label, int done, int total) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('$label $done/$total 章', style: tt.titleSmall),
          const SizedBox(width: Space.s),
          if (done >= total && total > 0)
            Icon(Icons.check_circle, size: 15, color: cs.primary),
        ]),
        const SizedBox(height: Space.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? null : done / total,
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
