import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';

import '../data/database.dart';
import '../data/session.dart';
import '../data/team_library.dart';
import 'cloud_api.dart';
import 'cloud_crypto.dart';
import 'cloud_media_sync.dart';
import 'media_store.dart';
import 'op_store.dart';
import 'team_invite.dart';

const _tokenKey = 'cloudToken';
const _emailKey = 'cloudEmail';
const _displayNameKey = 'cloudDisplayName';
const _linkedKey = 'cloudLinkedTeam';

/// 上次登记到云端时的团队名。改名后再登记一次，云端的团队列表才显示新名字。
const _linkedNameKey = 'cloudLinkedName';
const _lastSyncKey = 'cloudLastSync';

enum CloudState {
  /// 没有登录。
  signedOut,

  /// 正在连接云端。
  connecting,

  /// 已连接，实时同步中。
  connected,

  /// 暂时连不上（没网或服务器不可达），稍后自动重试。
  offline,
}

@immutable
class CloudStatus {
  const CloudStatus({
    this.state = CloudState.signedOut,
    this.email,
    this.displayName,
    this.lastSync,
  });

  final CloudState state;
  final String? email;

  /// 账号的用户名（只用来显示，登录仍用邮箱）。
  final String? displayName;

  /// 最近一次和云端交换数据的时间。
  final DateTime? lastSync;
}

/// 与云端的一条同步连接。协议同局域网：先交换版本向量，再互相补齐缺的记录，
/// 之后本机有变化就推上去，云端转发来的记录合并到本机。记录在本机加密后才上传。
class CloudPeer {
  CloudPeer({
    required this.socket,
    required this.db,
    required this.keys,
    this.onReceived,
    this.onActivity,
    this.onMediaReady,
  }) : _store = OpStore(db);

  final WebSocket socket;
  final AppDatabase db;
  final CloudKeys keys;

  /// 收到并合并了远端记录（用于推进本机时钟）。
  final void Function(List<SyncOp>)? onReceived;

  /// 有数据往来（用于更新“上次同步”时间）。
  final VoidCallback? onActivity;

  /// 同团队有设备传上了新图片。
  final VoidCallback? onMediaReady;

  final OpStore _store;
  final _ready = Completer<VersionVector>();
  final _done = Completer<void>();
  VersionVector _serverVector = {};
  StreamSubscription<void>? _changes;
  Future<void> _processing = Future.value();
  bool _pushing = false;
  bool _dirty = false;
  bool _closed = false;

  /// 握手完成，值为云端当时拥有的版本向量。
  Future<VersionVector> get ready => _ready.future;

  /// 连接结束。
  Future<void> get done => _done.future;

  Future<void> start() async {
    socket.listen(
      (data) => _processing = _processing.then((_) => _onMessage(data)),
      onDone: close,
      onError: (_) => close(),
      cancelOnError: true,
    );
    socket.add(
      jsonEncode({'type': 'hello', 'vv': await _store.versionVector()}),
    );
  }

  /// 本机是否已经拥有握手时云端的全部记录（恢复团队时用）。
  Future<bool> caughtUp() async {
    final server = await ready;
    final mine = await _store.versionVector();
    return server.entries.every((e) => (mine[e.key] ?? 0) >= e.value);
  }

  Future<void> _onMessage(Object? data) async {
    if (data is! String || _closed) return;
    final message = jsonDecode(data) as Map<String, dynamic>;
    switch (message['type']) {
      case 'hello':
        _serverVector = (message['vv'] as Map).cast<String, int>();
        if (!_ready.isCompleted) _ready.complete(Map.of(_serverVector));
        onActivity?.call();
        _changes = db
            .tableUpdates(TableUpdateQuery.onAllTables(_store.tables))
            .listen((_) => _schedulePush());
        _schedulePush();
      case 'ops':
        final ops = <SyncOp>[];
        for (final sealed in message['ops'] as List) {
          final op = await keys.open((sealed as Map).cast<String, dynamic>());
          if (op != null) ops.add(op);
        }
        final applied = await _store.applyRemote(ops);
        for (final op in ops) {
          if ((_serverVector[op.originDevice] ?? 0) < op.seq) {
            _serverVector[op.originDevice] = op.seq;
          }
        }
        if (applied.isNotEmpty) onReceived?.call(applied);
        onActivity?.call();
      case 'media-ready':
        onMediaReady?.call();
    }
  }

  void _schedulePush() {
    if (_closed) return;
    _dirty = true;
    if (!_pushing) unawaited(_pushLoop());
  }

