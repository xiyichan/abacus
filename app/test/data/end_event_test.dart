import 'dart:io';

import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/database.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:abacus/data/session.dart';
import 'package:abacus/domain/stock.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sync/op_store_test.dart' show Node, syncPair;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Node node;
  late Variant badge;
  late Variant card;
  late String eventId;

  setUp(() async {
    node = await Node.founder();
    await node.catalog.saveProduct(
      ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
    );
    await node.catalog.saveProduct(
      ProductDraft(name: '色纸', variants: [VariantDraft(price: 1000)]),
    );
    final items = await node.catalog.loadCatalog();
    badge = items.firstWhere((p) => p.product.name == '徽章').variants.single;
    card = items.firstWhere((p) => p.product.name == '色纸').variants.single;
    eventId = await node.inventory.createEvent(name: 'CP30');
    await node.inventory.setEventQuantity(
      variantId: badge.id,
      eventId: eventId,
      eventQuantity: 10,
    );
    await node.inventory.setEventQuantity(
      variantId: card.id,
      eventId: eventId,
      eventQuantity: 2,
    );
    await node.inventory.setCurrentEvent(eventId);
  });
  tearDown(() => node.db.close());

  Future<void> sell(Variant v, int qty) async => node.sales.placeOrder(
    eventId: eventId,
    lines: [
      SaleLine(variantId: v.id, name: 'x', unitPrice: v.price, quantity: qty),
    ],
    paymentMethod: (await node.sales.watchPaymentMethods().first).first,
  );

  test('结束场次：标记已结束并取消当前场次，剩余数量保留在场次里', () async {
    await sell(badge, 3);
    await sell(card, 3); // 带了 2 件卖了 3 件
    await node.inventory.endEvent(eventId);

    final event = await node.inventory.watchEvents().first;
    expect(event.single.endedAt, isNotNull);
    expect(await node.db.stockAt(eventId), {badge.id: 7, card.id: -1});
    expect(await node.db.stockAt(homeLocation), isEmpty);
    expect(await node.inventory.watchCurrentEventId().first, isNull);
  });

  test('备货只改本场数量，不影响其他场次', () async {
    final other = await node.inventory.createEvent(name: 'CP31');
    await node.inventory.setEventQuantity(
      variantId: badge.id,
      eventId: other,
      eventQuantity: 4,
    );
    expect(await node.db.stockAt(other), {badge.id: 4});
    expect(await node.db.stockAt(eventId), {badge.id: 10, card.id: 2});
    expect(await node.db.stockAt(homeLocation), isEmpty);
  });

  test('沿用上一场剩余：取最近一个有剩余的场次，只含正数', () async {
    await sell(badge, 3);
    await sell(card, 3);
    await node.inventory.endEvent(eventId);
    final next = await node.inventory.createEvent(name: 'CP31');
    final (from, left) = (await node.inventory.previousLeftover(next))!;
    expect(from.id, eventId);
    expect(left, {badge.id: 7});
    expect(await node.inventory.previousLeftover(eventId), isNull);
  });

  test('重新开启：恢复为进行中，旧版结束时退回家里的流水会撤销', () async {
    await sell(badge, 3);
    // 模拟旧版本结束时的退回流水。
    final ts = node.session.clock.tick();
    for (final (loc, delta) in [(eventId, -7), (homeLocation, 7)]) {
      await node.db
          .into(node.db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: newId(),
              updatedAt: ts,
              variantId: badge.id,
              location: loc,
              delta: delta,
              reason: 'close',
              orderId: Value('close:$eventId'),
              deviceId: node.session.deviceId,
              createdAt: DateTime.now(),
            ),
          );
    }
    await node.inventory.endEvent(eventId);
    await node.inventory.reopenEvent(eventId);
    expect((await node.inventory.watchEvents().first).single.endedAt, isNull);
    expect(await node.db.stockAt(eventId), {badge.id: 7, card.id: 2});
    expect(await node.db.stockAt(homeLocation), isEmpty);
  });

  test('结束状态会同步到其他设备', () async {
    final other = await Node.joining(node);
    addTearDown(other.db.close);
    await syncPair(node, other);
    await node.inventory.endEvent(eventId);
    await syncPair(node, other);
    expect(
      (await other.inventory.watchEvents().first).single.endedAt,
      isNotNull,
    );
    expect(await other.db.stockAt(eventId), {badge.id: 10, card.id: 2});
  });

  test('从旧版数据库（v3）升级：加上结束时间列，操作日志包含新列', () async {
    final dir = await Directory.systemTemp.createTemp('abacus');
    final file = File('${dir.path}/db.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    final session = await ensureSession(db);
    await InventoryRepository(db, session).createEvent(name: 'CP29');
    // 模拟 v3：去掉新列和触发器，把版本号改回 3。
    // （真实的 v3 触发器不含新列；升级时会全部重建，这里先删掉。）
    final triggers = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'trigger'")
        .get();
    for (final t in triggers) {
      await db.customStatement('DROP TRIGGER "${t.read<String>('name')}"');
    }
    await db.customStatement('ALTER TABLE events DROP COLUMN ended_at');
    await db.customStatement('ALTER TABLE events DROP COLUMN ends_on');
    await db.customStatement('ALTER TABLE order_payments DROP COLUMN pending');
    await db.customStatement(
      'ALTER TABLE order_payments DROP COLUMN confirmed_at',
    );
    await db.customStatement('DROP TABLE expenses');
    await db.customStatement('DROP TABLE categories');
    await db.customStatement('ALTER TABLE products DROP COLUMN category_ids');
    await db.customStatement('ALTER TABLE orders DROP COLUMN payment_code');
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    final upgraded = await ensureSession(db);
    final inventory = InventoryRepository(db, upgraded);
    final event = (await inventory.watchEvents().first).single;
    await inventory.endEvent(event.id);
    final last = await db
        .customSelect(
          "SELECT payload FROM op_log WHERE table_name = 'events' ORDER BY seq DESC LIMIT 1",
        )
        .getSingle();
    expect(last.read<String>('payload'), contains('"ended_at"'));
    expect(last.read<String>('payload'), isNot(contains('"ended_at":null')));
    expect(last.read<String>('payload'), contains('"ends_on"'));
  });
}
