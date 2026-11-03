import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pos/menu.dart';
import '../../data/catalog_repository.dart';
import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/grouped_list.dart';
import '../../ui/large_title_page.dart';
import '../../ui/layout.dart';
import '../../ui/design.dart';
import '../../ui/empty_state.dart';
import '../../ui/media.dart';
import '../../ui/money.dart';
import '../team/team_switcher.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  String _query = '';

  /// 只看某个分类；null 为全部。
  String? _categoryId;

  bool _matches(
    CatalogProduct item,
    String? categoryId,
    Map<String, ProductCategory> categories,
  ) {
    if (categoryId != null && !item.categoryIds.contains(categoryId)) {
      return false;
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final p = item.product;
    return [
      p.name,
      p.tags,
      item.creator?.name ?? '',
      for (final v in item.variants) v.label,
      for (final id in item.categoryIds) categories[id]?.name ?? '',
    ].any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final catalog = ref.watch(catalogProvider);
    final categoryList = ref.watch(categoriesProvider).value ?? const [];
    final categories = {for (final c in categoryList) c.id: c};
    // 选中的分类被删掉后回到全部。
    final categoryId = categories.containsKey(_categoryId) ? _categoryId : null;
    return LargeTitlePage(
      title: l10n.navProducts,
      leading: const TeamSwitcherButton(),
      actions: [
        BarButton(
          icon: CupertinoIcons.square_grid_2x2,
          tooltip: l10n.manageCategories,
          label: context.isTablet ? l10n.manageCategories : null,
          onPressed: () => context.go('/products/categories'),
        ),
        BarButton(
          icon: CupertinoIcons.add,
          tooltip: l10n.addProduct,
          onPressed: () => context.go('/products/new'),
        ),
      ],
      slivers: switch (catalog) {
        AsyncData(value: final items) when items.isEmpty => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: CupertinoIcons.cube_box,
              title: l10n.noProducts,
              actionLabel: l10n.addProduct,
              onAction: () => context.go('/products/new'),
            ),
          ),
        ],
        AsyncData(value: final items) => () {
          final shown = [
            for (final p in items)
              if (_matches(p, categoryId, categories)) p,
          ];
          return [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xs),
              sliver: SliverList.list(
                children: [
                  // 合并读屏信息：整个胶囊都算搜索框的点击区域。
                  MergeSemantics(
                    child: SearchBar(
                      hintText: l10n.searchProductsHint,
                      leading: const Icon(CupertinoIcons.search),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  if (categoryList.isNotEmpty) ...[
                    const SizedBox(height: Gap.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: [
                          for (final (id, name) in [
                            (null, l10n.filterAll),
                            for (final c in categoryList) (c.id, c.name),
                          ])
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: Gap.sm,
                              ),
                              child: ChoiceChip(
                                label: Text(name),
                                selected: categoryId == id,
                                onSelected: (_) =>
                                    setState(() => _categoryId = id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      Gap.md,
                      Gap.lg,
                      0,
                    ),
                    child: Text(
                      l10n.productTotal(shown.length),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (shown.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(Gap.xl),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    l10n.noMatchingProducts,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: GroupedSection(
                  dividerIndent: _ProductTile.textIndent,
                  children: [
                    for (final p in shown)
                      _ProductTile(item: p, categories: categories),
                  ],
                ),
              ),
          ];
        }(),
        AsyncError(:final error, :final stackTrace) => [
          SliverFillRemaining(child: asyncError(error, stackTrace)),
        ],
        _ => const [SliverFillRemaining(child: asyncLoading)],
      },
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.item, required this.categories});

  static const _imageSize = 56.0;

  /// 分隔线从文字开始画：左内边距 + 缩略图 + 间距。
  static const textIndent = Gap.lg + _imageSize + Gap.md;

  final CatalogProduct item;
  final Map<String, ProductCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = ref.watch(moneyProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = item.product;
    final prices = [for (final v in item.variants) v.price]..sort();
    final priceText = prices.isEmpty
        ? ''
        : prices.first == prices.last
        ? money(prices.first)
        : l10n.priceFrom(money(prices.first));

    final meta = <String>[
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
      ...productTags(p.tags),
    ];
    final categoryNames = [
      for (final id in item.categoryIds) ?categories[id]?.name,
    ];
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return InkWell(
      onTap: () => context.go('/products/${p.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.md, Gap.md),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: SizedBox.square(
                dimension: _imageSize,
                child: StoredImage(
                  p.imagePath,
                  placeholder: NamePlaceholder(p.name),
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  ],
                  if (categoryNames.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: Gap.xs,
                      runSpacing: Gap.xs,
                      children: [
                        for (final name in categoryNames) _CategoryPill(name),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Text(
              priceText,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: Gap.xs),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// 商品所属分类的小标签。
class _CategoryPill extends StatelessWidget {
  const _CategoryPill(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 2),
        child: Text(
          name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
