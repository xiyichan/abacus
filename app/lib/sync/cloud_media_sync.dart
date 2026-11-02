import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';

import '../data/database.dart';
import 'cloud_api.dart';
import 'cloud_crypto.dart';
import 'media_store.dart';

const _uploadedKey = 'cloudMediaUploaded';

/// 连着云端时同步图片：本机有、云端还没有的加密后传上去；本机缺的从云端取下来解密。
///
/// 数据库里的图片引用一有变化（本机新建商品、收到别的设备的记录、局域网收到图片）
/// 就再跑一轮；云端通知有设备传上新图片时（[refresh]）也是。
/// 别的设备的图片可能比它的记录晚到云端，取不到又没等到通知时隔一会儿再试。
class CloudMediaSync {
  CloudMediaSync({
    required this.db,
    required this.media,
    required this.api,
    required this.keys,
    required this.teamId,
    required this.token,
  });

  final AppDatabase db;
  final MediaStore media;
  final CloudApi api;
  final CloudKeys keys;
  final String teamId;
  final String token;

  static const _retryDelays = [5, 15, 60, 300];

  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _retry;
  int _retries = 0;
  bool _running = false;
  bool _dirty = false;
  bool _stopped = false;

  void start() {
    _subscriptions
      ..add(
        db
            .tableUpdates(TableUpdateQuery.onAllTables(mediaTables(db)))
            .listen((_) => _schedule()),
      )
      ..add(media.received.listen((_) => _schedule()));
    _schedule();
  }

  /// 云端通知有新图片：马上再跑一轮，不等重试。
  void refresh() {
    _retries = 0;
    _schedule();
  }

  void _schedule() {
    if (_stopped) return;
    _dirty = true;
    if (!_running) unawaited(_loop());
  }

  Future<void> _loop() async {
    _running = true;
    var pending = false;
    try {
      while (_dirty && !_stopped) {
        _dirty = false;
        try {
          pending = await _round();
        } on CloudApiException catch (e) {
          debugPrint('cloud media: $e');
          pending = true;
        }
      }
    } finally {
      _running = false;
    }
    if (_stopped) return;
    _retry?.cancel();
    if (pending) {
      final seconds = _retryDelays[_retries.clamp(0, _retryDelays.length - 1)];
      _retries++;
      _retry = Timer(Duration(seconds: seconds), _schedule);
    } else {
      _retries = 0;
    }
  }

  /// 跑一轮，返回是否还有云端暂时没有的图片（稍后再试）。
  /// 断网或登录失效时抛出，交给外层重试；单张图片被拒绝就跳过它。
  Future<bool> _round() async {
    final uploaded = await _loadUploaded();
    var pending = false;
    for (final name in await referencedMedia(db)) {
      if (_stopped) break;
      try {
        if (await media.has(name)) {
          if (uploaded.contains(name)) continue;
          final bytes = await media.read(name);
          if (bytes == null) continue;
          await api.putMedia(
            token,
            teamId: teamId,
            teamToken: keys.teamToken,
            name: name,
            sealed: await keys.sealMedia(name, bytes),
          );
        } else {
          final sealed = await api.getMedia(
            token,
            teamId: teamId,
            teamToken: keys.teamToken,
            name: name,
          );
          if (sealed == null) {
            pending = true;
            continue;
          }
          final bytes = await keys.openMedia(name, sealed);
          if (bytes == null) continue; // 解不开：不是本团队的数据，不再重试
          await media.write(name, bytes);
        }
      } on CloudApiException catch (e) {
        if (e.code == 'network' || e.isAuthError) rethrow;
        debugPrint('cloud media: skip $name: $e');
        continue;
      }
      uploaded.add(name);
      await db.setSetting(_uploadedKey, jsonEncode(uploaded.toList()));
    }
    return pending;
  }

  /// 已经确认云端有的图片（本机传上去的，或从云端取下来的）。
  Future<Set<String>> _loadUploaded() async {
    final raw = await db.getSetting(_uploadedKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } on Object {
      return {};
    }
  }

  Future<void> stop() async {
    _stopped = true;
    _retry?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
  }
}