  Future<void> _pushLoop() async {
    _pushing = true;
    try {
      while (_dirty && !_closed) {
        _dirty = false;
        while (!_closed) {
          final ops = await _store.opsMissingFrom(_serverVector, limit: 200);
          if (ops.isEmpty) break;
          final sealed = [for (final op in ops) await keys.seal(op)];
          socket.add(jsonEncode({'type': 'ops', 'ops': sealed}));
          for (final op in ops) {
            _serverVector[op.originDevice] = op.seq;
          }
          onActivity?.call();
        }
      }
    } finally {
      _pushing = false;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _changes?.cancel();
    await socket.close();
    if (!_ready.isCompleted) _ready.completeError(StateError('closed'));
    if (!_done.isCompleted) _done.complete();
  }
}

Future<WebSocket> _connect(
  CloudApi api,
  String teamId,
  String token,
  CloudKeys keys,
) => WebSocket.connect(
  api.syncUri(teamId).toString(),
  headers: {'Authorization': 'Bearer $token', 'X-Team-Token': keys.teamToken},
).timeout(const Duration(seconds: 15));

/// 某个团队数据库里存的登录（没有时为 null）。
Future<CloudAccount?> readCloudAccount(AppDatabase db) async {
  final token = await db.getSetting(_tokenKey);
  final email = await db.getSetting(_emailKey);
  if (token == null || email == null) return null;
  return CloudAccount(
    token: token,
    email: email,
    displayName: await db.getSetting(_displayNameKey),
  );
}

/// 把整个 App 共用的登录写进某个团队的数据库；没有登录时清掉这个库里留下的旧登录。
Future<void> applyCloudAccount(AppDatabase db, CloudAccount? account) async {
  if (account == null) {
    for (final key in [_tokenKey, _emailKey, _displayNameKey]) {
      await (db.delete(db.localSettings)..where((t) => t.key.equals(key))).go();
    }
    return;
  }
  await db.setSetting(_tokenKey, account.token);
  await db.setSetting(_emailKey, account.email);
  if (account.displayName == null) {
    await (db.delete(
      db.localSettings,
    )..where((t) => t.key.equals(_displayNameKey))).go();
  } else {
    await db.setSetting(_displayNameKey, account.displayName!);
  }
}

/// 云端同步：登录后把本团队登记到云端，并保持一条连接实时同步；断网时自动重试。
/// 给了 [media] 时，连着云端期间也同步图片。登录状态变化时通过 [onAccountChanged]
/// 告诉外面（多个团队共用一个登录）。
class CloudSyncService {
  CloudSyncService(
    this._db,
    this._session,
    this._api, {
    this._media,
    this._onAccountChanged,
  });

  final AppDatabase _db;
  final Session _session;
  final CloudApi _api;
  final MediaStore? _media;
  final void Function(CloudAccount?)? _onAccountChanged;

  final _statusController = StreamController<CloudStatus>.broadcast();
  CloudStatus _status = const CloudStatus();
  CloudPeer? _peer;
  bool _running = false;
  Timer? _retry;
  int _failures = 0;
  DateTime? _lastSavedSync;
  Completer<void>? _wake;

  /// 正在运行的重连循环（[stop] 要等它退出，免得再 [start] 时两个循环同时跑）。
  Future<void>? _loopTask;

  Stream<CloudStatus> get status => _statusController.stream;
  CloudStatus get current => _status;
  CloudApi get api => _api;

  /// 当前的登录（没登录时为 null），用来不重新验证邮箱就列出云端的团队。
  Future<CloudAccount?> account() => readCloudAccount(_db);

  Future<void> _publishAccount() async =>
      _onAccountChanged?.call(await account());

  Future<void> start() async {
    final email = await _db.getSetting(_emailKey);
    final last = int.tryParse(await _db.getSetting(_lastSyncKey) ?? '');
    _publish(
      CloudStatus(
        email: email,
        displayName: await _db.getSetting(_displayNameKey),
        lastSync: last == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(last),
      ),
    );
    final token = await _db.getSetting(_tokenKey);
    if (token == null) return;
    if (await _db.getSetting(_linkedKey) != _session.teamId) {
      try {
        await _link(token);
      } on CloudApiException catch (e) {
        if (e.isAuthError) await _signOutLocally();
        // 暂时连不上：下面的重连循环会再试登记。
      }
    }
    _running = true;
    unawaited(_loopTask = _loop());
  }

  /// 用邮箱验证码登录成功后调用：保存令牌，把本团队登记到云端，开始同步。
  Future<void> signIn({
    required String email,
    required String token,
    String? displayName,
  }) async {
    await _db.setSetting(_tokenKey, token);
    await _db.setSetting(_emailKey, email);
    await _saveDisplayName(displayName);
    await _link(token);
    _publish(
      CloudStatus(
        state: CloudState.connecting,
        email: email,
        displayName: displayName,
        lastSync: _status.lastSync,
      ),
    );
    if (!_running) {
      _running = true;
      unawaited(_loopTask = _loop());
    } else {
      _wakeUp();
    }
  }

