import 'package:drift/drift.dart';

import '../domain/checkout.dart';
import '../domain/creator_split.dart';
import '../domain/sales_stats.dart';
import '../domain/stock.dart';
import 'database.dart';
import 'session.dart';

/// 支付方式类型。
abstract final class PaymentKind {
  static const cash = 'cash';
  static const qr = 'qr';
  static const card = 'card';
  static const other = 'other';
}

/// 下单时的一行商品。
class SaleLine {
  const SaleLine({
    required this.variantId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.components = const [],
  });

  final String variantId;
  final String name;
  final int unitPrice;
  final int quantity;

  /// 套装成分；非空时售出扣成分库存。
  final List<BundleComponent> components;
}

/// 订单列表里的一行。
class OrderSummary {
  const OrderSummary({
    required this.order,
    required this.paymentNames,
    required this.itemCount,
    this.refund,
    this.paymentPending = false,
  });

  final Order order;
  final String paymentNames;
  final int itemCount;
  final Refund? refund;

  /// 扫码付款还没确认到账。
  final bool paymentPending;

  bool get isRefunded => refund != null;
}

/// 统计页“各场对比”的一行。已退款的订单不计入。
class EventComparisonRow {
  const EventComparisonRow({
    required this.event,
    required this.orderCount,
    required this.revenue,
    required this.itemCount,
    required this.pendingCount,
    this.expenses = 0,
  });

  factory EventComparisonRow.fromOrders(
    Event event,
    List<OrderDetail> orders, {
    int expenses = 0,
  }) {
    var count = 0, revenue = 0, items = 0, pending = 0;
    for (final d in orders) {
      if (d.refund != null) continue;
      count++;
      revenue += d.order.total;
      items += d.items.fold<int>(0, (a, i) => a + i.quantity);
      if (d.payments.any((p) => p.pending)) pending++;
    }
    return EventComparisonRow(
      event: event,
      orderCount: count,
      revenue: revenue,
      itemCount: items,
      pendingCount: pending,
      expenses: expenses,
    );
  }

  final Event event;
  final int orderCount;
  final int revenue;
  final int itemCount;
  final int pendingCount;

  /// 这一场记的支出合计。
  final int expenses;

  /// 净收入 = 实收 − 支出。
  int get net => revenue - expenses;
}

/// 付款备注码：订单号去掉横杠，如 A-007 → A007，方便客人在付款备注里输入。
String paymentCodeOf(String orderNumber) => orderNumber.replaceAll('-', '');

/// 搜索时统一格式：只保留字母数字并转大写，A-007、a007、A007 都算同一个。
String normalizeOrderCode(String text) =>
    text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

class OrderDetail {
  const OrderDetail({
    required this.order,
    required this.items,
    required this.payments,
    this.refund,
  });

  final Order order;
  final List<OrderItem> items;
  final List<OrderPayment> payments;
  final Refund? refund;
}

class SalesRepository {
  SalesRepository(this._db, this._session);

  final AppDatabase _db;
  final Session _session;

