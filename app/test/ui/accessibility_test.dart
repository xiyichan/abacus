import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/database.dart';
import 'package:abacus/data/expense_repository.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:abacus/data/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// 有商品、场次、订单和支出的数据，让每个页面都有内容可排版。
Future<void> _seed(AppDatabase db, Session session) async {
  final catalog = CatalogRepository(db, session);
  final inventory = InventoryRepository(db, session);
  final sales = SalesRepository(db, session);
  await catalog.saveProduct(
    ProductDraft(
      name: '小企鹅亚克力立牌（限定特典版）',
      tags: '谷子',
      variants: [VariantDraft(price: 3500)],
    ),
  );
  await catalog.saveProduct(
    ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
  );
  final eventId = await inventory.createEvent(name: 'CP30 上海站');
  await inventory.setCurrentEvent(eventId);
  final items = await catalog.loadCatalog();
  for (final p in items) {
    await inventory.setEventQuantity(
      variantId: p.variants.single.id,
      eventId: eventId,
      eventQuantity: 20,
    );
  }
  final v = items.first.variants.single;
  await sales.placeOrder(
    eventId: eventId,
    lines: [
      SaleLine(
        variantId: v.id,
        name: items.first.product.name,
        unitPrice: v.price,
        quantity: 2,
      ),
    ],
    paymentMethod: (await sales.watchPaymentMethods().first).first,
  );
  await ExpenseRepository(db, session).addExpense(
    eventId: eventId,
    category: 'travel',
    amount: 30000,
    note: '高铁往返',
    spentOn: DateTime(2026, 10, 1),
  );
}

void main() {
  for (final (name, size) in [
    ('手机', const Size(390, 844)),
    ('平板', const Size(1180, 820)),
  ]) {
    testWidgets('$name：系统字体放大 2 倍时每个页面都不溢出', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, size: size, seed: _seed);

      // 收银台加一件货，逐个打开标签页（布局溢出会直接让测试失败），最后打开结账。
      await tester.tap(find.text('徽章').first);
      await settle(tester);
      for (final tab in ['订单', '商品', '统计', '设置', '收银']) {
        await tester.tap(find.text(tab).last);
        await settle(tester);
      }
      await tester.tap(find.widgetWithText(FilledButton, '结账'));
      await settle(tester);
      expect(find.text('合计'), findsWidgets);
      await unmountApp(tester);
    });

    testWidgets('$name：可点的控件至少 44×44，并且都有读屏标签', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, size: size, seed: _seed);
      Future<void> check() async {
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }

      await check();
      for (final tab in ['订单', '商品', '统计', '设置']) {
        await tester.tap(find.text(tab).last);
        await settle(tester);
        await check();
      }
      semantics.dispose();
      await unmountApp(tester);
    });
  }
}
