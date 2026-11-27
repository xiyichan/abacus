import 'package:abacus/data/catalog_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('编辑商品时可以拖动把手调整规格顺序，保存后顺序不变', (tester) async {
    final app = await pumpApp(
      tester,
      size: const Size(1024, 1366),
      seed: (db, session) async {
        await CatalogRepository(db, session).saveProduct(
          ProductDraft(
            name: '谷子',
            kind: ProductKind.variants,
            variants: [
              VariantDraft(label: '拍立得', price: 600),
              VariantDraft(label: '钥匙扣', price: 500),
              VariantDraft(label: '徽章', price: 1800),
            ],
          ),
        );
      },
    );
    await tester.tap(find.text('商品'));
    await settle(tester);
    await tester.tap(find.text('谷子'));
    await settle(tester);

    final handles = find.byTooltip('拖动排序');
    expect(handles, findsNWidgets(3));
    // 把第一个规格拖到最后。
    final gesture = await tester.startGesture(tester.getCenter(handles.first));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);

    await tester.tap(find.text('保存'));
    await settle(tester);
    final catalog = (await tester.runAsync(
      () => CatalogRepository(app.db, app.session).loadCatalog(),
    ))!;
    expect(
      [for (final v in catalog.single.variants) v.label],
      ['钥匙扣', '徽章', '拍立得'],
    );
    await unmountApp(tester);
  });
}
