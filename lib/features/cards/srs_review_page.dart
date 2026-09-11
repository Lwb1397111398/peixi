import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/features/cards/srs_scheduler.dart';
import 'package:peixi/ui/widgets/loading_view.dart';
import 'package:peixi/providers.dart';

/// SRS 复习会话：到期卡 + 新卡依次出现，翻面后四键评分。
/// projectId 为 null 时复习全部项目。
class SrsReviewPage extends ConsumerStatefulWidget {
  const SrsReviewPage({super.key, this.projectId});
  final int? projectId;

  @override
  ConsumerState<SrsReviewPage> createState() => _SrsReviewPageState();
}

class _SrsReviewPageState extends ConsumerState<SrsReviewPage> {
  bool _loading = true;
  List<KnowledgeCard> _queue = [];
  Map<int, String> _projectTitle = {};
  int _index = 0;
  bool _revealed = false;
  int _reviewed = 0;
  int _againCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final q = db.select(db.knowledgeCards);
    if (widget.projectId != null) {
      q.where((c) => c.projectId.equals(widget.projectId!));
    }
    final all = await q.get();
    final due = [
      for (final c in all)
        if (c.dueAt != null && !c.dueAt!.isAfter(now)) c
    ]..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    final fresh = [
      for (final c in all)
        if (c.dueAt == null) c
    ]..sort((a, b) => b.id.compareTo(a.id));
    final projects = await db.select(db.projects).get();
    if (!mounted) return;
    setState(() {
      _queue = [...due, ...fresh];
      _projectTitle = {for (final p in projects) p.id: p.title};
      _loading = false;
    });
  }

  Future<void> _grade(SrsGrade grade) async {
    final db = ref.read(databaseProvider);
    final card = _queue[_index];
    final now = DateTime.now();
    final next = scheduleCard(
      SrsState(
          ivlDays: card.ivlDays,
          ease: card.ease,
          reps: card.reps,
          lapses: card.lapses),
      grade,
      now: now,
    );
    await (db.update(db.knowledgeCards)..where((t) => t.id.equals(card.id)))
        .write(KnowledgeCardsCompanion(
      dueAt: Value(next.dueAt),
      ivlDays: Value(next.ivlDays),
      ease: Value(next.ease),
      reps: Value(next.reps),
      lapses: Value(next.lapses),
      lastReviewAt: Value(now),
    ));
    if (!mounted) return;
    setState(() {
      _reviewed++;
      if (grade == SrsGrade.again) _againCount++;
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingView());
    }
    final done = _index >= _queue.length;
    return Scaffold(
      appBar: AppBar(title: Text(done ? '复习完成' : '复习 ${_index + 1}/${_queue.length}')),
      body: done
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.semanticColors.successBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.task_alt,
                        size: 34, color: context.semanticColors.success),
                  ),
                  const SizedBox(height: Space.l),
                  Text('已复习 $_reviewed 张',
                      style: Theme.of(context).textTheme.headlineSmall),
                  if (_againCount > 0)
                    Text('其中 $_againCount 张需要 10 分钟后巩固',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _projectTitle[_queue[_index].projectId] ?? '',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Text(_queue[_index].term,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                const SizedBox(height: Space.l),
                                if (_revealed) ...[
                                  Container(
                                    padding: const EdgeInsets.all(Space.l),
                                    constraints: const BoxConstraints(
                                        minWidth: double.infinity),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLowest,
                                      borderRadius: AppRadius.rLg,
                                      border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_queue[_index].title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        const SizedBox(height: Space.s),
                                        Text(_queue[_index].content,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge!
                                                .copyWith(height: 1.65)),
                                        if (_queue[_index].uncertain)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: Space.s),
                                            child: Text(
                                                'AI 对此词条不确定，请自行甄别',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall!
                                                    .copyWith(
                                                        color: context
                                                            .semanticColors
                                                            .warning)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!_revealed)
                        FilledButton(
                          onPressed: () => setState(() => _revealed = true),
                          child: const Text('显示答案'),
                        )
                      else
                        Row(children: [
                          for (final g in SrsGrade.values)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: OutlinedButton(
                                  onPressed: () => _grade(g),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: g == SrsGrade.again
                                        ? context.semanticColors.error
                                        : g == SrsGrade.easy
                                            ? context.semanticColors.success
                                            : null,
                                  ),
                                  child: Text(
                                      '${_gradeLabel(g)}\n${_fmtPreview(g)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                            ),
                        ]),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String _gradeLabel(SrsGrade g) => switch (g) {
        SrsGrade.again => '忘了',
        SrsGrade.hard => '费劲',
        SrsGrade.good => '想起',
        SrsGrade.easy => '简单',
      };

  String _fmtPreview(SrsGrade g) {
    final card = _queue[_index];
    final next = scheduleCard(
        SrsState(
            ivlDays: card.ivlDays,
            ease: card.ease,
            reps: card.reps,
            lapses: card.lapses),
        g);
    return _fmtInterval(next.dueAt.difference(DateTime.now()));
  }
}

String _fmtInterval(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes} 分钟';
  if (d.inHours < 24) return '${d.inHours} 小时';
  if (d.inDays < 31) return '${d.inDays} 天';
  return '${(d.inDays / 30).round()} 月';
}
