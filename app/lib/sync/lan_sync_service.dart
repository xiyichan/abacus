import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

import '../data/database.dart';
import '../data/session.dart';
import 'media_store.dart';
import 'peer_session.dart';

/// 同步状态，用于界面显示“已连接 N 台设备”。
@immutable
class SyncStatus {
  const SyncStatus({this.running = false, this.peers = const {}, this.error});

  final bool running;

  /// 当前已连接的设备 id。
  final Set<String> peers;
  final String? error;
}

abstract interface class SyncService {
  Stream<SyncStatus> get status;
  SyncStatus get current;
  Future<void> start();
  Future<void> stop();

  /// App 回到前台时调用：iOS 在后台会断开网络，需要重新发现和连接。
  Future<void> restart();
}

/// 不做任何同步（测试用）。
class DisabledSyncService implements SyncService {
  @override
  Stream<SyncStatus> get status => const Stream.empty();
  @override
  SyncStatus get current => const SyncStatus();
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> restart() async {}
}

const _serviceType = '_abacussync._tcp';

/// 局域网同步：本机开一个 WebSocket 服务并用 mDNS/Bonjour 广播，
/// 同时发现同一团队的其他设备并连接过去。任何一台设备都可以随时加入或离开。
class LanSyncService implements SyncService {
  LanSyncService(
    this._db,
    this._session, {
    this.media,
    this.useDiscovery = true,
  });

  final AppDatabase _db;
  final Session _session;

  /// 给了时，连上的设备之间也互传图片。
  final MediaStore? media;

  /// 关闭时不广播也不发现，只能用 [dialAddress] 手动连接（测试用）。
  final bool useDiscovery;

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = const SyncStatus();

  HttpServer? _server;
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySub;
  Timer? _retryTimer;

  /// 发现到的同团队设备：设备 id → (地址列表, 端口)。
  final _known = <String, (List<String>, int)>{};
  final _sessions = <PeerSession>{};
  final _dialing = <String>{};

  /// stop() 之后仍在进行中的连接（拨号、握手）完成时据此直接关闭。
  bool _active = false;

  String get _teamTag => _session.teamId.substring(0, 8);

  @override
  Stream<SyncStatus> get status => _statusController.stream;
  @override
  SyncStatus get current => _status;

