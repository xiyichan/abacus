import 'dart:math';

import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/database.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:abacus/data/session.dart';
import 'package:abacus/sync/hlc.dart';
import 'package:abacus/sync/op_store.dart';
import 'package:abacus/sync/team_invite.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试用的一台设备。
class Node {
  Node._(this.db, this.session)
    : store = OpStore(db),
      catalog = CatalogRepository(db, session),
      inventory = InventoryRepository(db, session),
      sales = SalesRepository(db, session);

  static Future<Node> founder() async {
    final db = AppDatabase(NativeDatabase.memory());
    return Node._(db, await ensureSession(db));
  }

  static Future<Node> joining(Node inviter) async {
    final db = AppDatabase(NativeDatabase.memory());
    await ensureSession(db); // 新装 App 先有自己的团队，加入时会被清空
    final invite = await createInvite(inviter.db, inviter.session);
    await joinTeam(db, invite, deviceName: 'test');
    return Node._(db, await ensureSession(db));
  }

  final AppDatabase db;
  final Session session;
  final OpStore store;
  final CatalogRepository catalog;
  final InventoryRepository inventory;
  final SalesRepository sales;
}

/// 把 [from] 有而 [to] 没有的操作全部发过去（和网络协议做的事一样）。
Future<void> pushAll(Node from, Node to) async {
  while (true) {
    final ops = await from.store.opsMissingFrom(
      await to.store.versionVector(),
      limit: 50,
    );
    if (ops.isEmpty) return;
    final applied = await to.store.applyRemote(ops);
    for (final op in applied) {
      to.session.clock.receive(op.hlc);
    }
  }
}

