import 'package:flutter/material.dart';
import 'package:peixi/core/theme/tokens.dart';

/// 行内统计项：数值 + 标签（可选图标）。不加容器，靠排版分层。
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: Space.xs),
        ],
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: Space.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
