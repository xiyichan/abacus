import 'package:abacus/domain/checkout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lines = [
    CartLine(variantId: 'a', unitPrice: 1500, quantity: 2), // 30.00
    CartLine(variantId: 'b', unitPrice: 1000, quantity: 1), // 10.00
  ];

  test('无优惠', () {
    final s = summarize(lines);
    expect(s.subtotal, 4000);
    expect(s.discount, 0);
    expect(s.total, 4000);
    expect(s.lineTotals, [3000, 1000]);
  });

  test('立减按金额比例摊到每行', () {
    final s = summarize(lines, const AmountOff(1000));
    expect(s.total, 3000);
    expect(s.lineTotals, [2250, 750]);
  });

  test('立减不能超过小计', () {
    expect(summarize(lines, const AmountOff(99999)).total, 0);
  });

  test('百分比折扣四舍五入到分', () {
    final s = summarize(const [
      CartLine(variantId: 'a', unitPrice: 999, quantity: 1),
    ], const PercentOff(15));
    expect(s.discount, 150); // 149.85 → 150
    expect(s.total, 849);
  });

  test('一口价', () {
    final s = summarize(lines, const FixedTotal(3500));
    expect(s.discount, 500);
    expect(s.total, 3500);
    expect(s.lineTotals.fold<int>(0, (a, b) => a + b), 3500);
  });

  test('现金找零', () {
    expect(changeDue(total: 3500, tendered: 5000), 1500);
    expect(changeDue(total: 3500, tendered: 3500), 0);
    expect(changeDue(total: 3500, tendered: 2000), isNull);
  });
}
