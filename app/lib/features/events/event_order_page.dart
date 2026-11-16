import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_repository.dart';
import '../../data/inventory_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../ui/design.dart';
import '../../ui/empty_state.dart';
import '../../ui/layout.dart';
import '../../ui/media.dart';
import '../pos/menu.dart';

/// 调整某一场收银台的顺序：左边分类栏的分组、商品。只影响这一场。
class EventOrderPage extends ConsumerStatefulWidget {
  const EventOrderPage({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventOrderPage> createState() => _EventOrderPageState();
}

class _EventOrderPageState extends ConsumerState<EventOrderPage> {
  /// 拖完还没等数据库回来时先按新顺序显示，免得闪回去。
  List<String>? _groups;
  List<String>? _products;

  void _move(List<String> keys, int from, int to, {required bool groups}) {
    final order = [...keys];
    order.insert(to, order.removeAt(from));
    setState(() => groups ? _groups = order : _products = order);
    final repo = ref.read(inventoryRepositoryProvider);
    if (groups) {
      repo.setEventOrder(widget.eventId, groups: order);
    } else {
      repo.setEventOrder(widget.eventId, products: order);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    ref.listen(eventsProvider, (_, _) {
      if (_groups != null || _products != null) {
        setState(() => _groups = _products = null);
      }
    });
    final event = ref
        .watch(eventsProvider)
        .value
        ?.where((e) => e.id == widget.eventId)
        .firstOrNull;
    final catalog = ref.watch(catalogProvider).value;
    final stock = ref.watch(stockProvider(widget.eventId)).value;
    if (event == null || catalog == null || stock == null) {
      return Scaffold(appBar: AppBar(), body: asyncLoading);
    }

    final sections = orderMenu(
      menuSections(
        [
          for (final p in catalog)
            if (stockedAtEvent(p, stock)) p,
        ],
        (p) => p,
        ref.watch(categoriesProvider).value ?? const [],
      ),
      groupOrder: _groups ?? decodeOrder(event.groupOrder),
      productOrder: _products ?? decodeOrder(event.productOrder),
      idOf: (p) => p.product.id,
    );
    final groupKeys = [for (final s in sections) groupKeyOf(s)];
    String titleOf(MenuSection<CatalogProduct> s) =>
        s.title ?? (sections.length == 1 ? l10n.all : l10n.otherCategory);
    // 一件商品可能在好几组里，排序时只算第一次出现的位置。
    final products = <String, CatalogProduct>{
      for (final s in sections)
        for (final p in s.items) p.product.id: p,
    };
    final productIds = products.keys.toList();

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.eventOrderTitle(event.name))),
      body: products.isEmpty
          ? EmptyState(
              icon: Icons.inventory_outlined,
              title: l10n.noStockTitle,
              body: l10n.noStockBody,
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Gap.xl,
                          Gap.sm,
                          Gap.xl,
                          0,
                        ),
                        child: Text(
                          l10n.eventOrderHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    if (sections.length > 1) ...[
                      SliverToBoxAdapter(child: header(l10n.eventOrderGroups)),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                        sliver: SliverReorderableList(
                          itemCount: sections.length,
                          onReorderItem: (from, to) =>
                              _move(groupKeys, from, to, groups: true),
                          itemBuilder: (context, i) => _OrderRow(
                            key: ValueKey('g:${groupKeys[i]}'),
                            index: i,
                            title: titleOf(sections[i]),
                            subtitle: l10n.categorySize(
                              sections[i].items.length,
                            ),
                            first: i == 0,
                            last: i == sections.length - 1,
                          ),
                        ),
                      ),
                    ],
                    SliverToBoxAdapter(child: header(l10n.eventOrderProducts)),
                    SliverPadding(
                      padding: withBottomBar(
                        context,
                        const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
                      ),
                      sliver: SliverReorderableList(
                        itemCount: productIds.length,
                        onReorderItem: (from, to) =>
                            _move(productIds, from, to, groups: false),
                        itemBuilder: (context, i) {
                          final p = products[productIds[i]]!.product;
                          return _OrderRow(
                            key: ValueKey('p:${p.id}'),
                            index: i,
                            image: p.imagePath,
                            imageName: p.name,
                            title: p.name,
                            first: i == 0,
                            last: i == productIds.length - 1,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// 一行：（商品有缩略图）名字，右边是拖动把手。整列是一张圆角卡片。
class _OrderRow extends StatelessWidget {
  const _OrderRow({
    super.key,
    required this.index,
    required this.title,
    required this.first,
    required this.last,
    this.subtitle,
    this.image,
    this.imageName,
  });

  static const _imageSize = 44.0;

  final int index;
  final String title;
  final String? subtitle;

  /// 商品图片；分组那一列为 null 且 [imageName] 也为 null（不显示图）。
  final String? image;
  final String? imageName;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    const r = Radius.circular(Radii.card);
    final hasImage = imageName != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.vertical(
            top: first ? r : Radius.zero,
            bottom: last ? r : Radius.zero,
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsetsDirectional.only(
              start: Gap.lg,
              end: Gap.xs,
            ),
            leading: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    child: SizedBox.square(
                      dimension: _imageSize,
                      child: StoredImage(
                        image,
                        placeholder: NamePlaceholder(imageName!),
                      ),
                    ),
                  )
                : null,
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: subtitle == null ? null : Text(subtitle!),
            trailing: ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: l10n.moveHandle,
                child: SizedBox.square(
                  dimension: minTapSize,
                  child: Icon(
                    CupertinoIcons.line_horizontal_3,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!last)
          ColoredBox(
            color: theme.colorScheme.surfaceContainer,
            child: Divider(
              height: 1,
              indent: hasImage ? Gap.lg + _imageSize + Gap.lg : Gap.lg,
            ),
          ),
      ],
    );
  }
}
