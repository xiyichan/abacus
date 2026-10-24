import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('手机宽度：底部导航，未选场次时提示选择', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('还没有选择场次'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('平板宽度：侧边导航', (tester) async {
    await pumpApp(tester, size: const Size(1180, 820));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('切换到商品页显示空状态', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('商品'));
    await settle(tester);
    expect(find.text('还没有商品，点右下角添加'), findsOneWidget);
    await unmountApp(tester);
  });
}
