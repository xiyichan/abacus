import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/catalog_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/empty_state.dart';
import '../../ui/media.dart';
import '../../ui/money.dart';

class ProductsPage extends ConsumerWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProducts)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/products/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addProduct),
      ),
      body: catalog.when(
        loading: () => asyncLoading,
        error: asyncError,
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.inventory_2_outlined,
                title: l10n.noProducts,
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 88),
                itemBuilder: (context, i) => _ProductTile(item: items[i]),
              ),
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.item});

  final CatalogProduct item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = ref.watch(moneyProvider);
    final p = item.product;
    final prices = [for (final v in item.variants) v.price]..sort();
    final priceText = prices.isEmpty
        ? ''
        : prices.first == prices.last
        ? money(prices.first)
        : '${money(prices.first)}–${money(prices.last)}';

    final parts = <String>[
      if (item.isBundle)
        l10n.bundleSummary(
          item.components.values.firstOrNull?.fold<int>(
                0,
                (a, c) => a + c.quantity,
              ) ??
              0,
        )
      else if (item.hasVariants)
        l10n.variantCount(item.variants.length),
      ?item.creator?.name,
      if (p.tags.isNotEmpty) p.tags,
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 56,
          child: StoredImage(p.imagePath, placeholder: NamePlaceholder(p.name)),
        ),
      ),
      title: Text(p.name),
      subtitle: parts.isEmpty ? null : Text(parts.join(' · ')),
      trailing: Text(priceText, style: Theme.of(context).textTheme.titleSmall),
      onTap: () => context.go('/products/${p.id}'),
    );
  }
}