  /// 修改账号的用户名（需要联网）。
  Future<void> setDisplayName(String name) async {
    final token = await _db.getSetting(_tokenKey);
    if (token == null) return;
    final saved = await _api.setDisplayName(token, name);
    await _saveDisplayName(saved);
    _publish(
      CloudStatus(
        state: _status.state,
        email: _status.email,
        displayName: saved,
        lastSync: _status.lastSync,
      ),
    );
  }

  /// 连上云端时顺便取一次用户名：别的设备上改过的名字也能同步过来。
  Future<void> _refreshDisplayName(String token) async {
    try {
      final name = await _api.fetchDisplayName(token);
      if (name == _status.displayName) return;
      await _saveDisplayName(name);
      _publish(
        CloudStatus(
          state: _status.state,
          email: _status.email,
          displayName: name,
          lastSync: _status.lastSync,
        ),
      );
    } on CloudApiException {
      // 取不到就沿用本机记的名字。
    }
  }

  Future<void> _saveDisplayName(String? name) async {
    if (name == null) {
      await (_db.delete(
        _db.localSettings,
      )..where((t) => t.key.equals(_displayNameKey))).go();
    } else {
      await _db.setSetting(_displayNameKey, name);
    }
    await _publishAccount();
  }

  Future<void> signOut() async {
    final token = await _db.getSetting(_tokenKey);
    _running = false;
    _wakeUp();
    await _peer?.close();
    if (token != null) {
      try {
        await _api.logout(token);
      } on CloudApiException {
        // 离线也允许退出，本机删掉令牌即可。
      }
    }
    await _signOutLocally();
  }

  Future<void> _signOutLocally() async {
    for (final key in [
      _tokenKey,
      _emailKey,
      _displayNameKey,
      _linkedKey,
      _linkedNameKey,
    ]) {
      await (_db.delete(
        _db.localSettings,
      )..where((t) => t.key.equals(key))).go();
    }
    _onAccountChanged?.call(null);
    _publish(const CloudStatus());
  }

  Future<void> _link(String token) async {
    final keys = await CloudKeys.derive(_session.teamKey);
    final team = await (_db.select(
      _db.teams,
    )..where((t) => t.id.equals(_session.teamId))).getSingleOrNull();
    await _api.linkTeam(
      token,
      teamId: _session.teamId,
      teamToken: keys.teamToken,
      teamKey: _session.teamKey,
      name: team?.name ?? '',
      currency: _session.currency,
    );
    await _db.setSetting(_linkedKey, _session.teamId);
    if (team != null) await _db.setSetting(_linkedNameKey, team.name);
  }

  /// 团队名和上次登记到云端的不一样（本机或别的设备改了名）时，重新登记一次。
  Future<void> _syncTeamName(String token) async {
    try {
      final team = await (_db.select(
        _db.teams,
      )..where((t) => t.id.equals(_session.teamId))).getSingleOrNull();
      if (team == null || team.name.trim().isEmpty) return;
      if (team.name == await _db.getSetting(_linkedNameKey)) return;
      await _link(token);
    } on Object catch (e) {
      debugPrint('cloud sync: team name: $e'); // 下次连上或再改名时再试
    }
  }

