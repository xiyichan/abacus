import 'package:abacus/data/inventory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('场次列表里点一下场次，直接回到收银台', (tester) async {
    await pumpApp(
      tester,
      seed: (db, session) async {
        await InventoryRepository(db, session).createEvent(name: 'CP32');
      },
    );
    await tester.tap(find.widgetWithText(FilledButton, '选择场次'));
    await settle(tester);
    expect(find.text('场次'), findsOneWidget);

    await tester.tap(find.text('CP32'));
    await settle(tester);
    // 回到收银台，标题显示刚选的场次。
    expect(find.text('场次'), findsNothing);
    expect(find.widgetWithText(TextButton, 'CP32'), findsOneWidget);
    expect(find.text('还没有选择场次'), findsNothing);
    await unmountApp(tester);
  });
}
