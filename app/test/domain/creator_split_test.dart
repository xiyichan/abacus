import 'package:abacus/domain/creator_split.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('普通商品记到各自作者', () {
    final r = splitByCreator(const [
      SoldLine(netAmount: 3000, creatorId: 'miya'),
      SoldLine(netAmount: 1000, creatorId: 'neko'),
      SoldLine(netAmount: 500, creatorId: 'miya'),
    ]);
    expect(r, {'miya': 3500, 'neko': 1000});
  });

  test('套装按成分价值比例拆分，总额不变', () {
    final r = splitByCreator(const [
      SoldLine(
        netAmount: 2500,
        bundleParts: [
          BundlePart(creatorId: 'miya', value: 2000),
          BundlePart(creatorId: 'neko', value: 1000),
        ],
      ),
    ]);
    expect(r, {'miya': 1667, 'neko': 833});
  });

  test('未设置作者的商品单独汇总', () {
    final r = splitByCreator(const [SoldLine(netAmount: 800)]);
    expect(r, {unassignedCreator: 800});
  });

  test('分账明细：每个作者名下每样商品，加起来等于分账金额', () {
    const lines = [
      SoldLine(
        variantId: 'badge',
        name: '徽章',
        quantity: 2,
        netAmount: 3000,
        creatorId: 'miya',
      ),
      SoldLine(
        variantId: 'badge',
        name: '徽章',
        quantity: 1,
        netAmount: 1500,
        creatorId: 'miya',
      ),
      SoldLine(
        variantId: 'set',
        name: '套装',
        quantity: 1,
        netAmount: 2500,
        bundleParts: [
          BundlePart(creatorId: 'miya', value: 1000),
          BundlePart(creatorId: 'miya', value: 1000),
          BundlePart(creatorId: 'neko', value: 1000),
        ],
      ),
    ];
    final items = itemsByCreator(lines);
    final miya = items['miya']!;
    expect([for (final i in miya) i.name], ['徽章', '套装']);
    expect(miya.first.quantity, 3);
    expect(miya.first.amount, 4500);
    expect(miya.first.bundleShare, isFalse);
    // 同一个作者在套装里有两样成分：只算 1 套，钱合起来。
    expect(miya.last.quantity, 1);
    expect(miya.last.amount, 1667);
    expect(miya.last.bundleShare, isTrue);
    expect(items['neko']!.single.amount, 833);

    final totals = splitByCreator(lines);
    for (final MapEntry(:key, :value) in items.entries) {
      expect(value.fold<int>(0, (a, i) => a + i.amount), totals[key]);
    }
  });
}
