import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/checkout.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/money.dart';

enum _Mode { amountOff, percentOff, fixedTotal }

/// 设置整单优惠。返回 null 表示取消，返回 [NoDiscount] 表示取消优惠。
Future<Discount?> showDiscountDialog(BuildContext context, Discount current) =>
    showDialog<Discount>(
      context: context,
      builder: (_) => _DiscountDialog(current: current),
    );

class _DiscountDialog extends ConsumerStatefulWidget {
  const _DiscountDialog({required this.current});

  final Discount current;

  @override
  ConsumerState<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends ConsumerState<_DiscountDialog> {
  late _Mode _mode = switch (widget.current) {
    PercentOff() => _Mode.percentOff,
    FixedTotal() => _Mode.fixedTotal,
    _ => _Mode.amountOff,
  };
  late final _value = TextEditingController(
    text: switch (widget.current) {
      AmountOff(:final amount) => moneyInputText(amount),
      PercentOff(:final percentOff) => '$percentOff',
      FixedTotal(:final total) => moneyInputText(total),
      _ => '',
    },
  );
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final Discount? result = switch (_mode) {
      _Mode.amountOff => parseMoney(_value.text).let(AmountOff.new),
      _Mode.fixedTotal => parseMoney(_value.text).let(FixedTotal.new),
      _Mode.percentOff => int.tryParse(
        _value.text,
      ).let((p) => p > 100 ? null : PercentOff(p)),
    };
    if (result == null) {
      setState(
        () => _error = _mode == _Mode.percentOff
            ? l10n.invalidNumber
            : l10n.invalidAmount,
      );
      return;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(currencySymbolProvider);
    final isPercent = _mode == _Mode.percentOff;
    return AlertDialog(
      title: Text(l10n.discountTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<_Mode>(
              segments: [
                ButtonSegment(
                  value: _Mode.amountOff,
                  label: Text(l10n.discountAmountOff),
                ),
                ButtonSegment(
                  value: _Mode.percentOff,
                  label: Text(l10n.discountPercentOff),
                ),
                ButtonSegment(
                  value: _Mode.fixedTotal,
                  label: Text(l10n.discountFixedTotal),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.single;
                _value.clear();
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _value,
              autofocus: true,
              keyboardType: isPercent ? TextInputType.number : moneyKeyboard,
              inputFormatters: isPercent
                  ? intInputFormatters
                  : moneyInputFormatters,
              decoration: InputDecoration(
                prefixText: isPercent ? null : '$currency ',
                suffixText: isPercent ? '%' : null,
                helperText: isPercent ? l10n.discountPercentHint : null,
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.current is! NoDiscount)
          TextButton(
            onPressed: () => Navigator.pop(context, const NoDiscount()),
            child: Text(l10n.removeDiscount),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.confirm)),
      ],
    );
  }
}

extension<T extends Object> on T? {
  R? let<R>(R? Function(T) f) {
    final self = this;
    return self == null ? null : f(self);
  }
}
