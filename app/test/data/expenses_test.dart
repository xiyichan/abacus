import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/expense_repository.dart';
import 'package:abacus/data/order_export.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:abacus/features/lock/cashier_lock.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import '../sync/op_store_test.dart' show Node, syncPair;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Node node;
  late ExpenseRepository expenses;
  late String eventId;

  setUp(() async {
    node = await Node.founder();
    expenses = ExpenseRepository(node.db, node.session);
    eventId = await node.inventory.createEvent(name: 'CP30');
  });
  tearDown(() => node.db.close());

  test('记支出、修改、删除；按场次或全部列出；汇总按分类', () async {
    final travel = await expenses.addExpense(
      eventId: eventId,
      category: 'travel',
      amount: 35000,
      note: '高铁往返',
      spentOn: DateTime(2026, 10, 1),
    );
    await expenses.addExpense(
      eventId: eventId,
      category: 'booth',
      amount: 50000,
      spentOn: DateTime(2026, 10, 2),
    );
    await expenses.addExpense(
      category: 'supplies',
      amount: 12000,
      spentOn: DateTime(2026, 9, 20),
    );

    final atEvent = await expenses.watchExpenses(eventId).first;
    expect(atEvent.map((x) => x.category), ['booth', 'travel']);
    expect((await expenses.watchExpenses(null).first).length, 3);

    final summary = ExpenseSummary(await expenses.watchExpenses(null).first);
    expect(summary.total, 97000);
    expect(summary.byCategory.first, isA<MapEntry<String, int>>());
    expect(summary.byCategory.first.key, 'booth');

    await expenses.updateExpense(
      travel,
      eventId: eventId,
      category: 'travel',
      amount: 40000,
      note: '高铁往返',
      spentOn: DateTime(2026, 10, 1),
    );
    await expenses.deleteExpense(travel);
    final left = await expenses.watchExpenses(eventId).first;
    expect(left.single.category, 'booth');
  });

  test('各场对比带上支出和净收入', () async {
    await node.catalog.saveProduct(
      ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
    );
    final v = (await node.catalog.loadCatalog()).single.variants.single;
    await node.sales.placeOrder(
      eventId: eventId,
      lines: [
        SaleLine(variantId: v.id, name: '徽章', unitPrice: 1500, quantity: 4),
      ],
      paymentMethod: (await node.sales.watchPaymentMethods().first).first,
    );
    await expenses.addExpense(
      eventId: eventId,
      category: 'booth',
      amount: 2000,
      spentOn: DateTime(2026, 10, 1),
    );
    final row = (await node.sales.watchEventComparison().first).single;
    expect(row.revenue, 6000);
    expect(row.expenses, 2000);
    expect(row.net, 4000);
  });

  test('支出会同步到其他设备', () async {
    final other = await Node.joining(node);
    addTearDown(other.db.close);
    await expenses.addExpense(
      eventId: eventId,
      category: 'lodging',
      amount: 30000,
      spentOn: DateTime(2026, 10, 1),
    );
    await syncPair(node, other);
    final there = await ExpenseRepository(
      other.db,
      other.session,
    ).watchExpenses(eventId).first;
    expect(there.single.amount, 30000);
  });

  test('导出支出明细 CSV：每笔一行，末尾附实收、支出合计、净收入', () async {
    await expenses.addExpense(
      eventId: eventId,
      category: 'travel',
      amount: 35000,
      note: '高铁, 往返',
      spentOn: DateTime(2026, 10, 1),
    );
    await expenses.addExpense(
      category: 'supplies',
      amount: 12050,
      spentOn: DateTime(2026, 9, 20),
    );

    final one = buildExpensesCsv(
      await expenses.watchExpenses(eventId).first,
      revenue: 100000,
    ).split('\r\n');
    expect(one, [
      '日期,分类,金额,备注',
      '2026-10-01,差旅交通,350.00,"高铁, 往返"',
      '',
      ',实收,1000.00,',
      ',支出合计,350.00,',
      ',净收入,650.00,',
    ]);

    final all = buildExpensesCsv(
      await expenses.watchExpenses(null).first,
      revenue: 100000,
      eventNames: {eventId: 'CP30'},
    ).split('\r\n');
    expect(all[0], '场次,日期,分类,金额,备注');
    expect(all[1], 'CP30,2026-10-01,差旅交通,350.00,"高铁, 往返"');
    expect(all[2], ',2026-09-20,物料制作,120.50,');
    expect(all.last, ',,净收入,529.50,');
  });

  test('收银锁 PIN：只存哈希，对的能解开，错的不行', () async {
    expect(await checkLockPin(node.db, '1234'), isFalse);
    await setLockPin(node.db, '1234');
    expect(await node.db.getSetting('cashierLockPin'), isNot(contains('1234')));
    expect(await checkLockPin(node.db, '1234'), isTrue);
    expect(await checkLockPin(node.db, '4321'), isFalse);
    await setCashierLocked(node.db, true);
    expect(await node.db.getSetting('cashierLocked'), '1');
    await setCashierLocked(node.db, false);
    expect(await node.db.getSetting('cashierLocked'), isNull);
  });
}
