import 'package:flutter/material.dart';
import 'package:peixi/core/theme/tokens.dart';

/// 统一确认对话框。返回 true 表示用户确认。
/// [destructive] 时确认按钮用语义 error 色（删除等不可逆操作）。
abstract final class ConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? message,
    required String confirmLabel,
    String cancelLabel = '取消',
    bool destructive = false,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null
            ? null
            : Text(message, style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: semantic.error,
                    foregroundColor: scheme.surfaceContainerLowest,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