  Future<void> _loop() async {
    final keys = await CloudKeys.derive(_session.teamKey);
    while (_running) {
      final token = await _db.getSetting(_tokenKey);
      if (token == null) break;
      _publish(
        CloudStatus(
          state: CloudState.connecting,
          email: _status.email,
          displayName: _status.displayName,
          lastSync: _status.lastSync,
        ),
      );
      CloudMediaSync? mediaSync;
      StreamSubscription<void>? renames;
      Timer? renameTimer;
      try {
        if (await _db.getSetting(_linkedKey) != _session.teamId) {
          await _link(token);
        }
        final socket = await _connect(_api, _session.teamId, token, keys);
        socket.pingInterval = const Duration(seconds: 20);
        final peer = CloudPeer(
          socket: socket,
          db: _db,
          keys: keys,
          onReceived: (ops) {
            for (final op in ops) {
              _session.clock.receive(op.hlc);
            }
          },
          onActivity: _markSynced,
          onMediaReady: () => mediaSync?.refresh(),
        );
        _peer = peer;
        await peer.start();
        await peer.ready.timeout(const Duration(seconds: 15));
        _failures = 0;
        unawaited(_refreshDisplayName(token));
        unawaited(_syncTeamName(token));
        // 连着期间改了团队名（本机改，或从别的设备同步过来）：稍等一下再登记新名字。
        renames = _db.tableUpdates(TableUpdateQuery.onTable(_db.teams)).listen((
          _,
        ) {
          renameTimer?.cancel();
          renameTimer = Timer(
            const Duration(seconds: 1),
            () => unawaited(_syncTeamName(token)),
          );
        });
        final media = _media;
        if (media != null) {
          mediaSync = CloudMediaSync(
            db: _db,
            media: media,
            api: _api,
            keys: keys,
            teamId: _session.teamId,
            token: token,
          )..start();
        }
        _publish(
          CloudStatus(
            state: CloudState.connected,
            email: _status.email,
            displayName: _status.displayName,
            lastSync: _status.lastSync,
          ),
        );
        await peer.done;
      } on CloudApiException catch (e) {
        if (e.isAuthError) {
          await _signOutLocally();
          break;
        }
      } on Object catch (e) {
        debugPrint('cloud sync: $e');
        // 连不上时确认一下是不是登录失效了。
        try {
          await _api.listTeams(token);
        } on CloudApiException catch (e) {
          if (e.isAuthError) {
            await _signOutLocally();
            break;
          }
        }
      } finally {
        renameTimer?.cancel();
        await renames?.cancel();
        await mediaSync?.stop();
        await _peer?.close();
        _peer = null;
      }
      if (!_running) break;
      _publish(
        CloudStatus(
          state: CloudState.offline,
          email: _status.email,
          displayName: _status.displayName,
          lastSync: _status.lastSync,
        ),
      );
      _failures++;
      final seconds = [2, 5, 15, 30, 60][_failures.clamp(1, 5) - 1];
      await _sleep(Duration(seconds: seconds));
    }
  }

  /// 可以被 [_wakeUp] 提前唤醒的等待（比如 App 回到前台时立即重连）。
  Future<void> _sleep(Duration duration) {
    final wake = _wake = Completer<void>();
    _retry = Timer(duration, () {
      if (!wake.isCompleted) wake.complete();
    });
    return wake.future;
  }

  void _wakeUp() {
    _retry?.cancel();
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  /// App 回到前台：如果没连着就立刻重试。
  void resume() {
    if (_status.state != CloudState.connected) {
      _failures = 0;
      _wakeUp();
    }
  }

  void _markSynced() {
    final now = DateTime.now();
    _publish(
      CloudStatus(
        state: _status.state,
        email: _status.email,
        displayName: _status.displayName,
        lastSync: now,
      ),
    );
    final saved = _lastSavedSync;
    if (saved == null || now.difference(saved) > const Duration(seconds: 10)) {
      _lastSavedSync = now;
      unawaited(_db.setSetting(_lastSyncKey, '${now.millisecondsSinceEpoch}'));
    }
  }

  void _publish(CloudStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  /// 断开并停止重连（之后可以再 [start]），比如恢复别的团队期间。
  Future<void> stop() async {
    _running = false;
    _wakeUp();
    await _peer?.close();
    await _loopTask;
  }

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }
}

/// 在新设备上用邮箱登录后恢复团队：清空本机，从云端拉下全部记录，
/// 再以新设备身份登记（代号取团队里还没用过的）。完成后需要重新加载会话。
Future<void> restoreTeamFromCloud({
  required AppDatabase db,
  required CloudApi api,
  required String token,
  required String email,
  required CloudTeam team,
  String? displayName,
  String? deviceName,
}) async {
  final remote = await api.fetchTeamKey(token, team.id);
  final keys = await CloudKeys.derive(remote.teamKey);
  // 先确认连得上，再清空本机数据。
  final socket = await _connect(api, team.id, token, keys);
  final deviceId = await resetForTeam(
    db,
    teamKey: remote.teamKey,
    currency: remote.currency,
  );
  final peer = CloudPeer(socket: socket, db: db, keys: keys);
  try {
    await peer.start();
    await peer.ready.timeout(const Duration(seconds: 15));
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (!await peer.caughtUp()) {
      if (DateTime.now().isAfter(deadline)) throw TimeoutException('restore');
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  } finally {
    await peer.close();
  }
  final devices = await (db.select(
    db.devices,
  )..where((t) => t.teamId.equals(team.id))).get();
  await registerThisDevice(
    db,
    deviceId: deviceId,
    teamId: team.id,
    shortCode: nextDeviceCode(devices.map((d) => d.shortCode)),
    name: deviceName,
  );
  await db.setSetting(_tokenKey, token);
  await db.setSetting(_emailKey, email);
  if (displayName != null) await db.setSetting(_displayNameKey, displayName);
  await db.setSetting(_linkedKey, team.id);
  await db.setSetting(_lastSyncKey, '${DateTime.now().millisecondsSinceEpoch}');
}
