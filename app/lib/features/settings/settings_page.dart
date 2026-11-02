import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/design.dart';
import '../../ui/grouped_list.dart';
import '../../ui/large_title_page.dart';
import '../lock/cashier_lock.dart';

/// 设置：iOS 设置那样的分组列表。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    return LargeTitlePage(
      title: l10n.navSettings,
      slivers: [
        SliverList.list(
          children: [
            GroupedSection(
              dividerIndent: GroupedTile.iconIndent,
              children: [
                GroupedTile(
                  icon: CupertinoIcons.device_phone_portrait,
                  iconColor: Brand.tiles[0],
                  title: l10n.teamAndDevices,
                  onTap: () => context.go('/settings/team'),
                ),
                GroupedTile(
                  icon: CupertinoIcons.calendar,
                  iconColor: Brand.tiles[1],
                  title: l10n.events,
                  onTap: () => context.go('/pos/events'),
                ),
                GroupedTile(
                  icon: CupertinoIcons.money_yen,
                  iconColor: Brand.tiles[2],
                  title: l10n.paymentMethods,
                  onTap: () => context.go('/settings/payments'),
                ),
              ],
            ),
            GroupedSection(
              dividerIndent: GroupedTile.iconIndent,
              footer: l10n.cashierLockHint,
              children: [
                GroupedTile(
                  icon: CupertinoIcons.lock_fill,
                  iconColor: Brand.tiles[3],
                  title: l10n.cashierLock,
                  onTap: () => lockCashier(context, ref),
                ),
                if (ref.watch(hasLockPinProvider).value ?? false)
                  GroupedTile(
                    icon: CupertinoIcons.number,
                    iconColor: Brand.tiles[4],
                    title: l10n.changeLockPin,
                    onTap: () => changeLockPin(context, ref),
                  ),
              ],
            ),
            GroupedSection(
              footer: l10n.deviceCode(
                session.deviceShortCode,
                session.orderPrefix,
              ),
              children: [
                GroupedTile(
                  title: l10n.thisDevice,
                  trailing: Text(
                    session.deviceShortCode,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
