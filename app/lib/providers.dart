import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/expense_repository.dart';
import 'data/catalog_repository.dart';
import 'data/database.dart';
import 'data/inventory_repository.dart';
import 'data/sales_repository.dart';
import 'data/session.dart';
import 'data/team_library.dart';
import 'data/team_repository.dart';
import 'sync/cloud_api.dart';
import 'sync/cloud_sync_service.dart';
import 'sync/lan_sync_service.dart';
import 'sync/media_store.dart';

/// 以下三个在 main() 启动时初始化后通过 overrides 注入（测试里同样注入）。
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('override in main()'),
);
final sessionProvider = Provider<Session>(
  (ref) => throw UnimplementedError('override in main()'),
);

/// 存放商品图片、收款码图片的目录。数据库里只存文件名，因为 iOS 每次安装路径会变。
final mediaDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('override in main()'),
);

/// 图片文件，局域网和云端同步都通过它收发。
final mediaStoreProvider = Provider((ref) {
  final store = MediaStore(ref.watch(mediaDirProvider));
  ref.onDispose(store.dispose);
  return store;
});

final catalogRepositoryProvider = Provider(
  (ref) => CatalogRepository(
    ref.watch(databaseProvider),
    ref.watch(sessionProvider),
  ),
);
final inventoryRepositoryProvider = Provider(
  (ref) => InventoryRepository(
    ref.watch(databaseProvider),
    ref.watch(sessionProvider),
  ),
);
final expenseRepositoryProvider = Provider(
  (ref) => ExpenseRepository(
    ref.watch(databaseProvider),
    ref.watch(sessionProvider),
  ),
);

/// key 为 null 时是全部支出。
final expensesProvider = StreamProvider.family<List<Expense>, String?>(
  (ref, eventId) => ref.watch(expenseRepositoryProvider).watchExpenses(eventId),
);

final salesRepositoryProvider = Provider(
  (ref) =>
      SalesRepository(ref.watch(databaseProvider), ref.watch(sessionProvider)),
);

final catalogProvider = StreamProvider(
  (ref) => ref.watch(catalogRepositoryProvider).watchCatalog(),
);
final categoriesProvider = StreamProvider(
  (ref) => ref.watch(catalogRepositoryProvider).watchCategories(),
);
final creatorsProvider = StreamProvider(
  (ref) => ref.watch(catalogRepositoryProvider).watchCreators(),
);
final eventsProvider = StreamProvider(
  (ref) => ref.watch(inventoryRepositoryProvider).watchEvents(),
);
final currentEventIdProvider = StreamProvider(
  (ref) => ref.watch(inventoryRepositoryProvider).watchCurrentEventId(),
);

/// 当前场次；没选或已删除时为 null。
final currentEventProvider = Provider<AsyncValue<Event?>>((ref) {
  final id = ref.watch(currentEventIdProvider);
  final events = ref.watch(eventsProvider);
  return switch ((id, events)) {
    (AsyncData(value: final id), AsyncData(value: final events)) => AsyncData(
      events.where((e) => e.id == id).firstOrNull,
    ),
    (AsyncError(:final error, :final stackTrace), _) ||
    (
      _,
      AsyncError(:final error, :final stackTrace),
    ) => AsyncError(error, stackTrace),
    _ => const AsyncLoading(),
  };
});

/// 某位置（'home' 或场次 id）的库存。
final stockProvider = StreamProvider.family<Map<String, int>, String>(
  (ref, location) =>
      ref.watch(inventoryRepositoryProvider).watchStock(location),
);

final paymentMethodsProvider = StreamProvider(
  (ref) => ref.watch(salesRepositoryProvider).watchPaymentMethods(),
);
final enabledPaymentMethodsProvider = StreamProvider(
  (ref) =>
      ref.watch(salesRepositoryProvider).watchPaymentMethods(enabledOnly: true),
);

final ordersProvider = StreamProvider.family<List<OrderSummary>, String>(
  (ref, eventId) => ref.watch(salesRepositoryProvider).watchOrders(eventId),
);
final orderDetailProvider = StreamProvider.family<OrderDetail, String>(
  (ref, orderId) =>
      ref.watch(salesRepositoryProvider).watchOrderDetail(orderId),
);

final teamRepositoryProvider = Provider(
  (ref) =>
      TeamRepository(ref.watch(databaseProvider), ref.watch(sessionProvider)),
);
final teamProvider = StreamProvider(
  (ref) => ref.watch(teamRepositoryProvider).watchTeam(),
);
final devicesProvider = StreamProvider(
  (ref) => ref.watch(teamRepositoryProvider).watchDevices(),
);

/// 局域网同步服务。随 ProviderScope 创建和销毁（加入新团队后会整体重建）。
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = LanSyncService(
    ref.watch(databaseProvider),
    ref.watch(sessionProvider),
    media: ref.watch(mediaStoreProvider),
  );
  unawaited(service.start());
  ref.onDispose(service.dispose);
  return service;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final service = ref.watch(syncServiceProvider);
  yield service.current;
  yield* service.status;
});

/// 切换团队。在 AppRoot 里注入；没有时（测试）界面不显示切换入口。
abstract interface class TeamSwitcher {
  TeamLibrary get library;

  /// 换成本机的另一个团队（[TeamLibrary] 里的 key）。
  Future<void> switchTo(String key);

  /// 在本机新增一个团队：新建一个数据库，用 [setup] 写入数据（新建、扫码加入、
  /// 从云端下载），然后切换过去。[setup] 失败时删掉这个数据库，当前团队不受影响。
  Future<void> add(Future<void> Function(AppDatabase db) setup);

  /// 换团队期间盖一层全屏的“正在切换…”（[message]），等新团队打开后才撤掉；
  /// [task] 失败时撤掉并把错误抛给调用方。
  Future<void> busy(String message, Future<void> Function() task);
}

final teamSwitcherProvider = Provider<TeamSwitcher?>((ref) => null);

/// 重新加载会话并重建整个界面。在 main() 里注入。
final restartAppProvider = Provider<VoidCallback>(
  (ref) => throw UnimplementedError('override in main()'),
);

final cloudApiProvider = Provider((ref) => CloudApi());

/// 云端同步。没登录时只读本机设置，不连网。
final cloudSyncProvider = Provider<CloudSyncService>((ref) {
  final service = CloudSyncService(
    ref.watch(databaseProvider),
    ref.watch(sessionProvider),
    ref.watch(cloudApiProvider),
    media: ref.watch(mediaStoreProvider),
    onAccountChanged: ref.watch(teamSwitcherProvider)?.library.setAccount,
  );
  unawaited(service.start());
  ref.onDispose(service.dispose);
  return service;
});

final cloudStatusProvider = StreamProvider<CloudStatus>((ref) async* {
  final service = ref.watch(cloudSyncProvider);
  yield service.current;
  yield* service.status;
});

/// 当前场次里待确认收款的订单数（订单导航上的角标）。
final pendingPaymentCountProvider = Provider<int>((ref) {
  final eventId = ref.watch(currentEventIdProvider).value;
  if (eventId == null) return 0;
  final orders = ref.watch(ordersProvider(eventId)).value ?? const [];
  return orders.where((o) => o.paymentPending && !o.isRefunded).length;
});
