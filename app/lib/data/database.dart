import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../sync/op_store.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Teams,
    Devices,
    Creators,
    Categories,
    Products,
    Variants,
    BundleItems,
    Events,
    StockMovements,
    PaymentMethods,
    Orders,
    OrderItems,
    OrderPayments,
    Refunds,
    Expenses,
    OpLog,
    LocalSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'abacus'));

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
      await installOpLogTriggers(this);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(localSettings);
      // 先加列，再建触发器（触发器会引用所有列）。
      if (from < 4) await m.addColumn(events, events.endedAt);
      if (from < 5) {
        await m.addColumn(orderPayments, orderPayments.pending);
        await m.addColumn(orderPayments, orderPayments.confirmedAt);
      }
      if (from < 6) await m.createTable(expenses);
      if (from < 7) await m.addColumn(events, events.endsOn);
      if (from < 8) {
        await m.createTable(categories);
        await m.addColumn(products, products.categoryIds);
      }
      if (from < 9) await m.addColumn(orders, orders.paymentCode);
      if (from < 3) {
        await installOpLogTriggers(this);
        // 旧数据补记操作日志：空更新会触发触发器，把每一行记成本机的一条操作。
        if (await getSetting('deviceId') != null) {
          for (final table in syncedTables(this)) {
            await customStatement(
              'UPDATE "${table.actualTableName}" SET id = id',
            );
          }
        }
      }
      if (from >= 3) await reinstallOpLogTriggers(this);
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX idx_stock_variant_location '
      'ON stock_movements (variant_id, location)',
    );
    await customStatement(
      'CREATE INDEX idx_orders_event ON orders (event_id, created_at)',
    );
  }

  Selectable<MapEntry<String, int>> _stockQuery(String location) {
    final sum = stockMovements.delta.sum();
    final query = selectOnly(stockMovements)
      ..addColumns([stockMovements.variantId, sum])
      ..where(
        stockMovements.location.equals(location) &
            stockMovements.deleted.equals(false),
      )
      ..groupBy([stockMovements.variantId]);
    return query.map(
      (r) => MapEntry(r.read(stockMovements.variantId)!, r.read(sum) ?? 0),
    );
  }

  /// 某个位置（家里或某场次）下各 SKU 的当前库存。
  /// 只包含在该位置有过流水的 SKU，可据此判断“这件货有没有带到本场”。
  Future<Map<String, int>> stockAt(String location) async =>
      Map.fromEntries(await _stockQuery(location).get());

  Stream<Map<String, int>> watchStockAt(String location) =>
      _stockQuery(location).watch().map(Map.fromEntries);

  /// 先加载一次，之后 [tables] 中任一张表有写入就重新加载。
  ///
  /// 用于需要多张表拼起来的列表（商品+规格+套装、订单+明细+支付）。
  Stream<T> watchTables<T>(
    Set<TableInfo> tables,
    Future<T> Function() load,
  ) async* {
    yield await load();
    await for (final _ in tableUpdates(TableUpdateQuery.onAllTables(tables))) {
      yield await load();
    }
  }

  Future<String?> getSetting(String key) async {
    final row = await (select(
      localSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchSetting(String key) => (select(
    localSettings,
  )..where((t) => t.key.equals(key))).watchSingleOrNull().map((r) => r?.value);

  Future<void> setSetting(String key, String value) =>
      into(localSettings)
          .insertOnConflictUpdate(LocalSetting(key: key, value: value));
}
