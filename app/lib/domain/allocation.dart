/// 把整数 [total] 按 [weights] 比例拆分，结果之和严格等于 [total]。
///
/// 使用最大余数法：先按比例向下取整，再把剩余的“分”依次分给余数最大的项。
/// 用于整单折扣摊到每件商品、套装收入按成分价值拆给作者等场景。
List<int> allocate(int total, List<int> weights) {
  if (weights.isEmpty) return const [];
  if (weights.any((w) => w < 0)) {
    throw ArgumentError.value(weights, 'weights', 'must be non-negative');
  }
  final weightSum = weights.fold<int>(0, (a, b) => a + b);
  if (weightSum == 0) {
    // 没有可参考的权重时平均分。
    return allocate(total, List.filled(weights.length, 1));
  }

  final sign = total < 0 ? -1 : 1;
  final absTotal = total.abs();
  final shares = <int>[];
  final remainders = <({int index, int remainder})>[];
  var assigned = 0;
  for (var i = 0; i < weights.length; i++) {
    final product = absTotal * weights[i];
    final share = product ~/ weightSum;
    shares.add(share);
    assigned += share;
    remainders.add((index: i, remainder: product % weightSum));
  }

  // 余数相同时按原顺序，保证结果稳定可复现。
  remainders.sort((a, b) {
    final c = b.remainder.compareTo(a.remainder);
    return c != 0 ? c : a.index.compareTo(b.index);
  });
  for (var k = 0; k < absTotal - assigned; k++) {
    shares[remainders[k].index] += 1;
  }
  return [for (final s in shares) s * sign];
}
