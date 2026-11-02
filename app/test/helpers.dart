import 'dart:io';

import 'package:abacus/data/database.dart';
import 'package:abacus/data/session.dart';
import 'package:abacus/main.dart';
import 'package:abacus/providers.dart';
import 'package:abacus/sync/lan_sync_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// 用内存数据库启动整个 App。[seed] 在界面出现前写入测试数据。
Future<({AppDatabase db, Session session})> pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Future<void> Function(AppDatabase db, Session session)? seed,
  List<Override> overrides = const [],
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase(NativeDatabase.memory());
  final session = (await tester.runAsync(() async {
    final session = await ensureSession(db);
    await seed?.call(db, session);
    return session;
  }))!;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sessionProvider.overrideWithValue(session),
        mediaDirProvider.overrideWithValue(Directory.systemTemp),
        syncServiceProvider.overrideWithValue(DisabledSyncService()),
        restartAppProvider.overrideWithValue(() {}),
        ...overrides,
      ],
      child: const AbacusApp(),
    ),
  );
  await settle(tester);
  addTearDown(() async {
    // 测试中途失败时界面还挂着、还在监听数据库，直接关库会一直等下去（整个测试卡死）。
    // 先卸载界面，再关库。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
  return (db: db, session: session);
}

/// 测试结束前卸载界面，让数据库监听和 Riverpod 的计时器在检查前结束。
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// 数据库查询在真实异步里完成，界面在假时钟里刷新，所以两边交替推进几轮。
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
