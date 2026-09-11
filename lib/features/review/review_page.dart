import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/ui/widgets/empty_state.dart';
import 'package:peixi/ui/widgets/loading_view.dart';
import 'package:peixi/ui/widgets/page_header.dart';
import 'package:peixi/providers.dart';

/// 复盘页（设计稿 8.5）：qa_records 时间线（我的回答 vs 参考视角），
/// 统计：已答/跳过数、连续答题天数。
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewEntry {
  _ReviewEntry({
    required this.answer,
    required this.question,
    required this.perspectives,
    required this.projectTitle,
  });
  final QaRecord answer;
  final Question question;
  final List<String> perspectives;
  final String projectTitle;
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  bool _loading = true;
  List<_ReviewEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final answers =
        await (db.select(db.qaRecords)..orderBy([(r) => OrderingTerm.desc(r.answeredAt)]))
            .get();
    final questions = await db.select(db.questions).get();
    final projects = await db.select(db.projects).get();
    final qById = {for (final q in questions) q.id: q};
    final titleById = {for (final p in projects) p.id: p.title};
    if (!mounted) return;
    setState(() {
      _entries = [
        for (final a in answers)
          if (qById.containsKey(a.questionId))
            _ReviewEntry(
              answer: a,
              question: qById[a.questionId]!,
              perspectives: _decodePerspectives(qById[a.questionId]!.perspectivesJson),
              projectTitle: titleById[qById[a.questionId]!.projectId] ?? '',
            ),
      ];
      _loading = false;
    });
  }

  List<String> _decodePerspectives(String json) {
    try {
      final v = jsonDecode(json);
      return v is List ? [for (final p in v) p.toString()] : const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final answered = _entries.where((e) => !e.answer.skipped).length;
    final skipped = _entries.length - answered;
    final streak = streakDays(_entries.map((e) => e.answer.answeredAt));

    return Scaffold(
      body: _loading
          ? const LoadingView()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          const PageHeader(
            title: '复盘',
            subtitle: '你在弹题里的每个回答，都是温故知新的素材',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.xl, 0, Space.xl, Space.m),
            child: Row(children: [
              _statChip('已答', answered, context.semanticColors.success),
              const SizedBox(width: Space.s),
              _statChip('跳过', skipped,
                  Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: Space.s),
              _statChip('连续答题', streak, context.semanticColors.info,
                  suffix: '天'),
            ]),
          ),
          Expanded(
            child: _entries.isEmpty
                ? EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: '还没有答题记录',
                    message: '在播放器或阅读器里完成 L4 提问后会出现在这里',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        Space.xl, 0, Space.xl, Space.xl),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) => _entryCard(_entries[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int value, Color color, {String suffix = ''}) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Space.m, vertical: Space.s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label $value$suffix',
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12.5)),
    );
  }

  Widget _entryCard(_ReviewEntry e) {
    final semantic = context.semanticColors;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: Space.m),
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(e.question.question,
                    style: tt.titleMedium)),
          ]),
          const SizedBox(height: Space.s),
          Row(children: [
            Icon(
                e.answer.skipped ? Icons.skip_next : Icons.check_circle,
                size: 15,
                color: e.answer.skipped
                    ? cs.onSurfaceVariant
                    : semantic.success),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Text(
                e.answer.skipped ? '已跳过' : '我的回答：${e.answer.userAnswer}',
                style: tt.bodyMedium!.copyWith(
                    color: e.answer.skipped ? cs.onSurfaceVariant : null),
              ),
            ),
          ]),
          if (e.perspectives.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            Text('参考视角',
                style: tt.labelLarge!.copyWith(color: cs.primary)),
            const SizedBox(height: Space.xs),
            for (final p in e.perspectives)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $p', style: tt.bodyMedium),
              ),
          ],
          const SizedBox(height: Space.s),
          Text(
            '${e.projectTitle}${e.projectTitle.isEmpty ? '' : ' · '}'
            '${_formatTime(e.answer.answeredAt)}',
            style: tt.bodySmall,
          ),
        ]),
      ),
    );
  }

  String _formatTime(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// 连续答题天数：按本地自然日去重，从最近一次答题日（今天或昨天）向前连续计数。
int streakDays(Iterable<DateTime> answeredAt, {DateTime? now}) {
  final days = answeredAt
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));
  if (days.isEmpty) return 0;
  final nowD = now ?? DateTime.now();
  final today = DateTime(nowD.year, nowD.month, nowD.day);
  final gap = today.difference(days.first).inDays;
  if (gap > 1) return 0; // 最近答题不在今天/昨天 → 连续已断
  var streak = 1;
  for (var i = 1; i < days.length; i++) {
    if (days[i - 1].difference(days[i]).inDays == 1) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

