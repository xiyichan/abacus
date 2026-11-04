import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// 打赏的商品 id（App Store Connect 和 Google Play 管理中心里都按这几个建“消耗型”商品）。
/// 价格以商店里设置的为准，界面上显示商店返回的本地价格。
const tipProductIds = ['tip_small', 'tip_medium', 'tip_large'];

/// 一个打赏档位。
@immutable
class TipOption {
  const TipOption({required this.id, required this.price, this.product});

  final String id;

  /// 商店返回的本地化价格，如 ¥6.00。
  final String price;

  /// 真实商店的商品（测试里为 null）。
  final ProductDetails? product;
}

enum TipOutcome { thanked, pending, cancelled, failed }

/// 应用内打赏（iOS 走 App Store，安卓走 Google Play 结算）。
abstract interface class TipStore {
  /// 能买的档位，按 [tipProductIds] 的顺序；连不上商店或没配置商品时为空。
  Future<List<TipOption>> load();

  /// 发起付款。结果从 [outcomes] 里来（付款界面是商店弹的，可能等很久）。
  Future<void> buy(TipOption option);

  Stream<TipOutcome> get outcomes;
}

class InAppPurchaseTipStore implements TipStore {
  InAppPurchaseTipStore(this._prefs);

  final SupportPrefs _prefs;
  final _iap = InAppPurchase.instance;
  final _outcomes = StreamController<TipOutcome>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<TipOption>? _cached;

  /// App 一启动就开始收付款结果：上次没处理完的交易（比如付到一半杀了 App）
  /// 商店会再推一次，要收下并结束它，不然会一直推。
  void listen() {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        debugPrint('tip purchase stream: $e');
        _outcomes.add(TipOutcome.failed);
      },
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (!tipProductIds.contains(p.productID)) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          _outcomes.add(TipOutcome.pending);
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          _prefs.markTipped();
          _outcomes.add(TipOutcome.thanked);
        case PurchaseStatus.canceled:
          _outcomes.add(TipOutcome.cancelled);
        case PurchaseStatus.error:
          debugPrint('tip purchase failed: ${p.error}');
          _outcomes.add(TipOutcome.failed);
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  @override
  Future<List<TipOption>> load() async {
    if (_cached case final cached? when cached.isNotEmpty) return cached;
    try {
      if (!await _iap.isAvailable()) return const [];
      final response = await _iap.queryProductDetails(tipProductIds.toSet());
      if (response.error != null) {
        debugPrint('tip products: ${response.error}');
      }
      final byId = {for (final p in response.productDetails) p.id: p};
      return _cached = [
        for (final id in tipProductIds)
          if (byId[id] case final p?)
            TipOption(id: id, price: p.price, product: p),
      ];
    } on Object catch (e) {
      debugPrint('tip products: $e');
      return const [];
    }
  }

  @override
  Future<void> buy(TipOption option) async {
    final product = option.product;
    if (product == null) return;
    final started = await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) _outcomes.add(TipOutcome.failed);
  }

  @override
  Stream<TipOutcome> get outcomes => _outcomes.stream;
}

/// 打赏相关的本机记录（整个 App 一份，不分团队、不同步）：打赏过没有、
/// 收摊后什么时候再提一次。存在文档目录的 support.json。
class SupportPrefs extends ChangeNotifier {
  SupportPrefs._(this._file, this._tipped, this._ended, this._nextPromptAt);

  factory SupportPrefs.load(File file) {
    try {
      if (file.existsSync()) {
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        return SupportPrefs._(
          file,
          json['tipped'] as bool? ?? false,
          json['ended'] as int? ?? 0,
          json['nextPromptAt'] as int? ?? 1,
        );
      }
    } on Object catch (e) {
      debugPrint('support.json unreadable, starting over: $e');
    }
    return SupportPrefs._(file, false, 0, 1);
  }

  /// 收摊后提过一次，再收 [snoozeEvents] 场才再提。
  static const snoozeEvents = 3;

  final File _file;
  bool _tipped;

  /// 卖出过东西的场次结束了几场。
  int _ended;

  /// 结束到第几场时提一次（第一次卖完就提）。
  int _nextPromptAt;

  bool get tipped => _tipped;

  /// 记下又收了一场摊，返回这次该不该提一句打赏。
  bool recordEventEnded() {
    _ended++;
    _save();
    return !_tipped && _ended >= _nextPromptAt;
  }

  /// 提过了：往后推几场再提，不管用户点了什么（中途杀掉 App 也不会每次都提）。
  void snoozePrompt() {
    _nextPromptAt = _ended + snoozeEvents;
    _save();
  }

  void markTipped() {
    if (_tipped) return;
    _tipped = true;
    _save();
    notifyListeners();
  }

  void _save() {
    try {
      _file.parent.createSync(recursive: true);
      final part = File('${_file.path}.part');
      part.writeAsStringSync(
        jsonEncode({
          'tipped': _tipped,
          'ended': _ended,
          'nextPromptAt': _nextPromptAt,
        }),
        flush: true,
      );
      part.renameSync(_file.path);
    } on Object catch (e) {
      debugPrint('support.json not saved: $e');
    }
  }
}
