import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:abacus/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('已结束的场次点进去只看订单，不用重新开启，也不改当前场次', (tester) async {
    late String current;
    await pumpApp(
      tester,
      size: const Size(1180, 820),
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        final inventory = InventoryRepository(db, session);
        final sales = SalesRepository(db, session);
        await catalog.saveProduct(
          ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
        );
        final badge = (await catalog.loadCatalog()).single.variants.single;
        final ended = await inventory.createEvent(name: 'CP29');
        current = await inventory.createEvent(name: 'CP30');
        await inventory.setEventQuantity(
          variantId: badge.id,
          eventId: ended,
          eventQuantity: 5,
        );
        final methods = await sales.watchPaymentMethods().first;
        await sales.placeOrder(
          eventId: ended,
          lines: [
            SaleLine(
              variantId: badge.id,
              name: '徽章',
              unitPrice: 1500,
              quantity: 3,
            ),
          ],
          paymentMethod: methods.firstWhere((m) => m.name == '现金'),
        );
        await inventory.endEvent(ended);
        await inventory.setCurrentEvent(current);
      },
    );

    // 收银台左上角的场次名 → 场次列表。
    await tester.tap(find.text('CP30'));
    await settle(tester);
    expect(find.text('查看订单'), findsOneWidget);
    await tester.tap(find.text('CP29'));
    await settle(tester);

    expect(find.textContaining('重新开启'), findsNothing);
    expect(find.textContaining('CP29 · 已结束 · '), findsOneWidget);
    expect(find.text('¥45.00'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    // 点订单看详情，返回回到这一场的订单。
    await tester.tap(find.text('¥45.00').last);
    await settle(tester);
    expect(find.textContaining('CP29 · 已结束 · '), findsNothing);
    await tester.tap(find.byType(BackButton).last);
    await settle(tester);
    expect(find.textContaining('CP29 · 已结束 · '), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(await container.read(currentEventIdProvider.future), current);
    await unmountApp(tester);
  });
}
