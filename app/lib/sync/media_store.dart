import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../data/database.dart';

/// 商品图片、收款码图片的本机文件。
///
/// 数据库里只存文件名，同步记录也只带文件名；文件本身另外传：
/// 局域网里设备之间直接互传，云端则加密后存一份。文件名是 UUID，内容不会变，
/// 所以“有没有”只看文件名。
class MediaStore {
  MediaStore(this.dir);

  final Directory dir;
  final _received = StreamController<String>.broadcast();

  /// 单张图片的上限（选图时已经压缩过，正常远小于这个）。
  static const maxBytes = 8 * 1024 * 1024;

  /// 只接受本 App 生成的文件名（UUID + 扩展名），别的设备发来的名字也要先过这一关。
  static final _validName = RegExp(r'^[0-9A-Za-z-]{1,64}\.[a-z0-9]{1,5}$');

  static bool isValidName(String name) => _validName.hasMatch(name);

  /// 从别的设备或云端新收到的文件名（界面据此刷新图片）。
  Stream<String> get received => _received.stream;

  File file(String name) => File(p.join(dir.path, name));

  Future<bool> has(String name) async =>
      isValidName(name) && await file(name).exists();

  Future<Uint8List?> read(String name) async {
    if (!await has(name)) return null;
    final bytes = await file(name).readAsBytes();
    return bytes.length > maxBytes ? null : bytes;
  }

  /// 保存收到的文件：先写临时文件再改名，避免显示到写了一半的图片。
  Future<void> write(String name, List<int> bytes) async {
    if (!isValidName(name) || bytes.isEmpty || bytes.length > maxBytes) return;
    if (await has(name)) return;
    await dir.create(recursive: true);
    final part = File(p.join(dir.path, '$name.part'));
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(file(name).path);
    if (!_received.isClosed) _received.add(name);
  }

  /// 数据库里引用了、本机却没有的文件。
  Future<Set<String>> missing(AppDatabase db) async => {
    for (final name in await referencedMedia(db))
      if (!await has(name)) name,
  };

  Future<void> dispose() => _received.close();
}

/// 会引用图片的表：它们有变化时要重新看看缺哪些图片。
Set<TableInfo> mediaTables(AppDatabase db) => {db.products, db.paymentMethods};

/// 本团队（未删除的）商品和支付方式引用到的全部图片文件名。
Future<Set<String>> referencedMedia(AppDatabase db) async {
  final products = await (db.selectOnly(db.products)
        ..addColumns([db.products.imagePath])
        ..where(
          db.products.deleted.equals(false) & db.products.imagePath.isNotNull(),
        ))
      .map((r) => r.read(db.products.imagePath)!)
      .get();
  final methods = await (db.selectOnly(db.paymentMethods)
        ..addColumns([db.paymentMethods.qrImagePath])
        ..where(
          db.paymentMethods.deleted.equals(false) &
              db.paymentMethods.qrImagePath.isNotNull(),
        ))
      .map((r) => r.read(db.paymentMethods.qrImagePath)!)
      .get();
  return {...products, ...methods}.where(MediaStore.isValidName).toSet();
}
