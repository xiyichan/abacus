/// 库存位置：家里，或某个场次 id。
const homeLocation = 'home';

/// 一条库存流水（与数据表 StockMovements 对应的纯 Dart 视图）。
class StockMove {
  const StockMove({
    required this.id,
    required this.variantId,
    required this.location,
    required this.delta,
    this.reason = 'adjust',
    this.orderId,
  });

  final String id;
  final String variantId;
  final String location;
  final int delta;
  final String reason;
  final String? orderId;
}

/// 套装组成：一个套装 SKU 由若干成分 SKU × 数量组成。
class BundleComponent {
  const BundleComponent(this.variantId, this.quantity);

  final String variantId;
  final int quantity;
}

/// 根据流水计算某位置的库存。
///
/// 按 [StockMove.id] 去重：多台设备同步时同一条流水可能被收到多次，
/// 去重后求和即可，与收到的先后顺序无关——这就是离线合并不会算错库存的原因。
Map<String, int> stockLevels(Iterable<StockMove> moves, String location) {
  final seen = <String>{};
  final levels = <String, int>{};
  for (final m in moves) {
    if (m.location != location || !seen.add(m.id)) continue;
    levels.update(m.variantId, (v) => v + m.delta, ifAbsent: () => m.delta);
  }
  return levels;
}

/// 套装当前可售数量 = 各成分 floor(库存 / 每套用量) 的最小值；任一成分缺货即为 0。
int bundleAvailable(List<BundleComponent> components, Map<String, int> levels) {
  if (components.isEmpty) return 0;
  var available = -1;
  for (final c in components) {
    final stock = levels[c.variantId] ?? 0;
    final n = stock <= 0 ? 0 : stock ~/ c.quantity;
    if (available < 0 || n < available) available = n;
  }
  return available;
}

/// 售出一行商品时要扣减的库存：普通 SKU 扣自身，套装展开成成分扣减。
///
/// 返回 variantId → 扣减数量（正数）。
Map<String, int> saleDeductions({
  required String variantId,
  required int quantity,
  List<BundleComponent> bundleComponents = const [],
}) {
  if (bundleComponents.isEmpty) return {variantId: quantity};
  final result = <String, int>{};
  for (final c in bundleComponents) {
    result.update(
      c.variantId,
      (v) => v + c.quantity * quantity,
      ifAbsent: () => c.quantity * quantity,
    );
  }
  return result;
}
