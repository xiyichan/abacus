import 'package:drift/drift.dart';

import 'database.dart';
import 'session.dart';

/// 支出分类（存英文 key，界面按语言显示）。
const expenseCategories = [
  'travel',
  'booth',
  'lodging',
  'food',
  'supplies',
  'shipping',
  'other',
];

/// 一段时间/一个场次的支出汇总。
class ExpenseSummary {
  ExpenseSummary(List<Expense> expenses)
    : total = expenses.fold(0, (a, e) => a + e.amount),
      byCategory = _byCategory(expenses);

  final int total;

  /// 分类 → 金额，按金额从大到小。
  final List<MapEntry<String, int>> byCategory;

  static List<MapEntry<String, int>> _byCategory(List<Expense> expenses) {
    final sums = <String, int>{};
    for (final e in expenses) {
      sums.update(e.category, (a) => a + e.amount, ifAbsent: () => e.amount);
    }
    return sums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }
}

/// 支出：差旅、摊位费、住宿等，统计时从实收里扣掉。
class ExpenseRepository {
  ExpenseRepository(this._db, this._session);

  final AppDatabase _db;
  final Session _session;

  /// [eventId] 为 null 时列出全部支出。按日期从近到远。
  Stream<List<Expense>> watchExpenses(String? eventId) {
    final query = _db.select(_db.expenses)
      ..where(
        (t) =>
            t.teamId.equals(_session.teamId) &
            t.deleted.equals(false) &
            (eventId == null
                ? const Constant(true)
                : t.eventId.equals(eventId)),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.spentOn, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Future<String> addExpense({
    String? eventId,
    required String category,
    required int amount,
    String note = '',
    required DateTime spentOn,
  }) async {
    final id = newId();
    await _db
        .into(_db.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: id,
            updatedAt: _session.clock.tick(),
            teamId: _session.teamId,
            eventId: Value(eventId),
            category: category,
            amount: amount,
            note: Value(note.trim()),
            spentOn: spentOn,
            deviceId: _session.deviceId,
            createdAt: DateTime.now(),
          ),
        );
    return id;
  }

  Future<void> updateExpense(
    String id, {
    String? eventId,
    required String category,
    required int amount,
    String note = '',
    required DateTime spentOn,
  }) => (_db.update(_db.expenses)..where((t) => t.id.equals(id))).write(
    ExpensesCompanion(
      updatedAt: Value(_session.clock.tick()),
      eventId: Value(eventId),
      category: Value(category),
      amount: Value(amount),
      note: Value(note.trim()),
      spentOn: Value(spentOn),
    ),
  );

  Future<void> deleteExpense(String id) =>
      (_db.update(_db.expenses)..where((t) => t.id.equals(id))).write(
        ExpensesCompanion(
          deleted: const Value(true),
          updatedAt: Value(_session.clock.tick()),
        ),
      );
}
