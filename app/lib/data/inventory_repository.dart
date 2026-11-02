import 'package:drift/drift.dart';

import 'database.dart';
import 'session.dart';

const _currentEventKey = 'currentEventId';

/// 场次与每场库存。
class InventoryRepository {
  InventoryRepository(this._db, this._session);

  final AppDatabase _db;
  final Session _session;

  Stream<List<Event>> watchEvents() =>
      (_db.select(_db.events)
            ..where(
              (t) => t.teamId.equals(_session.teamId) & t.deleted.equals(false),
            )
            ..orderBy([
              // 进行中的排前面，已结束的排后面。
              (t) => OrderingTerm(expression: t.endedAt.isNotNull()),
              (t) => OrderingTerm(
                expression: t.startsOn,
                mode: OrderingMode.desc,
                nulls: NullsOrder.last,
              ),
              (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
            ]))
          .watch();

  /// [endsOn] 是最后一天（含），不晚于 [startsOn] 时按单日场次处理。
  Future<String> createEvent({
    required String name,
    DateTime? startsOn,
    DateTime? endsOn,
    String? booth,
  }) async {
    final id = newId();
    await _db
        .into(_db.events)
        .insert(
          EventsCompanion.insert(
            id: id,
            updatedAt: _session.clock.tick(),
            teamId: _session.teamId,
            name: name.trim(),
            startsOn: Value(startsOn),
            endsOn: Value(_lastDay(startsOn, endsOn)),
            booth: Value(booth?.trim().isEmpty ?? true ? null : booth!.trim()),
          ),
        );
    return id;
  }

  Future<void> updateEvent(
    String id, {
    required String name,
    DateTime? startsOn,
    DateTime? endsOn,
    String? booth,
  }) => (_db.update(_db.events)..where((t) => t.id.equals(id))).write(
    EventsCompanion(
      updatedAt: Value(_session.clock.tick()),
      name: Value(name.trim()),
      startsOn: Value(startsOn),
      endsOn: Value(_lastDay(startsOn, endsOn)),
      booth: Value(booth?.trim().isEmpty ?? true ? null : booth!.trim()),
    ),
  );

  /// 单日场次不存结束日期。
  static DateTime? _lastDay(DateTime? startsOn, DateTime? endsOn) =>
      startsOn != null && endsOn != null && endsOn.isAfter(startsOn)
      ? endsOn
      : null;

  /// 本机当前在哪个场次收银（只存本机，不同设备可以各自选择）。
  Stream<String?> watchCurrentEventId() => _db.watchSetting(_currentEventKey);

  Future<void> setCurrentEvent(String eventId) =>
      _db.setSetting(_currentEventKey, eventId);

  Stream<Map<String, int>> watchStock(String location) =>
      _db.watchStockAt(location);

  /// 结束场次（收摊）：标记为已结束，收银台不再显示。剩余数量原样留在这个场次的记录里。
  Future<void> endEvent(String eventId) => _db.transaction(() async {
    await (_db.update(_db.events)..where((t) => t.id.equals(eventId))).write(
      EventsCompanion(
        endedAt: Value(DateTime.now()),
        updatedAt: Value(_session.clock.tick()),
      ),
    );
    if (await _db.getSetting(_currentEventKey) == eventId) {
      await (_db.delete(
        _db.localSettings,
      )..where((t) => t.key.equals(_currentEventKey))).go();
    }
  });

  /// 重新开启已结束的场次。
  ///
  /// 旧版本结束时会把剩余退回家里（reason = close），这里一并撤销，货回到场次里。
  Future<void> reopenEvent(String eventId) => _db.transaction(() async {
    final ts = _session.clock.tick();
    await (_db.update(_db.stockMovements)..where(
          (t) =>
              t.reason.equals('close') &
              t.orderId.equals('close:$eventId') &
              t.deleted.equals(false),
        ))
        .write(
          StockMovementsCompanion(
            deleted: const Value(true),
            updatedAt: Value(ts),
          ),
        );
    await (_db.update(_db.events)..where((t) => t.id.equals(eventId))).write(
      EventsCompanion(
        endedAt: const Value(null),
        updatedAt: Value(_session.clock.tick()),
      ),
    );
  });

  /// 把某 SKU 在场次里的数量调整为 [eventQuantity]（每场单独备货，不和其他位置联动）。
  Future<void> setEventQuantity({
    required String variantId,
    required String eventId,
    required int eventQuantity,
  }) => _db.transaction(() async {
    final current = (await _db.stockAt(eventId))[variantId];
    final delta = eventQuantity - (current ?? 0);
    // current == null 表示还没带到本场：即使数量为 0 也记一条，表示“本场有这件货”。
    if (delta == 0 && current != null) return;
    await _move(variantId, eventId, delta, 'restock');
  });

  /// 最近一个有剩余货的其他场次及其剩余（variantId → 件数，只含正数），备货时可以沿用。
  Future<(Event, Map<String, int>)?> previousLeftover(String eventId) async {
    final events =
        (await watchEvents().first).where((e) => e.id != eventId).toList()
          // 按日期从近到远，没设日期的放最后（同样没日期时按创建先后，UUIDv7 可排序）。
          ..sort((a, b) {
            final byDate = (b.startsOn ?? DateTime(0)).compareTo(
              a.startsOn ?? DateTime(0),
            );
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
    for (final e in events) {
      final left = {
        for (final MapEntry(:key, :value) in (await _db.stockAt(e.id)).entries)
          if (value > 0) key: value,
      };
      if (left.isNotEmpty) return (e, left);
    }
    return null;
  }

  Future<void> _move(
    String variantId,
    String location,
    int delta,
    String reason, {
    String? orderId,
  }) => _db
      .into(_db.stockMovements)
      .insert(
        StockMovementsCompanion.insert(
          id: newId(),
          updatedAt: _session.clock.tick(),
          variantId: variantId,
          location: location,
          delta: delta,
          reason: reason,
          orderId: Value(orderId),
          deviceId: _session.deviceId,
          createdAt: DateTime.now(),
        ),
      );
}
