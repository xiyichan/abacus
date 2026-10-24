import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/domain/stock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('录入商品：填写名称、售价后出现在商品列表，没有家里库存', (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(find.text('商品'));
    await settle(tester);
    await tester.tap(find.text('添加商品'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '小企鹅亚克力板');
    await tester.enterText(find.widgetWithText(TextFormField, '售价'), '35');
    expect(find.widgetWithText(TextFormField, '家里库存'), findsNothing);
    await tester.tap(find.text('保存'));
    await settle(tester);

    expect(find.text('小企鹅亚克力板'), findsOneWidget);
    expect(find.textContaining('件'), findsNothing);
    final home = (await tester.runAsync(() => app.db.stockAt(homeLocation)))!;
    expect(home, isEmpty);
    await unmountApp(tester);
  });

  testWidgets('平板收银：加购、现金结账、订单列表、退款', (tester) async {
    final app = await pumpApp(
      tester,
      size: const Size(1180, 820),
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        final inventory = InventoryRepository(db, session);
        await catalog.saveProduct(
          ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
        );
        final badge = (await catalog.loadCatalog()).single.variants.single;
        final eventId = await inventory.createEvent(name: 'CP30');
        await inventory.setEventQuantity(
          variantId: badge.id,
          eventId: eventId,
          eventQuantity: 5,
        );
        await inventory.setCurrentEvent(eventId);
      },
    );

    expect(find.text('CP30'), findsOneWidget);
    expect(find.text('剩 5'), findsOneWidget);

    await tester.tap(find.text('徽章'));
    await tester.tap(find.text('徽章').first);
    await settle(tester);
    expect(find.text('剩 3'), findsOneWidget);
    expect(find.text('¥30.00'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, '结账'));
    await settle(tester);
    await tester.tap(find.text('¥50.00'));
    await settle(tester);
    expect(find.text('¥20.00'), findsOneWidget); // 找零
    await tester.tap(find.text('确认收款'));
    await settle(tester);
    expect(find.text('已保存订单 ${app.session.orderPrefix}-001'), findsOneWidget);
    expect(find.text('剩 3'), findsOneWidget);

    await tester.tap(find.text('订单'));
    await settle(tester);
    expect(find.text('1 单 · 实收 ¥30.00'), findsOneWidget);
    await tester.tap(find.text('${app.session.orderPrefix}-001'));
    await settle(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, '整单退款'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '整单退款'));
    await settle(tester);
    expect(find.text('已退款'), findsOneWidget);

    final eventId = (await tester.runAsync(
      () => app.db.getSetting('currentEventId'),
    ))!;
    final stock = (await tester.runAsync(() => app.db.stockAt(eventId)))!;
    expect(stock.values.single, 5);
    await unmountApp(tester);
  });
}
