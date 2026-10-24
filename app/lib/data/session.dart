import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../sync/hlc.dart';
import 'database.dart';

/// 本机身份：属于哪个团队、自己是哪台设备。所有写操作都带上它。
class Session {
  Session({
    required this.teamId,
    required this.deviceId,
    required this.deviceShortCode,
    required this.currency,
    required this.teamKey,
  }) : clock = HlcClock(deviceId);

  final String teamId;
  final String deviceId;

  /// 设备号：6 位字母数字，如 K7XQ2M（早期版本是 A、B 这样的单个字母）。
  final String deviceShortCode;

  /// 订单号前缀：设备号前两位，如 K7-001 里的 K7。
  String get orderPrefix => orderPrefixOf(deviceShortCode);
  final String currency;

  /// 团队密钥（32 字节）。同一团队的设备用它加密局域网通信，只通过邀请二维码传递。
  final List<int> teamKey;
  final HlcClock clock;
}

String newId() => const Uuid().v7();

/// 设备号字符：去掉 0/O、1/I/L 这类容易看错的。
const _codeAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
const deviceCodeLength = 6;

/// 订单号前缀取设备号前两位；早期的单字母设备号原样使用。
String orderPrefixOf(String deviceCode) =>
    deviceCode.length > 2 ? deviceCode.substring(0, 2) : deviceCode;

/// 随机生成新设备号，保证订单号前缀不和团队里已有的设备重复。
String nextDeviceCode(Iterable<String> used, {Random? random}) {
  final taken = used.map(orderPrefixOf).toSet();
  final r = random ?? Random.secure();
  while (true) {
    final code = String.fromCharCodes([
      for (var i = 0; i < deviceCodeLength; i++)
        _codeAlphabet.codeUnitAt(r.nextInt(_codeAlphabet.length)),
    ]);
    if (!taken.contains(orderPrefixOf(code))) return code;
  }
}

const deviceIdKey = 'deviceId';
const teamKeyKey = 'teamKey';
const currencyKey = 'currency';

/// 新设备的默认名字：系统里的设备名（如“小明的 iPhone”）。
String defaultDeviceName() {
  try {
    return Platform.localHostname;
  } on Object {
    return '设备';
  }
}

List<int> generateTeamKey() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(256));
}

/// 读取本机身份；第一次打开时创建团队、本机设备和默认支付方式。
Future<Session> ensureSession(AppDatabase db) async {
  final existing = await db.getSetting(deviceIdKey);
  if (existing == null) return _createTeam(db);

  final device = await (db.select(
    db.devices,
  )..where((t) => t.id.equals(existing))).getSingle();
  // 早期版本的设备号是 A、B 这样的单个字母：换成随机设备号（之前的单号不变）。
  String? upgradedCode;
  if (device.shortCode.length < deviceCodeLength) {
    final others =
        await (db.select(db.devices)..where(
              (t) =>
                  t.teamId.equals(device.teamId) &
                  t.id.equals(device.id).not() &
                  t.deleted.equals(false),
            ))
            .get();
    upgradedCode = nextDeviceCode(others.map((d) => d.shortCode));
  }
  // 刚加入团队时，团队信息可能还没同步过来，先用邀请里带的币种。
  final team = await (db.select(
    db.teams,
  )..where((t) => t.id.equals(device.teamId))).getSingleOrNull();
  var key = await db.getSetting(teamKeyKey);
  if (key == null) {
    key = base64Encode(generateTeamKey());
    await db.setSetting(teamKeyKey, key);
  }
  final session = Session(
    teamId: device.teamId,
    deviceId: device.id,
    deviceShortCode: upgradedCode ?? device.shortCode,
    currency: team?.currency ?? await db.getSetting(currencyKey) ?? 'CNY',
    teamKey: base64Decode(key),
  );
  // 时钟不能落后于本机已经见过的时间戳（防止系统时间被往回调）。
  final latest = await db
      .customSelect('SELECT MAX(hlc) AS h FROM op_log', readsFrom: {db.opLog})
      .getSingle();
  final h = latest.readNullable<String>('h');
  if (h != null) session.clock.receive(h);
  if (upgradedCode != null) {
    await (db.update(db.devices)..where((t) => t.id.equals(device.id))).write(
      DevicesCompanion(
        shortCode: Value(upgradedCode),
        updatedAt: Value(session.clock.tick()),
      ),
    );
  }
  return session;
}

Future<Session> _createTeam(AppDatabase db) async {
  final teamId = newId();
  final deviceId = newId();
  final teamKey = generateTeamKey();
  final deviceCode = nextDeviceCode(const []);
  final session = Session(
    teamId: teamId,
    deviceId: deviceId,
    deviceShortCode: deviceCode,
    currency: 'CNY',
    teamKey: teamKey,
  );
  await db.transaction(() async {
    // 先记下本机 id：操作日志触发器要用它作为来源设备。
    await db.setSetting(deviceIdKey, deviceId);
    await db.setSetting(teamKeyKey, base64Encode(teamKey));
    final ts = session.clock.tick();
    await db
        .into(db.teams)
        .insert(TeamsCompanion.insert(id: teamId, updatedAt: ts, name: '我的摊位'));
    await db
        .into(db.devices)
        .insert(
          DevicesCompanion.insert(
            id: deviceId,
            updatedAt: ts,
            teamId: teamId,
            name: defaultDeviceName(),
            shortCode: deviceCode,
            role: const Value('admin'),
          ),
        );
    final defaults = [('现金', 'cash'), ('微信', 'qr'), ('支付宝', 'qr')];
    for (var i = 0; i < defaults.length; i++) {
      await db
          .into(db.paymentMethods)
          .insert(
            PaymentMethodsCompanion.insert(
              id: newId(),
              updatedAt: session.clock.tick(),
              teamId: teamId,
              name: defaults[i].$1,
              kind: defaults[i].$2,
              sortOrder: Value(i),
            ),
          );
    }
  });
  return session;
}
