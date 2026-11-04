import 'dart:async';
import 'dart:io';

import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:abacus/providers.dart';
import 'package:abacus/support/tip_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// 不连商店的打赏：三个档位，付款后马上成功。
class _FakeTipStore implements TipStore {
  _FakeTipStore(this.prefs);

  final SupportPrefs prefs;
  final _outcomes = StreamController<TipOutcome>.broadcast();
  final bought = <String>[];

  @override
  Future<List<TipOption>> load() async => const [
    TipOption(id: 'tip_small', price: '¥6.00'),
    TipOption(id: 'tip_medium', price: '¥18.00'),
    TipOption(id: 'tip_large', price: '¥30.00'),
  ];

  @override
  Future<void> buy(TipOption option) async {
    bought.add(option.id);
    prefs.markTipped();
    _outcomes.add(TipOutcome.thanked);
  }

  @override
  Stream<TipOutcome> get outcomes => _outcomes.stream;
}

Future<SupportPrefs> _prefs(WidgetTester tester) async {
  final dir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('abacus-support'),
  ))!;
  addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
  return SupportPrefs.load(File('${dir.path}/support.json'));
}

void main() {
  test('收摊后第一次提打赏，之后隔几场再提；打赏过就不再提，并且记在文件里', () async {
    final dir = await Directory.systemTemp.createTemp('abacus-support');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/support.json');
    var prefs = SupportPrefs.load(file);

    expect(prefs.recordEventEnded(), isTrue);
    prefs.snoozePrompt();
    for (var i = 1; i < SupportPrefs.snoozeEvents; i++) {
      expect(prefs.recordEventEnded(), isFalse);
    }
    // 重新打开 App 也记得推到第几场了。
    prefs = SupportPrefs.load(file);
    expect(prefs.recordEventEnded(), isTrue);

    prefs.markTipped();
    prefs = SupportPrefs.load(file);
    expect(prefs.tipped, isTrue);
    for (var i = 0; i < 10; i++) {
      expect(prefs.recordEventEnded(), isFalse);
    }
  });

  testWidgets('设置里请作者喝咖啡：显示商店价格，付款后道谢，设置页显示已请过', (tester) async {
    final prefs = await _prefs(tester);
    final store = _FakeTipStore(prefs);
    await pumpApp(
      tester,
      overrides: [
        supportPrefsProvider.overrideWithValue(prefs),
        tipStoreProvider.overrideWithValue(store),
      ],
    );

    await tester.tap(find.text('设置'));
    await settle(tester);
    expect(find.text('觉得好用的话，支持一下小算盘'), findsOneWidget);
    await tester.tap(find.text('请作者喝杯咖啡'));
    await settle(tester);
    expect(find.text('☕ 一杯咖啡'), findsOneWidget);
    expect(find.text('¥18.00'), findsOneWidget);

    await tester.tap(find.text('¥6.00'));
    await settle(tester);
    expect(store.bought, ['tip_small']);
    expect(find.text('谢谢你的咖啡！'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('已请过 ❤️'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('连不上商店时打赏页说明原因，不显示档位', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('设置'));
    await settle(tester);
    await tester.tap(find.text('请作者喝杯咖啡'));
    await settle(tester);
    expect(find.text('暂时连不上应用商店，稍后再来看看。'), findsOneWidget);
    expect(find.text('☕ 一杯咖啡'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('卖过东西的场次结束后提一句打赏，点“下次再说”就关掉', (tester) async {
    final prefs = await _prefs(tester);
    await pumpApp(
      tester,
      size: const Size(1180, 820),
      overrides: [
        supportPrefsProvider.overrideWithValue(prefs),
        tipStoreProvider.overrideWithValue(_FakeTipStore(prefs)),
      ],
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        final inventory = InventoryRepository(db, session);
        final sales = SalesRepository(db, session);
        await catalog.saveProduct(
          ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
        );
        final v = (await catalog.loadCatalog()).single.variants.single;
        final eventId = await inventory.createEvent(
          name: 'CP30',
          startsOn: DateTime.now().subtract(const Duration(days: 2)),
        );
        await inventory.setEventQuantity(
          variantId: v.id,
          eventId: eventId,
          eventQuantity: 4,
        );
        await inventory.setCurrentEvent(eventId);
        await sales.placeOrder(
          eventId: eventId,
          lines: [
            SaleLine(variantId: v.id, name: '徽章', unitPrice: 1500, quantity: 1),
          ],
          paymentMethod: (await sales.watchPaymentMethods().first).first,
        );
      },
    );

    await tester.tap(find.text('收银'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '结束场次'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '结束场次').last);
    await settle(tester);
    expect(find.text('「CP30」辛苦啦！'), findsOneWidget);
    expect(find.textContaining('这一场卖出了 1 单'), findsOneWidget);

    await tester.tap(find.text('下次再说'));
    await settle(tester);
    expect(find.text('「CP30」辛苦啦！'), findsNothing);
    expect(find.text('还没有选择场次'), findsOneWidget);
    await unmountApp(tester);
  });
}
