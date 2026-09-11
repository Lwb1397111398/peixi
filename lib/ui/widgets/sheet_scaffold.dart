import 'package:flutter/material.dart';
import 'package:peixi/core/theme/tokens.dart';

/// 底部面板统一骨架：拖拽柄 + 标题行（含关闭）+ 内容 + 可选底栏。
/// 用作 showModalBottomSheet(builder:) 的内容模板，
/// 替代各页重复的 SafeArea>Padding>Column 手拼。
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
    this.footer,
    this.maxHeightFactor = 0.92,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? footer;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: MediaQuery.viewInsetsOf(context),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Space.s),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.xl, Space.s, Space.m, Space.s),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  ...actions,
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Flexible(child: child),
            if (footer != null) ...[
              Divider(height: 1, color: scheme.outlineVariant),
              Padding(
                padding: EdgeInsets.fromLTRB(Space.xl, Space.m, Space.xl,
                    Space.m + MediaQuery.paddingOf(context).bottom),
                child: footer!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
