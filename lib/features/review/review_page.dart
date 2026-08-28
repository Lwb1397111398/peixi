import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
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
      appBar: AppBar(title: const Text('复盘')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  _statChip('已答', answered, Colors.green),
                  const SizedBox(width: 8),
                  _statChip('跳过', skipped, Colors.grey),
                  const SizedBox(width: 8),
                  _statChip('连续答题', streak, Colors.blue, suffix: '天'),
                ]),
              ),
              Expanded(
                child: _entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fact_check_outlined,
                                size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 8),
                            const Text('还没有答题记录'),
                            const Text('在播放器或阅读器里完成 L4 提问后会出现在这里'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _entries.length,
                        itemBuilder: (_, i) => _entryCard(_entries[i]),
                      ),
              ),
            ]),
    );
  }

  Widget _statChip(String label, int value, Color color, {String suffix = ''}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label $value$suffix',
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _entryCard(_ReviewEntry e) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(e.question.question,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(
                e.answer.skipped ? Icons.skip_next : Icons.check_circle,
                size: 14,
                color: e.answer.skipped ? Colors.grey : Colors.green),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                e.answer.skipped ? '已跳过' : '我的回答：${e.answer.userAnswer}',
                style: TextStyle(
                    fontSize: 13,
                    color: e.answer.skipped ? Colors.grey : null),
              ),
            ),
          ]),
          if (e.perspectives.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('参考视角',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
            for (final p in e.perspectives)
              Text('• $p', style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 6),
          Text(
            '${e.projectTitle}${e.projectTitle.isEmpty ? '' : ' · '}'
            '${_formatTime(e.answer.answeredAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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

