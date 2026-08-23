import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:peixi/core/database/app_database.dart';

/// 解说卡（设计稿 8.2）：L1 常显 → L2 折叠（角色分条）→ L3 词条胶囊。
/// [forceExpand] 为 true（手动暂停深读）时全展开。
class CommentaryCard extends StatelessWidget {
  const CommentaryCard({
    super.key,
    required this.scene,
    required this.commentary,
    required this.cards,
    required this.colorByName,
    this.forceExpand = false,
    this.seenCardIds = const {},
  });

  final Scene scene;
  final Commentary? commentary;
  final List<KnowledgeCard> cards;
  final Map<String, Color> colorByName;
  final bool forceExpand;
  final Set<int> seenCardIds;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = commentary;
    final l2 = _parseL2(c?.l2PsychologyJson);

    if (c == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('第 ${scene.idx + 1} 景 · 解说缺失（生成时失败，可重新处理）',
            style: TextStyle(color: cs.outline)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            if (scene.importance == 'high')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('关键场景',
                    style: TextStyle(fontSize: 10, color: Colors.orange)),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                scene.summary ?? '第 ${scene.idx + 1} 景',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _Section(
            icon: Icons.visibility_outlined,
            label: 'L1 潜台词',
            color: cs.primary,
            initiallyExpanded: true, // L1 常显（设计稿 8.2）
            child: Text(c.l1Subtext,
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
          _Section(
            icon: Icons.psychology_outlined,
            label: 'L2 心理',
            color: cs.tertiary,
            initiallyExpanded: forceExpand,
            child: l2.isEmpty
                ? const Text('（本场景无心理分析）',
                    style: TextStyle(fontSize: 12))
                : Column(
                    children: [
                      for (final e in l2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: colorByName[e['character']
                                              .toString()] ??
                                          cs.tertiary,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                          text: '${e['character']}　',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      TextSpan(text: e['analysis'].toString()),
                                    ]),
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.5,
                                        color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ]),
                        ),
                    ],
                  ),
          ),
          if (cards.isNotEmpty)
            _Section(
              icon: Icons.school_outlined,
              label: 'L3 知识',
              color: cs.secondary,
              initiallyExpanded: forceExpand,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final card in cards)
                    ActionChip(
                      avatar: seenCardIds.contains(card.id)
                          ? const Icon(Icons.check, size: 14)
                          : null,
                      label: Text(card.term),
                      onPressed: () => _openCard(context, card),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openCard(BuildContext context, KnowledgeCard card) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.title,
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (card.uncertain)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('AI 对此词条把握不大，仅供参考',
                    style: TextStyle(fontSize: 11, color: Colors.orange)),
              ),
            Text(card.content.isEmpty ? '（暂无内容）' : card.content,
                style: const TextStyle(fontSize: 14, height: 1.7)),
          ],
        ),
      ),
    );
  }

  static List<Map> _parseL2(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final v = jsonDecode(json);
      if (v is List) return v.cast<Map>();
    } catch (_) {}
    return const [];
  }
}

class _Section extends StatefulWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.color,
    required this.child,
    this.initiallyExpanded = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant _Section old) {
    super.didUpdateWidget(old);
    if (widget.initiallyExpanded && !old.initiallyExpanded) {
      _expanded = true; // 暂停深读：自动展开
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(widget.icon, size: 14, color: widget.color),
            const SizedBox(width: 4),
            Text(widget.label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.color)),
            const SizedBox(width: 2),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                size: 14, color: widget.color),
          ]),
        ),
      ),
      if (_expanded)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: widget.child,
        ),
    ]);
  }
}
