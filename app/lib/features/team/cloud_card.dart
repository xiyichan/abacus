import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../sync/cloud_sync_service.dart';
import '../../ui/empty_state.dart';
import '../../ui/input_dialog.dart';
import 'cloud_login_page.dart' show cloudErrorText;

/// 问用户名（只用来显示）。取消返回 null；[firstLogin] 时取消按钮叫“跳过”。
Future<String?> askDisplayName(
  BuildContext context, {
  String initial = '',
  bool firstLogin = false,
}) {
  final l10n = AppLocalizations.of(context);
  return showInputDialog(
    context,
    title: initial.isEmpty ? l10n.setDisplayName : l10n.editDisplayName,
    label: l10n.displayName,
    body: l10n.displayNameHint,
    initialValue: initial,
    inputFormatters: [LengthLimitingTextInputFormatter(30)],
    confirmLabel: l10n.save,
    cancelLabel: firstLogin ? l10n.skip : l10n.cancel,
  ).then((v) => v?.trim());
}

/// 团队与设备页里的“云端备份”卡片：登录入口或当前同步状态。
class CloudCard extends ConsumerWidget {
  const CloudCard({super.key});

  String _when(DateTime time) {
    final now = DateTime.now();
    final sameDay =
        now.year == time.year && now.month == time.month && now.day == time.day;
    return DateFormat(sameDay ? 'HH:mm' : 'MM-dd HH:mm').format(time);
  }

  Future<void> _editDisplayName(
    BuildContext context,
    WidgetRef ref,
    CloudStatus status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final name = await askDisplayName(
      context,
      initial: status.displayName ?? '',
    );
    if (name == null || name == (status.displayName ?? '')) return;
    try {
      await ref.read(cloudSyncProvider).setDisplayName(name);
      messenger.showSnackBar(SnackBar(content: Text(l10n.displayNameSaved)));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(cloudErrorText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(cloudStatusProvider).value ?? const CloudStatus();

    if (status.state == CloudState.signedOut) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_outlined),
                  const SizedBox(width: 12),
                  Text(l10n.cloudBackup, style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              Text(l10n.cloudSignedOutHint, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => context.go('/settings/team/cloud'),
                icon: const Icon(Icons.mail_outline),
                label: Text(l10n.signInWithEmail),
              ),
            ],
          ),
        ),
      );
    }

    final (icon, text, color) = switch (status.state) {
      CloudState.connected => (
        Icons.cloud_done_outlined,
        l10n.cloudConnected,
        theme.colorScheme.primary,
      ),
      CloudState.connecting => (
        Icons.cloud_sync_outlined,
        l10n.cloudConnecting,
        null,
      ),
      _ => (
        Icons.cloud_off_outlined,
        l10n.cloudOffline,
        theme.colorScheme.error,
      ),
    };
    final last = status.lastSync;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: Icon(icon, color: color),
        title: Text(status.displayName ?? status.email ?? l10n.cloudBackup),
        subtitle: Text(
          [
            if (status.displayName != null) ?status.email,
            text,
            last == null ? l10n.neverSynced : l10n.lastSync(_when(last)),
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 换成这个邮箱在云端的另一个团队（重新登录后选团队恢复）。
            IconButton(
              tooltip: l10n.switchCloudTeam,
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => context.go('/settings/team/cloud?restore=1'),
            ),
            IconButton(
              tooltip: status.displayName == null
                  ? l10n.setDisplayName
                  : l10n.editDisplayName,
              icon: const Icon(Icons.badge_outlined),
              onPressed: () => _editDisplayName(context, ref, status),
            ),
            TextButton(
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: l10n.signOutTitle,
                  body: l10n.signOutBody,
                  confirmLabel: l10n.signOut,
                  cancelLabel: l10n.cancel,
                );
                if (ok) await ref.read(cloudSyncProvider).signOut();
              },
              child: Text(l10n.signOut),
            ),
          ],
        ),
      ),
    );
  }
}
