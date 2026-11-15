import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/session.dart';
import '../../data/team_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/design.dart';
import '../../ui/grouped_list.dart';
import '../../ui/input_dialog.dart';
import '../../ui/large_title_page.dart';
import '../../support/tip_jar.dart';
import '../../sync/cloud_api.dart';
import '../lock/cashier_lock.dart';
import '../team/team_switcher.dart';

/// 设置：iOS 设置那样的分组列表。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final me = ref
        .watch(devicesProvider)
        .value
        ?.where((d) => d.id == session.deviceId)
        .firstOrNull;
    final orderPrefix = me == null
        ? session.orderPrefix
        : effectiveOrderPrefix(me);
    return LargeTitlePage(
      title: l10n.navSettings,
      leading: const TeamSwitcherButton(separator: true),
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
              dividerIndent: GroupedTile.iconIndent,
              children: [
                _SupportTile(prefs: ref.watch(supportPrefsProvider)),
                GroupedTile(
                  icon: CupertinoIcons.hand_raised_fill,
                  iconColor: Brand.tiles[4],
                  title: l10n.privacyPolicy,
                  onTap: () => launchUrl(
                    Uri.parse(privacyPolicyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
            GroupedSection(
              footer: l10n.orderPrefixFooter('$orderPrefix-001'),
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
                _OrderPrefixTile(prefix: orderPrefix),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// 「请作者喝杯咖啡」：打赏过之后右边显示一颗心。
class _SupportTile extends StatelessWidget {
  const _SupportTile({required this.prefs});

  final SupportPrefs? prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefs = this.prefs;
    Widget tile(bool tipped) => GroupedTile(
      icon: CupertinoIcons.heart_fill,
      iconColor: Brand.tiles[1],
      title: l10n.supportAuthor,
      subtitle: tipped ? null : l10n.supportTileHint,
      trailing: tipped
          ? Text(
              l10n.supportTipped,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      onTap: () => context.go('/settings/support'),
    );
    if (prefs == null) return tile(false);
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => tile(prefs.tipped),
    );
  }
}

/// 本机的订单号前缀，点开可以改（比如改成摊位名缩写）。
class _OrderPrefixTile extends ConsumerWidget {
  const _OrderPrefixTile({required this.prefix});

  final String prefix;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final value = await showInputDialog(
      context,
      title: l10n.orderPrefix,
      label: l10n.orderPrefix,
      body: l10n.orderPrefixBody,
      initialValue: prefix,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
        TextInputFormatter.withFunction(
          (_, next) => next.copyWith(text: next.text.toUpperCase()),
        ),
        LengthLimitingTextInputFormatter(4),
      ],
      confirmLabel: l10n.save,
      cancelLabel: l10n.cancel,
    );
    if (value == null) return;
    try {
      await ref.read(teamRepositoryProvider).setOrderPrefix(value);
    } on OrderPrefixTakenException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderPrefixTaken(e.deviceName))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final faint = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return GroupedTile(
      title: l10n.orderPrefix,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            prefix,
            style: theme.textTheme.bodyLarge?.copyWith(color: faint),
          ),
          const SizedBox(width: Gap.xs),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
      onTap: () => _edit(context, ref),
    );
  }
}
