import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/sync/lan_sync_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'op_store_test.dart' show Node;
import 'peer_session_test.dart' show eventually;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('通过真实 WebSocket（本机回环）同步，两边同时连也只保留一条连接', () async {
    final a = await Node.founder();
    final b = await Node.joining(a);
    final sa = LanSyncService(a.db, a.session, useDiscovery: false);
    final sb = LanSyncService(b.db, b.session, useDiscovery: false);
    addTearDown(() async {
      await sa.dispose();
      await sb.dispose();
      await a.db.close();
      await b.db.close();
    });
    await sa.start();
    await sb.start();
    expect(sa.current.running, isTrue);

    await a.catalog.saveProduct(
      ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
    );
    // 两边同时互相连接。
    await Future.wait([
      sa.dialAddress('127.0.0.1', sb.port!),
      sb.dialAddress('127.0.0.1', sa.port!),
    ]);
    await eventually(() async => (await b.catalog.loadCatalog()).length == 1);
    await eventually(
      () async => sa.current.peers.length == 1 && sb.current.peers.length == 1,
    );
    expect(sa.current.peers, {b.session.deviceId});

    // 断开后再写入，重新连接时补齐。
    await sb.stop();
    await eventually(() async => sa.current.peers.isEmpty);
    await a.catalog.saveProduct(
      ProductDraft(name: '色纸', variants: [VariantDraft(price: 2000)]),
    );
    await sb.start();
    await sb.dialAddress('127.0.0.1', sa.port!);
    await eventually(() async => (await b.catalog.loadCatalog()).length == 2);
  });

  test('停止后不再接受也不再发起连接（换团队时旧连接不能残留）', () async {
    final a = await Node.founder();
    final b = await Node.joining(a);
    final sa = LanSyncService(a.db, a.session, useDiscovery: false);
    final sb = LanSyncService(b.db, b.session, useDiscovery: false);
    addTearDown(() async {
      await sa.dispose();
      await sb.dispose();
      await a.db.close();
      await b.db.close();
    });
    await sa.start();
    await sb.start();
    await sa.dialAddress('127.0.0.1', sb.port!);
    await eventually(() async => sb.current.peers.length == 1);

    await sa.stop();
    await eventually(() async => sb.current.peers.isEmpty);
    // 已停止的服务即使再拨号，连接也会被立即关掉。
    await sa.dialAddress('127.0.0.1', sb.port!);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(sa.current.peers, isEmpty);
    expect(sb.current.peers, isEmpty);
  });
}
