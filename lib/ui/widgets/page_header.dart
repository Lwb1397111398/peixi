import 'package:flutter/material.dart';
import 'package:peixi/core/theme/tokens.dart';

/// rail 内四页通用页面头：大标题 + 副标题 + 右侧动作行。
/// 替代传统 AppBar（导航已由左侧 rail 承担）。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
    ];
    if (subtitle != null) {
      children.add(const SizedBox(height: Space.xs));
      children
          .add(Text(subtitle!, style: Theme.of(context).textTheme.bodySmall));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          )),
          if (actions.isNotEmpty)
            ..._withGaps(actions, const SizedBox(width: Space.s)),
        ],
      ),
    );
  }

  static List<Widget> _withGaps(List<Widget> ws, Widget gap) => [
        for (var i = 0; i < ws.length; i++) ...[
          if (i > 0) gap,
          ws[i],
        ]
      ];
}
