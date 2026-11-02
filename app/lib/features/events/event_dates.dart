import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';

final _fullFormat = DateFormat('yyyy-MM-dd');
final _monthDayFormat = DateFormat('MM-dd');

/// 场次的日期：可能是一天，也可能是连续几天（如两天的展）。
extension EventDates on Event {
  /// 最后一天；只有一天时就是开始那天，没设日期时为 null。
  DateTime? get lastDay => endsOn ?? startsOn;

  /// 2026-10-25，或 2026-10-25 ~ 10-26（跨年时两边都写年份）；没设日期时为 null。
  /// [withYear] 为 false 时不写年份，用于空间紧张的地方。
  String? dateLabel({bool withYear = true}) => startsOn == null
      ? null
      : formatDateRange(startsOn!, endsOn, withYear: withYear);
}

String formatDateRange(DateTime start, DateTime? end, {bool withYear = true}) {
  final first = DateUtils.dateOnly(start);
  final last = end == null ? first : DateUtils.dateOnly(end);
  final head = (withYear ? _fullFormat : _monthDayFormat).format(first);
  if (!last.isAfter(first)) return head;
  final tail = withYear && last.year != first.year
      ? _fullFormat.format(last)
      : _monthDayFormat.format(last);
  return '$head ~ $tail';
}
