import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.devices_outlined),
            title: Text(l10n.teamAndDevices),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/team'),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.events),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/pos/events'),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(l10n.paymentMethods),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/payments'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.phone_iphone),
            title: Text(l10n.thisDevice),
            subtitle: Text(
              l10n.deviceCode(session.deviceShortCode, session.orderPrefix),
            ),
          ),
        ],
      ),
    );
  }
}
