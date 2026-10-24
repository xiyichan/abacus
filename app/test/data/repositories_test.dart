import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/database.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:abacus/data/session.dart';
import 'package:abacus/domain/checkout.dart';
import 'package:abacus/domain/stock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Session session;
  late CatalogRepository catalog;
  late InventoryRepository inventory;
  late SalesRepository sales;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    session = await ensureSession(db);
    catalog = CatalogRepository(db, session);
    inventory = InventoryRepository(db, session);
    sales = SalesRepository(db, session);
  });
  tearDown(() => db.close());

  Future<PaymentMethod> cash() async =>
      (await sales.watchPaymentMethods().first).firstWhere(
        (m) => m.kind == 'cash',
      );

  test('首次启动创建团队、本机设备和默认支付方式，再次启动沿用', () async {
    final methods = await sales.watchPaymentMethods().first;
    expect([for (final m in methods) m.name], ['现金', '微信', '支付宝']);
    final again = await ensureSession(db);
    expect(again.deviceId, session.deviceId);
    expect(again.teamId, session.teamId);
    expect(again.deviceShortCode, session.deviceShortCode);
    expect(session.deviceShortCode, hasLength(6));
  });

  test('早期单字母设备号启动时升级为随机设备号，之前的单号不变', () async {
    final eventId = await inventory.createEvent(name: 'CP30');
    await db.customStatement(
      "UPDATE devices SET short_code = 'A' WHERE id = ?",
      [session.deviceId],
    );
    final legacy = await ensureSession(db);
    expect(legacy.deviceShortCode, hasLength(6));
    expect(legacy.orderPrefix, hasLength(2));
    final device = await (db.select(
      db.devices,
    )..where((t) => t.id.equals(session.deviceId))).getSingle();
    expect(device.shortCode, legacy.deviceShortCode);
    // 再次启动不会再换。
    expect((await ensureSession(db)).deviceShortCode, legacy.deviceShortCode);
    final next = await SalesRepository(db, legacy).nextOrderNumber(eventId);
    expect(next, '${legacy.orderPrefix}-001');
  });

  test('保存商品：规格、套装组成', () async {
    final badgeId = await catalog.saveProduct(
      ProductDraft(
        name: '徽章',
        kind: ProductKind.variants,
        variants: [
          VariantDraft(label: '红', price: 1500),
          VariantDraft(label: '蓝', price: 1500),
        ],
      ),
    );
    final items = await catalog.loadCatalog();
    final badge = items.single;
    expect(badge.product.id, badgeId);
    expect([
      for (final v in badge.variants) v.label,
    ], unorderedEquals(['红', '蓝']));
    final red = badge.variants.firstWhere((v) => v.label == '红');

    await catalog.saveProduct(
      ProductDraft(
        name: '徽章套装',
        kind: ProductKind.bundle,
        variants: [VariantDraft(price: 2500)],
        components: [BundleComponent(red.id, 2)],
      ),
    );
    final bundle = (await catalog.loadCatalog()).firstWhere((p) => p.isBundle);
    expect(bundle.components.values.single.single.quantity, 2);

    // 删掉的规格被软删除。
    await catalog.saveProduct(
      ProductDraft(
        id: badgeId,
        name: '徽章',
        kind: ProductKind.variants,
        variants: [VariantDraft(id: red.id, label: '红', price: 1600)],
      ),
    );
    final updated = (await catalog.loadCatalog()).firstWhere(
      (p) => p.product.id == badgeId,
    );
    expect(updated.variants.single.price, 1600);
    expect(await db.stockAt(homeLocation), isEmpty);
  });

  test('场次备货、下单扣库存（含套装）、退款回补', () async {
    await catalog.saveProduct(
      ProductDraft(name: '亚克力', variants: [VariantDraft(price: 3000)]),
    );
    final acrylic = (await catalog.loadCatalog()).single.variants.single;
    await catalog.saveProduct(
      ProductDraft(
        name: '双人套装',
        kind: ProductKind.bundle,
        variants: [VariantDraft(price: 5000)],
        components: [BundleComponent(acrylic.id, 2)],
      ),
    );
    final bundle = (await catalog.loadCatalog()).firstWhere((p) => p.isBundle);
    final bundleVariant = bundle.variants.single;

    final eventId = await inventory.createEvent(name: 'CP30');
    await inventory.setEventQuantity(
      variantId: acrylic.id,
      eventId: eventId,
      eventQuantity: 10,
    );
    expect(await db.stockAt(eventId), {acrylic.id: 10});

    final order = await sales.placeOrder(
      eventId: eventId,
      lines: [
        SaleLine(
          variantId: acrylic.id,
          name: '亚克力',
          unitPrice: 3000,
          quantity: 1,
        ),
        SaleLine(
          variantId: bundleVariant.id,
          name: '双人套装',
          unitPrice: 5000,
          quantity: 1,
          components: bundle.components[bundleVariant.id]!,
        ),
      ],
      paymentMethod: await cash(),
      discount: const AmountOff(1000),
      tendered: 10000,
    );
    expect(order.number, '${session.orderPrefix}-001');
    expect(order.total, 7000);
    expect((await db.stockAt(eventId))[acrylic.id], 7);

    final second = await sales.placeOrder(
      eventId: eventId,
      lines: [
        SaleLine(
          variantId: acrylic.id,
          name: '亚克力',
          unitPrice: 3000,
          quantity: 1,
        ),
      ],
      paymentMethod: await cash(),
    );
    expect(second.number, '${session.orderPrefix}-002');

    await sales.refundOrder(order.id);
    await sales.refundOrder(order.id); // 重复退款无效
    expect((await db.stockAt(eventId))[acrylic.id], 9);

    final summaries = await sales.watchOrders(eventId).first;
    expect(summaries.length, 2);
    final refunded = summaries.firstWhere((s) => s.order.id == order.id);
    expect(refunded.isRefunded, isTrue);
    expect(refunded.itemCount, 2);
    expect(refunded.paymentNames, '现金');

    final detail = await sales.watchOrderDetail(order.id).first;
    expect(detail.payments.single.tendered, 10000);
    expect(detail.items.length, 2);
  });

  test('带到本场数量为 0 也算本场有这件货', () async {
    await catalog.saveProduct(
      ProductDraft(name: '明信片', variants: [VariantDraft(price: 500)]),
    );
    final v = (await catalog.loadCatalog()).single.variants.single;
    final eventId = await inventory.createEvent(name: 'CP30');
    await inventory.setEventQuantity(
      variantId: v.id,
      eventId: eventId,
      eventQuantity: 0,
    );
    expect(await db.stockAt(eventId), {v.id: 0});
  });

  test('当前场次只存本机', () async {
    final eventId = await inventory.createEvent(name: 'CP30');
    expect(await inventory.watchCurrentEventId().first, isNull);
    await inventory.setCurrentEvent(eventId);
    expect(await inventory.watchCurrentEventId().first, eventId);
  });

  test('订单详情在退款后自动刷新', () async {
    await catalog.saveProduct(
      ProductDraft(name: '明信片', variants: [VariantDraft(price: 500)]),
    );
    final v = (await catalog.loadCatalog()).single.variants.single;
    final eventId = await inventory.createEvent(name: 'CP30');
    await inventory.setEventQuantity(
      variantId: v.id,
      eventId: eventId,
      eventQuantity: 5,
    );
    final order = await sales.placeOrder(
      eventId: eventId,
      lines: [
        SaleLine(variantId: v.id, name: '明信片', unitPrice: 500, quantity: 1),
      ],
      paymentMethod: await cash(),
    );
    final updates = sales
        .watchOrderDetail(order.id)
        .map((d) => d.refund != null);
    final expectation = expectLater(updates, emitsInOrder([false, true]));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sales.refundOrder(order.id);
    await expectation;
  });

  test('扫码付款：预先确定单号作备注码，稍后确认收款', () async {
    await catalog.saveProduct(
      ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
    );
    final v = (await catalog.loadCatalog()).single.variants.single;
    final eventId = await inventory.createEvent(name: 'CP30');
    await inventory.setEventQuantity(
      variantId: v.id,
      eventId: eventId,
      eventQuantity: 5,
    );
    final wechat = (await sales.watchPaymentMethods().first).firstWhere(
      (m) => m.name == '微信',
    );
    final line = SaleLine(
      variantId: v.id,
      name: '徽章',
      unitPrice: 1500,
      quantity: 1,
    );

    final reserved = await sales.nextOrderNumber(eventId);
    expect(reserved, '${session.orderPrefix}-001');
    expect(paymentCodeOf(reserved), '${session.orderPrefix}001');
    final order = await sales.placeOrder(
      eventId: eventId,
      lines: [line],
      paymentMethod: wechat,
      number: reserved,
      paymentPending: true,
    );
    expect(order.number, '${session.orderPrefix}-001');
    var summary = (await sales.watchOrders(eventId).first).single;
    expect(summary.paymentPending, isTrue);
    var stats = await sales.watchEventStats(eventId).first;
    expect((stats.pendingCount, stats.pendingAmount), (1, 1500));

    // 预留的单号已被占用时自动换一个。
    final second = await sales.placeOrder(
      eventId: eventId,
      lines: [line],
      paymentMethod: wechat,
      number: reserved,
    );
    expect(second.number, '${session.orderPrefix}-002');

    await sales.confirmPayment(order.id);
    summary = (await sales.watchOrders(eventId).first).firstWhere(
      (s) => s.order.id == order.id,
    );
    expect(summary.paymentPending, isFalse);
    stats = await sales.watchEventStats(eventId).first;
    expect(stats.pendingCount, 0);
    final detail = await sales.watchOrderDetail(order.id).first;
    expect(detail.payments.single.confirmedAt, isNotNull);
  });

  test('备注码搜索格式统一', () {
    expect(normalizeOrderCode('a-007'), 'A007');
    expect(normalizeOrderCode(' A 007 '), 'A007');
  });
}
