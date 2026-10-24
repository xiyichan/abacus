import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../sync/cloud_sync_service.dart';
import '../../ui/empty_state.dart';

/// 团队与设备页里的“云端备份”卡片：登录入口或当前同步状态。
class CloudCard extends ConsumerWidget {
  const CloudCard({super.key});

  String _when(DateTime time) {
    final now = DateTime.now();
    final sameDay =
        now.year == time.year && now.month == time.month && now.day == time.day;
    return DateFormat(sameDay ? 'HH:mm' : 'MM-dd HH:mm').format(time);
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
        title: Text(status.email ?? l10n.cloudBackup),
        subtitle: Text(
          '$text\n${last == null ? l10n.neverSynced : l10n.lastSync(_when(last))}',
        ),
        isThreeLine: true,
        trailing: TextButton(
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
      ),
    );
  }
}
