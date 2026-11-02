import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/sales_repository.dart';
import '../../domain/checkout.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/grouped_list.dart';
import '../../ui/design.dart';
import '../../ui/layout.dart';
import '../../ui/empty_state.dart';
import '../../ui/input_dialog.dart';
import '../../ui/money.dart';

const _sectionMargin = EdgeInsets.symmetric(vertical: Gap.sm);
final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  Future<void> _refund(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final reason = await showInputDialog(
      context,
      title: l10n.refundTitle,
      body: l10n.refundBody,
      label: l10n.refundReason,
      confirmLabel: l10n.refund,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (reason == null) return;
    await ref
        .read(salesRepositoryProvider)
        .refundOrder(
          orderId,
          reason: reason.trim().isEmpty ? null : reason.trim(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = ref.watch(moneyProvider);
    return ref
        .watch(orderDetailProvider(orderId))
        .when(
          loading: () => const Scaffold(body: asyncLoading),
          error: (e, s) => Scaffold(appBar: AppBar(), body: asyncError(e, s)),
          data: (detail) {
            final o = detail.order;
            return Scaffold(
              appBar: AppBar(title: Text('${l10n.orderDetail} ${o.number}')),
              body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: withBottomBar(context, const EdgeInsets.all(16)),
                    children: [
                      Text(
                        _dateTimeFormat.format(o.createdAt),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (detail.refund == null &&
                          detail.payments.any((p) => p.pending)) ...[
                        const SizedBox(height: 12),
                        Card(
                          color: theme.colorScheme.tertiaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.pendingPayment,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.paymentPendingBody(
                                    paymentCodeOf(o.number),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () async {
                                    await ref
                                        .read(salesRepositoryProvider)
                                        .confirmPayment(o.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n.paymentConfirmedDone,
                                              ),
                                            ),
                                          );
                                    }
                                  },
                                  icon: const Icon(Icons.check),
                                  label: Text(l10n.confirmReceived),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (detail.refund case final r?) ...[
                        const SizedBox(height: 12),
                        Card(
                          color: theme.colorScheme.errorContainer,
                          child: ListTile(
                            leading: const Icon(Icons.undo),
                            title: Text(l10n.refundDone),
                            subtitle: Text(
                              [
                                _dateTimeFormat.format(r.createdAt),
                                ?r.reason,
                              ].join(' · '),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: Gap.sm),
                      GroupedSection(
                        margin: _sectionMargin,
                        children: [
                          for (final item in detail.items)
                            ListTile(
                              title: Text(item.nameSnapshot),
                              subtitle: Text(
                                '${money(item.unitPrice)} × ${item.quantity}',
                              ),
                              trailing: Text(
                                money(item.unitPrice * item.quantity),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      GroupedSection(
                        margin: _sectionMargin,
                        children: [
                          LabeledRow(
                            label: l10n.subtotal,
                            value: money(o.subtotal),
                          ),
                          if (o.discount > 0)
                            LabeledRow(
                              label: l10n.discount,
                              value: '−${money(o.discount)}',
                            ),
                          LabeledRow(
                            label: l10n.total,
                            value: money(o.total),
                            emphasis: true,
                          ),
                        ],
                      ),
                      GroupedSection(
                        margin: _sectionMargin,
                        children: [
                          LabeledRow(
                            label: l10n.paymentCode,
                            value: paymentCodeOf(o.number),
                          ),
                          for (final p in detail.payments) ...[
                            LabeledRow(
                              label: l10n.paymentMethod,
                              value: p.methodNameSnapshot,
                            ),
                            // 事后才确认收款的，显示确认时间。
                            if (!p.pending &&
                                p.confirmedAt != null &&
                                p.confirmedAt!
                                        .difference(o.createdAt)
                                        .inMinutes >=
                                    1)
                              LabeledRow(
                                label: l10n.pendingPayment,
                                value: l10n.paymentConfirmedAt(
                                  _dateTimeFormat.format(p.confirmedAt!),
                                ),
                              ),
                            if (p.tendered case final t?) ...[
                              LabeledRow(
                                label: l10n.cashTendered,
                                value: money(t),
                              ),
                              LabeledRow(
                                label: l10n.change,
                                value: money(
                                  changeDue(total: p.amount, tendered: t) ?? 0,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (detail.refund == null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: () => _refund(context, ref),
                          icon: const Icon(Icons.undo),
                          label: Text(l10n.refund),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
  }
}
