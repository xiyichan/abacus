import 'dart:convert';

import 'package:abacus/domain/csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('含逗号、引号、换行的字段加引号转义', () {
    expect(
      toCsv([
        ['单号', '备注'],
        ['A-001', '徽章, 2 个'],
        ['A-002', '他说"好"'],
        ['A-003', '第一行\n第二行'],
        ['A-004', null],
      ]),
      '单号,备注\r\nA-001,"徽章, 2 个"\r\nA-002,"他说""好"""\r\nA-003,"第一行\n第二行"\r\nA-004,',
    );
  });

  test('导出字节以 UTF-8 BOM 开头', () {
    final bytes = csvBytes('单号');
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(utf8.decode(bytes.skip(3).toList()), '单号');
  });

  test('金额格式化为纯数字', () {
    expect(plainAmount(1500), '15.00');
    expect(plainAmount(5), '0.05');
    expect(plainAmount(-250), '-2.50');
  });
}
