import 'dart:convert';

/// 生成 CSV 文本（RFC 4180）：含逗号、引号、换行的字段用双引号包起来。
String toCsv(List<List<Object?>> rows) {
  String field(Object? value) {
    final text = value?.toString() ?? '';
    final needsQuotes =
        text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r');
    return needsQuotes ? '"${text.replaceAll('"', '""')}"' : text;
  }

  return rows.map((row) => row.map(field).join(',')).join('\r\n');
}

/// 带 UTF-8 BOM 的字节，Excel 打开中文才不会乱码。
List<int> csvBytes(String csv) => [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];

/// 分 → “15.00” 这样不带货币符号的数字，方便在表格里求和。
String plainAmount(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}
