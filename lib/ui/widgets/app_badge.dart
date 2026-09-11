import 'package:flutter/material.dart';
import 'package:peixi/core/theme/tokens.dart';

enum BadgeTone { success, warning, error, info, neutral }

/// 语义色胶囊徽章：全应用统一的紧凑状态标签（DESIGN.md §4）。
/// 替代各页手写的 Container+BoxDecoration 胶囊。
class AppBadge extends StatelessWidget {
  const AppBadge(this.label, {super.key, this.tone = BadgeTone.neutral});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final scheme = Theme.of(context).colorScheme;
    final (Color fg, Color bg) = switch (tone) {
      BadgeTone.success => (semantic.success, semantic.successBg),
      BadgeTone.warning => (semantic.warning, semantic.warningBg),
      BadgeTone.error => (semantic.error, semantic.errorBg),
      BadgeTone.info => (semantic.info, semantic.infoBg),
      BadgeTone.neutral => (scheme.onSurfaceVariant, scheme.surfaceContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium!
            .copyWith(color: fg, fontSize: 10.5, letterSpacing: 0.2),
      ),
    );
  }
}
