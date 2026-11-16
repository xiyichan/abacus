import '../../data/catalog_repository.dart';
import '../../data/database.dart';

/// 点菜式菜单的一组：分类名和其中的商品。[title] 为 null 表示“其他”（没有标签的商品），
/// 或者所有商品都没有标签时的唯一一组（“全部”）。
class MenuSection<T> {
  const MenuSection(this.title, this.items);

  final String? title;
  final List<T> items;
}

/// 商品标签：中英文逗号分隔，去掉空白。
List<String> productTags(String tags) => [
  for (final t in tags.split(RegExp(r'[,，]')))
    if (t.trim().isNotEmpty) t.trim(),
];

/// 按标签分组：分类按第一次出现的顺序；一个商品有多个标签时出现在每个分类里；
/// 没有标签的放在最后一组（title 为 null）。
List<MenuSection<T>> groupByTags<T>(
  List<T> items,
  List<String> Function(T item) tagsOf,
) {
  final byTag = <String, List<T>>{};
  final untagged = <T>[];
  for (final item in items) {
    final tags = tagsOf(item);
    if (tags.isEmpty) {
      untagged.add(item);
      continue;
    }
    for (final tag in tags) {
      byTag.putIfAbsent(tag, () => []).add(item);
    }
  }
  return [
    for (final MapEntry(:key, :value) in byTag.entries) MenuSection(key, value),
    if (untagged.isNotEmpty) MenuSection(null, untagged),
  ];
}

/// 收银台左边分类栏的分组（收银台和场次排序页共用）。
/// 优先用自定义分类（按分类的排序），没归类的放“其他”；
/// 还没给商品选分类时按标签分；都没有标签时按作者分；作者也没有就是一组“全部”。
List<MenuSection<T>> menuSections<T>(
  List<T> sellable,
  CatalogProduct Function(T item) productOf,
  List<ProductCategory> categories,
) {
  final order = {for (final (i, c) in categories.indexed) c.id: i};
  List<String> categoriesOf(T s) => [
    for (final id in productOf(s).categoryIds)
      if (order.containsKey(id)) id,
  ];
  if (sellable.any((s) => categoriesOf(s).isNotEmpty)) {
    final byId = groupByTags(sellable, categoriesOf)
      ..sort(
        (a, b) => (order[a.title] ?? categories.length).compareTo(
          order[b.title] ?? categories.length,
        ),
      );
    return [
      for (final s in byId)
        MenuSection(
          s.title == null ? null : categories[order[s.title]!].name,
          s.items,
        ),
    ];
  }
  final byTag = groupByTags(
    sellable,
    (s) => productTags(productOf(s).product.tags),
  );
  if (byTag.any((s) => s.title != null)) return byTag;
  final byCreator = groupByTags(
    sellable,
    (s) => [if (productOf(s).creator case final c?) c.name],
  );
  return byCreator.any((s) => s.title != null) ? byCreator : byTag;
}

/// 分类栏里「其他」那一组的 key（它没有标题）。
const otherGroupKey = '\u0000other';

/// 分组的 key：标题；「其他」用 [otherGroupKey]。
String groupKeyOf(MenuSection<Object?> section) =>
    section.title ?? otherGroupKey;

/// 按场次里存的顺序排分组和每组里的商品：[groupOrder] 是分组 key（见 [groupKeyOf]），
/// [productOrder] 是商品 id。没列出的排在后面，保持原来的先后。
List<MenuSection<T>> orderMenu<T>(
  List<MenuSection<T>> sections, {
  required List<String> groupOrder,
  required List<String> productOrder,
  required String Function(T item) idOf,
}) {
  List<E> byOrder<E>(
    List<E> items,
    String Function(E) keyOf,
    List<String> order,
  ) {
    if (order.isEmpty) return items;
    final rank = {for (final (i, k) in order.indexed) k: i};
    final indexed = items.indexed.toList()
      ..sort((a, b) {
        final ra = rank[keyOf(a.$2)] ?? order.length;
        final rb = rank[keyOf(b.$2)] ?? order.length;
        return ra != rb ? ra.compareTo(rb) : a.$1.compareTo(b.$1);
      });
    return [for (final (_, e) in indexed) e];
  }

  return [
    for (final s in byOrder(sections, groupKeyOf, groupOrder))
      MenuSection(s.title, byOrder(s.items, idOf, productOrder)),
  ];
}

/// 这件商品有没有带到本场（[stock] 是本场库存，有记录就算带了，数量 0 也算）：
/// 套装要每个成分都带了。
bool stockedAtEvent(CatalogProduct p, Map<String, int> stock) {
  if (p.isBundle) {
    final comps = p.components.values.firstOrNull ?? const [];
    return comps.isNotEmpty &&
        comps.every((c) => stock.containsKey(c.variantId));
  }
  return p.variants.any((v) => stock.containsKey(v.id));
}
