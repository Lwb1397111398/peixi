import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/ui/widgets/app_badge.dart';
import 'package:peixi/ui/widgets/sheet_scaffold.dart';

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
    final tt = Theme.of(context).textTheme;
    final c = commentary;
    final l2 = _parseL2(c?.l2PsychologyJson);

    if (c == null) {
      return Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Row(children: [
          Icon(Icons.info_outline, size: 15, color: cs.outline),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text('第 ${scene.idx + 1} 景 · 解说缺失（生成时失败，可重新处理）',
                style: tt.bodySmall),
          ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (scene.importance == 'high') ...[
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: AppBadge('关键场景', tone: BadgeTone.warning),
                ),
                const SizedBox(width: Space.s),
              ],
              Expanded(
                child: Text(
                  scene.summary ?? '第 ${scene.idx + 1} 景',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          _Section(
            icon: Icons.visibility_outlined,
            label: 'L1 潜台词',
            color: cs.primary,
            initiallyExpanded: true, // L1 常显（设计稿 8.2）
            child: Text(c.l1Subtext,
                style: tt.bodyLarge!.copyWith(height: 1.65)),
          ),
          _Section(
            icon: Icons.psychology_outlined,
            label: 'L2 心理',
            color: cs.tertiary,
            initiallyExpanded: forceExpand,
            child: l2.isEmpty
                ? Text('（本场景无心理分析）', style: tt.bodySmall)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in l2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.s),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 7),
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                      color: colorByName[e['character']
                                              .toString()] ??
                                          cs.tertiary,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: Space.s),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                          text: '${e['character']}　',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurface)),
                                      TextSpan(
                                          text: e['analysis'].toString()),
                                    ]),
                                    style: tt.bodyMedium!
                                        .copyWith(height: 1.55),
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
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final card in cards)
                    ActionChip(
                      avatar: seenCardIds.contains(card.id)
                          ? Icon(Icons.check, size: 14, color: cs.primary)
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
    // 用捕获的主题（播放器语境）包住路由级面板，保证明暗一致
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Theme(
        data: theme,
        child: SheetScaffold(
          title: card.title,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                Space.xl, Space.m, Space.xl, Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (card.uncertain) ...[
                  Row(children: [
                    Icon(Icons.help_outline,
                        size: 14, color: semantic.warning),
                    const SizedBox(width: Space.xs),
                    Text('AI 对此词条把握不大，仅供参考',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: semantic.warning)),
                  ]),
                  const SizedBox(height: Space.m),
                ],
                Text(card.content.isEmpty ? '（暂无内容）' : card.content,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(height: 1.7)),
              ],
            ),
          ),
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
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: AppRadius.rSm,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: Space.s),
              child: Row(children: [
                Icon(widget.icon, size: 14, color: widget.color),
                const SizedBox(width: Space.xs),
                Text(widget.label,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium!
                        .copyWith(color: widget.color)),
                const SizedBox(width: Space.xs),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 15, color: widget.color),
              ]),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(left: Space.l, bottom: Space.m),
              child: widget.child,
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ]);
  }
}
