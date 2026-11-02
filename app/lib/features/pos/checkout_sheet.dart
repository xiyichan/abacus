import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/sales_repository.dart';
import '../../domain/checkout.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/grouped_list.dart';
import '../../ui/layout.dart';
import '../../ui/media.dart';
import '../../ui/money.dart';
import 'cart.dart';

/// 打开结账界面：平板用对话框，手机用底部弹层。成功后清空购物车并提示单号。
Future<void> startCheckout(BuildContext context, String eventId) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final ({Order order, bool pending})? result;
  if (context.isTablet) {
    result = await showDialog<({Order order, bool pending})>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
          child: CheckoutSheet(eventId: eventId),
        ),
      ),
    );
  } else {
    result = await showModalBottomSheet<({Order order, bool pending})>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => CheckoutSheet(eventId: eventId),
    );
  }
  if (result != null) {
    final number = result.order.number;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.pending
              ? l10n.orderSavedPending(number)
              : l10n.orderSaved(number),
        ),
      ),
    );
  }
}

class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  String? _methodId;
  final _tendered = TextEditingController();
  bool _saving = false;

  /// 预先确定的单号，去掉横杠后作为付款备注码给客人看。
  String? _number;

  @override
  void initState() {
    super.initState();
    _tendered.addListener(() => setState(() {}));
    ref.read(salesRepositoryProvider).nextOrderNumber(widget.eventId).then((n) {
      if (mounted) setState(() => _number = n);
    });
  }

  @override
  void dispose() {
    _tendered.dispose();
    super.dispose();
  }

  /// 现金快捷金额：刚好，以及凑整到 10 / 50 / 100。
  List<int> _quickAmounts(int total) {
    final amounts = <int>{total};
    for (final step in [1000, 5000, 10000]) {
      final rounded = (total + step - 1) ~/ step * step;
      if (rounded > total) amounts.add(rounded);
    }
    return amounts.toList()..sort();
  }

  Future<void> _confirm(
    PaymentMethod method,
    CartState cart,
    int? tendered, {
    bool pending = false,
  }) async {
    setState(() => _saving = true);
    try {
      final order = await ref
          .read(salesRepositoryProvider)
          .placeOrder(
            eventId: widget.eventId,
            lines: cart.lines,
            paymentMethod: method,
            discount: cart.discount,
            tendered: tendered,
            number: _number,
            paymentPending: pending,
          );
      ref.read(cartProvider.notifier).clear();
      if (mounted) Navigator.pop(context, (order: order, pending: pending));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = ref.watch(moneyProvider);
    final currency = ref.watch(currencySymbolProvider);
    final cart = ref.watch(cartProvider);
    final total = cart.summary.total;
    final methods = ref.watch(enabledPaymentMethodsProvider).value ?? const [];
    final method =
        methods.where((m) => m.id == _methodId).firstOrNull ??
        methods.firstOrNull;
    final isCash = method?.kind == PaymentKind.cash;
    final tendered = isCash ? parseMoney(_tendered.text) : null;
    final change = tendered == null
        ? null
        : changeDue(total: total, tendered: tendered);
    final canConfirm =
        method != null &&
        !_saving &&
        !cart.isEmpty &&
        (!isCash || _tendered.text.isEmpty || change != null);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.total, style: theme.textTheme.titleMedium),
            Text(money(total), style: theme.textTheme.displaySmall),
            if (cart.summary.discount > 0)
              Text(
                '${l10n.subtotal} ${money(cart.summary.subtotal)} · '
                '${l10n.discount} −${money(cart.summary.discount)}',
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 20),
            Text(l10n.paymentMethod, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (methods.isEmpty)
              Text(l10n.noPaymentMethods)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in methods)
                    ChoiceChip(
                      label: Text(m.name),
                      selected: m.id == method?.id,
                      onSelected: (_) => setState(() => _methodId = m.id),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            if (isCash) ...[
              TextField(
                controller: _tendered,
                keyboardType: moneyKeyboard,
                inputFormatters: moneyInputFormatters,
                decoration: InputDecoration(
                  labelText: l10n.cashTendered,
                  prefixText: '$currency ',
                  errorText: _tendered.text.isNotEmpty && change == null
                      ? l10n.notEnoughCash
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final a in _quickAmounts(total))
                    ActionChip(
                      label: Text(a == total ? l10n.exactAmount : money(a)),
                      onPressed: () => _tendered.text = moneyInputText(a),
                    ),
                ],
              ),
              if (change != null) ...[
                const SizedBox(height: 16),
                LabelValueRow(
                  label: Text(l10n.change, style: theme.textTheme.titleMedium),
                  value: Text(
                    money(change),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ] else if (method != null && method.kind == PaymentKind.qr)
              Center(
                child: method.qrImagePath == null
                    ? Text(l10n.noQrImage, textAlign: TextAlign.center)
                    : ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 280,
                          maxHeight: 280,
                        ),
                        child: StoredImage(
                          method.qrImagePath,
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            if (method != null && !isCash && _number != null) ...[
              const SizedBox(height: 16),
              _PaymentCode(code: paymentCodeOf(_number!)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: canConfirm
                  ? () => _confirm(method, cart, tendered)
                  : null,
              child: Text(isCash ? l10n.confirmPayment : l10n.paymentReceived),
            ),
            if (!isCash && method != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: canConfirm
                    ? () => _confirm(method, cart, null, pending: true)
                    : null,
                child: Text(l10n.confirmLater),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 付款备注码：大字显示，请客人付款时填进备注，事后好对上是哪一单。
class _PaymentCode extends StatelessWidget {
  const _PaymentCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context).paymentRemarkHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            code,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
