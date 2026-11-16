import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/features/pos/menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('按标签分组：按第一次出现的顺序，多个标签出现在每一组，没标签的放最后', () {
    final sections = groupByTags(
      ['徽章A', '立牌', '明信片', '色纸'],
      (name) => productTags(
        {'徽章A': '徽章', '立牌': '立牌，新品', '明信片': '', '色纸': ' 新品 ,'}[name]!,
      ),
    );
    expect([for (final s in sections) s.title], ['徽章', '立牌', '新品', null]);
    expect(sections[2].items, ['立牌', '色纸']);
    expect(sections.last.items, ['明信片']);
  });

  test('按场次的顺序排分组和组里的商品，没列出的排后面保持原顺序', () {
    final sections = [
      const MenuSection('徽章', ['a', 'b', 'c']),
      const MenuSection('立牌', ['d', 'e']),
      const MenuSection<String>(null, ['f']),
    ];
    final ordered = orderMenu(
      sections,
      groupOrder: [otherGroupKey, '立牌'],
      productOrder: ['c', 'e', 'a'],
      idOf: (s) => s,
    );
    expect([for (final s in ordered) s.title], [null, '立牌', '徽章']);
    expect(ordered[1].items, ['e', 'd']);
    expect(ordered[2].items, ['c', 'a', 'b']);
    // 没调过顺序就原样。
    expect(
      orderMenu(
        sections,
        groupOrder: [],
        productOrder: [],
        idOf: (s) => s,
      ).map((s) => s.title),
      ['徽章', '立牌', null],
    );
  });

  testWidgets('收银台按这一场的顺序显示，分类栏下面的「排序」能打开这一场的排序页', (tester) async {
    await pumpApp(
      tester,
      size: const Size(1180, 820),
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        final inventory = InventoryRepository(db, session);
        final eventId = await inventory.createEvent(name: 'CP30');
        for (final (name, tag) in [
          ('徽章A', '徽章'),
          ('徽章B', '徽章'),
          ('立牌', '立牌'),
        ]) {
          await catalog.saveProduct(
            ProductDraft(
              name: name,
              tags: tag,
              variants: [VariantDraft(price: 100)],
            ),
          );
        }
        final ids = {
          for (final p in await catalog.loadCatalog()) p.product.name: p,
        };
        for (final p in ids.values) {
          await inventory.setEventQuantity(
            variantId: p.variants.single.id,
            eventId: eventId,
            eventQuantity: 3,
          );
        }
        await inventory.setEventOrder(
          eventId,
          groups: ['立牌', '徽章'],
          products: [ids['徽章B']!.product.id],
        );
        await inventory.setCurrentEvent(eventId);
      },
    );
    double top(String text) => tester.getTopLeft(find.text(text).first).dy;
    double left(String text) => tester.getTopLeft(find.text(text)).dx;
    // 分类栏：立牌在徽章前面；徽章组里 B 在 A 前面（平板上同一行，B 在左边）。
    expect(top('立牌'), lessThan(top('徽章')));
    expect(left('徽章B'), lessThan(left('徽章A')));

    await tester.tap(find.text('排序'));
    await settle(tester);
    expect(find.text('收银台顺序 · CP30'), findsOneWidget);
    expect(find.byTooltip('拖动排序'), findsNWidgets(2 + 3));
    await unmountApp(tester);
  });

  testWidgets('手机点菜：左边分类，点分类跳过去，直接加减，多规格选规格', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        final inventory = InventoryRepository(db, session);
        // 一屏放不下的徽章，后面是没有标签的明信片和两种规格的色纸。
        for (var i = 1; i <= 8; i++) {
          await catalog.saveProduct(
            ProductDraft(
              name: '徽章$i',
              tags: '徽章',
              variants: [VariantDraft(price: 1500)],
            ),
          );
        }
        await catalog.saveProduct(
          ProductDraft(name: '明信片', variants: [VariantDraft(price: 500)]),
        );
        await catalog.saveProduct(
          ProductDraft(
            name: '色纸',
            kind: ProductKind.variants,
            tags: '色纸',
            variants: [
              VariantDraft(label: '红', price: 2000),
              VariantDraft(label: '蓝', price: 2000),
            ],
          ),
        );
        final eventId = await inventory.createEvent(name: 'CP30');
        for (final p in await catalog.loadCatalog()) {
          for (final v in p.variants) {
            await inventory.setEventQuantity(
              variantId: v.id,
              eventId: eventId,
              eventQuantity: 5,
            );
          }
        }
        await inventory.setCurrentEvent(eventId);
      },
    );

    // 分类栏在左边（排在前面，所以 .first 是分类栏、.last 是列表里的标题）。
    // 默认选中“全部”：所有分类按段列出（分类栏 + 段标题）。
    expect(
      tester.getSemantics(find.text('全部').first),
      isSemantics(isSelected: true),
    );
    for (final title in ['徽章', '色纸', '其他']) {
      expect(find.text(title), findsNWidgets(title == '色纸' ? 3 : 2));
    }

    // 点“其他”只显示这一类的商品。
    await tester.tap(find.text('其他').first);
    await settle(tester);
    expect(find.text('明信片'), findsOneWidget);
    expect(find.text('徽章1'), findsNothing);
    expect(find.text('色纸'), findsOneWidget); // 只剩分类栏里的
    expect(
      tester.getSemantics(find.text('其他').first),
      isSemantics(isSelected: true),
    );

    // 加两件、减一件；行里显示数量，分类栏上显示这一类已点的件数。
    Finder inItem(Finder text, Finder matching) => find.descendant(
      of: find.ancestor(of: text, matching: find.byType(InkWell)).first,
      matching: matching,
    );
    // 购物车清单里也有“明信片”，列表在前面，用 .first。
    final postcard = find.text('明信片').first;
    final otherTab = find.text('其他').first;
    // 加减只改内存里的购物车，不碰数据库：直接推几帧就行。
    Future<void> frames() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.tap(inItem(postcard, find.byTooltip('加一件')));
    await tester.tap(inItem(postcard, find.byTooltip('加一件')));
    await frames();
    expect(inItem(postcard, find.text('2')), findsOneWidget);
    expect(inItem(otherTab, find.text('2')), findsOneWidget);
    await tester.tap(inItem(postcard, find.byTooltip('减一件')));
    await frames();
    expect(inItem(postcard, find.text('1')), findsOneWidget);
    expect(inItem(otherTab, find.text('1')), findsOneWidget);
    expect(inItem(postcard, find.text('余 4')), findsOneWidget);

    // 多规格：到“色纸”里选规格，选一个加进购物车。
    await tester.tap(find.text('色纸').first);
    await settle(tester);
    expect(find.text('明信片'), findsOneWidget); // 购物车清单里的
    await tester.tap(find.widgetWithText(OutlinedButton, '选择规格'));
    await settle(tester);
    await tester.tap(find.text('蓝'));
    await settle(tester);
    // 手机上已点清单常驻在购物车条上面。
    expect(find.text('已点 2 件'), findsOneWidget);
    expect(find.text('色纸 · 蓝'), findsOneWidget);

    // 回到“全部”，又能看到所有商品。
    await tester.tap(find.text('全部').first);
    await settle(tester);
    expect(find.text('徽章1'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('全部').first),
      isSemantics(isSelected: true),
    );
    semantics.dispose();
    await unmountApp(tester);
  });

  testWidgets('自定义分类：按分类排序显示，没归类的在“其他”；已点清单可以收起', (tester) async {
    await pumpApp(
      tester,
      seed: (db, session) async {
        final catalog = CatalogRepository(db, session);
        final inventory = InventoryRepository(db, session);
        final stand = await catalog.createCategory('立牌');
        final badge = await catalog.createCategory('吧唧');
        // 拖动排序：吧唧放到最前面。
        await catalog.reorderCategories([badge, stand]);
        final gone = await catalog.createCategory('已删除');
        await catalog.deleteCategory(gone);
        await catalog.saveProduct(
          ProductDraft(
            name: '亚克力立牌',
            tags: '旧标签',
            categoryIds: [stand],
            variants: [VariantDraft(price: 4500)],
          ),
        );
        await catalog.saveProduct(
          ProductDraft(
            name: '吧唧套组',
            categoryIds: [badge, gone],
            variants: [VariantDraft(price: 3000)],
          ),
        );
        await catalog.saveProduct(
          ProductDraft(name: '明信片', variants: [VariantDraft(price: 500)]),
        );
        final eventId = await inventory.createEvent(name: 'CP30');
        for (final p in await catalog.loadCatalog()) {
          await inventory.setEventQuantity(
            variantId: p.variants.single.id,
            eventId: eventId,
            eventQuantity: 5,
          );
        }
        await inventory.setCurrentEvent(eventId);
      },
    );

    // 分类栏：全部、吧唧、立牌、其他（从上到下）；删掉的分类和旧标签都不出现。
    final ys = [
      for (final t in ['全部', '吧唧', '立牌', '其他'])
        tester.getCenter(find.text(t).first).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.text('已删除'), findsNothing);
    expect(find.text('旧标签'), findsNothing);

    // 加一件后已点清单出现在购物车条上面，点收起后只剩购物车条。
    await tester.tap(find.text('明信片'));
    await settle(tester);
    expect(find.text('已点 1 件'), findsOneWidget);
    await tester.tap(find.byTooltip('收起已点'));
    await settle(tester);
    expect(find.text('已点 1 件'), findsNothing);
    expect(find.text('¥5.00'), findsWidgets);
    await unmountApp(tester);
  });
}
