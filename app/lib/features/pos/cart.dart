import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sales_repository.dart';
import '../../domain/checkout.dart';
import '../../domain/stock.dart';

class CartState {
  const CartState({this.lines = const [], this.discount = const NoDiscount()});

  final List<SaleLine> lines;
  final Discount discount;

  int get itemCount => lines.fold(0, (a, l) => a + l.quantity);
  bool get isEmpty => lines.isEmpty;

  CheckoutSummary get summary => summarize([
    for (final l in lines)
      CartLine(
        variantId: l.variantId,
        unitPrice: l.unitPrice,
        quantity: l.quantity,
      ),
  ], discount);

  /// 购物车里的商品会占用多少库存（套装展开成成分）。
  Map<String, int> get reserved {
    final result = <String, int>{};
    for (final l in lines) {
      saleDeductions(
        variantId: l.variantId,
        quantity: l.quantity,
        bundleComponents: l.components,
      ).forEach((id, q) => result.update(id, (v) => v + q, ifAbsent: () => q));
    }
    return result;
  }

  CartState copyWith({List<SaleLine>? lines, Discount? discount}) => CartState(
    lines: lines ?? this.lines,
    discount: discount ?? this.discount,
  );
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(SaleLine line) {
    final index = state.lines.indexWhere((l) => l.variantId == line.variantId);
    if (index < 0) {
      state = state.copyWith(lines: [...state.lines, line]);
    } else {
      setQuantity(line.variantId, state.lines[index].quantity + line.quantity);
    }
  }

  void setQuantity(String variantId, int quantity) {
    state = state.copyWith(
      lines: [
        for (final l in state.lines)
          if (l.variantId != variantId)
            l
          else if (quantity > 0)
            SaleLine(
              variantId: l.variantId,
              name: l.name,
              unitPrice: l.unitPrice,
              quantity: quantity,
              components: l.components,
            ),
      ],
    );
  }

  void setDiscount(Discount discount) =>
      state = state.copyWith(discount: discount);

  void clear() => state = const CartState();
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);
