import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database.dart';

/// 一条同步操作：某台设备对某一行的一次写入（整行快照）。
class SyncOp {
  const SyncOp({
    required this.originDevice,
    required this.seq,
    required this.hlc,
    required this.table,
    required this.rowId,
    required this.row,
  });

  factory SyncOp.fromJson(Map<String, dynamic> json) => SyncOp(
    originDevice: json['o'] as String,
    seq: json['s'] as int,
    hlc: json['h'] as String,
    table: json['t'] as String,
    rowId: json['r'] as String,
    row: (json['p'] as Map).cast<String, Object?>(),
  );

  factory SyncOp.fromData(OpLogData d) => SyncOp(
    originDevice: d.originDevice,
    seq: d.seq,
    hlc: d.hlc,
    table: d.tableName_,
    rowId: d.rowId,
    row: (jsonDecode(d.payload) as Map).cast<String, Object?>(),
  );

  final String originDevice;
  final int seq;
  final String hlc;
  final String table;
  final String rowId;
  final Map<String, Object?> row;

  Map<String, Object?> toJson() => {
    'o': originDevice,
    's': seq,
    'h': hlc,
    't': table,
    'r': rowId,
    'p': row,
  };
}

/// 版本向量：每个来源设备 → 已拥有的最大序号。
typedef VersionVector = Map<String, int>;

const _applyingRemoteKey = 'applyingRemote';

/// 参与同步的表。本机设置（local_settings）和操作日志本身不同步。
List<TableInfo> syncedTables(AppDatabase db) => [
  db.teams,
  db.devices,
  db.creators,
  db.products,
  db.variants,
  db.bundleItems,
  db.events,
  db.stockMovements,
  db.paymentMethods,
  db.orders,
  db.orderItems,
  db.orderPayments,
  db.refunds,
];

/// 为每张同步表建触发器：本机的每次插入/更新都自动记一条操作日志。
///
/// 用触发器而不是在每个仓库方法里手写，保证不会漏记。应用远端操作时
/// 设置 applyingRemote 标记，触发器跳过，远端操作按原来源和序号单独写入日志。
Future<void> installOpLogTriggers(AppDatabase db) async {
  const localDevice =
      "(SELECT value FROM local_settings WHERE key = 'deviceId')";
  for (final table in syncedTables(db)) {
    final name = table.actualTableName;
    final payload = [
      for (final c in table.$columns) "'${c.name}', NEW.\"${c.name}\"",
    ].join(', ');
    for (final event in ['INSERT', 'UPDATE']) {
      await db.customStatement('''
CREATE TRIGGER IF NOT EXISTS oplog_${name}_${event.toLowerCase()}
AFTER $event ON "$name"
WHEN NOT EXISTS (
  SELECT 1 FROM local_settings WHERE key = '$_applyingRemoteKey' AND value = '1'
) AND $localDevice IS NOT NULL
BEGIN
  INSERT INTO op_log (origin_device, seq, hlc, table_name, row_id, payload)
  VALUES (
    $localDevice,
    (SELECT COALESCE(MAX(seq), 0) + 1 FROM op_log WHERE origin_device = $localDevice),
    NEW.updated_at,
    '$name',
    NEW.id,
    json_object($payload)
  );
END''');
    }
  }
}

/// 表结构变化（加列）后重建触发器，让操作日志包含新列。
Future<void> reinstallOpLogTriggers(AppDatabase db) async {
  for (final table in syncedTables(db)) {
    for (final event in ['insert', 'update']) {
      await db.customStatement(
        'DROP TRIGGER IF EXISTS oplog_${table.actualTableName}_$event',
      );
    }
  }
  await installOpLogTriggers(db);
}

/// 读写操作日志、合并远端操作。
class OpStore {
  OpStore(this._db)
    : _tables = {for (final t in syncedTables(_db)) t.actualTableName: t};

  final AppDatabase _db;
  final Map<String, TableInfo> _tables;

  Set<TableInfo> get tables => _tables.values.toSet();

