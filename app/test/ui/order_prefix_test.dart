import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('设置里改单号前缀，新订单用它；订单详情显示规格', (tester) async {
    await pumpApp(
      tester,
      size: const Size(1180, 820),
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        final inventory = InventoryRepository(db, session);
        await catalog.saveProduct(
          ProductDraft(
            name: '徽章',
            kind: ProductKind.variants,
            variants: [VariantDraft(label: '红', price: 1500)],
          ),
        );
        final red = (await catalog.loadCatalog()).single.variants.single;
        final eventId = await inventory.createEvent(name: 'CP30');
        await inventory.setEventQuantity(
          variantId: red.id,
          eventId: eventId,
          eventQuantity: 5,
        );
        await inventory.setCurrentEvent(eventId);
      },
    );

    await tester.tap(find.text('设置'));
    await settle(tester);
    await tester.tap(find.text('单号前缀'));
    await settle(tester);
    // 只收字母数字、自动转大写。
    await tester.enterText(find.byType(TextField).last, 'be-ar');
    await tester.tap(find.text('保存'));
    await settle(tester);
    expect(find.text('BEAR'), findsOneWidget);

    await tester.tap(find.text('收银'));
    await settle(tester);
    await tester.tap(find.text('徽章'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '结账'));
    await settle(tester);
    await tester.tap(find.text('确认收款'));
    await settle(tester);
    expect(find.text('已保存订单 BEAR-001'), findsOneWidget);

    await tester.tap(find.text('订单'));
    await settle(tester);
    await tester.tap(find.text('BEAR-001'));
    await settle(tester);
    expect(find.text('徽章'), findsOneWidget);
    expect(find.text('规格：红'), findsOneWidget);
    await unmountApp(tester);
  });
}
