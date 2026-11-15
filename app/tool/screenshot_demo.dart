// 商店截图用的启动入口：第一次启动时往当前团队写入一套演示数据（商品、场次、订单、支出），
// 然后照常启动 App。只在模拟器上用，不要装到真机或正式设备上。
//
//   flutter run -t tool/screenshot_demo.dart \
//     --dart-define=DEMO_IMAGES=/path/to/images --dart-define=DEMO_LANG=zh
//
// DEMO_IMAGES 目录里放 badge/stand/postcards/stickers/shikishi/keychain/book/tote.jpg。
// 想重新生成数据就先卸载 App。

import 'dart:io';
import 'dart:math';

import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/data/database.dart';
import 'package:abacus/data/expense_repository.dart';
import 'package:abacus/data/inventory_repository.dart';
import 'package:abacus/data/sales_repository.dart';
import 'package:abacus/data/session.dart';
import 'package:abacus/data/team_library.dart';
import 'package:abacus/main.dart' as app;
import 'package:abacus/sync/media_store.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _imagesDir = String.fromEnvironment('DEMO_IMAGES');
const _en = String.fromEnvironment('DEMO_LANG') == 'en';

String _t(String zh, String en) => _en ? en : zh;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final marker = File(p.join(docs.path, 'demo_seeded'));
  if (!marker.existsSync()) {
    final library = TeamLibrary.load(docs);
    final db = library.open(library.currentKey);
    // 先改团队名和货币，再重新读一次身份，订单才会记成这个货币。
    final teamId = (await ensureSession(db)).teamId;
    await (db.update(db.teams)..where((t) => t.id.equals(teamId))).write(TeamsCompanion(
      name: Value(_t('星屑工房', 'Stardust Studio')),
      currency: Value(_t('CNY', 'USD')),
    ));
    final session = await ensureSession(db);
    await _seed(db, session, MediaStore(Directory(p.join(docs.path, 'media'))));
    await db.close();
    marker.writeAsStringSync('ok');
  }
  await app.main();
}

class _Item {
  const _Item(this.zh, this.en, this.image, this.price, this.category, this.stock,
      [this.variants = const []]);
  final String zh;
  final String en;
  final String image;
  final int price;
  final int category;
  final int stock;
  final List<(String, String)> variants;
}

const _categories = [('吧唧', 'Badges'), ('立牌', 'Stands'), ('纸品', 'Paper'), ('周边', 'Goods')];

const _items = [
  _Item('猫猫吧唧 58mm', 'Cat Badge 58mm', 'badge', 1500, 0, 150,
      [('蓝', 'Blue'), ('粉', 'Pink'), ('黄', 'Yellow')]),
  _Item('星夜少女 亚克力立牌', 'Starry Night Acrylic Stand', 'stand', 4500, 1, 40),
  _Item('夏日风景 明信片套装', 'Summer Postcard Set', 'postcards', 2000, 2, 60),
  _Item('闪闪贴纸', 'Glitter Sticker Sheet', 'stickers', 1000, 2, 80),
  _Item('落日 色纸', 'Sunset Art Board', 'shikishi', 2500, 2, 30),
  _Item('兔兔亚克力挂件', 'Bunny Keychain', 'keychain', 3800, 3, 40),
  _Item('本子《午后的猫》', 'Zine: Afternoon Cat', 'book', 6000, 2, 40),
  _Item('猫猫帆布袋', 'Cat Tote Bag', 'tote', 5500, 3, 25),
];

