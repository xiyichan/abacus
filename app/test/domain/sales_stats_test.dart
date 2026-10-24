import 'package:abacus/domain/creator_split.dart';
import 'package:abacus/domain/sales_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const badge = StatsLine(
    variantId: 'badge',
    name: '徽章',
    unitPrice: 1500,
    quantity: 2,
  );
  const card = StatsLine(
    variantId: 'card',
    name: '色纸',
    unitPrice: 1000,
    quantity: 1,
  );
  const set = StatsLine(
    variantId: 'set',
    name: '套装',
    unitPrice: 2500,
    quantity: 1,
  );

  final ownership = {
    'badge': const VariantOwnership(creatorId: 'miya'),
    'card': const VariantOwnership(creatorId: 'neko'),
    'set': const VariantOwnership(
      bundleParts: [
        BundlePart(creatorId: 'miya', value: 1500),
        BundlePart(creatorId: 'neko', value: 1000),
      ],
    ),
  };

  test('营业额、件数、客单价，已退款订单只计入退款', () {
    final stats = computeSalesStats([
      const StatsOrder(
        discount: 0,
        total: 4000,
        lines: [badge, card],
        paymentName: '现金',
      ),
      const StatsOrder(
        discount: 0,
        total: 1000,
        lines: [card],
        paymentName: '微信',
      ),
      const StatsOrder(
        discount: 0,
        total: 3000,
        lines: [badge],
        paymentName: '现金',
        refunded: true,
        refundAmount: 3000,
      ),
    ], ownership);
    expect(stats.revenue, 5000);
    expect(stats.orderCount, 2);
    expect(stats.itemCount, 4);
    expect(stats.averageOrder, 2500);
    expect(stats.refundCount, 1);
    expect(stats.refundAmount, 3000);
  });

  test('热销榜按销量排序，金额为摊完优惠后的实收', () {
    final stats = computeSalesStats([
      const StatsOrder(
        discount: 1000,
        total: 3000,
        lines: [badge, card],
        paymentName: '现金',
      ),
      const StatsOrder(
        discount: 0,
        total: 1000,
        lines: [card],
        paymentName: '现金',
      ),
      const StatsOrder(
        discount: 0,
        total: 1000,
        lines: [card],
        paymentName: '现金',
      ),
    ], ownership);
    expect([for (final s in stats.topSellers) s.name], ['色纸', '徽章']);
    expect(stats.topSellers.first.quantity, 3);
    // 第一单优惠 10 元按 30:10 摊：徽章 22.5、色纸 7.5
    expect(stats.topSellers.last.revenue, 2250);
    expect(stats.topSellers.first.revenue, 750 + 1000 + 1000);
    expect(stats.discountTotal, 1000);
  });

  test('按作者分账：套装按成分价值拆分，总额等于营业额', () {
    final stats = computeSalesStats([
      const StatsOrder(
        discount: 0,
        total: 3000,
        lines: [badge],
        paymentName: '现金',
      ),
      const StatsOrder(
        discount: 0,
        total: 2500,
        lines: [set],
        paymentName: '现金',
      ),
    ], ownership);
    expect(Map.fromEntries(stats.byCreator), {
      'miya': 3000 + 1500,
      'neko': 1000,
    });
    expect(stats.byCreator.first.key, 'miya');
    expect(stats.byCreator.fold<int>(0, (a, e) => a + e.value), stats.revenue);
  });

  test('没有作者信息的商品记到未设置作者', () {
    final stats = computeSalesStats([
      const StatsOrder(
        discount: 0,
        total: 500,
        lines: [
          StatsLine(variantId: 'x', name: '贴纸', unitPrice: 500, quantity: 1),
        ],
        paymentName: '现金',
      ),
    ], ownership);
    expect(Map.fromEntries(stats.byCreator), {unassignedCreator: 500});
  });

  test('按支付方式汇总', () {
    final stats = computeSalesStats([
      const StatsOrder(
        discount: 0,
        total: 3000,
        lines: [badge],
        paymentName: '现金',
      ),
      const StatsOrder(
        discount: 0,
        total: 1000,
        lines: [card],
        paymentName: '微信',
      ),
      const StatsOrder(
        discount: 0,
        total: 1000,
        lines: [card],
        paymentName: '现金',
      ),
    ], ownership);
    expect(
      [for (final p in stats.byPayment) (p.name, p.orders, p.amount)],
      [('现金', 2, 4000), ('微信', 1, 1000)],
    );
  });

  test('没有订单时全为 0', () {
    final stats = computeSalesStats(const [], const {});
    expect(stats.revenue, 0);
    expect(stats.averageOrder, 0);
    expect(stats.topSellers, isEmpty);
  });
}
