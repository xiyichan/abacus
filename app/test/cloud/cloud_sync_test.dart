// 端到端测试：需要先在 cloud/ 目录运行 `npm run dev` 启动本地云端（端口 8790）。
// 没有启动时自动跳过。
import 'dart:io';

import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/database.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:abacus/data/session.dart';
import 'package:abacus/sync/cloud_api.dart';
import 'package:abacus/sync/cloud_crypto.dart';
import 'package:abacus/sync/cloud_sync_service.dart';
import 'package:abacus/sync/op_store.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sync/media_store_test.dart' show tempMedia;
import '../sync/op_store_test.dart' show Node;
import '../sync/peer_session_test.dart' show eventually;

const _url = String.fromEnvironment(
  'CLOUD_TEST_URL',
  defaultValue: 'http://127.0.0.1:8790',
);

Future<bool> _serverUp() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final response = await (await client.getUrl(Uri.parse('$_url/health')))
        .close();
    return response.statusCode == 200;
  } on Object {
    return false;
  }
}

Future<String> _login(CloudApi api, String email) async {
  final code = await api.startLogin(email);
  return (await api.verifyLogin(email, code!)).token;
}

String _email(String tag) =>
    '$tag-${DateTime.now().microsecondsSinceEpoch}@test.local';

void main() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final up = await _serverUp();
  final skip = up ? null : '本地云端没有启动（cloud/ 下运行 npm run dev）';
  final api = CloudApi(baseUrl: _url);

  test('验证码登录：错误验证码被拒，正确的拿到令牌', () async {
    final email = _email('login');
    final code = await api.startLogin(email);
    expect(code, hasLength(6));
    await expectLater(
      api.verifyLogin(email, code == '000000' ? '111111' : '000000'),
      throwsA(
        isA<CloudApiException>().having((e) => e.code, 'code', 'wrong_code'),
      ),
    );
    final login = await api.verifyLogin(email, code!);
    expect(login.displayName, isNull);
    expect(await api.listTeams(login.token), isEmpty);
  }, skip: skip);

  test('用户名：设置、去掉首尾空格、超长被拒，再次登录带回来', () async {
    final email = _email('name');
    final token = await _login(api, email);
    expect(await api.setDisplayName(token, '  小企鹅摊主 '), '小企鹅摊主');
    expect(await api.fetchDisplayName(token), '小企鹅摊主');
    await expectLater(
      api.setDisplayName(token, 'a' * 31),
      throwsA(
        isA<CloudApiException>().having((e) => e.code, 'code', 'invalid_name'),
      ),
    );
    final code = await api.startLogin(email);
    expect((await api.verifyLogin(email, code!)).displayName, '小企鹅摊主');
    expect(await api.setDisplayName(token, ''), isNull);
  }, skip: skip);

  test(
    '上传到云端，新设备用邮箱恢复，之后双向实时同步',
    () async {
      final email = _email('restore');
      final a = await Node.founder();
      await a.catalog.saveProduct(
        ProductDraft(name: '徽章', variants: [VariantDraft(price: 1500)]),
      );
      final cloudA = CloudSyncService(a.db, a.session, api);
      addTearDown(cloudA.dispose);
      await cloudA.start();
      await cloudA.signIn(email: email, token: await _login(api, email));
      await eventually(
        () async => cloudA.current.state == CloudState.connected,
      );

      await cloudA.setDisplayName('小企鹅摊主');
      expect(cloudA.current.displayName, '小企鹅摊主');

      // 云端的团队列表里有它。
      final tokenC = await _login(api, email);
      final teams = await api.listTeams(tokenC);
      expect(teams.single.id, a.session.teamId);

      // 全新设备 C：恢复团队。
      final dbC = AppDatabase(NativeDatabase.memory());
      addTearDown(dbC.close);
      await ensureSession(dbC); // 新装的 App 先有自己的空团队
      await restoreTeamFromCloud(
        db: dbC,
        api: api,
        token: tokenC,
        email: email,
        team: teams.single,
        deviceName: 'C',
      );
      final sessionC = await ensureSession(dbC);
      expect(sessionC.teamId, a.session.teamId);
      expect(sessionC.deviceShortCode, hasLength(6));
      final catalogC = CatalogRepository(dbC, sessionC);
      expect((await catalogC.loadCatalog()).single.product.name, '徽章');

      // C 连上云端后，A 卖货 → C 实时看到；C 改商品 → A 实时看到。
      final cloudC = CloudSyncService(dbC, sessionC, api);
      addTearDown(cloudC.dispose);
      await cloudC.start();
      await eventually(
        () async => cloudC.current.state == CloudState.connected,
      );
      // 用户名是在 A 上设置的，C 连上后自动取到。
      await eventually(() async => cloudC.current.displayName == '小企鹅摊主');
      final v = (await a.catalog.loadCatalog()).single.variants.single;
      final eventId = await a.inventory.createEvent(name: 'CP30');
      await a.inventory.setEventQuantity(
        variantId: v.id,
        eventId: eventId,
        eventQuantity: 5,
      );
      await a.sales.placeOrder(
        eventId: eventId,
        lines: [
          SaleLine(variantId: v.id, name: '徽章', unitPrice: 1500, quantity: 2),
        ],
        paymentMethod: (await a.sales.watchPaymentMethods().first).first,
      );
      await eventually(() async => (await dbC.stockAt(eventId))[v.id] == 3);

      final product = (await catalogC.loadCatalog()).single;
      await catalogC.saveProduct(
        ProductDraft(
          id: product.product.id,
          name: '徽章（新版）',
          variants: [VariantDraft(id: v.id, price: 1800)],
        ),
      );
      await eventually(
        () async =>
            (await a.catalog.loadCatalog()).single.product.name == '徽章（新版）',
      );
      // A 也知道了 C 这台设备。
      await eventually(
        () async => (await a.db.select(a.db.devices).get()).length == 2,
      );
      await a.db.close();
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    '图片：A 加密传到云端，新设备恢复后取下来；之后 A 新加的图片也会同步',
    () async {
      final email = _email('media');
      final a = await Node.founder();
      addTearDown(a.db.close);
      final mediaA = await tempMedia();
      final photo = List.generate(200 * 1024, (i) => i % 251);
      await mediaA.write('p1.jpg', photo);
      await a.catalog.saveProduct(
        ProductDraft(
          name: '徽章',
          imagePath: 'p1.jpg',
          variants: [VariantDraft(price: 1500)],
        ),
      );
      final cloudA = CloudSyncService(a.db, a.session, api, media: mediaA);
      addTearDown(cloudA.dispose);
      await cloudA.start();
      await cloudA.signIn(email: email, token: await _login(api, email));

      // 云端存的是密文，用团队令牌也只能拿到密文。
      final keys = await CloudKeys.derive(a.session.teamKey);
      final token = await _login(api, email);
      Future<List<int>?> fetch() => api.getMedia(
        token,
        teamId: a.session.teamId,
        teamToken: keys.teamToken,
        name: 'p1.jpg',
      );
      await eventually(() async => await fetch() != null);
      final sealed = (await fetch())!;
      expect(sealed, isNot(photo));
      expect(await keys.openMedia('p1.jpg', sealed), photo);
      // 换个文件名就解不开（不能把一张图的密文冒充另一张）。
      expect(await keys.openMedia('p2.jpg', sealed), isNull);

      final dbC = AppDatabase(NativeDatabase.memory());
      addTearDown(dbC.close);
      await ensureSession(dbC);
      await restoreTeamFromCloud(
        db: dbC,
        api: api,
        token: token,
        email: email,
        team: (await api.listTeams(token)).single,
        deviceName: 'C',
      );
      final sessionC = await ensureSession(dbC);
      final mediaC = await tempMedia();
      final cloudC = CloudSyncService(dbC, sessionC, api, media: mediaC);
      addTearDown(cloudC.dispose);
      await cloudC.start();
      await eventually(() async => await mediaC.has('p1.jpg'));
      expect(await mediaC.read('p1.jpg'), photo);

      // 都在线时 A 换了新图，C 也拿到。
      await mediaA.write('p3.jpg', [9, 9, 9]);
      final product = (await a.catalog.loadCatalog()).single;
      await a.catalog.saveProduct(
        ProductDraft(
          id: product.product.id,
          name: '徽章',
          imagePath: 'p3.jpg',
          variants: [VariantDraft(id: product.variants.single.id, price: 1500)],
        ),
      );
      await eventually(() async => await mediaC.has('p3.jpg'));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('没有团队密钥的人无法登记或连接别人的团队', () async {
    final owner = await Node.founder();
    addTearDown(owner.db.close);
    final ownerToken = await _login(api, _email('owner'));
    final keys = await CloudKeys.derive(owner.session.teamKey);
    await api.linkTeam(
      ownerToken,
      teamId: owner.session.teamId,
      teamToken: keys.teamToken,
      teamKey: owner.session.teamKey,
      name: '我的摊位',
      currency: 'CNY',
    );

    final attackerToken = await _login(api, _email('attacker'));
    final fake = await CloudKeys.derive(generateTeamKey());
    await expectLater(
      api.linkTeam(
        attackerToken,
        teamId: owner.session.teamId,
        teamToken: fake.teamToken,
        teamKey: generateTeamKey(),
        name: 'x',
        currency: 'CNY',
      ),
      throwsA(
        isA<CloudApiException>().having(
          (e) => e.code,
          'code',
          'wrong_team_key',
        ),
      ),
    );
    await expectLater(
      api.fetchTeamKey(attackerToken, owner.session.teamId),
      throwsA(
        isA<CloudApiException>().having((e) => e.code, 'code', 'not_member'),
      ),
    );
    await expectLater(
      api.getMedia(
        attackerToken,
        teamId: owner.session.teamId,
        teamToken: fake.teamToken,
        name: 'p1.jpg',
      ),
      throwsA(isA<CloudApiException>().having((e) => e.status, 'status', 403)),
    );
    await expectLater(
      WebSocket.connect(
        api.syncUri(owner.session.teamId).toString(),
        headers: {
          'Authorization': 'Bearer $attackerToken',
          'X-Team-Token': fake.teamToken,
        },
      ),
      throwsA(isA<WebSocketException>()),
    );
  }, skip: skip);

  test('加密：云端只看到来源和序号，内容解不开；换了密钥也解不开', () async {
    final keys = await CloudKeys.derive(List.filled(32, 1));
    const op = SyncOp(
      originDevice: 'dev',
      seq: 3,
      hlc: 'h',
      table: 'products',
      rowId: 'r',
      row: {'name': '徽章'},
    );
    final sealed = await keys.seal(op);
    expect(sealed['c'], isNot(contains('徽章')));
    expect((await keys.open(sealed.cast()))!.row['name'], '徽章');
    final other = await CloudKeys.derive(List.filled(32, 2));
    expect(await other.open(sealed.cast()), isNull);
    // 改了序号（想调换记录）也解不开。
    expect(await keys.open({...sealed, 's': 4}.cast()), isNull);
  });
}
