import 'allocation.dart';

/// 购物车中的一行。金额单位为最小货币单位（分）。
class CartLine {
  const CartLine({
    required this.variantId,
    required this.unitPrice,
    required this.quantity,
  });

  final String variantId;
  final int unitPrice;
  final int quantity;

  int get amount => unitPrice * quantity;
}

/// 整单优惠。
sealed class Discount {
  const Discount();

  /// 根据小计算出优惠金额（不超过小计）。
  int amountFor(int subtotal);
}

class NoDiscount extends Discount {
  const NoDiscount();

  @override
  int amountFor(int subtotal) => 0;
}

/// 立减固定金额。
class AmountOff extends Discount {
  const AmountOff(this.amount);

  final int amount;

  @override
  int amountFor(int subtotal) => amount.clamp(0, subtotal);
}

/// 按百分比打折，[percentOff] 为 0–100，如 20 表示 8 折。结果四舍五入到分。
class PercentOff extends Discount {
  const PercentOff(this.percentOff);

  final int percentOff;

  @override
  int amountFor(int subtotal) =>
      ((subtotal * percentOff.clamp(0, 100) + 50) ~/ 100).clamp(0, subtotal);
}

/// 直接改成一口价。
class FixedTotal extends Discount {
  const FixedTotal(this.total);

  final int total;

  @override
  int amountFor(int subtotal) => (subtotal - total).clamp(0, subtotal);
}

class CheckoutSummary {
  const CheckoutSummary({
    required this.subtotal,
    required this.discount,
    required this.lineTotals,
  });

  final int subtotal;
  final int discount;

  /// 每行摊完优惠后的实收金额，用于分账和退款。之和等于 [total]。
  final List<int> lineTotals;

  int get total => subtotal - discount;
}

CheckoutSummary summarize(
  List<CartLine> lines, [
  Discount discount = const NoDiscount(),
]) {
  final subtotal = lines.fold<int>(0, (a, l) => a + l.amount);
  final off = discount.amountFor(subtotal);
  final lineDiscounts = allocate(off, [for (final l in lines) l.amount]);
  return CheckoutSummary(
    subtotal: subtotal,
    discount: off,
    lineTotals: [
      for (var i = 0; i < lines.length; i++) lines[i].amount - lineDiscounts[i],
    ],
  );
}

/// 现金找零。客人给的钱不够时返回 null。
int? changeDue({required int total, required int tendered}) =>
    tendered < total ? null : tendered - total;
