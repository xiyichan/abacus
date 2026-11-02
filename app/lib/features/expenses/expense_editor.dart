import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/expense_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/empty_state.dart';
import '../../ui/layout.dart';
import '../../ui/money.dart';

String expenseCategoryName(AppLocalizations l10n, String key) => switch (key) {
  'travel' => l10n.expenseCat_travel,
  'booth' => l10n.expenseCat_booth,
  'lodging' => l10n.expenseCat_lodging,
  'food' => l10n.expenseCat_food,
  'supplies' => l10n.expenseCat_supplies,
  'shipping' => l10n.expenseCat_shipping,
  _ => l10n.expenseCat_other,
};

IconData expenseCategoryIcon(String key) => switch (key) {
  'travel' => Icons.train_outlined,
  'booth' => Icons.storefront_outlined,
  'lodging' => Icons.hotel_outlined,
  'food' => Icons.restaurant_outlined,
  'supplies' => Icons.print_outlined,
  'shipping' => Icons.local_shipping_outlined,
  _ => Icons.more_horiz,
};

/// 记一笔或修改支出：平板用对话框，手机用底部弹层。
/// 新建时默认归到 [eventId]（通常是当前场次）。
Future<void> showExpenseEditor(
  BuildContext context, {
  Expense? existing,
  String? eventId,
}) {
  final editor = _ExpenseEditor(
    existing: existing,
    eventId: existing?.eventId ?? eventId,
  );
  if (context.isTablet) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: editor,
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => editor,
  );
}

class _ExpenseEditor extends ConsumerStatefulWidget {
  const _ExpenseEditor({this.existing, this.eventId});

  final Expense? existing;
  final String? eventId;

  @override
  ConsumerState<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends ConsumerState<_ExpenseEditor> {
  late String _category = widget.existing?.category ?? expenseCategories.first;
  late String? _eventId = widget.eventId;
  late DateTime _spentOn = widget.existing?.spentOn ?? DateTime.now();
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : moneyInputText(widget.existing!.amount),
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentOn,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _spentOn = picked);
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text);
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    final repo = ref.read(expenseRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final money = ref.read(moneyProvider);
    final existing = widget.existing;
    if (existing == null) {
      await repo.addExpense(
        eventId: _eventId,
        category: _category,
        amount: amount,
        note: _note.text,
        spentOn: _spentOn,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.expenseSaved(money(amount)))),
      );
    } else {
      await repo.updateExpense(
        existing.id,
        eventId: _eventId,
        category: _category,
        amount: amount,
        note: _note.text,
        spentOn: _spentOn,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l10n.deleteExpenseTitle,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(expenseRepositoryProvider)
        .deleteExpense(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currency = ref.watch(currencySymbolProvider);
    final events = ref.watch(eventsProvider).value ?? const <Event>[];
    final amount = parseMoney(_amount.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? l10n.newExpense : l10n.editExpense,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(l10n.expenseCategory, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in expenseCategories)
                  ChoiceChip(
                    avatar: Icon(expenseCategoryIcon(c), size: 18),
                    label: Text(expenseCategoryName(l10n, c)),
                    selected: c == _category,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: widget.existing == null,
              keyboardType: moneyKeyboard,
              inputFormatters: moneyInputFormatters,
              decoration: InputDecoration(
                labelText: l10n.expenseAmount,
                prefixText: '$currency ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l10n.expenseNote,
                hintText: l10n.expenseNoteHint,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: events.any((e) => e.id == _eventId)
                  ? _eventId
                  : null,
              decoration: InputDecoration(labelText: l10n.expenseEvent),
              items: [
                for (final e in events)
                  DropdownMenuItem(value: e.id, child: Text(e.name)),
                DropdownMenuItem(child: Text(l10n.expenseNoEvent)),
              ],
              onChanged: (v) => setState(() => _eventId = v),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(l10n.expenseDate),
              trailing: Text(DateFormat('yyyy-MM-dd').format(_spentOn)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: amount != null && amount > 0 && !_saving
                  ? _save
                  : null,
              child: Text(l10n.save),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: _delete,
                child: Text(l10n.delete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
