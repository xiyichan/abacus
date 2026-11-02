import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'design.dart';

/// 空状态（iOS 的 ContentUnavailableView）：大号灰色图标、粗体标题、说明和一个可选按钮。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.xl + Gap.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: secondary.withValues(alpha: 0.6)),
            const SizedBox(height: Gap.lg),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                body!,
                style: theme.textTheme.bodyLarge?.copyWith(color: secondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: Gap.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// AsyncValue 的通用加载/错误显示。
Widget asyncError(Object error, StackTrace _) => Center(
  child: Padding(padding: const EdgeInsets.all(24), child: Text('$error')),
);

const asyncLoading = Center(child: CircularProgressIndicator.adaptive());

/// iOS 原生样式的确认框：取消在左，确认在右；危险操作的确认是红字。
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        CupertinoDialogAction(
          isDefaultAction: !destructive,
          isDestructiveAction: destructive,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
