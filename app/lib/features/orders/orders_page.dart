import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/sales_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/design.dart';
import '../../ui/empty_state.dart';
import '../../ui/large_title_page.dart';
import '../../ui/money.dart';
import 'export_orders.dart';

final _timeFormat = DateFormat('HH:mm');

/// 当前场次的订单列表。
class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  String _query = '';
  bool _pendingOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final event = ref.watch(currentEventProvider).value;
    return LargeTitlePage(
      title: l10n.navOrders,
      actions: [if (event != null) ExportOrdersButton(event: event)],
      slivers: event == null
          ? [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: CupertinoIcons.cart,
                  title: l10n.noEventTitle,
                  actionLabel: l10n.chooseEvent,
                  onAction: () => context.go('/pos/events'),
                ),
              ),
            ]
          : ref
                .watch(ordersProvider(event.id))
                .when(
                  loading: () => const [
                    SliverFillRemaining(child: asyncLoading),
                  ],
                  error: (e, s) => [
                    SliverFillRemaining(child: asyncError(e, s)),
                  ],
                  data: (orders) => orders.isEmpty
                      ? [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: CupertinoIcons.doc_text,
                              title: l10n.noOrders,
                              body: event.name,
                            ),
                          ),
                        ]
                      : _orderSlivers(event.name, orders),
                ),
    );
  }

  List<Widget> _orderSlivers(String eventName, List<OrderSummary> orders) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = ref.watch(moneyProvider);
    final cell =
        theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLowest;
    final kept = orders.where((o) => !o.isRefunded);
    final revenue = kept.fold<int>(0, (a, o) => a + o.order.total);
    final pending = [
      for (final o in orders)
        if (o.paymentPending && !o.isRefunded) o,
    ];
    final pendingAmount = pending.fold<int>(0, (a, o) => a + o.order.total);
    // 单号和付款备注码按同一格式比较：A-007、a007、A007 都能搜到。
    final q = normalizeOrderCode(_query);
    final shown = [
      for (final o in _pendingOnly ? pending : orders)
        if (q.isEmpty ||
            normalizeOrderCode(o.order.number).contains(q) ||
            normalizeOrderCode(orderPaymentCode(o.order)).contains(q))
          o,
    ];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        sliver: SliverList.list(
          children: [
            Text(
              eventName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              l10n.ordersSummary(kept.length, money(revenue)),
              style: theme.textTheme.titleMedium,
            ),
            if (pending.isNotEmpty)
              Text(
                l10n.ordersPendingSummary(pending.length, money(pendingAmount)),
                style: TextStyle(color: theme.colorScheme.tertiary),
              ),
            const SizedBox(height: Gap.md),
            // 合并读屏信息：整个胶囊（48pt 高）都算搜索框的点击区域，而不只是里面那一行字。
            MergeSemantics(
              child: SearchBar(
                hintText: l10n.searchOrdersHint,
                leading: const Icon(CupertinoIcons.search),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              children: [
                ChoiceChip(
                  label: Text(l10n.filterAll),
                  selected: !_pendingOnly,
                  onSelected: (_) => setState(() => _pendingOnly = false),
                ),
                ChoiceChip(
                  label: Text('${l10n.filterPending} ${pending.length}'),
                  selected: _pendingOnly,
                  onSelected: (_) => setState(() => _pendingOnly = true),
                ),
              ],
            ),
          ],
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        // 分组列表：整列是一张圆角卡片，只给首尾两行圆角，保持懒加载。
        sliver: SliverList.separated(
          itemCount: shown.length,
          separatorBuilder: (_, _) => ColoredBox(
            color: cell,
            child: const Divider(height: 1, indent: Gap.lg),
          ),
          itemBuilder: (context, i) {
            final s = shown[i];
            final o = s.order;
            final tile = ListTile(
              title: Wrap(
                spacing: Gap.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(o.number, style: theme.textTheme.titleMedium),
                  if (s.isRefunded)
                    _StatusChip(
                      label: l10n.refunded,
                      color: theme.colorScheme.errorContainer,
                      textColor: theme.colorScheme.onErrorContainer,
                    )
                  else if (s.paymentPending)
                    _StatusChip(
                      label: l10n.pendingPayment,
                      color: theme.colorScheme.tertiaryContainer,
                      textColor: theme.colorScheme.onTertiaryContainer,
                    ),
                ],
              ),
              subtitle: Text(
                '${_timeFormat.format(o.createdAt)} · '
                '${l10n.itemCount(s.itemCount)} · ${s.paymentNames}',
              ),
              trailing: Text(
                money(o.total),
                style: theme.textTheme.titleMedium?.copyWith(
                  decoration: s.isRefunded ? TextDecoration.lineThrough : null,
                ),
              ),
              onTap: () => context.go('/orders/${o.id}'),
            );
            return ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? Radii.card : 0),
                bottom: Radius.circular(i == shown.length - 1 ? Radii.card : 0),
              ),
              child: Material(color: cell, child: tile),
            );
          },
        ),
      ),
    ];
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: textColor),
      ),
    );
  }
}
