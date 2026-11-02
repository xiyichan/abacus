import 'package:abacus/features/events/event_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('单日只写一个日期，多天写范围，同年的结束日期省略年份', () {
    expect(formatDateRange(DateTime(2026, 10, 25, 14, 30), null), '2026-10-25');
    expect(
      formatDateRange(DateTime(2026, 10, 25), DateTime(2026, 10, 25)),
      '2026-10-25',
    );
    expect(
      formatDateRange(DateTime(2026, 10, 25), DateTime(2026, 10, 26)),
      '2026-10-25 ~ 10-26',
    );
    expect(
      formatDateRange(DateTime(2026, 12, 31), DateTime(2027, 1, 1)),
      '2026-12-31 ~ 2027-01-01',
    );
    expect(
      formatDateRange(
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 26),
        withYear: false,
      ),
      '10-25 ~ 10-26',
    );
  });
}
