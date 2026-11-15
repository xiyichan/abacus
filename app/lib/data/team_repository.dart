import 'package:drift/drift.dart';

import 'database.dart';
import 'session.dart';

/// 团队和设备信息。
class TeamRepository {
  TeamRepository(this._db, this._session);

  final AppDatabase _db;
  final Session _session;

  /// 刚加入团队、团队信息还没同步过来时为 null。
  Stream<Team?> watchTeam() => (_db.select(
    _db.teams,
  )..where((t) => t.id.equals(_session.teamId))).watchSingleOrNull();

  Stream<List<Device>> watchDevices() =>
      (_db.select(_db.devices)
            ..where(
              (t) => t.teamId.equals(_session.teamId) & t.deleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.shortCode)]))
          .watch();

  Future<void> renameTeam(String name) =>
      (_db.update(_db.teams)..where((t) => t.id.equals(_session.teamId))).write(
        TeamsCompanion(
          name: Value(name.trim()),
          updatedAt: Value(_session.clock.tick()),
        ),
      );

  /// 改本机的订单号前缀；传空字符串恢复默认（设备号前两位）。
  /// 前缀不合格式时抛 [FormatException]；和团队里其他设备撞了时抛 [OrderPrefixTakenException]。
  Future<void> setOrderPrefix(String prefix) async {
    final value = prefix.trim().toUpperCase();
    final devices =
        await (_db.select(_db.devices)..where(
              (t) => t.teamId.equals(_session.teamId) & t.deleted.equals(false),
            ))
            .get();
    final me = devices.where((d) => d.id == _session.deviceId).firstOrNull;
    // 和默认的一样就不另存，以后设备号变了也跟着变。
    final custom =
        value.isEmpty || value == orderPrefixOf(_session.deviceShortCode)
        ? null
        : value;
    if (custom != null && !orderPrefixPattern.hasMatch(custom)) {
      throw FormatException('invalid order prefix', custom);
    }
    final effective =
        custom ?? orderPrefixOf(me?.shortCode ?? _session.deviceShortCode);
    for (final d in devices) {
      if (d.id != _session.deviceId && effectiveOrderPrefix(d) == effective) {
        throw OrderPrefixTakenException(d.name);
      }
    }
    await (_db.update(
      _db.devices,
    )..where((t) => t.id.equals(_session.deviceId))).write(
      DevicesCompanion(
        orderPrefix: Value(custom),
        updatedAt: Value(_session.clock.tick()),
      ),
    );
  }

  Future<void> renameDevice(String name) =>
      (_db.update(
        _db.devices,
      )..where((t) => t.id.equals(_session.deviceId))).write(
        DevicesCompanion(
          name: Value(name.trim()),
          updatedAt: Value(_session.clock.tick()),
        ),
      );
}

/// 订单号前缀已经被团队里的另一台设备（[deviceName]）用了：两台设备同一个前缀会出现重复的单号。
class OrderPrefixTakenException implements Exception {
  const OrderPrefixTakenException(this.deviceName);

  final String deviceName;
}