Future<void> syncPair(Node a, Node b) async {
  await pushAll(a, b);
  await pushAll(b, a);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('HLC：收到更晚的远端时间戳后，本机新时间戳排在它后面', () {
    final clock = HlcClock(
      'a',
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final remote = HlcClock(
      'b',
      now: () => DateTime.fromMillisecondsSinceEpoch(5000),
    ).tick();
    clock.receive(remote);
    expect(clock.tick().compareTo(remote), greaterThan(0));
  });

  test('邀请码编码/解析，代号依次分配', () {
    final invite = TeamInvite(
      teamId: 't',
      teamName: '我的摊位',
      currency: 'CNY',
      teamKey: List.filled(32, 7),
      deviceCode: 'B',
    );
    final parsed = TeamInvite.tryParse(invite.encode())!;
    expect(parsed.teamName, '我的摊位');
    expect(parsed.teamKey, invite.teamKey);
    expect(TeamInvite.tryParse('hello'), isNull);
    // 随机 6 位字母数字，不含容易看错的字符；订单号前缀（前两位）不和已有设备重复。
    final used = ['A', 'K7XQ2M'];
    for (var i = 0; i < 200; i++) {
      final code = nextDeviceCode(used);
      expect(code, matches(RegExp(r'^[2-9A-HJKMNP-Z]{6}$')));
      expect(orderPrefixOf(code), isNot('K7'));
    }
    expect(orderPrefixOf('K7XQ2M'), 'K7');
    expect(orderPrefixOf('A'), 'A');
  });

  test('本机写入自动记入操作日志', () async {
    final a = await Node.founder();
    addTearDown(a.db.close);
    final before = (await a.store.versionVector())[a.session.deviceId]!;
    await a.catalog.saveProduct(
      ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
    );
    final after = (await a.store.versionVector())[a.session.deviceId]!;
    expect(after, greaterThan(before));
  });

  test('新设备加入团队后同步到全部数据', () async {
    final a = await Node.founder();
    await a.catalog.saveProduct(
      ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
    );
    final b = await Node.joining(a);
    addTearDown(a.db.close);
    addTearDown(b.db.close);
    expect(b.session.teamId, a.session.teamId);
    expect(b.session.deviceShortCode, hasLength(6));
    expect(b.session.orderPrefix, isNot(a.session.orderPrefix));
    expect(await b.catalog.loadCatalog(), isEmpty);

    await syncPair(a, b);
    final items = await b.catalog.loadCatalog();
    expect(items.single.product.name, '徽章');
    expect((await b.sales.watchPaymentMethods().first).length, 3);
    // A 也知道了 B 这台设备。
    final devices = await a.db.select(a.db.devices).get();
    expect(
      devices.map((d) => d.shortCode),
      unorderedEquals([a.session.deviceShortCode, b.session.deviceShortCode]),
    );
  });

  test('两台设备离线各自卖同一件货，合并后库存和订单都对', () async {
    final a = await Node.founder();
    final b = await Node.joining(a);
    addTearDown(a.db.close);
    addTearDown(b.db.close);
    await a.catalog.saveProduct(
      ProductDraft(name: '亚克力', variants: [VariantDraft(price: 3000)]),
    );
    final v = (await a.catalog.loadCatalog()).single.variants.single;
    final eventId = await a.inventory.createEvent(name: 'CP30');
    await a.inventory.setEventQuantity(
      variantId: v.id,
      eventId: eventId,
      eventQuantity: 10,
    );
    await syncPair(a, b);

    // 断网：各卖各的
    final cashA = (await a.sales.watchPaymentMethods().first).first;
    final cashB = (await b.sales.watchPaymentMethods().first).first;
    final line = SaleLine(
      variantId: v.id,
      name: '亚克力',
      unitPrice: 3000,
      quantity: 2,
    );
    final orderA = await a.sales.placeOrder(
      eventId: eventId,
      lines: [line],
      paymentMethod: cashA,
    );
    final orderB = await b.sales.placeOrder(
      eventId: eventId,
      lines: [line],
      paymentMethod: cashB,
    );
    final numA = '${a.session.orderPrefix}-001';
    final numB = '${b.session.orderPrefix}-001';
    expect(orderA.number, numA);
    expect(orderB.number, numB);

    await syncPair(a, b);
    for (final node in [a, b]) {
      expect((await node.db.stockAt(eventId))[v.id], 6);
      final orders = await node.sales.watchOrders(eventId).first;
      expect(orders.map((o) => o.order.number), unorderedEquals([numA, numB]));
    }
  });

  test('同一商品两边同时改价：时间戳较晚的一方生效，两边一致', () async {
    final a = await Node.founder();
    final b = await Node.joining(a);
    addTearDown(a.db.close);
    addTearDown(b.db.close);
    final id = await a.catalog.saveProduct(
      ProductDraft(name: '明信片', variants: [VariantDraft(price: 500)]),
    );
    await syncPair(a, b);
    final variantId = (await a.catalog.loadCatalog()).single.variants.single.id;

    await a.catalog.saveProduct(
      ProductDraft(
        id: id,
        name: '明信片',
        variants: [VariantDraft(id: variantId, price: 600)],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await b.catalog.saveProduct(
      ProductDraft(
        id: id,
        name: '明信片（新版）',
        variants: [VariantDraft(id: variantId, price: 800)],
      ),
    );
    await syncPair(a, b);
    for (final node in [a, b]) {
      final p = (await node.catalog.loadCatalog()).single;
      expect(p.product.name, '明信片（新版）');
      expect(p.variants.single.price, 800);
    }
  });

  test('三台设备随机离线、乱序互相同步，最终数据完全一致', () async {
    final random = Random(42);
    final a = await Node.founder();
    final b = await Node.joining(a);
    await syncPair(a, b);
    final c = await Node.joining(a);
    final nodes = [a, b, c];
    addTearDown(() async {
      for (final n in nodes) {
        await n.db.close();
      }
    });
    await a.catalog.saveProduct(
      ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
    );
    final v = (await a.catalog.loadCatalog()).single.variants.single;
    final eventId = await a.inventory.createEvent(name: 'CP30');
    await a.inventory.setEventQuantity(
      variantId: v.id,
      eventId: eventId,
      eventQuantity: 60,
    );
    await syncPair(a, b);
    await syncPair(a, c);

    var sold = 0;
    for (var round = 0; round < 30; round++) {
      final node = nodes[random.nextInt(3)];
      final method = (await node.sales.watchPaymentMethods().first).first;
      final qty = 1 + random.nextInt(3);
      await node.sales.placeOrder(
        eventId: eventId,
        lines: [
          SaleLine(variantId: v.id, name: '徽章', unitPrice: 1500, quantity: qty),
        ],
        paymentMethod: method,
      );
      sold += qty;
      // 随机挑两台设备同步一次（模拟时有时无的网络）。
      if (random.nextBool()) {
        final i = random.nextInt(3);
        await syncPair(nodes[i], nodes[(i + 1 + random.nextInt(2)) % 3]);
      }
    }
    // 网络恢复后两两同步一轮。
    await syncPair(a, b);
    await syncPair(b, c);
    await syncPair(a, c);

    final vectors = [for (final n in nodes) await n.store.versionVector()];
    expect(vectors[1], vectors[0]);
    expect(vectors[2], vectors[0]);
    for (final n in nodes) {
      expect((await n.db.stockAt(eventId))[v.id], 60 - sold);
      final orders = await n.sales.watchOrders(eventId).first;
      expect(orders.length, 30);
      expect(orders.map((o) => o.order.number).toSet().length, 30); // 单号不重复
    }
  });
}
