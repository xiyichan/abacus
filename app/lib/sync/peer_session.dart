import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;

import '../data/database.dart';
import '../data/session.dart';
import 'media_store.dart';
import 'op_store.dart';

/// 一条双向二进制通道（WebSocket，或测试里的内存管道）。
abstract interface class FrameChannel {
  Stream<Uint8List> get incoming;
  void send(Uint8List frame);
  Future<void> close();
}

/// 用团队密钥做 AES-GCM 加密。能解开对方的消息就说明是同一团队。
class TeamCipher {
  TeamCipher(List<int> key) : _key = SecretKey(key);

  final SecretKey _key;
  final _algorithm = AesGcm.with256bits();

  Future<Uint8List> seal(Map<String, Object?> message) async {
    final box = await _algorithm.encrypt(
      utf8.encode(jsonEncode(message)),
      secretKey: _key,
    );
    return box.concatenation();
  }

  /// 解密失败（不是同一团队或数据被篡改）返回 null。
  Future<Map<String, dynamic>?> open(Uint8List frame) async {
    try {
      final box = SecretBox.fromConcatenation(
        frame,
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      final clear = await _algorithm.decrypt(box, secretKey: _key);
      return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }
}

/// 与一台对端设备的同步会话。
///
/// 协议：
/// 1. 连上后双方各发 hello（团队 id、设备 id、版本向量）。
/// 2. 收到对方 hello 后，把对方缺的操作分批发过去。
/// 3. 之后本机数据库一有变化（本机写入或从别处收到的操作），就把对方缺的部分推过去，
///    所以三台以上设备即使没有两两直连也能经中间设备转发。
/// 4. 收到 ops 后合并到本机，并记下对方已经有这些操作，避免回传。
/// 5. 图片（给了 [media] 时）：各自发 media-want 告诉对方本机缺哪些文件，
///    有的一方用 media 消息发过去。对方要的文件本机暂时也没有时先记着，
///    等本机从别处收到再转给它。
class PeerSession {
  PeerSession({
    required this.channel,
    required this.db,
    required this.session,
    required this.dialedByUs,
    this.media,
    this.onClosed,
  }) : _store = OpStore(db),
       _cipher = TeamCipher(session.teamKey);

  final FrameChannel channel;
  final AppDatabase db;
  final Session session;
  final MediaStore? media;

  /// 是不是本机主动连过去的。两台设备互相连了两条时，用它决定保留哪一条。
  final bool dialedByUs;
  final void Function(PeerSession)? onClosed;

  final OpStore _store;
  final TeamCipher _cipher;
  final _ready = Completer<void>();

  String? peerDeviceId;
  VersionVector _peerVector = {};
  StreamSubscription<void>? _changes;
  StreamSubscription<Uint8List>? _incoming;
  StreamSubscription<String>? _mediaReceived;
  bool _pushing = false;
  bool _dirty = false;
  bool _closed = false;

  /// 上次告诉对方本机缺的图片；对方还要、本机还没发的图片。
  Set<String> _wanted = {};
  Set<String> _peerWants = {};
  Timer? _wantTimer;

  /// 收到的消息按顺序逐条处理，保证同一来源的操作按序号合并。
  Future<void> _processing = Future.value();

  /// 握手完成（收到对方 hello）。
  Future<void> get ready => _ready.future;
  bool get isClosed => _closed;

  Future<void> start() async {
    _incoming = channel.incoming.listen(
      (frame) => _processing = _processing.then((_) => _onFrame(frame)),
      onDone: close,
      onError: (_) => close(),
      cancelOnError: true,
    );
    await _send({
      'type': 'hello',
      'team': session.teamId,
      'device': session.deviceId,
      'vv': await _store.versionVector(),
    });
  }

  Future<void> _onFrame(Uint8List frame) async {
    final message = await _cipher.open(frame);
    if (message == null) {
      await close(); // 不是同一团队
      return;
    }
    switch (message['type']) {
      case 'hello':
        if (message['team'] != session.teamId) {
          await close();
          return;
        }
        peerDeviceId = message['device'] as String;
        _peerVector = (message['vv'] as Map).cast<String, int>();
        if (!_ready.isCompleted) _ready.complete();
        _changes = db
            .tableUpdates(TableUpdateQuery.onAllTables(_store.tables))
            .listen((_) {
              _schedulePush();
              _scheduleWants();
            });
        _mediaReceived = media?.received.listen((name) {
          _scheduleWants();
          if (_peerWants.contains(name)) unawaited(_sendMedia({name}));
        });
        _schedulePush();
        _scheduleWants();
      case 'media-want':
        _peerWants = {
          for (final n in message['names'] as List)
            if (n is String && MediaStore.isValidName(n)) n,
        };
        await _sendMedia(_peerWants);
      case 'media':
        final name = message['name'];
        final data = message['data'];
        // 只收本机确实缺的文件。
        if (media == null || name is! String || data is! String) return;
        if (!(await media!.missing(db)).contains(name)) return;
        await media!.write(name, base64Decode(data));
      case 'ops':
        final ops = [
          for (final o in message['ops'] as List)
            SyncOp.fromJson((o as Map).cast()),
        ];
        final applied = await _store.applyRemote(ops);
        for (final op in [...ops, ...applied]) {
          if ((_peerVector[op.originDevice] ?? 0) < op.seq) {
            _peerVector[op.originDevice] = op.seq;
          }
          session.clock.receive(op.hlc);
        }
    }
  }

  /// 合并多次变化，同一时间只有一个推送循环。
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
          final ops = await _store.opsMissingFrom(_peerVector);
          if (ops.isEmpty) break;
          await _send({
            'type': 'ops',
            'ops': [for (final o in ops) o.toJson()],
          });
          for (final op in ops) {
            _peerVector[op.originDevice] = op.seq;
          }
        }
      }
    } finally {
      _pushing = false;
    }
  }

  /// 本机缺的图片有变化时告诉对方（数据库变化很频繁，稍微攒一下）。
  void _scheduleWants() {
    if (media == null || _closed || (_wantTimer?.isActive ?? false)) return;
    _wantTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_closed) return;
      final missing = await media!.missing(db);
      if (missing.length == _wanted.length && missing.containsAll(_wanted)) {
        return;
      }
      _wanted = missing;
      await _send({'type': 'media-want', 'names': missing.toList()});
    });
  }

  /// 把 [names] 里本机有的图片发给对方。
  Future<void> _sendMedia(Set<String> names) async {
    final store = media;
    if (store == null) return;
    for (final name in names.toList()) {
      if (_closed) return;
      final bytes = await store.read(name);
      if (bytes == null) continue;
      await _send({'type': 'media', 'name': name, 'data': base64Encode(bytes)});
      _peerWants.remove(name);
    }
  }

  Future<void> _send(Map<String, Object?> message) async {
    if (_closed) return;
    channel.send(await _cipher.seal(message));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _wantTimer?.cancel();
    await _mediaReceived?.cancel();
    await _changes?.cancel();
    await _incoming?.cancel();
    await channel.close();
    if (!_ready.isCompleted) _ready.completeError(StateError('closed'));
    onClosed?.call(this);
  }
}
