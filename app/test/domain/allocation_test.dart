import 'package:abacus/domain/allocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('按比例拆分且总和不变', () {
    expect(allocate(100, [1, 1, 1]), [34, 33, 33]);
    expect(allocate(1000, [3000, 1000]), [750, 250]);
  });

  test('负数总额（退款）同样守恒', () {
    final r = allocate(-100, [1, 1, 1]);
    expect(r, [-34, -33, -33]);
  });

  test('权重全为 0 时平均分', () {
    expect(allocate(5, [0, 0]), [3, 2]);
  });

  test('空权重返回空列表', () {
    expect(allocate(5, []), isEmpty);
  });

  test('随机输入总和恒等', () {
    for (var t = 0; t < 200; t++) {
      final weights = List.generate(1 + t % 7, (i) => (i * 37 + t * 13) % 997);
      final total = t * 101 - 5000;
      expect(allocate(total, weights).fold<int>(0, (a, b) => a + b), total);
    }
  });
}
