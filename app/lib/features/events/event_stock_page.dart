import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_repository.dart';
import '../../data/database.dart';
import '../../domain/stock.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/design.dart';
import '../../ui/empty_state.dart';
import '../../ui/input_dialog.dart';
import '../../ui/media.dart';
import '../../ui/money.dart';
import 'end_event.dart';

/// 备货：每场单独记带了多少件货，可以沿用上一场的剩余。
/// 商品按作者分组，点组标题可以折叠不想看的作者。
class EventStockPage extends ConsumerStatefulWidget {
  const EventStockPage({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventStockPage> createState() => _EventStockPageState();
}

class _EventStockPageState extends ConsumerState<EventStockPage> {
  /// 折叠起来的作者 id（null 是未设置作者）。
  final _collapsed = <String?>{};

  String get eventId => widget.eventId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final event = ref
        .watch(eventsProvider)
        .value
        ?.where((e) => e.id == eventId)
        .firstOrNull;
    final catalog = ref.watch(catalogProvider);
    final creators = ref.watch(creatorsProvider).value ?? const <Creator>[];
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

    Future<void> removeFromEvent(String variantId) async {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await repo.removeFromEvent(
        variantId: variantId,
        eventId: eventId,
      );
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.cannotRemoveFromEvent)),
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
          // 按作者分组：作者列表的顺序，未设置作者放最后。
          final known = {for (final c in creators) c.id};
          final groups = <String?, List<CatalogProduct>>{
            for (final c in creators) c.id: [],
          };
          for (final p in items) {
            final id = p.creator?.id;
            groups.putIfAbsent(known.contains(id) ? id : null, () => []).add(p);
          }
          final names = {for (final c in creators) c.id: c.name};

          final tiles = <Widget>[];
          for (final MapEntry(key: creatorId, value: products)
              in groups.entries) {
            if (products.isEmpty) continue;
            final variantIds = [
              for (final p in products)
                if (!p.isBundle)
                  for (final v in p.variants) v.id,
            ];
            final collapsed = _collapsed.contains(creatorId);
            tiles.add(
              _GroupHeader(
                name: names[creatorId] ?? l10n.noCreator,
                summary: l10n.stockGroupSummary(
                  variantIds.where(atEvent.containsKey).length,
                  variantIds.length,
                  variantIds.fold<int>(
                    0,
                    (a, id) => a + ((atEvent[id] ?? 0).clamp(0, 1 << 30)),
                  ),
                ),
                collapsed: collapsed,
                onTap: () => setState(() {
                  if (!_collapsed.remove(creatorId)) _collapsed.add(creatorId);
                }),
              ),
            );
            if (collapsed) continue;
            for (final p in products) {
              if (p.isBundle) {
                final components = p.components.values.firstOrNull ?? const [];
                tiles.add(
                  ListTile(
                    leading: _Thumbnail(p.product.imagePath, p.product.name),
                    title: Text(p.product.name),
                    subtitle: Text(
                      l10n.bundleAvailable(
                        bundleAvailable(components, atEvent),
                      ),
                    ),
                  ),
                );
                continue;
              }
              for (final v in p.variants) {
                tiles.add(
                  _StockRow(
                    name: p.displayName(v),
                    imagePath: p.product.imagePath,
                    atEvent: atEvent[v.id],
                    onChanged: (q) => repo.setEventQuantity(
                      variantId: v.id,
                      eventId: eventId,
                      eventQuantity: q,
                    ),
                    onRemove: () => removeFromEvent(v.id),
                  ),
                );
              }
            }
          }
          return ListView.separated(
            itemCount: tiles.length,
            separatorBuilder: (_, i) =>
                i + 1 < tiles.length && tiles[i + 1] is _GroupHeader
                ? const SizedBox.shrink()
                : const Divider(height: 1),
            itemBuilder: (_, i) => tiles[i],
          );
        },
      ),
    );
  }
}

/// 作者分组标题：名字、已备货款数和件数，点一下折叠/展开。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.name,
    required this.summary,
    required this.collapsed,
    required this.onTap,
  });

  final String name;
  final String summary;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              AnimatedRotation(
                turns: collapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(Icons.expand_more),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.name,
    required this.imagePath,
    required this.atEvent,
    required this.onChanged,
    required this.onRemove,
  });

  final String name;
  final String? imagePath;

  /// null 表示还没带到本场。
  final int? atEvent;
  final ValueChanged<int> onChanged;

  /// 数量为 0 时再减：移出本场，回到「—」。
  final VoidCallback onRemove;

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
      leading: _Thumbnail(imagePath, name),
      title: Text(
        name,
        style: current < 0 ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: atEvent == null || current < 0
                ? null
                : current > 0
                ? () => onChanged(current - 1)
                : onRemove,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
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

/// 商品缩略图，没有图片时是首字色块，和商品列表一样。
class _Thumbnail extends StatelessWidget {
  const _Thumbnail(this.imagePath, this.name);

  final String? imagePath;
  final String name;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Radii.sm),
    child: SizedBox.square(
      dimension: 44,
      child: StoredImage(imagePath, placeholder: NamePlaceholder(name)),
    ),
  );
}
