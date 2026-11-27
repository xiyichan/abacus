import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('备货按作者分组可折叠；0 件再减移出本场，卖过的不能移出', (tester) async {
    final app = await pumpApp(
      tester,
      size: const Size(1180, 820),
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        final inventory = InventoryRepository(db, session);
        final miya = await catalog.createCreator('Miya');
        await catalog.saveProduct(
          ProductDraft(
            name: '徽章',
            creatorId: miya,
            variants: [VariantDraft(price: 1500)],
          ),
        );
        await catalog.saveProduct(
          ProductDraft(name: '色纸', variants: [VariantDraft(price: 1000)]),
        );
        final eventId = await inventory.createEvent(name: 'CP30');
        await inventory.setCurrentEvent(eventId);
      },
    );
    await tester.tap(find.text('备货'));
    await settle(tester);

    // 两个分组：Miya 在前，未设置作者在后。
    expect(find.text('Miya'), findsOneWidget);
    expect(find.text('未设置作者'), findsOneWidget);
    expect(find.text('0/1 款已备货 · 共 0 件'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Miya')).dy,
      lessThan(tester.getTopLeft(find.text('未设置作者')).dy),
    );

    // 折叠 Miya：徽章不显示，色纸还在；再点展开。
    await tester.tap(find.text('Miya'));
    await settle(tester);
    expect(find.text('徽章'), findsNothing);
    expect(find.text('色纸'), findsOneWidget);
    await tester.tap(find.text('Miya'));
    await settle(tester);
    expect(find.text('徽章'), findsOneWidget);

    Finder inRow(String name, IconData icon) => find.descendant(
      of: find.widgetWithText(ListTile, name),
      matching: find.byIcon(icon),
    );
    Finder qty(String name, String text) => find.descendant(
      of: find.widgetWithText(ListTile, name),
      matching: find.text(text),
    );

    // 没带到本场时减号不能点。
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: inRow('徽章', Icons.remove_circle_outline),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    // +1 → 1，-1 → 0，再 -1 → 回到「—」。
    await tester.tap(inRow('徽章', Icons.add_circle_outline));
    await settle(tester);
    expect(qty('徽章', '1'), findsOneWidget);
    expect(find.text('1/1 款已备货 · 共 1 件'), findsOneWidget);
    await tester.tap(inRow('徽章', Icons.remove_circle_outline));
    await settle(tester);
    expect(qty('徽章', '0'), findsOneWidget);
    await tester.tap(inRow('徽章', Icons.remove_circle_outline));
    await settle(tester);
    expect(qty('徽章', '—'), findsOneWidget);
    expect(find.text('0/1 款已备货 · 共 0 件'), findsNWidgets(2));

    // 卖过的货在本场减到 0 后不能移出。
    await tester.tap(inRow('色纸', Icons.add_circle_outline));
    await settle(tester);
    await tester.runAsync(() async {
      final sales = SalesRepository(app.db, app.session);
      final card = (await CatalogRepository(app.db, app.session).loadCatalog())
          .firstWhere((p) => p.product.name == '色纸')
          .variants
          .single;
      final eventId = (await InventoryRepository(
        app.db,
        app.session,
      ).watchEvents().first).single.id;
      final methods = await sales.watchPaymentMethods().first;
      await sales.placeOrder(
        eventId: eventId,
        lines: [
          SaleLine(
            variantId: card.id,
            name: '色纸',
            unitPrice: 1000,
            quantity: 1,
          ),
        ],
        paymentMethod: methods.first,
      );
    });
    await settle(tester);
    expect(qty('色纸', '0'), findsOneWidget);
    await tester.tap(inRow('色纸', Icons.remove_circle_outline));
    await settle(tester);
    expect(qty('色纸', '0'), findsOneWidget);
    expect(find.text('本场已经卖过这件货，不能移出备货'), findsOneWidget);
    await unmountApp(tester);
  });
}
