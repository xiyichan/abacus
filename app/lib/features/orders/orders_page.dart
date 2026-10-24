import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/sales_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/empty_state.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          event == null ? l10n.navOrders : '${l10n.navOrders} · ${event.name}',
        ),
        actions: [if (event != null) ExportOrdersButton(event: event)],
      ),
      body: event == null
          ? EmptyState(
              icon: Icons.storefront_outlined,
              title: l10n.noEventTitle,
              actionLabel: l10n.chooseEvent,
              onAction: () => context.go('/pos/events'),
            )
          : ref
                .watch(ordersProvider(event.id))
                .when(
                  loading: () => asyncLoading,
                  error: asyncError,
                  data: (orders) {
                    if (orders.isEmpty) {
                      return EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: l10n.noOrders,
                      );
                    }
                    final money = ref.watch(moneyProvider);
                    final kept = orders.where((o) => !o.isRefunded);
                    final revenue = kept.fold<int>(
                      0,
                      (a, o) => a + o.order.total,
                    );
                    final pending = [
                      for (final o in orders)
                        if (o.paymentPending && !o.isRefunded) o,
                    ];
                    final pendingAmount = pending.fold<int>(
                      0,
                      (a, o) => a + o.order.total,
                    );
                    // 单号和付款备注码按同一格式比较：A-007、a007、A007 都能搜到。
                    final q = normalizeOrderCode(_query);
                    final shown = [
                      for (final o in _pendingOnly ? pending : orders)
                        if (q.isEmpty ||
                            normalizeOrderCode(o.order.number).contains(q))
                          o,
                    ];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.ordersSummary(
                                    kept.length,
                                    money(revenue),
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              if (pending.isNotEmpty)
                                Text(
                                  l10n.ordersPendingSummary(
                                    pending.length,
                                    money(pendingAmount),
                                  ),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .tertiary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              SearchBar(
                                hintText: l10n.searchOrdersHint,
                                leading: const Icon(Icons.search),
                                elevation: const WidgetStatePropertyAll(0),
                                onChanged: (v) => setState(() => _query = v),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ChoiceChip(
                                    label: Text(l10n.filterAll),
                                    selected: !_pendingOnly,
                                    onSelected: (_) =>
                                        setState(() => _pendingOnly = false),
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: Text(
                                      '${l10n.filterPending} ${pending.length}',
                                    ),
                                    selected: _pendingOnly,
                                    onSelected: (_) =>
                                        setState(() => _pendingOnly = true),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: shown.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final s = shown[i];
                              final o = s.order;
                              return ListTile(
                                title: Row(
                                  children: [
                                    Text(
                                      o.number,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    if (s.isRefunded) ...[
                                      const SizedBox(width: 8),
                                      _StatusChip(
                                        label: l10n.refunded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .errorContainer,
                                        textColor: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer,
                                      ),
                                    ] else if (s.paymentPending) ...[
                                      const SizedBox(width: 8),
                                      _StatusChip(
                                        label: l10n.pendingPayment,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiaryContainer,
                                        textColor: Theme.of(context)
                                            .colorScheme
                                            .onTertiaryContainer,
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  '${_timeFormat.format(o.createdAt)} · '
                                  '${l10n.itemCount(s.itemCount)} · ${s.paymentNames}',
                                ),
                                trailing: Text(
                                  money(o.total),
                                  style: TextStyle(
                                    decoration: s.isRefunded
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                onTap: () => context.go('/orders/${o.id}'),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: textColor),
      ),
    );
  }
}
