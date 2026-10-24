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
}
