import 'package:intl/intl.dart';

/// 金额统一用最小货币单位的整数存储，显示时再按币种格式化。
String formatMoney(int minorUnits, String currency, {String? locale}) {
  final format = NumberFormat.simpleCurrency(locale: locale, name: currency);
  final digits = format.decimalDigits ?? 2;
  var factor = 1;
  for (var i = 0; i < digits; i++) {
    factor *= 10;
  }
  return format.format(minorUnits / factor);
}
