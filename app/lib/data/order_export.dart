import 'package:intl/intl.dart';

import '../domain/checkout.dart';
import '../domain/csv.dart';
import 'sales_repository.dart';

final _time = DateFormat('yyyy-MM-dd HH:mm:ss');

/// 订单列表导出为 CSV：一行一单，金额为不带符号的数字，方便在表格软件里求和。
/// 传入 [eventNames] 时（导出多个场次）第一列为场次名。
String buildOrdersCsv(
  List<OrderDetail> orders, {
  Map<String, String>? eventNames,
}) {
  final rows = <List<Object?>>[
    [
      if (eventNames != null) '场次',
      '单号',
      '时间',
      '商品',
      '件数',
      '小计',
      '优惠',
      '实收',
      '支付方式',
      '付款备注码',
      '收款状态',
      '收到现金',
      '找零',
      '状态',
      '退款时间',
      '退款原因',
    ],
  ];
  for (final d in orders) {
    final o = d.order;
    final cash = d.payments.where((p) => p.tendered != null).firstOrNull;
    rows.add([
      if (eventNames != null) eventNames[o.eventId] ?? '',
      o.number,
      _time.format(o.createdAt),
      d.items.map((i) => '${i.nameSnapshot} ×${i.quantity}').join('；'),
      d.items.fold<int>(0, (a, i) => a + i.quantity),
      plainAmount(o.subtotal),
      plainAmount(o.discount),
      plainAmount(o.total),
      d.payments.map((p) => p.methodNameSnapshot).join('、'),
      paymentCodeOf(o.number),
      d.payments.any((p) => p.pending) ? '待确认' : '已收款',
      cash == null ? '' : plainAmount(cash.tendered!),
      cash == null
          ? ''
          : plainAmount(
              changeDue(total: cash.amount, tendered: cash.tendered!) ?? 0,
            ),
      d.refund == null ? '已完成' : '已退款',
      d.refund == null ? '' : _time.format(d.refund!.createdAt),
      d.refund?.reason ?? '',
    ]);
  }
  return toCsv(rows);
}
