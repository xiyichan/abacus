import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/money.dart';
import '../providers.dart';

/// 按团队币种格式化金额：`ref.watch(moneyProvider)(1500)` → “¥15.00”。
final moneyProvider = Provider<String Function(int)>((ref) {
  final currency = ref.watch(sessionProvider).currency;
  return (cents) => formatMoney(cents, currency, locale: 'zh');
});

/// 把输入的“15”“15.5”“15.50”解析为分。格式不对返回 null。
int? parseMoney(String text) {
  final match = RegExp(r'^\s*(\d+)(?:\.(\d{0,2}))?\s*$').firstMatch(text);
  if (match == null) return null;
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return int.parse(match.group(1)!) * 100 + int.parse(fraction);
}

/// 分 → 输入框里的文字，去掉多余的 0：1500 → “15”，1550 → “15.5”。
String moneyInputText(int cents) {
  final yuan = cents ~/ 100;
  final fraction = cents % 100;
  if (fraction == 0) return '$yuan';
  return fraction % 10 == 0
      ? '$yuan.${fraction ~/ 10}'
      : '$yuan.${fraction.toString().padLeft(2, '0')}';
}

const moneyKeyboard = TextInputType.numberWithOptions(decimal: true);
final moneyInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
];
final intInputFormatters = [FilteringTextInputFormatter.digitsOnly];

/// 团队币种符号，用作金额输入框前缀，如 “¥”。
final currencySymbolProvider = Provider<String>((ref) {
  final currency = ref.watch(sessionProvider).currency;
  return NumberFormat.simpleCurrency(
    locale: 'zh',
    name: currency,
  ).currencySymbol;
});
