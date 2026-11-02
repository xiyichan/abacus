import 'package:drift/drift.dart';

/// 所有可同步表的公共列：
/// - [id] 离线生成的 UUIDv7，多设备不会冲突
/// - [updatedAt] 混合逻辑时钟（HLC）字符串，同步时按它做“后写为准”
/// - [deleted] 软删除，删除也要能同步到其他设备
mixin SyncColumns on Table {
  TextColumn get id => text()();
  TextColumn get updatedAt => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 团队（一个摊位/合摊）。
class Teams extends Table with SyncColumns {
  TextColumn get name => text()();

  /// ISO 4217 币种代码，国内默认 CNY。
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
}

/// 设备。[shortCode] 是 6 位字母数字设备号，前两位用作订单号前缀，如 K7-048。
class Devices extends Table with SyncColumns {
  TextColumn get teamId => text()();
  TextColumn get name => text()();
  TextColumn get shortCode => text()();

  /// admin / cashier / picker
  TextColumn get role => text().withDefault(const Constant('cashier'))();
}

/// 作者（合摊时按作者分账）。
class Creators extends Table with SyncColumns {
  TextColumn get teamId => text()();
  TextColumn get name => text()();
}

/// 商品分类（收银台左边的分类栏），按 [sortOrder] 排。
/// 数据类不叫 Category，免得和 Flutter 的同名注解冲突。
@DataClassName('ProductCategory')
class Categories extends Table with SyncColumns {
  TextColumn get teamId => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// 商品。[kind]: single / variants / bundle
class Products extends Table with SyncColumns {
  TextColumn get teamId => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get creatorId => text().nullable()();
  TextColumn get imagePath => text().nullable()();

  /// 逗号分隔的标签，如“亚克力,徽章”。
  TextColumn get tags => text().withDefault(const Constant(''))();

  /// 所属分类的 id，逗号分隔；一个商品可以在多个分类里。
  TextColumn get categoryIds => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// 可售 SKU。单品也有且只有一个 variant；套装的 variant 通过 [BundleItems] 指向成分。
class Variants extends Table with SyncColumns {
  TextColumn get productId => text()();

  /// 规格名，单品为空字符串。
  TextColumn get label => text().withDefault(const Constant(''))();

  /// 售价、成本，单位为最小货币单位（分）。
  IntColumn get price => integer()();
  IntColumn get cost => integer().withDefault(const Constant(0))();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
}

/// 套装组成：[bundleVariantId] = [componentVariantId] × [quantity] 的组合。
class BundleItems extends Table with SyncColumns {
  TextColumn get bundleVariantId => text()();
  TextColumn get componentVariantId => text()();
  IntColumn get quantity => integer()();
}

/// 场次（一次展会）。
class Events extends Table with SyncColumns {
  TextColumn get teamId => text()();
  TextColumn get name => text()();
  DateTimeColumn get startsOn => dateTime().nullable()();

  /// 最后一天（含）。为 null 表示只有 [startsOn] 那一天。
  DateTimeColumn get endsOn => dateTime().nullable()();
  TextColumn get booth => text().nullable()();

  /// 结束（收摊）时间。结束时剩余库存退回家里；为 null 表示进行中。
  DateTimeColumn get endedAt => dateTime().nullable()();
}

/// 库存流水。库存 = 同一 SKU + 位置下所有 [delta] 之和，只追加不修改。
/// [location] 为 'home' 或场次 id；[reason]: restock / transfer / sale / refund / adjust / close
/// （close 为结束场次时退回家里的流水，[orderId] 存 `close:<场次id>` 以便重新开启时撤销）
class StockMovements extends Table with SyncColumns {
  TextColumn get variantId => text()();
  TextColumn get location => text()();
  IntColumn get delta => integer()();
  TextColumn get reason => text()();
  TextColumn get orderId => text().nullable()();
  TextColumn get deviceId => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// 支付方式。[kind]: cash / qr / card / other，不写死具体渠道，方便以后加海外方式。
class PaymentMethods extends Table with SyncColumns {
  TextColumn get teamId => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get qrImagePath => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

/// 订单，生成后不再修改（退款另记 [Refunds]）。
class Orders extends Table with SyncColumns {
  TextColumn get eventId => text()();
  TextColumn get deviceId => text()();

  /// 现场展示用单号，如 B-048。
  TextColumn get number => text()();
  TextColumn get currency => text()();
  IntColumn get subtotal => integer()();
  IntColumn get discount => integer()();
  IntColumn get total => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// 订单明细，记录下单时的名称与价格快照。
class OrderItems extends Table with SyncColumns {
  TextColumn get orderId => text()();
  TextColumn get variantId => text()();
  TextColumn get nameSnapshot => text()();
  IntColumn get unitPrice => integer()();
  IntColumn get quantity => integer()();
}

class OrderPayments extends Table with SyncColumns {
  TextColumn get orderId => text()();
  TextColumn get paymentMethodId => text()();
  TextColumn get methodNameSnapshot => text()();
  IntColumn get amount => integer()();

  /// 现金收款时客人给的金额，用于回看找零。
  IntColumn get tendered => integer().nullable()();

  /// 扫码付款时选了“稍后确认”：还没核对到这笔钱。
  BoolColumn get pending => boolean().withDefault(const Constant(false))();

  /// 事后核对、确认已收款的时间。
  DateTimeColumn get confirmedAt => dateTime().nullable()();
}

class Refunds extends Table with SyncColumns {
  TextColumn get orderId => text()();
  IntColumn get amount => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get deviceId => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// 支出（差旅、摊位费等），统计时从实收里扣掉算净收入。
/// [eventId] 为 null 表示不属于某个场次的支出。
/// [category]: travel / booth / lodging / food / supplies / shipping / other
class Expenses extends Table with SyncColumns {
  TextColumn get teamId => text()();
  TextColumn get eventId => text().nullable()();
  TextColumn get category => text()();
  IntColumn get amount => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get spentOn => dateTime()();
  TextColumn get deviceId => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// 同步用操作日志。每台设备按 [seq] 自增，(originDevice, seq) 全局唯一；
/// 同步时双方交换“每个来源设备已收到的最大 seq”（版本向量），只补缺的部分。
class OpLog extends Table {
  TextColumn get originDevice => text()();
  IntColumn get seq => integer()();
  TextColumn get hlc => text()();
  TextColumn get tableName_ => text().named('table_name')();
  TextColumn get rowId => text()();

  /// 变更后的整行 JSON。
  TextColumn get payload => text()();

  @override
  Set<Column> get primaryKey => {originDevice, seq};
}

/// 本机设置（不参与同步），如当前设备 id、当前场次。
class LocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
