import 'package:intl/intl.dart';

import '../domain/checkout.dart';
import '../domain/csv.dart';
import 'database.dart';
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
      orderPaymentCode(o),
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

const _expenseCategoryNames = {
  'travel': '差旅交通',
  'booth': '摊位费',
  'lodging': '住宿',
  'food': '餐饮',
  'supplies': '物料制作',
  'shipping': '快递运费',
  'other': '其他',
};

final _date = DateFormat('yyyy-MM-dd');

/// 支出明细导出为 CSV：一行一笔，最后空一行附上对账汇总（实收、支出合计、净收入）。
/// [revenue] 是同一范围的实收（不含已退款订单）。
/// 传入 [eventNames] 时（导出多个场次）第一列为场次名，不属于场次的留空。
String buildExpensesCsv(
  List<Expense> expenses, {
  required int revenue,
  Map<String, String>? eventNames,
}) {
  final multi = eventNames != null;
  final rows = <List<Object?>>[
    [if (multi) '场次', '日期', '分类', '金额', '备注'],
  ];
  var total = 0;
  for (final x in expenses) {
    total += x.amount;
    rows.add([
      if (multi) x.eventId == null ? '' : eventNames[x.eventId] ?? '',
      _date.format(x.spentOn),
      _expenseCategoryNames[x.category] ?? x.category,
      plainAmount(x.amount),
      x.note,
    ]);
  }
  // 汇总的“金额”放在同一列，表格里对齐好看。
  List<Object?> summary(String label, int cents) => [
    if (multi) '',
    '',
    label,
    plainAmount(cents),
    '',
  ];
  rows
    ..add([])
    ..add(summary('实收', revenue))
    ..add(summary('支出合计', total))
    ..add(summary('净收入', revenue - total));
  return toCsv(rows);
}
