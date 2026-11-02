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
