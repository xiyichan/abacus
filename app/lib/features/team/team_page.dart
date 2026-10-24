import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../sync/team_invite.dart';
import '../../ui/empty_state.dart';
import '../../ui/input_dialog.dart';
import 'cloud_card.dart';

/// 团队与设备：团队名、本机、在线设备、邀请/加入。
class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final team = ref.watch(teamProvider).value;
    final devices = ref.watch(devicesProvider);
    final status = ref.watch(syncStatusProvider).value;
    final peers = status?.peers ?? const <String>{};
    final repo = ref.read(teamRepositoryProvider);

    Future<void> rename({
      required String title,
      required String initial,
      required Future<void> Function(String) save,
    }) async {
      final name = await showInputDialog(
        context,
        title: title,
        label: title,
        initialValue: initial,
        confirmLabel: l10n.save,
        cancelLabel: l10n.cancel,
      );
      if (name != null && name.trim().isNotEmpty) await save(name);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.teamAndDevices)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(team?.name ?? '…'),
            subtitle: Text(l10n.teamName),
            trailing: const Icon(Icons.edit_outlined),
            onTap: team == null
                ? null
                : () => rename(
                    title: l10n.teamName,
                    initial: team.name,
                    save: repo.renameTeam,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: ListTile(
                leading: Icon(
                  peers.isEmpty ? Icons.wifi_off : Icons.wifi,
                  color: peers.isEmpty ? null : theme.colorScheme.primary,
                ),
                title: Text(
                  peers.isEmpty
                      ? l10n.syncAlone
                      : l10n.syncConnected(peers.length),
                ),
                subtitle: Text(
                  status?.error != null
                      ? l10n.syncError(status!.error!)
                      : l10n.syncHelp,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: CloudCard(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l10n.devicesInTeam, style: theme.textTheme.titleSmall),
          ),
          ...devices.when(
            loading: () => [asyncLoading],
            error: (e, s) => [asyncError(e, s)],
            data: (devices) => [
              for (final d in devices)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(orderPrefixOf(d.shortCode)),
                  ),
                  title: Text(d.name),
                  subtitle: Text(
                    '${d.shortCode} · ${d.id == session.deviceId
                        ? l10n.thisDeviceTag
                        : peers.contains(d.id)
                        ? l10n.online
                        : l10n.offline}',
                  ),
                  trailing: d.id == session.deviceId
                      ? IconButton(
                          tooltip: l10n.rename,
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => rename(
                            title: l10n.deviceName,
                            initial: d.name,
                            save: repo.renameDevice,
                          ),
                        )
                      : Icon(
                          Icons.circle,
                          size: 12,
                          color: peers.contains(d.id)
                              ? Colors.green
                              : theme.colorScheme.outlineVariant,
                        ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => _showInvite(context, ref),
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(l10n.inviteDevice),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/settings/team/join'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n.joinTeam),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInvite(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final invite = await createInvite(
      ref.read(databaseProvider),
      ref.read(sessionProvider),
    );
    final code = invite.encode();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.inviteTitle),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColoredBox(
                color: Colors.white,
                child: QrImageView(data: code, size: 260),
              ),
              const SizedBox(height: 12),
              Text(l10n.inviteBody(invite.deviceCode)),
              const SizedBox(height: 8),
              Text(
                l10n.inviteWarning,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.inviteCopied)));
              }
            },
            icon: const Icon(Icons.copy),
            label: Text(l10n.copyInviteCode),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}
