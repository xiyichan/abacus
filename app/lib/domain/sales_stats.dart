import 'allocation.dart';
import 'creator_split.dart';

/// 统计用的一笔订单（与数据库解耦，方便测试）。
class StatsOrder {
  const StatsOrder({
    required this.discount,
    required this.total,
    required this.lines,
    required this.paymentName,
    this.refunded = false,
    this.refundAmount = 0,
    this.paymentPending = false,
  });

  final int discount;
  final int total;
  final List<StatsLine> lines;
  final String paymentName;
  final bool refunded;
  final int refundAmount;

  /// 扫码付款还没确认到账。
  final bool paymentPending;
}

class StatsLine {
  const StatsLine({
    required this.variantId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final String variantId;
  final String name;
  final int unitPrice;
  final int quantity;

  int get amount => unitPrice * quantity;
}

/// 某个 SKU 属于哪个作者；套装则给出各成分的作者和价值，用于拆分收入。
class VariantOwnership {
  const VariantOwnership({this.creatorId, this.bundleParts = const []});

  final String? creatorId;
  final List<BundlePart> bundleParts;
}

class TopSeller {
  const TopSeller({
    required this.variantId,
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String variantId;
  final String name;
  final int quantity;

  /// 摊完整单优惠后的实收。
  final int revenue;
}

class PaymentTotal {
  const PaymentTotal({
    required this.name,
    required this.orders,
    required this.amount,
  });

  final String name;
  final int orders;
  final int amount;
}

class SalesStats {
  const SalesStats({
    required this.revenue,
    required this.orderCount,
    required this.itemCount,
    required this.discountTotal,
    required this.refundCount,
    required this.refundAmount,
    this.pendingCount = 0,
    this.pendingAmount = 0,
    required this.topSellers,
    required this.byCreator,
    required this.byPayment,
  });

  /// 实收（不含已退款订单）。
  final int revenue;
  final int orderCount;
  final int itemCount;
  final int discountTotal;
  final int refundCount;
  final int refundAmount;

  /// 待确认收款的订单（已计入营业额，但还没核对到账）。
  final int pendingCount;
  final int pendingAmount;

  /// 按销量从高到低。
  final List<TopSeller> topSellers;

  /// 作者 id（未设置作者为 [unassignedCreator]）→ 应得金额，按金额从高到低。
  final List<MapEntry<String, int>> byCreator;

  /// 按金额从高到低。
  final List<PaymentTotal> byPayment;

  int get averageOrder => orderCount == 0 ? 0 : (revenue / orderCount).round();
}

/// 汇总一个场次的销售数据。已退款的订单不计入营业额、销量和分账，只计入退款合计。
SalesStats computeSalesStats(
  List<StatsOrder> orders,
  Map<String, VariantOwnership> ownership,
) {
  var revenue = 0, orderCount = 0, itemCount = 0, discountTotal = 0;
  var refundCount = 0, refundAmount = 0, pendingCount = 0, pendingAmount = 0;
  final sellers = <String, TopSeller>{};
  final soldLines = <SoldLine>[];
  final payments = <String, PaymentTotal>{};

  for (final order in orders) {
    if (order.refunded) {
      refundCount++;
      refundAmount += order.refundAmount;
      continue;
    }
    orderCount++;
    revenue += order.total;
    if (order.paymentPending) {
      pendingCount++;
      pendingAmount += order.total;
    }
    discountTotal += order.discount;
    // 整单优惠按金额比例摊到每一行，分账和热销榜都用摊后的实收。
    final shares = allocate(order.discount, [
      for (final l in order.lines) l.amount,
    ]);
    for (var i = 0; i < order.lines.length; i++) {
      final line = order.lines[i];
      final net = line.amount - shares[i];
      itemCount += line.quantity;
      final prev = sellers[line.variantId];
      sellers[line.variantId] = TopSeller(
        variantId: line.variantId,
        name: line.name,
        quantity: (prev?.quantity ?? 0) + line.quantity,
        revenue: (prev?.revenue ?? 0) + net,
      );
      final owner = ownership[line.variantId];
      soldLines.add(
        SoldLine(
          netAmount: net,
          creatorId: owner?.creatorId,
          bundleParts: owner?.bundleParts ?? const [],
        ),
      );
    }
    final p = payments[order.paymentName];
    payments[order.paymentName] = PaymentTotal(
      name: order.paymentName,
      orders: (p?.orders ?? 0) + 1,
      amount: (p?.amount ?? 0) + order.total,
    );
  }

  final topSellers = sellers.values.toList()
    ..sort((a, b) {
      final byQty = b.quantity.compareTo(a.quantity);
      return byQty != 0 ? byQty : b.revenue.compareTo(a.revenue);
    });
  final byCreator = splitByCreator(soldLines).entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final byPayment = payments.values.toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  return SalesStats(
    revenue: revenue,
    orderCount: orderCount,
    itemCount: itemCount,
    discountTotal: discountTotal,
    refundCount: refundCount,
    refundAmount: refundAmount,
    pendingCount: pendingCount,
    pendingAmount: pendingAmount,
    topSellers: topSellers,
    byCreator: byCreator,
    byPayment: byPayment,
  );
}
