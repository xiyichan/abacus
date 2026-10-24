import 'package:abacus/domain/stock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const event = 'event-1';

  test('库存 = 流水之和，按位置区分', () {
    final moves = [
      const StockMove(
        id: 'm1',
        variantId: 'a',
        location: homeLocation,
        delta: 20,
      ),
      const StockMove(
        id: 'm2',
        variantId: 'a',
        location: homeLocation,
        delta: -10,
      ),
      const StockMove(id: 'm3', variantId: 'a', location: event, delta: 10),
      const StockMove(id: 'm4', variantId: 'a', location: event, delta: -1),
    ];
    expect(stockLevels(moves, homeLocation), {'a': 10});
    expect(stockLevels(moves, event), {'a': 9});
  });

  test('两台设备离线各卖同一件货，合并后库存正确且与顺序无关', () {
    const transfer = StockMove(
      id: 't',
      variantId: 'a',
      location: event,
      delta: 10,
    );
    final deviceA = [
      transfer,
      const StockMove(id: 'sa1', variantId: 'a', location: event, delta: -2),
      const StockMove(id: 'sa2', variantId: 'a', location: event, delta: -1),
    ];
    final deviceB = [
      transfer,
      const StockMove(id: 'sb1', variantId: 'a', location: event, delta: -3),
    ];

    final mergedAB = [...deviceA, ...deviceB];
    final mergedBA = [...deviceB, ...deviceA.reversed];
    expect(stockLevels(mergedAB, event), {'a': 4});
    expect(stockLevels(mergedBA, event), {'a': 4});
    // 重复收到同一条流水不会重复计算。
    expect(stockLevels([...mergedAB, ...mergedAB], event), {'a': 4});
  });

  test('离线期间卖超时库存为负数，不丢数据', () {
    final moves = [
      const StockMove(id: 't', variantId: 'a', location: event, delta: 1),
      const StockMove(id: 's1', variantId: 'a', location: event, delta: -1),
      const StockMove(id: 's2', variantId: 'a', location: event, delta: -1),
    ];
    expect(stockLevels(moves, event), {'a': -1});
  });

  group('套装', () {
    const components = [
      BundleComponent('badge', 1),
      BundleComponent('card', 2),
    ];

    test('可售数量取各成分最小可组数', () {
      expect(bundleAvailable(components, {'badge': 5, 'card': 6}), 3);
      expect(bundleAvailable(components, {'badge': 2, 'card': 6}), 2);
    });

    test('任一成分缺货或为负则不可售', () {
      expect(bundleAvailable(components, {'badge': 5}), 0);
      expect(bundleAvailable(components, {'badge': -1, 'card': 6}), 0);
      expect(bundleAvailable(const [], {}), 0);
    });

    test('售出套装扣减成分库存', () {
      expect(
        saleDeductions(
          variantId: 'set',
          quantity: 2,
          bundleComponents: components,
        ),
        {'badge': 2, 'card': 4},
      );
    });

    test('普通商品扣自身', () {
      expect(saleDeductions(variantId: 'badge', quantity: 3), {'badge': 3});
    });
  });
}