Future<void> _seed(AppDatabase db, Session session, MediaStore media) async {
  final catalog = CatalogRepository(db, session);
  final inventory = InventoryRepository(db, session);
  final sales = SalesRepository(db, session);
  final expenses = ExpenseRepository(db, session);
  final random = Random(7);

  if (_en) {
    // 默认支付方式是现金 / 微信 / 支付宝，英文截图换成海外常见的叫法。
    const names = ['Cash', 'Card', 'QR Pay'];
    final rows = await (db.select(db.paymentMethods)..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();
    for (var i = 0; i < rows.length && i < names.length; i++) {
      await (db.update(db.paymentMethods)..where((t) => t.id.equals(rows[i].id)))
          .write(PaymentMethodsCompanion(name: Value(names[i])));
    }
  }

  final categoryIds = [
    for (final (zh, en) in _categories) await catalog.createCategory(_t(zh, en)),
  ];

  // 每件商品的各个规格：(variantId, 显示名, 单价, 备货)
  final skus = <(String, String, int, int)>[];
  for (final item in _items) {
    String? imageName;
    final source = File(p.join(_imagesDir, '${item.image}.jpg'));
    if (_imagesDir.isNotEmpty && source.existsSync()) {
      imageName = '${const Uuid().v4()}.jpg';
      await media.write(imageName, await source.readAsBytes());
    }
    final variants = item.variants.isEmpty
        ? [VariantDraft(price: item.price)]
        : [
            for (final (zh, en) in item.variants)
              VariantDraft(label: _t(zh, en), price: item.price),
          ];
    await catalog.saveProduct(ProductDraft(
      name: _t(item.zh, item.en),
      kind: item.variants.isEmpty ? ProductKind.single : ProductKind.variants,
      categoryIds: [categoryIds[item.category]],
      imagePath: imageName,
      variants: variants,
    ));
    final name = _t(item.zh, item.en);
    for (final v in variants) {
      final label = v.label.isEmpty ? name : '$name · ${v.label}';
      skus.add((v.id!, label, v.price, item.stock ~/ variants.length));
    }
  }

  final methods = await db.select(db.paymentMethods).get();
  final today = DateTime.now();
  final day = DateTime(today.year, today.month, today.day);

  // 订单时间铺开在开展的 10:00–16:30 之间（placeOrder 记的是当前时间）。
  Future<void> runEvent(String eventId, DateTime date, int orders, {required bool popular}) async {
    for (final (id, _, _, stock) in skus) {
      await inventory.setEventQuantity(variantId: id, eventId: eventId, eventQuantity: stock);
    }
    for (var i = 0; i < orders; i++) {
      final picks = <String, (String, String, int, int)>{};
      final count = 1 + random.nextInt(3);
      while (picks.length < count) {
        // 偏向前几件（吧唧、立牌、明信片卖得最好），统计页的排行更像真的。
        final index = popular
            ? min(random.nextInt(skus.length), random.nextInt(skus.length))
            : random.nextInt(skus.length);
        picks[skus[index].$1] = skus[index];
      }
      final order = await sales.placeOrder(
        eventId: eventId,
        lines: [
          for (final (id, name, price, _) in picks.values)
            SaleLine(
              variantId: id,
              name: name,
              unitPrice: price,
              quantity: random.nextInt(4) == 0 ? 2 : 1,
            ),
        ],
        paymentMethod: methods[random.nextInt(10) < 6 ? 1 : random.nextInt(methods.length)],
      );
      final at = date.add(Duration(minutes: 600 + i * 390 ~/ orders + random.nextInt(390 ~/ orders)));
      await (db.update(db.orders)..where((t) => t.id.equals(order.id)))
          .write(OrdersCompanion(createdAt: Value(at)));
    }
  }

  final summer = await inventory.createEvent(
    name: _t('夏日同人祭', 'Summer Doujin Fair'),
    startsOn: day.subtract(const Duration(days: 70)),
    endsOn: day.subtract(const Duration(days: 69)),
    booth: 'A-12',
  );
  await runEvent(summer, day.subtract(const Duration(days: 70)), 30, popular: false);
  await expenses.addExpense(
      eventId: summer, category: 'booth', amount: 30000, spentOn: day.subtract(const Duration(days: 70)));
  await inventory.endEvent(summer);

  final autumn = await inventory.createEvent(
    name: _t('秋日同人祭', 'Autumn Doujin Fair'),
    startsOn: day,
    endsOn: day.add(const Duration(days: 1)),
    booth: 'C-23',
  );
  await runEvent(autumn, day, 52, popular: true);
  await expenses.addExpense(eventId: autumn, category: 'booth', amount: 35000, spentOn: day);
  await expenses.addExpense(eventId: autumn, category: 'travel', amount: 12800, spentOn: day);
  await expenses.addExpense(eventId: autumn, category: 'supplies', amount: 6500, spentOn: day);
  await inventory.setCurrentEvent(autumn);
}
