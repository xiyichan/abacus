import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../features/lock/cashier_lock.dart';
import '../providers.dart';
import 'floating_tab_bar.dart';

/// 主框架：底部悬浮的玻璃标签栏（手机和平板都一样）。同时负责启动局域网同步。
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
    // 收银锁：只留收银台，不显示导航。
    if (ref.watch(cashierLockedProvider).value ?? false) {
      return Scaffold(body: navigationShell);
    }
    // 订单标签上用角标提示待确认收款的单数。
    final pending = ref.watch(pendingPaymentCountProvider);
    // iOS 26 的悬浮玻璃标签栏：未选中用线条图标，选中用实心图标。手机和平板都用它，内容从下面透过来。
    final tabs = [
      FloatingTab(
        icon: CupertinoIcons.cart,
        selectedIcon: CupertinoIcons.cart_fill,
        label: l10n.navPos,
      ),
      FloatingTab(
        icon: CupertinoIcons.doc_text,
        selectedIcon: CupertinoIcons.doc_text_fill,
        label: l10n.navOrders,
        badge: pending,
      ),
      FloatingTab(
        icon: CupertinoIcons.cube_box,
        selectedIcon: CupertinoIcons.cube_box_fill,
        label: l10n.navProducts,
      ),
      FloatingTab(
        icon: CupertinoIcons.chart_bar,
        selectedIcon: CupertinoIcons.chart_bar_fill,
        label: l10n.navStats,
      ),
      FloatingTab(
        icon: CupertinoIcons.gear,
        selectedIcon: CupertinoIcons.gear_solid,
        label: l10n.navSettings,
      ),
    ];

    return Scaffold(
      // 内容延伸到标签栏下面；各页面的滚动列表用 MediaQuery 的底部内边距留出它的高度。
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: FloatingTabBar(
        tabs: tabs,
        selectedIndex: navigationShell.currentIndex,
        onSelect: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
