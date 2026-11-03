import 'package:abacus/providers.dart';
import 'package:abacus/sync/cloud_api.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers.dart';

/// 不连网的云端，[teams] 是这个邮箱下的团队。
class _FakeCloudApi extends CloudApi {
  _FakeCloudApi() : super(baseUrl: 'http://fake');

  List<CloudTeam> teams = [];

  @override
  Future<String?> startLogin(String email) async => '123456';

  @override
  Future<({String token, String? displayName})> verifyLogin(
    String email,
    String code,
  ) async => (token: 'token', displayName: '摊主');

  @override
  Future<List<CloudTeam>> listTeams(String token) async => teams;
}

CloudTeam _team(String id, DateTime createdAt, int devices, int records) =>
    CloudTeam(
      id: id,
      name: '我的摊位',
      currency: 'CNY',
      createdAt: createdAt,
      devices: devices,
      records: records,
    );

Future<void> _login(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first))
      .go('/settings/team/cloud');
  await settle(tester);
  await tester.enterText(find.byType(TextField), 'a@example.com');
  await tester.tap(find.widgetWithText(FilledButton, '发送验证码'));
  await settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, '登录'));
  await settle(tester);
}

void main() {
  testWidgets('云端备份：邮箱下已有团队时先问要不要恢复，选恢复后列出团队详情', (tester) async {
    final api = _FakeCloudApi()
      ..teams = [
        _team('other-a', DateTime(2026, 11, 3, 12, 38), 1, 6),
        _team('other-b', DateTime(2026, 11, 3, 1, 5), 2, 240),
      ];
    await pumpApp(tester, overrides: [cloudApiProvider.overrideWithValue(api)]);
    await _login(tester);

    expect(find.text('这个邮箱在云端还有 2 个其他团队'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '恢复其他团队'));
    await settle(tester);

    expect(find.text('选择要恢复的团队'), findsOneWidget);
    expect(find.text('创建于 2026-11-03 12:38 · 1 台设备 · 6 条记录'), findsOneWidget);
    expect(find.text('创建于 2026-11-03 01:05 · 2 台设备 · 240 条记录'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('本机团队已经备份过，邮箱下还有别的团队时也能选择换过去', (tester) async {
    final api = _FakeCloudApi();
    final app = await pumpApp(
      tester,
      overrides: [cloudApiProvider.overrideWithValue(api)],
    );
    api.teams = [
      _team(app.session.teamId, DateTime(2026, 11, 3, 12, 38), 1, 6),
      _team('other', DateTime(2026, 11, 3, 1, 5), 2, 240),
    ];
    await _login(tester);

    expect(find.text('这个邮箱在云端还有 1 个其他团队'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '恢复其他团队'));
    await settle(tester);
    expect(
      find.text('创建于 2026-11-03 12:38 · 1 台设备 · 6 条记录 · 本机当前团队'),
      findsOneWidget,
    );
    await unmountApp(tester);
  });
}
