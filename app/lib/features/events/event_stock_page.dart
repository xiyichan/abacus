import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/stock.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/empty_state.dart';
import '../../ui/input_dialog.dart';
import 'end_event.dart';
import '../../ui/money.dart';

/// 备货：每场单独记带了多少件货，可以沿用上一场的剩余。
class EventStockPage extends ConsumerWidget {
  const EventStockPage({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final event = ref
        .watch(eventsProvider)
        .value
        ?.where((e) => e.id == eventId)
        .firstOrNull;
    final catalog = ref.watch(catalogProvider);
    final atEvent = ref.watch(stockProvider(eventId)).value ?? const {};
    final repo = ref.read(inventoryRepositoryProvider);

    Future<void> useLeftover() async {
      final messenger = ScaffoldMessenger.of(context);
      final previous = await repo.previousLeftover(eventId);
      if (!context.mounted) return;
      if (previous == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.noLeftover)));
        return;
      }
      final (from, left) = previous;
      final ok = await confirmDialog(
        context,
        title: l10n.useLeftover,
        body: l10n.useLeftoverBody(
          from.name,
          left.values.fold<int>(0, (a, q) => a + q),
        ),
        confirmLabel: l10n.confirm,
        cancelLabel: l10n.cancel,
      );
      if (!ok) return;
      for (final MapEntry(key: variantId, value: qty) in left.entries) {
        await repo.setEventQuantity(
          variantId: variantId,
          eventId: eventId,
          eventQuantity: qty,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.stockForEvent} · ${event?.name ?? ''}'),
        actions: [
          if (event != null && event.endedAt == null) ...[
            TextButton.icon(
              onPressed: useLeftover,
              icon: const Icon(Icons.history),
              label: Text(l10n.useLeftover),
            ),
            TextButton.icon(
              onPressed: () => confirmEndEvent(context, ref, event),
              icon: const Icon(Icons.event_available_outlined),
              label: Text(l10n.endEvent),
            ),
          ] else if (event != null)
            TextButton.icon(
              onPressed: () => confirmReopenEvent(context, ref, event),
              icon: const Icon(Icons.replay),
              label: Text(l10n.reopenEvent),
            ),
        ],
      ),
      body: catalog.when(
        loading: () => asyncLoading,
        error: asyncError,
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: l10n.noProducts,
            );
          }
          final tiles = <Widget>[];
          for (final p in items) {
            if (p.isBundle) {
              final components = p.components.values.firstOrNull ?? const [];
              tiles.add(
                ListTile(
                  leading: const Icon(Icons.collections_bookmark_outlined),
                  title: Text(p.product.name),
                  subtitle: Text(
                    l10n.bundleAvailable(bundleAvailable(components, atEvent)),
                  ),
                ),
              );
              continue;
            }
            for (final v in p.variants) {
              tiles.add(
                _StockRow(
                  name: p.displayName(v),
                  atEvent: atEvent[v.id],
                  onChanged: (q) => repo.setEventQuantity(
                    variantId: v.id,
                    eventId: eventId,
                    eventQuantity: q,
                  ),
                ),
              );
            }
          }
          return ListView.separated(
            itemCount: tiles.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => tiles[i],
          );
        },
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.name,
    required this.atEvent,
    required this.onChanged,
  });

  final String name;

  /// null 表示还没带到本场。
  final int? atEvent;
  final ValueChanged<int> onChanged;

  Future<void> _edit(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final text = await showInputDialog(
      context,
      title: name,
      label: l10n.eventQty,
      initialValue: '${atEvent ?? 0}',
      keyboardType: TextInputType.number,
      inputFormatters: intInputFormatters,
      confirmLabel: l10n.save,
      cancelLabel: l10n.cancel,
    );
    final value = int.tryParse(text ?? '');
    if (value != null) onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = atEvent ?? 0;
    return ListTile(
      title: Text(
        name,
        style: current < 0 ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: current > 0 ? () => onChanged(current - 1) : null,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _edit(context),
            child: Container(
              constraints: const BoxConstraints(minWidth: 48),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: Alignment.center,
              child: Text(
                atEvent == null ? '—' : '$current',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onChanged(current + 1),
          ),
        ],
      ),
    );
  }
}
