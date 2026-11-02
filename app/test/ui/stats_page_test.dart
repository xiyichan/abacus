import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('统计页显示实收、热销、作者分账和支付方式', (tester) async {
    await pumpApp(
      tester,
      size: const Size(1180, 820),
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        final inventory = InventoryRepository(db, session);
        final sales = SalesRepository(db, session);
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
        final items = await catalog.loadCatalog();
        final badge = items
            .firstWhere((p) => p.product.name == '徽章')
            .variants
            .single;
        final card = items
            .firstWhere((p) => p.product.name == '色纸')
            .variants
            .single;
        final eventId = await inventory.createEvent(name: 'CP30');
        await inventory.setCurrentEvent(eventId);
        final methods = await sales.watchPaymentMethods().first;
        await sales.placeOrder(
          eventId: eventId,
          lines: [
            SaleLine(
              variantId: badge.id,
              name: '徽章',
              unitPrice: 1500,
              quantity: 2,
            ),
          ],
          paymentMethod: methods.firstWhere((m) => m.name == '现金'),
        );
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
          paymentMethod: methods.firstWhere((m) => m.name == '微信'),
        );
        final earlier = await inventory.createEvent(name: 'CP29');
        await sales.placeOrder(
          eventId: earlier,
          lines: [
            SaleLine(
              variantId: badge.id,
              name: '徽章',
              unitPrice: 1500,
              quantity: 1,
            ),
          ],
          paymentMethod: methods.firstWhere((m) => m.name == '现金'),
        );
      },
    );
    await tester.tap(find.text('统计'));
    await settle(tester);

    // 默认选中当前场次。
    final cp30Chip = find.widgetWithText(ChoiceChip, 'CP30');
    expect(tester.widget<ChoiceChip>(cp30Chip).selected, isTrue);
    expect(find.text('各场对比'), findsNothing);
    expect(find.text('¥40.00'), findsWidgets); // 实收
    expect(find.text('热销榜'), findsOneWidget);
    expect(find.text('2 件 · ¥30.00'), findsOneWidget);
    expect(find.text('Miya'), findsOneWidget);
    expect(find.text('未设置作者'), findsOneWidget);
    expect(find.text('¥30.00 · 75%'), findsOneWidget);
    expect(find.text('1 单 · ¥10.00'), findsOneWidget); // 微信
    expect(find.byTooltip('导出 CSV（订单和支出）'), findsOneWidget);

    // 全部场次：合计 + 各场对比。
    await tester.tap(find.widgetWithText(ChoiceChip, '全部场次'));
    await settle(tester);
    expect(find.text('¥55.00'), findsWidgets);
    expect(find.text('各场对比'), findsOneWidget);
    expect(find.textContaining('2 单'), findsWidgets);

    // 点对比表里的一行切到那一场。
    // 标签行在前，对比表在后：最后一个 “CP29” 是对比表里的那一行。
    await tester.tap(find.text('CP29').last);
    await settle(tester);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'CP29'))
          .selected,
      isTrue,
    );
    expect(find.text('各场对比'), findsNothing);
    expect(find.text('¥15.00'), findsWidgets);
    await unmountApp(tester);
  });
}
