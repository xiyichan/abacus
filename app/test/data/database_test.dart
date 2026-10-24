import 'package:abacus/data/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  StockMovementsCompanion move(
    String id,
    String variant,
    String location,
    int delta,
  ) => StockMovementsCompanion.insert(
    id: id,
    updatedAt: '0',
    variantId: variant,
    location: location,
    delta: delta,
    reason: 'adjust',
    deviceId: 'dev-a',
    createdAt: DateTime(2026, 10, 23),
  );

  test('stockAt 按位置汇总流水并忽略已删除记录', () async {
    await db.batch((b) {
      b.insertAll(db.stockMovements, [
        move('1', 'a', 'home', 20),
        move('2', 'a', 'home', -10),
        move('3', 'a', 'ev', 10),
        move('4', 'b', 'ev', 5),
        move('5', 'a', 'ev', -2),
      ]);
    });
    await (db.update(db.stockMovements)..where((t) => t.id.equals('5'))).write(
      const StockMovementsCompanion(deleted: Value(true)),
    );

    expect(await db.stockAt('home'), {'a': 10});
    expect(await db.stockAt('ev'), {'a': 10, 'b': 5});
  });
}