  /// 生成订单：写订单、明细、支付记录，并按场次扣减库存（套装扣成分）。
  Future<Order> placeOrder({
    required String eventId,
    required List<SaleLine> lines,
    required PaymentMethod paymentMethod,
    Discount discount = const NoDiscount(),
    int? tendered,
    String? number,
    bool paymentPending = false,
  }) {
    if (lines.isEmpty) throw ArgumentError.value(lines, 'lines', 'empty');
    return _db.transaction(() async {
      final summary = summarize([
        for (final l in lines)
          CartLine(
            variantId: l.variantId,
            unitPrice: l.unitPrice,
            quantity: l.quantity,
          ),
      ], discount);
      final now = DateTime.now();
      final orderId = newId();
      final order = OrdersCompanion.insert(
        id: orderId,
        updatedAt: _session.clock.tick(),
        eventId: eventId,
        deviceId: _session.deviceId,
        number: await _numberToUse(eventId, number),
        currency: _session.currency,
        subtotal: summary.subtotal,
        discount: summary.discount,
        total: summary.total,
        createdAt: now,
      );
      await _db.into(_db.orders).insert(order);

      for (final line in lines) {
        await _db
            .into(_db.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                id: newId(),
                updatedAt: _session.clock.tick(),
                orderId: orderId,
                variantId: line.variantId,
                nameSnapshot: line.name,
                unitPrice: line.unitPrice,
                quantity: line.quantity,
              ),
            );
        final deductions = saleDeductions(
          variantId: line.variantId,
          quantity: line.quantity,
          bundleComponents: line.components,
        );
        for (final MapEntry(key: variantId, value: qty) in deductions.entries) {
          await _move(variantId, eventId, -qty, 'sale', orderId, now);
        }
      }

      await _db
          .into(_db.orderPayments)
          .insert(
            OrderPaymentsCompanion.insert(
              id: newId(),
              updatedAt: _session.clock.tick(),
              orderId: orderId,
              paymentMethodId: paymentMethod.id,
              methodNameSnapshot: paymentMethod.name,
              amount: summary.total,
              tendered: Value(tendered),
              pending: Value(paymentPending),
              confirmedAt: Value(paymentPending ? null : now),
            ),
          );
      return (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(orderId))).getSingle();
    });
  }

  /// 单号 = 设备短码 + 本设备在本场的第几单，如 A-007。
  /// 结账界面打开时先确定单号（作为付款备注码给客人看），下单时沿用它。
  Future<String> nextOrderNumber(String eventId) => _nextNumber(eventId);

  /// 预先给的单号如果已被占用（极少见），就重新取一个。
  Future<String> _numberToUse(String eventId, String? reserved) async {
    if (reserved == null) return _nextNumber(eventId);
    final taken =
        await (_db.select(_db.orders)..where(
              (t) =>
                  t.eventId.equals(eventId) &
                  t.deviceId.equals(_session.deviceId) &
                  t.number.equals(reserved),
            ))
            .getSingleOrNull();
    return taken == null ? reserved : _nextNumber(eventId);
  }

  /// 事后核对到这笔钱：标记为已收款。
  Future<void> confirmPayment(String orderId) =>
      (_db.update(_db.orderPayments)
            ..where((t) => t.orderId.equals(orderId) & t.pending.equals(true)))
          .write(
            OrderPaymentsCompanion(
              pending: const Value(false),
              confirmedAt: Value(DateTime.now()),
              updatedAt: Value(_session.clock.tick()),
            ),
          );

  Future<String> _nextNumber(String eventId) async {
    final count = _db.orders.id.count();
    final n =
        await (_db.selectOnly(_db.orders)
              ..addColumns([count])
              ..where(
                _db.orders.eventId.equals(eventId) &
                    _db.orders.deviceId.equals(_session.deviceId),
              ))
            .map((r) => r.read(count)!)
            .getSingle();
    return '${_session.orderPrefix}-${(n + 1).toString().padLeft(3, '0')}';
  }

  /// 整单退款：记一条退款，并把售出时扣掉的库存加回本场。
  Future<void> refundOrder(String orderId, {String? reason}) => _db.transaction(
    () async {
      final existing =
          await (_db.select(_db.refunds)..where(
                (t) => t.orderId.equals(orderId) & t.deleted.equals(false),
              ))
              .getSingleOrNull();
      if (existing != null) return;
      final order = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(orderId))).getSingle();
      final now = DateTime.now();
      await _db
          .into(_db.refunds)
          .insert(
            RefundsCompanion.insert(
              id: newId(),
              updatedAt: _session.clock.tick(),
              orderId: orderId,
              amount: order.total,
              reason: Value(reason),
              deviceId: _session.deviceId,
              createdAt: now,
            ),
          );
      final sold =
          await (_db.select(_db.stockMovements)..where(
                (t) =>
                    t.orderId.equals(orderId) &
                    t.reason.equals('sale') &
                    t.deleted.equals(false),
              ))
              .get();
      for (final m in sold) {
        await _move(m.variantId, m.location, -m.delta, 'refund', orderId, now);
      }
    },
  );

  Stream<List<OrderSummary>> watchOrders(String eventId) => _db.watchTables({
    _db.orders,
    _db.orderItems,
    _db.orderPayments,
    _db.refunds,
  }, () => _loadOrders(eventId));

  Future<List<OrderSummary>> _loadOrders(String eventId) async {
    final orders =
        await (_db.select(_db.orders)
              ..where(
                (t) => t.eventId.equals(eventId) & t.deleted.equals(false),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    final ids = [for (final o in orders) o.id];
    final payments = await (_db.select(
      _db.orderPayments,
    )..where((t) => t.orderId.isIn(ids))).get();
    final items = await (_db.select(
      _db.orderItems,
    )..where((t) => t.orderId.isIn(ids))).get();
    final refunds = await (_db.select(
      _db.refunds,
    )..where((t) => t.orderId.isIn(ids) & t.deleted.equals(false))).get();

    final paymentNames = <String, List<String>>{};
    final pendingOrders = <String>{};
    for (final p in payments) {
      paymentNames.putIfAbsent(p.orderId, () => []).add(p.methodNameSnapshot);
      if (p.pending) pendingOrders.add(p.orderId);
    }
    final itemCounts = <String, int>{};
    for (final i in items) {
      itemCounts.update(
        i.orderId,
        (v) => v + i.quantity,
        ifAbsent: () => i.quantity,
      );
    }
    final refundByOrder = {for (final r in refunds) r.orderId: r};
    return [
      for (final o in orders)
        OrderSummary(
          order: o,
          paymentNames: (paymentNames[o.id] ?? const []).join('、'),
          itemCount: itemCounts[o.id] ?? 0,
          refund: refundByOrder[o.id],
          paymentPending: pendingOrders.contains(o.id),
        ),
    ];
  }

  Stream<OrderDetail> watchOrderDetail(String orderId) => _db.watchTables(
    {_db.orders, _db.orderItems, _db.orderPayments, _db.refunds},
    () async {
      final order = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(orderId))).getSingle();
      return OrderDetail(
        order: order,
        items: await (_db.select(
          _db.orderItems,
        )..where((t) => t.orderId.equals(orderId))).get(),
        payments: await (_db.select(
          _db.orderPayments,
        )..where((t) => t.orderId.equals(orderId))).get(),
        refund:
            await (_db.select(_db.refunds)..where(
                  (t) => t.orderId.equals(orderId) & t.deleted.equals(false),
                ))
                .getSingleOrNull(),
      );
    },
  );

  /// 某场次（[eventId] 为 null 时为所有场次）的全部订单（含明细、支付、退款），
  /// 按时间先后。用于导出和统计。
  Future<List<OrderDetail>> loadOrderDetails(String? eventId) async {
    final orders =
        await (_db.select(_db.orders)
              ..where(
                (t) =>
                    (eventId == null
                        ? const Constant(true)
                        : t.eventId.equals(eventId)) &
                    t.deleted.equals(false),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
            .get();
    final ids = [for (final o in orders) o.id];
    final items = await (_db.select(
      _db.orderItems,
    )..where((t) => t.orderId.isIn(ids))).get();
    final payments = await (_db.select(
      _db.orderPayments,
    )..where((t) => t.orderId.isIn(ids))).get();
    final refunds = await (_db.select(
      _db.refunds,
    )..where((t) => t.orderId.isIn(ids) & t.deleted.equals(false))).get();

    final itemsByOrder = <String, List<OrderItem>>{};
    for (final i in items) {
      itemsByOrder.putIfAbsent(i.orderId, () => []).add(i);
    }
    final paymentsByOrder = <String, List<OrderPayment>>{};
    for (final p in payments) {
      paymentsByOrder.putIfAbsent(p.orderId, () => []).add(p);
    }
    final refundByOrder = {for (final r in refunds) r.orderId: r};
    return [
      for (final o in orders)
        OrderDetail(
          order: o,
          items: itemsByOrder[o.id] ?? const [],
          payments: paymentsByOrder[o.id] ?? const [],
          refund: refundByOrder[o.id],
        ),
    ];
  }

  /// 销售统计（[eventId] 为 null 时汇总所有场次），订单或商品有变化
  /// （包括其他设备同步过来的）时自动重算。
  Stream<SalesStats> watchEventStats(String? eventId) => _db.watchTables(
    {
      _db.orders,
      _db.orderItems,
      _db.orderPayments,
      _db.refunds,
      _db.variants,
      _db.products,
      _db.bundleItems,
    },
    () async => computeSalesStats([
      for (final d in await loadOrderDetails(eventId))
        StatsOrder(
          discount: d.order.discount,
          total: d.order.total,
          paymentName: d.payments.map((p) => p.methodNameSnapshot).join('、'),
          refunded: d.refund != null,
          refundAmount: d.refund?.amount ?? 0,
          paymentPending: d.payments.any((p) => p.pending),
          lines: [
            for (final i in d.items)
              StatsLine(
                variantId: i.variantId,
                name: i.nameSnapshot,
                unitPrice: i.unitPrice,
                quantity: i.quantity,
              ),
          ],
        ),
    ], await _loadOwnership()),
  );

  /// 各场次对比：每场的订单数、实收、件数、待确认收款数。按场次日期从新到旧。
  Stream<List<EventComparisonRow>> watchEventComparison() => _db.watchTables(
    {
      _db.events,
      _db.orders,
      _db.orderItems,
      _db.orderPayments,
      _db.refunds,
      _db.expenses,
    },
    () async {
      final events =
          await (_db.select(_db.events)..where(
                (t) =>
                    t.teamId.equals(_session.teamId) & t.deleted.equals(false),
              ))
              .get();
      final byEvent = <String, List<OrderDetail>>{};
      for (final d in await loadOrderDetails(null)) {
        byEvent.putIfAbsent(d.order.eventId, () => []).add(d);
      }
      final spent = <String, int>{};
      final expenses =
          await (_db.select(_db.expenses)..where(
                (t) =>
                    t.teamId.equals(_session.teamId) &
                    t.deleted.equals(false) &
                    t.eventId.isNotNull(),
              ))
              .get();
      for (final x in expenses) {
        spent.update(x.eventId!, (a) => a + x.amount, ifAbsent: () => x.amount);
      }
      final rows = [
        for (final e in events)
          EventComparisonRow.fromOrders(
            e,
            byEvent[e.id] ?? const [],
            expenses: spent[e.id] ?? 0,
          ),
      ];
      rows.sort((a, b) {
        final da = a.event.startsOn, db = b.event.startsOn;
        if (da == null || db == null) return da == null ? 1 : -1;
        return db.compareTo(da);
      });
      return rows;
    },
  );

  /// 每个 SKU（包括已删除的，历史订单还会用到）属于哪个作者；套装给出成分。
  Future<Map<String, VariantOwnership>> _loadOwnership() async {
    final rows = await _db.select(_db.variants).join([
      innerJoin(
        _db.products,
        _db.products.id.equalsExp(_db.variants.productId),
      ),
    ]).get();
    final creatorOf = <String, String?>{};
    final priceOf = <String, int>{};
    for (final r in rows) {
      final v = r.readTable(_db.variants);
      creatorOf[v.id] = r.readTable(_db.products).creatorId;
      priceOf[v.id] = v.price;
    }
    final bundleItems = await (_db.select(
      _db.bundleItems,
    )..where((t) => t.deleted.equals(false))).get();
    final parts = <String, List<BundlePart>>{};
    for (final b in bundleItems) {
      parts
          .putIfAbsent(b.bundleVariantId, () => [])
          .add(
            BundlePart(
              creatorId: creatorOf[b.componentVariantId],
              value: (priceOf[b.componentVariantId] ?? 0) * b.quantity,
            ),
          );
    }
    return {
      for (final id in creatorOf.keys)
        id: VariantOwnership(
          creatorId: creatorOf[id],
          bundleParts: parts[id] ?? const [],
        ),
    };
  }

  // ---- 支付方式 ----

  Stream<List<PaymentMethod>> watchPaymentMethods({bool enabledOnly = false}) =>
      (_db.select(_db.paymentMethods)
            ..where(
              (t) =>
                  t.teamId.equals(_session.teamId) &
                  t.deleted.equals(false) &
                  (enabledOnly ? t.enabled.equals(true) : const Constant(true)),
            )
            ..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.name),
            ]))
          .watch();

  Future<void> savePaymentMethod({
    String? id,
    required String name,
    required String kind,
    String? qrImagePath,
    bool enabled = true,
    int sortOrder = 0,
  }) => _db
      .into(_db.paymentMethods)
      .insertOnConflictUpdate(
        PaymentMethodsCompanion.insert(
          id: id ?? newId(),
          updatedAt: _session.clock.tick(),
          teamId: _session.teamId,
          name: name.trim(),
          kind: kind,
          qrImagePath: Value(qrImagePath),
          enabled: Value(enabled),
          sortOrder: Value(sortOrder),
        ),
      );

  Future<void> deletePaymentMethod(String id) =>
      (_db.update(_db.paymentMethods)..where((t) => t.id.equals(id))).write(
        PaymentMethodsCompanion(
          deleted: const Value(true),
          updatedAt: Value(_session.clock.tick()),
        ),
      );

  Future<void> _move(
    String variantId,
    String location,
    int delta,
    String reason,
    String orderId,
    DateTime at,
  ) => _db
      .into(_db.stockMovements)
      .insert(
        StockMovementsCompanion.insert(
          id: newId(),
          updatedAt: _session.clock.tick(),
          variantId: variantId,
          location: location,
          delta: delta,
          reason: reason,
          orderId: Value(orderId),
          deviceId: _session.deviceId,
          createdAt: at,
        ),
      );
}
