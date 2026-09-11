import 'package:flutter/material.dart';
import 'package:peixi/core/theme/tokens.dart';

/// 分区卡片：标题 + 可选副标题/尾注 + 内容，用于设置页等长表单分组。
/// 顶层容器（不允许嵌套卡片）。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.all(Space.l),
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  Icon(leading, size: 18, color: scheme.primary),
                  const SizedBox(width: Space.s),
                ],
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                ?trailing,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: Space.xs),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: Space.m),
            child,
          ],
        ),
      ),
    );
  }
}
