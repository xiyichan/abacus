import 'package:abacus/data/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('商品页可以进入调整顺序，每件商品有拖动把手', (tester) async {
    await pumpApp(
      tester,
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        for (final name in ['徽章', '色纸']) {
          await catalog.saveProduct(
            ProductDraft(name: name, variants: [VariantDraft(price: 100)]),
          );
        }
      },
    );
    await tester.tap(find.text('商品'));
    await settle(tester);
    await tester.tap(find.byTooltip('调整顺序'));
    await settle(tester);
    expect(find.byTooltip('拖动排序'), findsNWidgets(2));
    expect(find.text('徽章'), findsOneWidget);

    await tester.tap(find.byTooltip('完成'));
    await settle(tester);
    expect(find.byTooltip('拖动排序'), findsNothing);
    expect(find.text('共 2 款'), findsOneWidget);
    await unmountApp(tester);
  });
}
