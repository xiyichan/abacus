import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('扫码付款显示备注码，稍后确认，事后按备注码找到订单并确认收款', (tester) async {
    final app = await pumpApp(
      tester,
      size: const Size(1180, 820),
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        final inventory = InventoryRepository(db, session);
        await catalog.saveProduct(
          ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
        );
        final v = (await catalog.loadCatalog()).single.variants.single;
        final eventId = await inventory.createEvent(name: 'CP30');
        await inventory.setEventQuantity(
          variantId: v.id,
          eventId: eventId,
          eventQuantity: 5,
        );
        await inventory.setCurrentEvent(eventId);
      },
    );

    await tester.tap(find.text('徽章'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '结账'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '微信'));
    await settle(tester);
    expect(find.text('请客人付款时在备注里填写'), findsOneWidget);
    expect(find.text('${app.session.orderPrefix}001'), findsOneWidget);
    await tester.tap(find.text('稍后确认收款'));
    await settle(tester);
    expect(
      find.text('已保存订单 ${app.session.orderPrefix}-001，待确认收款'),
      findsOneWidget,
    );

    // 订单页：筛出待确认，按备注码搜索
    await tester.tap(find.text('订单'));
    await settle(tester);
    expect(find.text('待确认收款 1'), findsOneWidget);
    await tester.enterText(
      find.byType(SearchBar),
      '${app.session.orderPrefix.toLowerCase()}001',
    );
    await settle(tester);
    await tester.tap(find.text('${app.session.orderPrefix}-001'));
    await settle(tester);
    expect(
      find.text('核对到客人备注 ${app.session.orderPrefix}001 的付款后，点下面的按钮。'),
      findsOneWidget,
    );
    await tester.tap(find.text('确认已收款'));
    await settle(tester);
    expect(find.text('确认已收款'), findsNothing);
    expect(find.text('已确认收款'), findsOneWidget);
    await unmountApp(tester);
  });
}
