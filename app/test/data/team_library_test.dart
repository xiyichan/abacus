import 'dart:io';

import 'package:abacus/data/database.dart';
import 'package:abacus/data/session.dart';
import 'package:abacus/data/team_library.dart';
import 'package:abacus/sync/cloud_sync_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// 临时目录里的团队库，数据库也放在临时文件里。
TeamLibrary tempLibrary(Directory dir) => TeamLibrary.load(
  dir,
  open: (key) => AppDatabase(NativeDatabase(File('${dir.path}/$key.sqlite'))),
);

Future<Directory> tempDir() async {
  final dir = await Directory.systemTemp.createTemp('abacus-teams');
  addTearDown(() => dir.delete(recursive: true));
  return dir;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('没有索引时（旧版本）把原来的 abacus 数据库当作唯一的团队', () async {
    final library = tempLibrary(await tempDir());
    expect(library.teams.single.key, TeamLibrary.legacyKey);
    expect(library.currentKey, TeamLibrary.legacyKey);
    expect(library.account, isNull);
    // 共用登录还不知道，要从原来的数据库里取，不能当成已退出。
    expect(library.accountKnown, isFalse);
    library.setAccount(null);
    expect(library.accountKnown, isTrue);
  });

  test('新增、切换、记名字和登录都写进索引，重新打开后还在', () async {
    final dir = await tempDir();
    final library = tempLibrary(dir);
    final key = library.newKey();
    library
      ..add(LocalTeam(key: key))
      ..setCurrent(key)
      ..remember(key, teamId: 't2', name: '二号摊')
      ..setAccount(const CloudAccount(token: 'tok', email: 'a@b.c'));

    final again = tempLibrary(dir);
    expect([for (final t in again.teams) t.key], [TeamLibrary.legacyKey, key]);
    expect(again.currentKey, key);
    expect(again.byTeamId('t2')!.name, '二号摊');
    expect(again.account!.email, 'a@b.c');
  });

  test('从本机移除团队会删掉它的数据库文件；当前团队不能移除', () async {
    final dir = await tempDir();
    final library = tempLibrary(dir);
    final key = library.newKey();
    library.add(LocalTeam(key: key));
    final db = library.open(key);
    await ensureSession(db);
    await db.close();
    expect(File('${dir.path}/$key.sqlite').existsSync(), isTrue);

    library.remove(key);
    expect(File('${dir.path}/$key.sqlite').existsSync(), isFalse);
    expect(library.teams.single.key, TeamLibrary.legacyKey);
    library.remove(TeamLibrary.legacyKey);
    expect(library.teams, hasLength(1));
  });

  test('共用的登录写进团队数据库；退出后打开其他团队时清掉旧登录', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await applyCloudAccount(
      db,
      const CloudAccount(token: 'tok', email: 'a@b.c', displayName: '摊主'),
    );
    expect(await db.getSetting('cloudToken'), 'tok');
    expect(await db.getSetting('cloudDisplayName'), '摊主');
    await applyCloudAccount(db, null);
    expect(await db.getSetting('cloudToken'), isNull);
    expect(await db.getSetting('cloudEmail'), isNull);
  });
}
