import 'dart:io';

import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/database.dart';
import 'package:abacus/data/session.dart';
import 'package:abacus/main.dart';
import 'package:abacus/providers.dart';
import 'package:abacus/data/team_library.dart';
import 'package:abacus/sync/cloud_api.dart';
import 'package:abacus/sync/cloud_sync_service.dart';
import 'package:abacus/sync/lan_sync_service.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/team_library_test.dart' show tempLibrary;
import '../helpers.dart';

/// 不连网的云端：只会列出一个团队。同步连接指向本机一个没人监听的端口，马上失败。
class _FakeCloudApi extends CloudApi {
  _FakeCloudApi() : super(baseUrl: 'http://127.0.0.1:9');

  @override
  Future<List<CloudTeam>> listTeams(String token) async {
    if (token != 'tok') throw const CloudApiException('unauthorized', 401);
    return const [CloudTeam(id: 'cloud-team', name: '云端摊', currency: 'CNY')];
  }

  @override
  Future<void> linkTeam(
    String token, {
    required String teamId,
    required String teamToken,
    required List<int> teamKey,
    required String name,
    required String currency,
  }) async {}
}

Future<Directory> _tempDir(WidgetTester tester) async {
  final dir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('abacus-switch'),
  ))!;
  addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
  return dir;
}

void main() {
  testWidgets('右上角切换团队：新建团队后切回来，原来团队的商品还在', (tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('abacus-switch'),
    ))!;
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    final library = tempLibrary(dir);

    // 原来的团队：改个名字，加一件商品。
    await tester.runAsync(() async {
      final db = library.open(library.currentKey);
      final session = await ensureSession(db);
      await (db.update(db.teams)..where((t) => t.id.equals(session.teamId)))
          .write(const TeamsCompanion(name: Value('一号摊')));
      await CatalogRepository(db, session).saveProduct(
        ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
      );
      await db.close();
    });

    await tester.pumpWidget(
      AppRoot(
        library: library,
        mediaDir: dir,
        overrides: [
          syncServiceProvider.overrideWithValue(DisabledSyncService()),
        ],
      ),
    );
    await settle(tester);
    expect(find.widgetWithText(InkWell, '一号摊'), findsOneWidget);

    // 新建团队：切到一个空团队。
    await tester.tap(find.widgetWithText(InkWell, '一号摊'));
    await settle(tester);
    await tester.tap(find.text('新建团队'));
    await settle(tester);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '新建团队'));
    await settle(tester);
    await settle(tester);
    expect(library.teams, hasLength(2));
    expect(library.currentKey, isNot(library.teams.first.key));
    await tester.tap(find.text('商品'));
    await settle(tester);
    expect(find.text('还没有商品'), findsOneWidget);

    // 切回原来的团队，商品还在，不用登录也不用下载。
    await tester.tap(find.text('收银'));
    await settle(tester);
    await tester.tap(find.widgetWithText(InkWell, '我的摊位'));
    await settle(tester);
    expect(find.text('本机的团队'), findsOneWidget);
    await tester.tap(find.text('一号摊'));
    // 点下去马上盖上加载画面，不是停在原来的界面上等。
    await tester.pump();
    await tester.pump();
    expect(find.text('正在切换到「一号摊」…'), findsOneWidget);
    // 关旧库最多等 2 秒（假时钟里要多推几轮）。
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
    expect(library.currentKey, library.teams.first.key);
    await tester.tap(find.text('商品'));
    await settle(tester);
    expect(find.text('徽章'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('从旧版本升级：沿用原来数据库里的登录，添加云端团队不用再收验证码', (tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = await _tempDir(tester);
    final library = tempLibrary(dir); // 没有 teams.json：旧版本
    await tester.runAsync(() async {
      final db = library.open(library.currentKey);
      await ensureSession(db);
      await applyCloudAccount(
        db,
        const CloudAccount(token: 'tok', email: 'a@b.c'),
      );
      await db.close();
    });

    await tester.pumpWidget(
      AppRoot(
        library: library,
        mediaDir: dir,
        overrides: [
          syncServiceProvider.overrideWithValue(DisabledSyncService()),
          cloudApiProvider.overrideWithValue(_FakeCloudApi()),
        ],
      ),
    );
    await settle(tester);
    expect(library.account?.email, 'a@b.c');

    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/settings/team/cloud?restore=1');
    await settle(tester);
    expect(find.text('选择要恢复的团队'), findsOneWidget);
    expect(find.text('云端摊'), findsOneWidget);
    expect(find.text('发送验证码'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('登录过邮箱：团队面板直接列出这个邮箱的其他团队，不用验证码', (tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = await _tempDir(tester);
    final library = tempLibrary(dir)
      ..setAccount(const CloudAccount(token: 'tok', email: 'a@b.c'));

    await tester.pumpWidget(
      AppRoot(
        library: library,
        mediaDir: dir,
        overrides: [
          syncServiceProvider.overrideWithValue(DisabledSyncService()),
          cloudApiProvider.overrideWithValue(_FakeCloudApi()),
        ],
      ),
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(InkWell, '我的摊位'));
    await settle(tester);
    expect(find.text('这个邮箱的其他团队'), findsOneWidget);
    expect(find.text('云端摊'), findsOneWidget);
    expect(find.text('用邮箱登录'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
