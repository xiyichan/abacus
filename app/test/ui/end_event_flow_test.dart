import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/domain/stock.dart';
import 'package:abacus/features/events/event_dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('日期已过时提醒结束，结束后剩余数量留在场次里', (tester) async {
    late String eventId;
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
        eventId = await inventory.createEvent(
          name: 'CP30',
          startsOn: DateTime.now().subtract(const Duration(days: 2)),
        );
        await inventory.setEventQuantity(
          variantId: v.id,
          eventId: eventId,
          eventQuantity: 4,
        );
        await inventory.setCurrentEvent(eventId);
      },
    );

    // 收银台：日期已过的提醒
    await tester.tap(find.text('收银'));
    await settle(tester);
    expect(find.text('「CP30」的日期已经过了，结束了吗？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '结束场次'));
    await settle(tester);
    expect(find.text('本场剩余 4 件：'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '结束场次').last);
    await settle(tester);
    expect(find.text('「CP30」已结束，剩余 4 件'), findsOneWidget);
    expect(find.text('还没有选择场次'), findsOneWidget);

    final left = (await tester.runAsync(() => app.db.stockAt(eventId)))!;
    expect(left.values.single, 4);
    final home = (await tester.runAsync(() => app.db.stockAt(homeLocation)))!;
    expect(home, isEmpty);

    // 场次列表里显示已结束
    await tester.tap(find.widgetWithText(FilledButton, '选择场次'));
    await settle(tester);
    expect(find.textContaining(' · 已结束'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('两天的展第二天不提醒结束，场次列表显示日期范围', (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    await pumpApp(
      tester,
      size: const Size(1180, 820),
      seed: (db, session) async {
        final inventory = InventoryRepository(db, session);
        final id = await inventory.createEvent(
          name: 'CP31',
          startsOn: yesterday,
          endsOn: today,
        );
        await inventory.setCurrentEvent(id);
      },
    );

    await tester.tap(find.text('收银'));
    await settle(tester);
    expect(find.textContaining('的日期已经过了'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'CP31'));
    await settle(tester);
    expect(
      find.textContaining(formatDateRange(yesterday, today)),
      findsOneWidget,
    );
    await unmountApp(tester);
  });
}
