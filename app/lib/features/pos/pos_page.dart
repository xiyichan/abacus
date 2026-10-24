import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/catalog_repository.dart';
import '../../data/database.dart';
import '../../data/sales_repository.dart';
import '../../domain/stock.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/empty_state.dart';
import '../../ui/layout.dart';
import '../../ui/media.dart';
import '../../ui/money.dart';
import '../events/end_event.dart';
import '../team/sync_status_chip.dart';
import 'cart.dart';
import 'cart_panel.dart';
import 'checkout_sheet.dart';

/// 收银台。平板：左商品网格 + 右常驻购物车；手机：商品网格 + 底部购物车条。
class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final event = ref.watch(currentEventProvider);
    final current = event.value;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: TextButton.icon(
          onPressed: () => context.go('/pos/events'),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_drop_down),
          label: Text(
            current?.name ?? l10n.chooseEvent,
            style: Theme.of(context).textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          if (current != null && current.endedAt == null)
            TextButton.icon(
              onPressed: () => context.go('/pos/events/${current.id}/stock'),
              icon: const Icon(Icons.inventory_outlined),
              label: Text(l10n.stockForEvent),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SyncStatusChip(compact: !context.isTablet),
          ),
        ],
      ),
      body: event.when(
        loading: () => asyncLoading,
        error: asyncError,
        data: (event) => event == null
            ? EmptyState(
                icon: Icons.storefront_outlined,
                title: l10n.noEventTitle,
                body: l10n.noEventBody,
                actionLabel: l10n.chooseEvent,
                onAction: () => context.go('/pos/events'),
              )
            : event.endedAt != null
            ? EmptyState(
                icon: Icons.event_available_outlined,
                title: l10n.eventEndedTitle(event.name),
                body: l10n.eventEndedBody,
                actionLabel: l10n.chooseEvent,
                onAction: () => context.go('/pos/events'),
              )
            : Column(
                children: [
                  EndEventReminder(event: event),
                  Expanded(child: _Till(event: event)),
                ],
              ),
      ),
    );
  }
}

/// 收银台中可售的一件商品，以及它在本场的剩余数量（已扣除购物车占用）。
class _SellableProduct {
  const _SellableProduct(this.item, this.variants, this.remaining);

  final CatalogProduct item;

  /// 本场带了的规格。
  final List<Variant> variants;
  final int remaining;
}

class _Till extends ConsumerStatefulWidget {
  const _Till({required this.event});

  final Event event;

  @override
  ConsumerState<_Till> createState() => _TillState();
}

class _TillState extends ConsumerState<_Till> {
  /// 选中的筛选：null = 全部，`c:作者id` = 作者，`t:标签` = 标签。
  String? _filter;

  Map<String, int> _remaining(Map<String, int> stock, CartState cart) {
    final remaining = Map.of(stock);
    cart.reserved.forEach(
      (id, q) => remaining.update(id, (v) => v - q, ifAbsent: () => -q),
    );
    return remaining;
  }

  List<_SellableProduct> _sellable(
    List<CatalogProduct> catalog,
    Map<String, int> stock,
    Map<String, int> remaining,
  ) => [
    for (final p in catalog)
      if (p.isBundle)
        if (p.components.values.firstOrNull case final comps?
            when comps.isNotEmpty &&
                comps.every((c) => stock.containsKey(c.variantId)))
          _SellableProduct(p, p.variants, bundleAvailable(comps, remaining))
        else
          ...[]
      else if (p.variants.where((v) => stock.containsKey(v.id)).toList()
          case final vs when vs.isNotEmpty)
        _SellableProduct(
          p,
          vs,
          vs.fold(0, (a, v) => a + (remaining[v.id] ?? 0)),
        ),
  ];

  bool _matches(_SellableProduct s) {
    final f = _filter;
    if (f == null) return true;
    if (f.startsWith('c:')) return s.item.product.creatorId == f.substring(2);
    return _tags(s.item.product).contains(f.substring(2));
  }

  static List<String> _tags(Product p) => [
    for (final t in p.tags.split(RegExp(r'[,，]')))
      if (t.trim().isNotEmpty) t.trim(),
  ];

