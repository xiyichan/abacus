import 'dart:async';
import 'dart:typed_data';

import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:abacus/sync/peer_session.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'op_store_test.dart' show Node;

/// 内存里的一对通道，模拟一条网络连接。
(FrameChannel, FrameChannel) memoryPipe() {
  final aToB = StreamController<Uint8List>();
  final bToA = StreamController<Uint8List>();
  return (_Pipe(bToA.stream, aToB), _Pipe(aToB.stream, bToA));
}

class _Pipe implements FrameChannel {
  _Pipe(this.incoming, this._out);

  @override
  final Stream<Uint8List> incoming;
  final StreamController<Uint8List> _out;

  @override
  void send(Uint8List frame) {
    if (!_out.isClosed) _out.add(frame);
  }

  @override
  Future<void> close() => _out.close();
}

Future<(PeerSession, PeerSession)> connect(Node a, Node b) async {
  final (ca, cb) = memoryPipe();
  final sa = PeerSession(
    channel: ca,
    db: a.db,
    session: a.session,
    dialedByUs: true,
  );
  final sb = PeerSession(
    channel: cb,
    db: b.db,
    session: b.session,
    dialedByUs: false,
  );
  await sa.start();
  await sb.start();
  await Future.wait([sa.ready, sb.ready]);
  return (sa, sb);
}

/// 等待条件成立（同步是异步进行的）。
Future<void> eventually(Future<bool> Function() check) async {
  for (var i = 0; i < 200; i++) {
    if (await check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('条件在 4 秒内没有成立');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('连上后自动补齐数据，之后一方写入实时推到另一方', () async {
    final a = await Node.founder();
    final b = await Node.joining(a);
    addTearDown(a.db.close);
    addTearDown(b.db.close);
    await a.catalog.saveProduct(
      ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
    );

    final (sa, sb) = await connect(a, b);
    await eventually(() async => (await b.catalog.loadCatalog()).length == 1);
    expect(sa.peerDeviceId, b.session.deviceId);

    // 连接期间 B 卖货，A 立刻看到。
    final v = (await b.catalog.loadCatalog()).single.variants.single;
    final eventId = await b.inventory.createEvent(name: 'CP30');
    await b.inventory.setEventQuantity(
      variantId: v.id,
      eventId: eventId,
      eventQuantity: 5,
    );
    final cash = (await b.sales.watchPaymentMethods().first).first;
    await b.sales.placeOrder(
      eventId: eventId,
      lines: [
        SaleLine(variantId: v.id, name: '徽章', unitPrice: 1500, quantity: 2),
      ],
      paymentMethod: cash,
    );
    await eventually(() async => (await a.db.stockAt(eventId))[v.id] == 3);

    await sa.close();
    await sb.close();
  });

  test('A—B—C 链式连接：A 的数据经 B 转发到 C', () async {
    final a = await Node.founder();
    final b = await Node.joining(a);
    final c = await Node.joining(a);
    addTearDown(() async {
      for (final n in [a, b, c]) {
        await n.db.close();
      }
    });
    final (ab1, ab2) = await connect(a, b);
    final (bc1, bc2) = await connect(b, c);
    await a.catalog.saveProduct(
      ProductDraft(name: '色纸', variants: [VariantDraft(price: 2000)]),
    );
    await eventually(() async => (await c.catalog.loadCatalog()).length == 1);
    // C 也认识 A 设备。
    await eventually(
      () async => (await c.db.select(c.db.devices).get()).length == 3,
    );
    for (final s in [ab1, ab2, bc1, bc2]) {
      await s.close();
    }
  });

  test('密钥不同（不是同一团队）的设备连不上', () async {
    final a = await Node.founder();
    final stranger = await Node.founder();
    addTearDown(a.db.close);
    addTearDown(stranger.db.close);
    final (ca, cb) = memoryPipe();
    final sa = PeerSession(
      channel: ca,
      db: a.db,
      session: a.session,
      dialedByUs: true,
    );
    final sb = PeerSession(
      channel: cb,
      db: stranger.db,
      session: stranger.session,
      dialedByUs: false,
    );
    unawaited(sa.ready.catchError((_) {}));
    unawaited(sb.ready.catchError((_) {}));
    await sa.start();
    await sb.start();
    await eventually(() async => sa.isClosed && sb.isClosed);
    expect(sa.peerDeviceId, isNull);
  });
}