  @override
  Future<void> start() async {
    if (_server != null) return;
    _active = true;
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _server = server;
      server.listen(_onRequest);
      if (useDiscovery) await _startBonsoir(server.port);
      _retryTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _dialKnown(),
      );
      _publish(running: true);
    } on Object catch (e) {
      debugPrint('LAN sync failed to start: $e');
      _publish(running: _server != null, error: '$e');
    }
  }

  Future<void> _startBonsoir(int port) async {
    final suffix = _session.deviceId.substring(_session.deviceId.length - 6);
    final broadcast = BonsoirBroadcast(
      service: BonsoirService(
        name: 'abacus-${_session.deviceShortCode}-$suffix',
        type: _serviceType,
        port: port,
        attributes: {'team': _teamTag, 'dev': _session.deviceId},
      ),
    );
    await broadcast.initialize();
    await broadcast.start();
    _broadcast = broadcast;

    final discovery = BonsoirDiscovery(type: _serviceType);
    await discovery.initialize();
    _discoverySub = discovery.eventStream?.listen((event) {
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent(:final service):
          if (service.attributes['dev'] != _session.deviceId) {
            // 附近设备解析失败（比如已经离开）很常见，忽略即可，下次发现会再试。
            unawaited(
              Future.sync(
                () => discovery.serviceResolver.resolveService(service),
              ).catchError((Object _) {}),
            );
          }
        case BonsoirDiscoveryServiceResolvedEvent(:final service) ||
            BonsoirDiscoveryServiceUpdatedEvent(:final service):
          final dev = service.attributes['dev'];
          if (service.attributes['team'] != _teamTag ||
              dev == null ||
              dev == _session.deviceId) {
            return;
          }
          final addresses = service.hostAddresses.isNotEmpty
              ? service.hostAddresses
              : [?service.hostname];
          if (addresses.isEmpty) return;
          _known[dev] = (_preferIpv4(addresses), service.port);
          unawaited(_dial(dev));
        case BonsoirDiscoveryServiceLostEvent(:final service):
          _known.remove(service.attributes['dev']);
        default:
          break;
      }
    }, onError: (Object _) {});
    await discovery.start();
    _discovery = discovery;
  }

  static List<String> _preferIpv4(List<String> addresses) => [
    ...addresses.where(
      (a) => InternetAddress.tryParse(a)?.type == InternetAddressType.IPv4,
    ),
    ...addresses.where(
      (a) => InternetAddress.tryParse(a)?.type != InternetAddressType.IPv4,
    ),
  ];

  Future<void> _onRequest(HttpRequest request) async {
    if (request.uri.path != '/sync' ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    await _attach(socket, dialedByUs: false);
  }

  /// 本机同步服务监听的端口。
  int? get port => _server?.port;

  /// 直接连接某个地址（跳过自动发现）。
  @visibleForTesting
  Future<void> dialAddress(String host, int port) async {
    final socket = await WebSocket.connect('ws://$host:$port/sync');
    await _attach(socket, dialedByUs: true);
  }

  void _dialKnown() {
    for (final dev in _known.keys.toList()) {
      unawaited(_dial(dev));
    }
  }

  bool _isConnected(String dev) =>
      _sessions.any((s) => !s.isClosed && s.peerDeviceId == dev);

  Future<void> _dial(String dev) async {
    final target = _known[dev];
    if (!_active || target == null || _isConnected(dev) || !_dialing.add(dev)) {
      return;
    }
    try {
      final (addresses, port) = target;
      for (final address in addresses) {
        try {
          final uri = Uri(
            scheme: 'ws',
            host: address,
            port: port,
            path: '/sync',
          );
          final socket = await WebSocket.connect(uri.toString())
              .timeout(const Duration(seconds: 5));
          await _attach(socket, dialedByUs: true);
          return;
        } on Object catch (e) {
          debugPrint('LAN sync: dial $address:$port failed: $e');
        }
      }
    } finally {
      _dialing.remove(dev);
    }
  }

  Future<void> _attach(WebSocket socket, {required bool dialedByUs}) async {
    if (!_active) {
      await socket.close();
      return;
    }
    socket.pingInterval = const Duration(seconds: 5);
    final peer = PeerSession(
      channel: _WebSocketChannel(socket),
      db: _db,
      session: _session,
      dialedByUs: dialedByUs,
      media: media,
      onClosed: (s) {
        _sessions.remove(s);
        _publish();
      },
    );
    _sessions.add(peer);
    await peer.start();
    try {
      await peer.ready.timeout(const Duration(seconds: 10));
    } on Object {
      await peer.close();
      return;
    }
    if (!_active) {
      await peer.close(); // 握手期间服务已停止
      return;
    }
    _dropDuplicates(peer.peerDeviceId!);
    _publish();
  }

  /// 两台设备可能同时互相连接，各留下一条：保留“由 id 较小的一方发起”的那条。
  /// 两边按同一规则判断，所以会关掉同一条。
  void _dropDuplicates(String dev) {
    final links = _sessions
        .where((s) => !s.isClosed && s.peerDeviceId == dev)
        .toList();
    if (links.length < 2) return;
    final lowerDials = _session.deviceId.compareTo(dev) < 0;
    for (final s in links) {
      if (s.dialedByUs != lowerDials) unawaited(s.close());
    }
  }

  void _publish({bool? running, String? error}) {
    _status = SyncStatus(
      running: running ?? _status.running,
      peers: {
        for (final s in _sessions)
          if (!s.isClosed && s.peerDeviceId != null) s.peerDeviceId!,
      },
      error: error ?? _status.error,
    );
    if (!_statusController.isClosed) _statusController.add(_status);
  }

  @override
  Future<void> stop() async {
    _active = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _known.clear();
    // 先断开连接、关掉服务器，再停广播和发现：iOS 上停 Bonsoir 偶尔会卡住，
    // 不能让它挡住后面的关闭（否则旧团队的连接会一直留着）。
    final sessions = _sessions.toList();
    _sessions.clear();
    await Future.wait([
      for (final s in sessions)
        s.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    ]);
    await _server?.close(force: true);
    _server = null;
    await _discoverySub?.cancel();
    _discoverySub = null;
    final discovery = _discovery;
    final broadcast = _broadcast;
    _discovery = null;
    _broadcast = null;
    for (final action in [?discovery?.stop, ?broadcast?.stop]) {
      try {
        await action().timeout(const Duration(seconds: 2));
      } on Object {
        // 插件在停止时偶尔报错或超时，不影响关闭。
      }
    }
    _publish(running: false);
  }

  @override
  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }
}

class _WebSocketChannel implements FrameChannel {
  _WebSocketChannel(this._socket);

  final WebSocket _socket;

  @override
  Stream<Uint8List> get incoming => _socket
      .where((data) => data is List<int>)
      .map(
        (data) =>
            data is Uint8List ? data : Uint8List.fromList(data as List<int>),
      );

  @override
  void send(Uint8List frame) {
    if (_socket.readyState == WebSocket.open) _socket.add(frame);
  }

  @override
  Future<void> close() => _socket.close();
}
