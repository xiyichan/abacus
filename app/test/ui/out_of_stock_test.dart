import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/database.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/data/session.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('本场卖完了不能再加；结账时被别的设备卖掉了就不下单', (tester) async {
    late String eventId;
    late String badgeId;
    final app = await pumpApp(
      tester,
      size: const Size(1180, 820),
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        final inventory = InventoryRepository(db, session);
        await catalog.saveProduct(
          ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
        );
        badgeId = (await catalog.loadCatalog()).single.variants.single.id;
        eventId = await inventory.createEvent(name: 'CP30');
        await inventory.setEventQuantity(
          variantId: badgeId,
          eventId: eventId,
          eventQuantity: 1,
        );
        await inventory.setCurrentEvent(eventId);
      },
    );

    await tester.tap(find.text('徽章'));
    await settle(tester);
    expect(find.text('余 0'), findsOneWidget);
    await tester.tap(find.text('徽章'));
    await settle(tester);
    expect(find.textContaining('「徽章」本场没有剩余了'), findsOneWidget);
    expect(find.text('1 件 · ¥15.00'), findsOneWidget);

    // 购物车里的加号也不能点（先等提示条消失，它盖着底部的购物车条）。
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await tester.tap(find.byTooltip('展开购物车'));
    await settle(tester);
    final add = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('加一件'),
        matching: find.byType(IconButton),
      ),
    );
    expect(add.onPressed, isNull);

    // 另一台设备同步过来一笔，把最后一件卖掉了。
    await tester.runAsync(
      () => app.db
          .into(app.db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: newId(),
              updatedAt: app.session.clock.tick(),
              variantId: badgeId,
              location: eventId,
              delta: -1,
              reason: 'sale',
              orderId: Value(newId()),
              deviceId: newId(),
              createdAt: DateTime.now(),
            ),
          ),
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '结账'));
    await settle(tester);
    await tester.tap(find.text('确认收款'));
    await settle(tester);
    expect(find.textContaining('库存不够，没有下单：徽章'), findsOneWidget);
    final orders = (await tester.runAsync(
      () => app.db.select(app.db.orders).get(),
    ))!;
    expect(orders, isEmpty);
    await unmountApp(tester);
  });
}
