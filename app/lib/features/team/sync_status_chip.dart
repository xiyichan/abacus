import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/large_title_page.dart';

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
    return BarButton(
      icon: connected ? CupertinoIcons.wifi : CupertinoIcons.wifi_slash,
      tooltip: connected ? l10n.syncConnected(peers) : l10n.syncAlone,
      label: compact
          ? null
          : (connected ? l10n.syncConnected(peers) : l10n.syncAlone),
      badge: compact ? peers : null,
      onPressed: () => context.go('/settings/team'),
    );
  }
}
