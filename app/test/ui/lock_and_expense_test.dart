import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/ui/floating_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('收银锁：锁上后只剩收银台，PIN 错了解不开，对了恢复', (tester) async {
    await pumpApp(
      tester,
      size: const Size(1180, 820),
      seed: (db, session) async {
        final inventory = InventoryRepository(db, session);
        await inventory.setCurrentEvent(
          await inventory.createEvent(name: 'CP30'),
        );
      },
    );
    await tester.tap(find.text('设置'));
    await settle(tester);
    await tester.tap(find.text('收银锁'));
    await settle(tester);
    expect(find.text('设置收银锁 PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await settle(tester);
    expect(find.text('再输一遍 PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await settle(tester);

    // 锁上：回到收银台，没有导航，也不能备货、记支出。
    expect(find.byType(FloatingTabBar), findsNothing);
    expect(find.text('订单'), findsNothing);
    expect(find.text('备货'), findsNothing);
    expect(find.text('记支出'), findsNothing);
    expect(find.text('CP30'), findsOneWidget);

    await tester.tap(find.byTooltip('已锁定，点此解锁'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '0000');
    await settle(tester);
    expect(find.text('PIN 不对'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await settle(tester);
    expect(find.byType(FloatingTabBar), findsOneWidget);
    expect(find.text('备货'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('出摊时记一笔支出，统计里显示支出和净收入', (tester) async {
    await pumpApp(
      tester,
      size: const Size(1180, 820),
      seed: (db, session) async {
        final inventory = InventoryRepository(db, session);
        await inventory.setCurrentEvent(
          await inventory.createEvent(name: 'CP30'),
        );
      },
    );
    await tester.tap(find.text('记支出'));
    await settle(tester);
    await tester.tap(find.text('摊位费'));
    await tester.enterText(find.widgetWithText(TextField, '金额'), '200');
    await tester.enterText(find.widgetWithText(TextField, '备注（可选）'), '两天摊位');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await settle(tester);
    expect(find.text('已记下支出 ¥200.00'), findsOneWidget);

    await tester.tap(find.text('统计'));
    await settle(tester);
    expect(find.text('支出'), findsWidgets);
    expect(find.text('净收入'), findsOneWidget);
    expect(find.text('-¥200.00'), findsOneWidget);
    expect(find.textContaining('两天摊位'), findsOneWidget);
    await unmountApp(tester);
  });
}
