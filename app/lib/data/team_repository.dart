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
