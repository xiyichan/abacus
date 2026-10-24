import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/database.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/data/order_export.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:abacus/data/session.dart';
import 'package:abacus/domain/checkout.dart';
import 'package:abacus/domain/stock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;
  late SalesRepository sales;
  late String eventId;
  late String prefix;
  late PaymentMethod cash;
  late PaymentMethod wechat;
  late Variant badge;
  late Variant card;
  late Variant set;
  late Map<Variant, List<BundleComponent>> components;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final session = await ensureSession(db);
    prefix = session.orderPrefix;
    catalog = CatalogRepository(db, session);
    sales = SalesRepository(db, session);
    final inventory = InventoryRepository(db, session);
    final miya = await catalog.createCreator('Miya');
    final neko = await catalog.createCreator('Neko');
    await catalog.saveProduct(
      ProductDraft(
        name: '徽章',
        creatorId: miya,
        variants: [VariantDraft(price: 1500)],
      ),
    );
    await catalog.saveProduct(
      ProductDraft(
        name: '色纸',
        creatorId: neko,
        variants: [VariantDraft(price: 1000)],
      ),
    );
    final items = await catalog.loadCatalog();
    badge = items.firstWhere((p) => p.product.name == '徽章').variants.single;
    card = items.firstWhere((p) => p.product.name == '色纸').variants.single;
    await catalog.saveProduct(
      ProductDraft(
        name: '合摊套装',
        kind: ProductKind.bundle,
        variants: [VariantDraft(price: 2000)],
        components: [BundleComponent(badge.id, 1), BundleComponent(card.id, 1)],
      ),
    );
    final bundle = (await catalog.loadCatalog()).firstWhere((p) => p.isBundle);
    set = bundle.variants.single;
    components = {set: bundle.components[set.id]!};
    eventId = await inventory.createEvent(name: 'CP30');
    for (final v in [badge, card]) {
      await inventory.setEventQuantity(
        variantId: v.id,
        eventId: eventId,
        eventQuantity: 10,
      );
    }
    final methods = await sales.watchPaymentMethods().first;
    cash = methods.firstWhere((m) => m.name == '现金');
    wechat = methods.firstWhere((m) => m.name == '微信');
  });
  tearDown(() => db.close());

  SaleLine line(Variant v, String name, int qty) => SaleLine(
    variantId: v.id,
    name: name,
    unitPrice: v.price,
    quantity: qty,
    components: components[v] ?? const [],
  );

  test('统计：营业额、热销、按作者分账（含套装）、支付方式，退款不计入', () async {
    await sales.placeOrder(
      eventId: eventId,
      lines: [line(badge, '徽章', 2)],
      paymentMethod: cash,
      tendered: 5000,
    );
    await sales.placeOrder(
      eventId: eventId,
      lines: [line(set, '合摊套装', 1)],
      paymentMethod: wechat,
    );
    final refunded = await sales.placeOrder(
      eventId: eventId,
      lines: [line(card, '色纸', 1)],
      paymentMethod: cash,
    );
    await sales.refundOrder(refunded.id, reason: '客人改主意');

    final stats = await sales.watchEventStats(eventId).first;
    expect(stats.revenue, 3000 + 2000);
    expect(stats.orderCount, 2);
    expect(stats.refundCount, 1);
    expect(stats.refundAmount, 1000);
    expect(stats.topSellers.first.name, '徽章');

    final creators = await catalog.watchCreators().first;
    final miya = creators.firstWhere((c) => c.name == 'Miya').id;
    final neko = creators.firstWhere((c) => c.name == 'Neko').id;
    // 套装 20 元按成分价值 15:10 拆：Miya 12，Neko 8
    expect(Map.fromEntries(stats.byCreator), {miya: 3000 + 1200, neko: 800});
    expect(
      {for (final p in stats.byPayment) p.name: p.amount},
      {'现金': 3000, '微信': 2000},
    );
  });

  test('商品删除后，历史订单仍按原作者分账', () async {
    await sales.placeOrder(
      eventId: eventId,
      lines: [line(card, '色纸', 1)],
      paymentMethod: cash,
    );
    await catalog.deleteProduct(card.productId);
    final stats = await sales.watchEventStats(eventId).first;
    final neko = (await catalog.watchCreators().first)
        .firstWhere((c) => c.name == 'Neko')
        .id;
    expect(Map.fromEntries(stats.byCreator), {neko: 1000});
  });

  test('统计随新订单自动刷新', () async {
    final updates = sales.watchEventStats(eventId).map((s) => s.orderCount);
    final expectation = expectLater(updates, emitsInOrder([0, 1]));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sales.placeOrder(
      eventId: eventId,
      lines: [line(badge, '徽章', 1)],
      paymentMethod: cash,
    );
    await expectation;
  });

  test('全部场次：统计合计、各场对比、CSV 带场次列', () async {
    final inventory = InventoryRepository(db, (await ensureSession(db)));
    final earlier = await inventory.createEvent(name: 'CP29');
    await sales.placeOrder(
      eventId: eventId,
      lines: [line(badge, '徽章', 2)],
      paymentMethod: cash,
    );
    final refunded = await sales.placeOrder(
      eventId: eventId,
      lines: [line(card, '色纸', 1)],
      paymentMethod: cash,
    );
    await sales.refundOrder(refunded.id);
    await sales.placeOrder(
      eventId: earlier,
      lines: [line(card, '色纸', 3)],
      paymentMethod: wechat,
      paymentPending: true,
    );

    final all = await sales.watchEventStats(null).first;
    expect(all.revenue, 3000 + 3000);
    expect(all.orderCount, 2);
    expect(all.refundCount, 1);

    final rows = await sales.watchEventComparison().first;
    final byName = {for (final r in rows) r.event.name: r};
    expect(byName['CP30']!.orderCount, 1);
    expect(byName['CP30']!.revenue, 3000);
    expect(byName['CP30']!.itemCount, 2);
    expect(byName['CP29']!.itemCount, 3);
    expect(byName['CP29']!.pendingCount, 1);

    final events = await inventory.watchEvents().first;
    final csv = buildOrdersCsv(
      await sales.loadOrderDetails(null),
      eventNames: {for (final e in events) e.id: e.name},
    );
    final lines = csv.split('\r\n');
    expect(lines.length, 4);
    expect(lines[0], startsWith('场次,单号,'));
    expect(lines.skip(1).map((l) => l.split(',').first).toSet(), {
      'CP30',
      'CP29',
    });
  });

  test('导出 CSV：表头、明细、找零和退款信息', () async {
    await sales.placeOrder(
      eventId: eventId,
      lines: [line(badge, '徽章', 2), line(card, '色纸', 1)],
      paymentMethod: cash,
      discount: const AmountOff(500),
      tendered: 5000,
    );
    final second = await sales.placeOrder(
      eventId: eventId,
      lines: [line(card, '色纸', 1)],
      paymentMethod: wechat,
    );
    await sales.refundOrder(second.id, reason: '重复下单');

    final csv = buildOrdersCsv(await sales.loadOrderDetails(eventId));
    final rows = csv.split('\r\n');
    expect(rows.length, 3);
    expect(
      rows[0],
      startsWith('单号,时间,商品,件数,小计,优惠,实收,支付方式,付款备注码,收款状态,收到现金,找零,状态'),
    );
    final first = rows[1].split(',');
    expect(first[0], '$prefix-001');
    expect(first[2], '徽章 ×2；色纸 ×1');
    expect(first.sublist(3, 12), [
      '3',
      '40.00',
      '5.00',
      '35.00',
      '现金',
      '${prefix}001',
      '已收款',
      '50.00',
      '15.00',
    ]);
    expect(first[12], '已完成');
    final refundRow = rows[2].split(',');
    expect(refundRow[0], '$prefix-002');
    expect(refundRow[12], '已退款');
    expect(refundRow.last, '重复下单');
  });
}