  /// 本机拥有的每个来源设备的最大序号。
  Future<VersionVector> versionVector() async {
    final rows = await _db
        .customSelect(
          'SELECT origin_device, MAX(seq) AS seq FROM op_log GROUP BY origin_device',
          readsFrom: {_db.opLog},
        )
        .get();
    return {
      for (final r in rows) r.read<String>('origin_device'): r.read<int>('seq'),
    };
  }

  /// 对方（版本向量为 [known]）还没有的操作，按来源和序号排序，最多 [limit] 条。
  Future<List<SyncOp>> opsMissingFrom(
    VersionVector known, {
    int limit = 500,
  }) async {
    final mine = await versionVector();
    final result = <SyncOp>[];
    for (final MapEntry(key: origin, value: maxSeq) in mine.entries) {
      final from = known[origin] ?? 0;
      if (maxSeq <= from) continue;
      final rows =
          await (_db.select(_db.opLog)
                ..where(
                  (t) =>
                      t.originDevice.equals(origin) &
                      t.seq.isBiggerThanValue(from),
                )
                ..orderBy([(t) => OrderingTerm(expression: t.seq)])
                ..limit(limit - result.length))
              .get();
      result.addAll(rows.map(SyncOp.fromData));
      if (result.length >= limit) break;
    }
    return result;
  }

  /// 合并远端操作：写入操作日志，并按 HLC “后写为准”更新数据行。
  ///
  /// 同一来源的操作必须按序号连续到达（发送方保证）；已有的操作会被跳过，
  /// 所以重复收到同一批也没关系。返回实际新增的操作。
  Future<List<SyncOp>> applyRemote(List<SyncOp> ops) async {
    if (ops.isEmpty) return const [];
    final applied = <SyncOp>[];
    final touched = <TableInfo>{};
    await _db.transaction(() async {
      final have = await versionVector();
      await _db.setSetting(_applyingRemoteKey, '1');
      try {
        for (final op in ops) {
          final expected = (have[op.originDevice] ?? 0) + 1;
          if (op.seq < expected) continue; // 已经有了
          if (op.seq > expected) break; // 中间缺了，等对方重发
          final table = _tables[op.table];
          if (table == null) continue;
          await _upsert(table, op.row);
          await _db
              .into(_db.opLog)
              .insert(
                OpLogCompanion.insert(
                  originDevice: op.originDevice,
                  seq: op.seq,
                  hlc: op.hlc,
                  tableName_: op.table,
                  rowId: op.rowId,
                  payload: jsonEncode(op.row),
                ),
              );
          have[op.originDevice] = op.seq;
          touched.add(table);
          applied.add(op);
        }
      } finally {
        await (_db.delete(
          _db.localSettings,
        )..where((t) => t.key.equals(_applyingRemoteKey))).go();
      }
    });
    // 触发器和原生 SQL 写入不会通知界面，这里手动通知被修改的表。
    if (touched.isNotEmpty) {
      _db.notifyUpdates({
        for (final t in touched)
          TableUpdate.onTable(t, kind: UpdateKind.update),
        TableUpdate.onTable(_db.opLog, kind: UpdateKind.insert),
      });
    }
    return applied;
  }

  Future<void> _upsert(TableInfo table, Map<String, Object?> row) async {
    final known = {for (final c in table.$columns) c.name};
    final columns = [
      for (final k in row.keys)
        if (known.contains(k)) k,
    ];
    if (!columns.contains('id') || !columns.contains('updated_at')) return;
    final name = table.actualTableName;
    final quoted = [for (final c in columns) '"$c"'];
    final updates = [
      for (final c in columns)
        if (c != 'id') '"$c" = excluded."$c"',
    ];
    await _db.customStatement(
      'INSERT INTO "$name" (${quoted.join(', ')}) '
      'VALUES (${List.filled(columns.length, '?').join(', ')}) '
      'ON CONFLICT(id) DO UPDATE SET ${updates.join(', ')} '
      'WHERE excluded.updated_at > "$name".updated_at',
      [for (final c in columns) row[c]],
    );
  }
}
