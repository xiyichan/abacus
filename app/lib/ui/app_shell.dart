import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'layout.dart';

/// 主框架：手机用底部导航栏，平板用左侧导航栏。同时负责启动局域网同步。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // iOS 退到后台会断开网络；回到前台时如果没有连着的设备，就重新发现。
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final sync = ref.read(syncServiceProvider);
        if (sync.current.peers.isEmpty) sync.restart();
        ref.read(cloudSyncProvider).resume();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncServiceProvider); // 进入主界面即启动局域网同步
    ref.watch(cloudSyncProvider); // 已登录时同时连云端
    final navigationShell = widget.navigationShell;
    final l10n = AppLocalizations.of(context);
    // 订单导航上用角标提示待确认收款的单数。
    final pending = ref.watch(pendingPaymentCountProvider);
    Widget badged(IconData icon, int count) => Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: Icon(icon),
    );
    final destinations = [
      (Icons.point_of_sale_outlined, Icons.point_of_sale, l10n.navPos, 0),
      (
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        l10n.navOrders,
        pending,
      ),
      (Icons.inventory_2_outlined, Icons.inventory_2, l10n.navProducts, 0),
      (Icons.insights_outlined, Icons.insights, l10n.navStats, 0),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings, 0),
    ];

    void onSelect(int index) => navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );

    if (context.isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: onSelect,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, selected, label, count) in destinations)
                  NavigationRailDestination(
                    icon: badged(icon, count),
                    selectedIcon: badged(selected, count),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: onSelect,
        destinations: [
          for (final (icon, selected, label, count) in destinations)
            NavigationDestination(
              icon: badged(icon, count),
              selectedIcon: badged(selected, count),
              label: label,
            ),
        ],
      ),
    );
  }
}
