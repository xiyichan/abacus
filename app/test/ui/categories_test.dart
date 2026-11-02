import 'package:abacus/data/catalog_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('管理分类：新建、改名，商品里勾选分类', (tester) async {
    await pumpApp(
      tester,
      seed: (db, session) => CatalogRepository(db, session).saveProduct(
        ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
      ),
    );
    await tester.tap(find.text('商品').last);
    await settle(tester);
    await tester.tap(find.byTooltip('管理分类'));
    await settle(tester);
    expect(find.text('还没有分类'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '新建分类'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '吧唧');
    await tester.tap(find.text('添加'));
    await settle(tester);
    expect(find.text('吧唧'), findsOneWidget);
    expect(find.text('0 个商品'), findsOneWidget);

    // 点一行改名。
    await tester.tap(find.text('吧唧'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '徽章类');
    await tester.tap(find.text('保存'));
    await settle(tester);
    expect(find.text('徽章类'), findsOneWidget);

    // 商品编辑页勾上这个分类并保存。
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.text('徽章'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilterChip, '徽章类'));
    await settle(tester);
    await tester.tap(find.text('保存'));
    await settle(tester);
    // 回到商品列表：顶部多了这个分类的筛选，商品下面显示所属分类。
    expect(find.text('徽章'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '徽章类'), findsOneWidget);
    expect(find.text('徽章类'), findsNWidgets(2));
    await tester.tap(find.widgetWithText(ChoiceChip, '徽章类'));
    await settle(tester);
    expect(find.text('共 1 款'), findsOneWidget);
    await unmountApp(tester);
  });
}
