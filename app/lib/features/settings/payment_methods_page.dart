import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/sales_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/empty_state.dart';
import '../../ui/media.dart';

String paymentKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  PaymentKind.cash => l10n.paymentKindCash,
  PaymentKind.qr => l10n.paymentKindQr,
  PaymentKind.card => l10n.paymentKindCard,
  _ => l10n.paymentKindOther,
};

class PaymentMethodsPage extends ConsumerWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final methods = ref.watch(paymentMethodsProvider);
    final repo = ref.read(salesRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentMethods)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) =>
              _PaymentMethodDialog(sortOrder: methods.value?.length ?? 0),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.addPaymentMethod),
      ),
      body: methods.when(
        loading: () => asyncLoading,
        error: asyncError,
        data: (methods) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final m in methods)
              ListTile(
                leading: SizedBox.square(
                  dimension: 40,
                  child: m.qrImagePath == null
                      ? Icon(switch (m.kind) {
                          PaymentKind.cash => Icons.payments_outlined,
                          PaymentKind.qr => Icons.qr_code_2,
                          PaymentKind.card => Icons.credit_card,
                          _ => Icons.account_balance_wallet_outlined,
                        })
                      : StoredImage(m.qrImagePath),
                ),
                title: Text(m.name),
                subtitle: Text(paymentKindLabel(l10n, m.kind)),
                trailing: Switch(
                  value: m.enabled,
                  onChanged: (v) => repo.savePaymentMethod(
                    id: m.id,
                    name: m.name,
                    kind: m.kind,
                    qrImagePath: m.qrImagePath,
                    sortOrder: m.sortOrder,
                    enabled: v,
                  ),
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      _PaymentMethodDialog(method: m, sortOrder: m.sortOrder),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodDialog extends ConsumerStatefulWidget {
  const _PaymentMethodDialog({this.method, required this.sortOrder});

  final PaymentMethod? method;
  final int sortOrder;

  @override
  ConsumerState<_PaymentMethodDialog> createState() =>
      _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends ConsumerState<_PaymentMethodDialog> {
  late final _name = TextEditingController(text: widget.method?.name);
  late String _kind = widget.method?.kind ?? PaymentKind.qr;
  late String? _qr = widget.method?.qrImagePath;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l10n.required);
      return;
    }
    await ref
        .read(salesRepositoryProvider)
        .savePaymentMethod(
          id: widget.method?.id,
          name: _name.text,
          kind: _kind,
          qrImagePath: _kind == PaymentKind.qr ? _qr : null,
          enabled: widget.method?.enabled ?? true,
          sortOrder: widget.sortOrder,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref
        .read(salesRepositoryProvider)
        .deletePaymentMethod(widget.method!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.method == null ? l10n.addPaymentMethod : l10n.editPaymentMethod,
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: widget.method == null,
                decoration: InputDecoration(
                  labelText: l10n.paymentName,
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final kind in [
                    PaymentKind.cash,
                    PaymentKind.qr,
                    PaymentKind.card,
                    PaymentKind.other,
                  ])
                    ChoiceChip(
                      label: Text(paymentKindLabel(l10n, kind)),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              if (_kind == PaymentKind.qr) ...[
                const SizedBox(height: 16),
                if (_qr != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: StoredImage(_qr, fit: BoxFit.contain),
                  ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final name = await pickAndStoreImage(ref);
                        if (name != null) setState(() => _qr = name);
                      },
                      icon: const Icon(Icons.qr_code_2),
                      label: Text(l10n.uploadQr),
                    ),
                    if (_qr != null)
                      TextButton(
                        onPressed: () => setState(() => _qr = null),
                        child: Text(l10n.removeImage),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.method != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _delete,
            child: Text(l10n.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
