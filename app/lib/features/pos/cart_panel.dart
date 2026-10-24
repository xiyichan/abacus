import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/money.dart';
import 'cart.dart';
import 'discount_dialog.dart';

/// 购物车内容 + 合计 + 结账按钮。平板常驻右侧，手机放在底部弹层里。
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key, required this.onCheckout});

  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = ref.watch(moneyProvider);
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final summary = cart.summary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.cart, style: theme.textTheme.titleLarge),
              ),
              if (!cart.isEmpty)
                TextButton(
                  onPressed: notifier.clear,
                  child: Text(l10n.clearCart),
                ),
            ],
          ),
          Expanded(
            child: cart.isEmpty
                ? Center(child: Text(l10n.cartEmpty))
                : ListView(
                    children: [
                      for (final line in cart.lines)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      money(line.unitPrice),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => notifier.setQuantity(
                                  line.variantId,
                                  line.quantity - 1,
                                ),
                              ),
                              Text(
                                '${line.quantity}',
                                style: theme.textTheme.titleMedium,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => notifier.setQuantity(
                                  line.variantId,
                                  line.quantity + 1,
                                ),
                              ),
                              SizedBox(
                                width: 72,
                                child: Text(
                                  money(line.unitPrice * line.quantity),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const Divider(),
          _SummaryRow(label: l10n.subtotal, value: money(summary.subtotal)),
          InkWell(
            onTap: cart.isEmpty
                ? null
                : () async {
                    final d = await showDiscountDialog(context, cart.discount);
                    if (d != null) notifier.setDiscount(d);
                  },
            child: _SummaryRow(
              label: l10n.discount,
              value: summary.discount == 0
                  ? '—'
                  : '−${money(summary.discount)}',
              trailing: const Icon(Icons.chevron_right, size: 18),
            ),
          ),
          const SizedBox(height: 4),
          _SummaryRow(
            label: l10n.total,
            value: money(summary.total),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: cart.isEmpty ? null : onCheckout,
            child: Text(l10n.checkout),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.style,
    this.trailing,
  });

  final String label;
  final String value;
  final TextStyle? style;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
          ?trailing,
        ],
      ),
    );
  }
}

/// 手机底部的购物车条：件数、合计、结账。点击展开完整购物车。
class CartBar extends ConsumerWidget {
  const CartBar({super.key, required this.onCheckout});

  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = ref.watch(moneyProvider);
    final cart = ref.watch(cartProvider);
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: InkWell(
        onTap: cart.isEmpty
            ? null
            : () => showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (sheetContext) => SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.75,
                  child: CartPanel(
                    onCheckout: () {
                      Navigator.pop(sheetContext);
                      onCheckout();
                    },
                  ),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Badge(
                isLabelVisible: !cart.isEmpty,
                label: Text('${cart.itemCount}'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  cart.isEmpty
                      ? l10n.itemCount(0)
                      : '${l10n.itemCount(cart.itemCount)} · ${money(cart.summary.total)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton(
                onPressed: cart.isEmpty ? null : onCheckout,
                child: Text(l10n.checkout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
