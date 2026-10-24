import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database.dart';
import '../data/session.dart';
import 'hlc.dart';
import 'op_store.dart';

const _prefix = 'ABACUS1:';

/// 邀请码：新设备扫码（或粘贴）后加入团队。包含团队密钥，只应当面出示。
class TeamInvite {
  const TeamInvite({
    required this.teamId,
    required this.teamName,
    required this.currency,
    required this.teamKey,
    required this.deviceCode,
  });

  final String teamId;
  final String teamName;
  final String currency;
  final List<int> teamKey;

  /// 分配给新设备的代号（订单号前缀）。
  final String deviceCode;

  String encode() =>
      _prefix +
      base64Url.encode(
        utf8.encode(
          jsonEncode({
            'v': 1,
            'team': teamId,
            'name': teamName,
            'cur': currency,
            'key': base64Encode(teamKey),
            'code': deviceCode,
          }),
        ),
      );

  /// 解析邀请码；格式不对返回 null。
  static TeamInvite? tryParse(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith(_prefix)) return null;
    try {
      final json = jsonDecode(
        utf8.decode(base64Url.decode(trimmed.substring(_prefix.length))),
      ) as Map<String, dynamic>;
      if (json['v'] != 1) return null;
      return TeamInvite(
        teamId: json['team'] as String,
        teamName: json['name'] as String,
        currency: json['cur'] as String,
        teamKey: base64Decode(json['key'] as String),
        deviceCode: json['code'] as String,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

/// 生成邀请码，为新设备预留下一个代号。
Future<TeamInvite> createInvite(AppDatabase db, Session session) async {
  final devices =
      await (db.select(db.devices)..where(
            (t) => t.teamId.equals(session.teamId) & t.deleted.equals(false),
          ))
          .get();
  final team = await (db.select(
    db.teams,
  )..where((t) => t.id.equals(session.teamId))).getSingleOrNull();
  return TeamInvite(
    teamId: session.teamId,
    teamName: team?.name ?? '',
    currency: session.currency,
    teamKey: session.teamKey,
    deviceCode: nextDeviceCode(devices.map((d) => d.shortCode)),
  );
}

/// 本机加入邀请码对应的团队：清空本机数据，以新的设备身份登记，
/// 其余数据等同步从其他设备拉取。调用后需要重新加载会话。
///
/// 每次加入都换一个新的设备 id：操作日志序号从 1 重新开始，
/// 用旧 id 会和其他设备已收到的旧操作冲突。
Future<void> joinTeam(
  AppDatabase db,
  TeamInvite invite, {
  String? deviceName,
}) => db.transaction(() async {
  final deviceId = await resetForTeam(
    db,
    teamKey: invite.teamKey,
    currency: invite.currency,
  );
  await registerThisDevice(
    db,
    deviceId: deviceId,
    teamId: invite.teamId,
    shortCode: invite.deviceCode,
    name: deviceName,
  );
});

/// 清空本机数据，换一个新的设备 id 准备加入团队，返回新 id。
/// 之后需调用 [registerThisDevice] 登记本机（邮箱恢复时在拉完数据后再登记）。
Future<String> resetForTeam(
  AppDatabase db, {
  required List<int> teamKey,
  required String currency,
}) => db.transaction(() async {
  for (final table in syncedTables(db)) {
    await db.customStatement('DELETE FROM "${table.actualTableName}"');
  }
  await db.customStatement('DELETE FROM op_log');
  await db.customStatement('DELETE FROM local_settings');
  final deviceId = newId();
  await db.setSetting(deviceIdKey, deviceId);
  await db.setSetting(teamKeyKey, base64Encode(teamKey));
  await db.setSetting(currencyKey, currency);
  return deviceId;
});

Future<void> registerThisDevice(
  AppDatabase db, {
  required String deviceId,
  required String teamId,
  required String shortCode,
  String? name,
}) => db
    .into(db.devices)
    .insert(
      DevicesCompanion.insert(
        id: deviceId,
        updatedAt: HlcClock(deviceId).tick(),
        teamId: teamId,
        name: name ?? defaultDeviceName(),
        shortCode: shortCode,
      ),
    );
