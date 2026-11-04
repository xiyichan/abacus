import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/empty_state.dart';
import '../../ui/money.dart';
import '../settings/support_page.dart';
import 'event_dates.dart';

/// 结束场次：先展示本场销售和剩余汇总，确认后标记结束。返回是否已结束。
Future<bool> confirmEndEvent(
  BuildContext context,
  WidgetRef ref,
  Event event,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final money = ref.read(moneyProvider);
  final db = ref.read(databaseProvider);
  final remaining = await db.stockAt(event.id);
  final stats = await ref
      .read(salesRepositoryProvider)
      .watchEventStats(event.id)
      .first;
  final catalog = await ref.read(catalogProvider.future);
  final names = {
    for (final p in catalog)
      for (final v in p.variants) v.id: p.displayName(v),
  };
  final left = [
    for (final MapEntry(key: id, value: qty) in remaining.entries)
      if (qty > 0) (names[id] ?? '?', qty),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  final oversold = [
    for (final MapEntry(key: id, value: qty) in remaining.entries)
      if (qty < 0) (names[id] ?? '?', -qty),
  ];
  final total = left.fold<int>(0, (a, e) => a + e.$2);
  if (!context.mounted) return false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: Text(l10n.endEventTitle(event.name)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.endEventSales(stats.orderCount, money(stats.revenue)),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                if (left.isEmpty)
                  Text(l10n.endEventNothing)
                else ...[
                  Text(l10n.endEventReturn(total)),
                  const SizedBox(height: 4),
                  for (final (name, qty) in left.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('×$qty'),
                        ],
                      ),
                    ),
                  if (left.length > 8)
                    Text(
                      l10n.endEventMore(left.length),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
                for (final (name, qty) in oversold)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.endEventOversold(name, qty),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  l10n.endEventHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.endEvent),
          ),
        ],
      );
    },
  );
  if (ok != true) return false;
  await ref.read(inventoryRepositoryProvider).endEvent(event.id);
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.eventEndedDone(event.name, total))),
  );
  if (context.mounted) {
    await maybeAskForTip(
      context,
      ref,
      eventName: event.name,
      orders: stats.orderCount,
    );
  }
  return true;
}

Future<bool> confirmReopenEvent(
  BuildContext context,
  WidgetRef ref,
  Event event,
) async {
  final l10n = AppLocalizations.of(context);
  final ok = await confirmDialog(
    context,
    title: l10n.reopenEventTitle(event.name),
    body: l10n.reopenEventBody,
    confirmLabel: l10n.reopenEvent,
    cancelLabel: l10n.cancel,
  );
  if (!ok) return false;
  await ref.read(inventoryRepositoryProvider).reopenEvent(event.id);
  return true;
}

/// 切换或新建场次前：如果上一场还没结束且还有剩余货，问一下要不要先结束它。
Future<void> promptEndPrevious(
  BuildContext context,
  WidgetRef ref, {
  String? nextEventId,
}) async {
  final currentId = await ref.read(currentEventIdProvider.future);
  if (currentId == null || currentId == nextEventId) return;
  final events = await ref.read(eventsProvider.future);
  final current = events.where((e) => e.id == currentId).firstOrNull;
  if (current == null || current.endedAt != null) return;
  final remaining = await ref.read(databaseProvider).stockAt(current.id);
  final total = remaining.values
      .where((q) => q > 0)
      .fold<int>(0, (a, q) => a + q);
  if (total == 0 || !context.mounted) return;

  final l10n = AppLocalizations.of(context);
  final ok = await confirmDialog(
    context,
    title: l10n.endPreviousTitle(current.name),
    body: l10n.endPreviousBody(total),
    confirmLabel: l10n.endPreviousConfirm(current.name),
    cancelLabel: l10n.later,
  );
  if (ok && context.mounted) await confirmEndEvent(context, ref, current);
}

String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// 场次日期已过但还没结束时，收银台顶部的提醒。“还没结束”当天不再提示。
class EndEventReminder extends ConsumerStatefulWidget {
  const EndEventReminder({super.key, required this.event});

  final Event event;

  @override
  ConsumerState<EndEventReminder> createState() => _EndEventReminderState();
}

class _EndEventReminderState extends ConsumerState<EndEventReminder> {
  bool _dismissed = true;

  String get _key => 'endPromptDismissed:${widget.event.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EndEventReminder old) {
    super.didUpdateWidget(old);
    if (old.event.id != widget.event.id) _load();
  }

  Future<void> _load() async {
    // 多天的展到最后一天过了才提醒。
    final lastDay = widget.event.lastDay;
    final today = DateUtils.dateOnly(DateTime.now());
    final past = lastDay != null && DateUtils.dateOnly(lastDay).isBefore(today);
    final dismissedOn = await ref.read(databaseProvider).getSetting(_key);
    if (mounted) setState(() => _dismissed = !past || dismissedOn == _today());
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || widget.event.endedAt != null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return MaterialBanner(
      leading: const Icon(Icons.event_available_outlined),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.endPromptTitle(widget.event.name)),
          Text(
            l10n.endPromptBody,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await ref.read(databaseProvider).setSetting(_key, _today());
            if (mounted) setState(() => _dismissed = true);
          },
          child: Text(l10n.notYet),
        ),
        FilledButton(
          onPressed: () => confirmEndEvent(context, ref, widget.event),
          child: Text(l10n.endEvent),
        ),
      ],
    );
  }
}
