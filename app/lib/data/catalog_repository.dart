import 'package:drift/drift.dart';

import '../domain/stock.dart';
import 'database.dart';
import 'session.dart';

/// 商品类型。
abstract final class ProductKind {
  static const single = 'single';
  static const variants = 'variants';
  static const bundle = 'bundle';
}

/// 商品及其规格、作者、套装组成，供列表和收银台使用。
class CatalogProduct {
  const CatalogProduct({
    required this.product,
    required this.variants,
    this.creator,
    this.components = const {},
  });

  final Product product;
  final List<Variant> variants;
  final Creator? creator;

  /// 套装 variantId → 成分列表。
  final Map<String, List<BundleComponent>> components;

  bool get isBundle => product.kind == ProductKind.bundle;
  bool get hasVariants => product.kind == ProductKind.variants;

  /// 规格在收银台和订单上显示的名字，如“徽章 · 红”。
  String displayName(Variant v) =>
      v.label.isEmpty ? product.name : '${product.name} · ${v.label}';
}

class VariantDraft {
  VariantDraft({this.id, this.label = '', this.price = 0, this.cost = 0});

  String? id;
  String label;
  int price;
  int cost;
}

class ProductDraft {
  ProductDraft({
    this.id,
    this.name = '',
    this.kind = ProductKind.single,
    this.creatorId,
    this.tags = '',
    this.imagePath,
    List<VariantDraft>? variants,
    List<BundleComponent>? components,
  }) : variants = variants ?? [VariantDraft()],
       components = components ?? [];

  String? id;
  String name;
  String kind;
  String? creatorId;
  String tags;
  String? imagePath;
  List<VariantDraft> variants;

  /// 套装成分，仅 [ProductKind.bundle] 使用。
  List<BundleComponent> components;
}

class CatalogRepository {
  CatalogRepository(this._db, this._session);

  final AppDatabase _db;
  final Session _session;

  Stream<List<CatalogProduct>> watchCatalog() => _db.watchTables({
    _db.products,
    _db.variants,
    _db.bundleItems,
    _db.creators,
  }, () => loadCatalog());

  Future<List<CatalogProduct>> loadCatalog() async {
    final products =
        await (_db.select(_db.products)
              ..where(
                (t) =>
                    t.teamId.equals(_session.teamId) & t.deleted.equals(false),
              )
              ..orderBy([
                (t) => OrderingTerm(expression: t.sortOrder),
                (t) => OrderingTerm(expression: t.name),
              ]))
            .get();
    final variants = await (_db.select(
      _db.variants,
    )..where((t) => t.deleted.equals(false))).get();
    final bundleItems = await (_db.select(
      _db.bundleItems,
    )..where((t) => t.deleted.equals(false))).get();
    final creators = {for (final c in await watchCreators().first) c.id: c};

    final variantsByProduct = <String, List<Variant>>{};
    for (final v in variants) {
      variantsByProduct.putIfAbsent(v.productId, () => []).add(v);
    }
    final componentsByBundle = <String, List<BundleComponent>>{};
    for (final b in bundleItems) {
      componentsByBundle
          .putIfAbsent(b.bundleVariantId, () => [])
          .add(BundleComponent(b.componentVariantId, b.quantity));
    }

    return [
      for (final p in products)
        CatalogProduct(
          product: p,
          creator: creators[p.creatorId],
          variants: variantsByProduct[p.id] ?? const [],
          components: {
            for (final v in variantsByProduct[p.id] ?? const <Variant>[])
              v.id: ?componentsByBundle[v.id],
          },
        ),
    ];
  }

  Stream<List<Creator>> watchCreators() =>
      (_db.select(_db.creators)
            ..where(
              (t) => t.teamId.equals(_session.teamId) & t.deleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .watch();

  Future<String> createCreator(String name) async {
    final id = newId();
    await _db
        .into(_db.creators)
        .insert(
          CreatorsCompanion.insert(
            id: id,
            updatedAt: _session.clock.tick(),
            teamId: _session.teamId,
            name: name.trim(),
          ),
        );
    return id;
  }

  /// 新建或更新商品。规格被移除时软删除；家里库存有变化时记一条盘点流水。
  Future<String> saveProduct(ProductDraft draft) {
    return _db.transaction(() async {
      final productId = draft.id ?? newId();
      final ts = _session.clock.tick();
      await _db
          .into(_db.products)
          .insertOnConflictUpdate(
            ProductsCompanion.insert(
              id: productId,
              updatedAt: ts,
              teamId: _session.teamId,
              name: draft.name.trim(),
              kind: draft.kind,
              creatorId: Value(draft.creatorId),
              imagePath: Value(draft.imagePath),
              tags: Value(draft.tags.trim()),
            ),
          );

      final keptIds = {for (final v in draft.variants) ?v.id};
      await (_db.update(_db.variants)..where(
            (t) =>
                t.productId.equals(productId) &
                t.deleted.equals(false) &
                t.id.isNotIn(keptIds),
          ))
          .write(
            VariantsCompanion(deleted: const Value(true), updatedAt: Value(ts)),
          );

      for (final v in draft.variants) {
        final variantId = v.id ??= newId();
        await _db
            .into(_db.variants)
            .insertOnConflictUpdate(
              VariantsCompanion.insert(
                id: variantId,
                updatedAt: _session.clock.tick(),
                productId: productId,
                label: Value(v.label.trim()),
                price: v.price,
                cost: Value(v.cost),
              ),
            );
      }

      if (draft.kind == ProductKind.bundle) {
        final bundleVariantId = draft.variants.single.id!;
        await (_db.update(_db.bundleItems)..where(
              (t) =>
                  t.bundleVariantId.equals(bundleVariantId) &
                  t.deleted.equals(false),
            ))
            .write(
              BundleItemsCompanion(
                deleted: const Value(true),
                updatedAt: Value(_session.clock.tick()),
              ),
            );
        for (final c in draft.components) {
          await _db
              .into(_db.bundleItems)
              .insert(
                BundleItemsCompanion.insert(
                  id: newId(),
                  updatedAt: _session.clock.tick(),
                  bundleVariantId: bundleVariantId,
                  componentVariantId: c.variantId,
                  quantity: c.quantity,
                ),
              );
        }
      }
      return productId;
    });
  }

  /// 软删除商品及其规格。历史订单里的名称和价格是快照，不受影响。
  Future<void> deleteProduct(String productId) => _db.transaction(() async {
    final ts = _session.clock.tick();
    await (_db.update(
      _db.products,
    )..where((t) => t.id.equals(productId))).write(
      ProductsCompanion(deleted: const Value(true), updatedAt: Value(ts)),
    );
    await (_db.update(
      _db.variants,
    )..where((t) => t.productId.equals(productId))).write(
      VariantsCompanion(deleted: const Value(true), updatedAt: Value(ts)),
    );
  });
}
