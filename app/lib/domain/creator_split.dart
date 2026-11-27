import 'allocation.dart';

/// 分账时需要的一行已售商品信息。
class SoldLine {
  const SoldLine({
    required this.netAmount,
    this.creatorId,
    this.bundleParts = const [],
    this.variantId = '',
    this.name = '',
    this.quantity = 0,
  });

  /// 分账明细里用：是哪件商品、卖了几件。
  final String variantId;
  final String name;
  final int quantity;

  /// 这一行摊完整单优惠后的实收金额。
  final int netAmount;

  /// 普通商品的作者；套装时忽略，按 [bundleParts] 拆。
  final String? creatorId;

  /// 套装成分，按价值比例拆分收入。
  final List<BundlePart> bundleParts;
}

class BundlePart {
  const BundlePart({required this.creatorId, required this.value});

  final String? creatorId;

  /// 成分价值 = 成分单价 × 每套数量，用作拆分权重。
  final int value;
}

/// 没有设置作者的商品统一记到这个 key 下。
const unassignedCreator = '';

/// 合摊分账：返回 creatorId → 应得金额。套装按成分价值比例拆给各自作者。
Map<String, int> splitByCreator(Iterable<SoldLine> lines) => {
  for (final MapEntry(:key, :value) in itemsByCreator(lines).entries)
    key: value.fold(0, (a, i) => a + i.amount),
};

/// 某个作者名下卖出的一样商品：件数和分到的金额。
class CreatorItem {
  const CreatorItem({
    required this.variantId,
    required this.name,
    required this.quantity,
    required this.amount,
    this.bundleShare = false,
  });

  final String variantId;
  final String name;
  final int quantity;

  /// 这个作者分到的钱（摊完优惠；套装是按成分价值拆到的那一份）。
  final int amount;

  /// 套装里有这个作者的东西，[amount] 只是其中一部分。
  final bool bundleShare;
}

/// 分账明细：creatorId → 名下每样商品，按金额从高到低。和 [splitByCreator] 用同一套拆法，
/// 所以每个作者的明细加起来正好等于他的分账金额。
Map<String, List<CreatorItem>> itemsByCreator(Iterable<SoldLine> lines) {
  final items = <String, Map<String, CreatorItem>>{};
  void add(String? creator, SoldLine line, int amount, bool bundle) {
    final byVariant = items.putIfAbsent(creator ?? unassignedCreator, () => {});
    final prev = byVariant[line.variantId];
    byVariant[line.variantId] = CreatorItem(
      variantId: line.variantId,
      name: line.name,
      quantity: (prev?.quantity ?? 0) + line.quantity,
      amount: (prev?.amount ?? 0) + amount,
      bundleShare: bundle,
    );
  }

  for (final line in lines) {
    if (line.bundleParts.isEmpty) {
      add(line.creatorId, line, line.netAmount, false);
      continue;
    }
    final shares = allocate(line.netAmount, [
      for (final p in line.bundleParts) p.value,
    ]);
    // 同一个作者在套装里有好几样成分时，先合起来再记一次，件数才不会重复算。
    final perCreator = <String?, int>{};
    for (var i = 0; i < shares.length; i++) {
      final c = line.bundleParts[i].creatorId;
      perCreator[c] = (perCreator[c] ?? 0) + shares[i];
    }
    for (final MapEntry(key: c, value: amount) in perCreator.entries) {
      add(c, line, amount, true);
    }
  }
  return {
    for (final MapEntry(:key, :value) in items.entries)
      key: value.values.toList()..sort((a, b) => b.amount.compareTo(a.amount)),
  };
}