  void _add(_SellableProduct s, Map<String, int> remaining) {
    final notifier = ref.read(cartProvider.notifier);
    final item = s.item;
    if (item.isBundle) {
      final v = item.variants.single;
      notifier.add(
        SaleLine(
          variantId: v.id,
          name: item.product.name,
          unitPrice: v.price,
          quantity: 1,
          components: item.components[v.id] ?? const [],
        ),
      );
    } else if (s.variants.length == 1) {
      final v = s.variants.single;
      notifier.add(
        SaleLine(
          variantId: v.id,
          name: item.displayName(v),
          unitPrice: v.price,
          quantity: 1,
        ),
      );
    } else {
      _chooseVariant(s, remaining);
    }
  }

  void _chooseVariant(_SellableProduct s, Map<String, int> remaining) {
    final l10n = AppLocalizations.of(context);
    final money = ref.read(moneyProvider);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '${s.item.product.name} · ${l10n.chooseVariant}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final v in s.variants)
              ListTile(
                title: Text(v.label),
                subtitle: _StockText(remaining[v.id] ?? 0),
                trailing: Text(money(v.price)),
                onTap: () {
                  ref
                      .read(cartProvider.notifier)
                      .add(
                        SaleLine(
                          variantId: v.id,
                          name: s.item.displayName(v),
                          unitPrice: v.price,
                          quantity: 1,
                        ),
                      );
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogProvider);
    final stock = ref.watch(stockProvider(widget.event.id));
    final cart = ref.watch(cartProvider);
    void checkout() => startCheckout(context, widget.event.id);

    return switch ((catalog, stock)) {
      (AsyncData(value: final catalog), AsyncData(value: final stock)) =>
        Builder(
          builder: (context) {
            final remaining = _remaining(stock, cart);
            final sellable = _sellable(catalog, stock, remaining);
            final Widget grid;
            if (sellable.isEmpty) {
              grid = EmptyState(
                icon: Icons.inventory_outlined,
                title: l10n.noStockTitle,
                body: l10n.noStockBody,
                actionLabel: l10n.goStock,
                onAction: () =>
                    context.go('/pos/events/${widget.event.id}/stock'),
              );
            } else {
              final shown = sellable.where(_matches).toList();
              grid = Column(
                children: [
                  _FilterBar(
                    products: [for (final s in sellable) s.item],
                    selected: _filter,
                    onSelected: (f) => setState(() => _filter = f),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _ProductCard(
                        sellable: shown[i],
                        onTap: () => _add(shown[i], remaining),
                      ),
                    ),
                  ),
                ],
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) =>
                  isTabletWidth(constraints.maxWidth)
                  ? Row(
                      children: [
                        Expanded(child: grid),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 360,
                          child: SafeArea(
                            top: false,
                            left: false,
                            child: CartPanel(onCheckout: checkout),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: grid),
                        CartBar(onCheckout: checkout),
                      ],
                    ),
            );
          },
        ),
      (AsyncError(:final error, :final stackTrace), _) ||
      (
        _,
        AsyncError(:final error, :final stackTrace),
      ) => asyncError(error, stackTrace),
      _ => asyncLoading,
    };
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.products,
    required this.selected,
    required this.onSelected,
  });

  final List<CatalogProduct> products;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final creators = <String, String>{
      for (final p in products)
        if (p.creator case final c?) c.id: c.name,
    };
    final tags = <String>{
      for (final p in products) ..._TillState._tags(p.product),
    };
    if (creators.isEmpty && tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final (value, label) in [
            (null, l10n.all),
            for (final MapEntry(:key, :value) in creators.entries)
              ('c:$key', value),
            for (final t in tags) ('t:$t', '#$t'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected == value,
                onSelected: (_) => onSelected(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.sellable, required this.onTap});

  final _SellableProduct sellable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(moneyProvider);
    final theme = Theme.of(context);
    final p = sellable.item.product;
    final prices = [for (final v in sellable.variants) v.price]..sort();
    final priceText = prices.first == prices.last
        ? money(prices.first)
        : AppLocalizations.of(context).priceFrom(money(prices.first));
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: StoredImage(
                p.imagePath,
                placeholder: NamePlaceholder(p.name),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          priceText,
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StockText(sellable.remaining),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockText extends StatelessWidget {
  const _StockText(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      AppLocalizations.of(context).stockLeft(count),
      style: theme.textTheme.bodySmall?.copyWith(
        color: count <= 0
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: count <= 0 ? FontWeight.bold : null,
      ),
    );
  }
}
