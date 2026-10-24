import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';

/// 收银台顶部的同步状态：已连接几台设备。点一下进入团队与设备。
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key, this.compact = false});

  /// 手机上只显示图标和数字。
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final peers = ref.watch(syncStatusProvider).value?.peers.length ?? 0;
    final connected = peers > 0;
    final icon = Icon(
      connected ? Icons.wifi : Icons.wifi_off,
      size: 18,
      color: connected ? Theme.of(context).colorScheme.primary : null,
    );
    void open() => context.go('/settings/team');
    if (compact) {
      return IconButton(
        tooltip: connected ? l10n.syncConnected(peers) : l10n.syncAlone,
        onPressed: open,
        icon: Badge(
          isLabelVisible: connected,
          label: Text('$peers'),
          child: icon,
        ),
      );
    }
    return ActionChip(
      avatar: icon,
      label: Text(connected ? l10n.syncConnected(peers) : l10n.syncAlone),
      onPressed: open,
    );
  }
}
