import 'dart:io';

import 'package:abacus/data/catalog_repository.dart';
import 'package:abacus/sync/media_store.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'op_store_test.dart' show Node;

/// 每台测试设备各自的图片目录。
Future<MediaStore> tempMedia() async {
  final dir = await Directory.systemTemp.createTemp('abacus-media');
  addTearDown(() => dir.delete(recursive: true));
  final store = MediaStore(dir);
  addTearDown(store.dispose);
  return store;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('只接受 App 生成的文件名，别的设备发来的路径写不出目录', () async {
    expect(
      MediaStore.isValidName('0193f0a2-7b1c-7d2e-8f3a-1b2c3d4e5f60.jpg'),
      isTrue,
    );
    for (final bad in ['../x.jpg', 'a/b.jpg', '.jpg', 'x', 'x.JPG', '']) {
      expect(MediaStore.isValidName(bad), isFalse, reason: bad);
    }
    final store = await tempMedia();
    await store.write('../escape.jpg', [1, 2, 3]);
    expect(await File('${store.dir.parent.path}/escape.jpg').exists(), isFalse);
  });

  test('缺哪些图片：只看未删除的商品和支付方式引用的文件', () async {
    final node = await Node.founder();
    addTearDown(node.db.close);
    final store = await tempMedia();
    await node.catalog.saveProduct(
      ProductDraft(
        name: '徽章',
        imagePath: 'p1.jpg',
        variants: [VariantDraft(price: 1500)],
      ),
    );
    expect(await store.missing(node.db), {'p1.jpg'});

    final arrived = store.received.first;
    await store.write('p1.jpg', [1, 2, 3]);
    expect(await arrived, 'p1.jpg');
    expect(await store.missing(node.db), isEmpty);
    expect(await store.read('p1.jpg'), [1, 2, 3]);
  });
}
