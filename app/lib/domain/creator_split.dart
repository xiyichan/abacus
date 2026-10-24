import 'allocation.dart';

/// 分账时需要的一行已售商品信息。
class SoldLine {
  const SoldLine({
    required this.netAmount,
    this.creatorId,
    this.bundleParts = const [],
  });

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
Map<String, int> splitByCreator(Iterable<SoldLine> lines) {
  final totals = <String, int>{};
  void add(String? creator, int amount) {
    totals.update(
      creator ?? unassignedCreator,
      (v) => v + amount,
      ifAbsent: () => amount,
    );
  }

  for (final line in lines) {
    if (line.bundleParts.isEmpty) {
      add(line.creatorId, line.netAmount);
      continue;
    }
    final shares = allocate(line.netAmount, [
      for (final p in line.bundleParts) p.value,
    ]);
    for (var i = 0; i < shares.length; i++) {
      add(line.bundleParts[i].creatorId, shares[i]);
    }
  }
  return totals;
}
