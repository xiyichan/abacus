import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'摊位助手'**
  String get appTitle;

  /// No description provided for @navPos.
  ///
  /// In zh, this message translates to:
  /// **'收银'**
  String get navPos;

  /// No description provided for @navOrders.
  ///
  /// In zh, this message translates to:
  /// **'订单'**
  String get navOrders;

  /// No description provided for @navProducts.
  ///
  /// In zh, this message translates to:
  /// **'商品'**
  String get navProducts;

  /// No description provided for @navStats.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get navStats;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @comingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将推出'**
  String get comingSoon;

  /// No description provided for @offlineReady.
  ///
  /// In zh, this message translates to:
  /// **'离线可用'**
  String get offlineReady;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @required.
  ///
  /// In zh, this message translates to:
  /// **'必填'**
  String get required;

  /// No description provided for @invalidAmount.
  ///
  /// In zh, this message translates to:
  /// **'请输入正确的金额'**
  String get invalidAmount;

  /// No description provided for @invalidNumber.
  ///
  /// In zh, this message translates to:
  /// **'请输入整数'**
  String get invalidNumber;

  /// No description provided for @none.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get none;

  /// No description provided for @cart.
  ///
  /// In zh, this message translates to:
  /// **'购物车'**
  String get cart;

  /// No description provided for @cartEmpty.
  ///
  /// In zh, this message translates to:
  /// **'点商品加入购物车'**
  String get cartEmpty;

  /// No description provided for @checkout.
  ///
  /// In zh, this message translates to:
  /// **'结账'**
  String get checkout;

  /// No description provided for @clearCart.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clearCart;

  /// No description provided for @itemCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 件'**
  String itemCount(int count);

  /// No description provided for @subtotal.
  ///
  /// In zh, this message translates to:
  /// **'小计'**
  String get subtotal;

  /// No description provided for @discount.
  ///
  /// In zh, this message translates to:
  /// **'优惠'**
  String get discount;

  /// No description provided for @total.
  ///
  /// In zh, this message translates to:
  /// **'合计'**
  String get total;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @chooseEvent.
  ///
  /// In zh, this message translates to:
  /// **'选择场次'**
  String get chooseEvent;

  /// No description provided for @noEventTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有选择场次'**
  String get noEventTitle;

  /// No description provided for @noEventBody.
  ///
  /// In zh, this message translates to:
  /// **'先新建或选择一个场次，收银台只显示本场带来的货。'**
  String get noEventBody;

  /// No description provided for @noStockTitle.
  ///
  /// In zh, this message translates to:
  /// **'本场还没有备货'**
  String get noStockTitle;

  /// No description provided for @noStockBody.
  ///
  /// In zh, this message translates to:
  /// **'在「备货」里选择要带到本场的商品和数量。'**
  String get noStockBody;

  /// No description provided for @goStock.
  ///
  /// In zh, this message translates to:
  /// **'去备货'**
  String get goStock;

  /// No description provided for @stockLeft.
  ///
  /// In zh, this message translates to:
  /// **'剩 {count}'**
  String stockLeft(int count);

  /// No description provided for @chooseVariant.
  ///
  /// In zh, this message translates to:
  /// **'选择规格'**
  String get chooseVariant;

  /// No description provided for @discountTitle.
  ///
  /// In zh, this message translates to:
  /// **'整单优惠'**
  String get discountTitle;

  /// No description provided for @discountAmountOff.
  ///
  /// In zh, this message translates to:
  /// **'立减'**
  String get discountAmountOff;

  /// No description provided for @discountPercentOff.
  ///
  /// In zh, this message translates to:
  /// **'打折'**
  String get discountPercentOff;

  /// No description provided for @discountFixedTotal.
  ///
  /// In zh, this message translates to:
  /// **'一口价'**
  String get discountFixedTotal;

  /// No description provided for @discountPercentHint.
  ///
  /// In zh, this message translates to:
  /// **'优惠百分比，如 20 表示 8 折'**
  String get discountPercentHint;

  /// No description provided for @removeDiscount.
  ///
  /// In zh, this message translates to:
  /// **'取消优惠'**
  String get removeDiscount;

  /// No description provided for @paymentMethod.
  ///
  /// In zh, this message translates to:
  /// **'支付方式'**
  String get paymentMethod;

  /// No description provided for @cashTendered.
  ///
  /// In zh, this message translates to:
  /// **'实收现金'**
  String get cashTendered;

  /// No description provided for @change.
  ///
  /// In zh, this message translates to:
  /// **'找零'**
  String get change;

  /// No description provided for @notEnoughCash.
  ///
  /// In zh, this message translates to:
  /// **'实收不足'**
  String get notEnoughCash;

  /// No description provided for @exactAmount.
  ///
  /// In zh, this message translates to:
  /// **'刚好'**
  String get exactAmount;

  /// No description provided for @noQrImage.
  ///
  /// In zh, this message translates to:
  /// **'还没有上传收款码，可在「设置 › 支付方式」里上传'**
  String get noQrImage;

  /// No description provided for @confirmPayment.
  ///
  /// In zh, this message translates to:
  /// **'确认收款'**
  String get confirmPayment;

  /// No description provided for @orderSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存订单 {number}'**
  String orderSaved(String number);

  /// No description provided for @noPaymentMethods.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的支付方式，请在设置里启用'**
  String get noPaymentMethods;

  /// No description provided for @addProduct.
  ///
  /// In zh, this message translates to:
  /// **'添加商品'**
  String get addProduct;

  /// No description provided for @editProduct.
  ///
  /// In zh, this message translates to:
  /// **'编辑商品'**
  String get editProduct;

  /// No description provided for @noProducts.
  ///
  /// In zh, this message translates to:
  /// **'还没有商品，点右下角添加'**
  String get noProducts;

  /// No description provided for @productName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get productName;

  /// No description provided for @creator.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get creator;

  /// No description provided for @newCreator.
  ///
  /// In zh, this message translates to:
  /// **'新建作者…'**
  String get newCreator;

  /// No description provided for @creatorName.
  ///
  /// In zh, this message translates to:
  /// **'作者名'**
  String get creatorName;

  /// No description provided for @tags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tags;

  /// No description provided for @tagsHint.
  ///
  /// In zh, this message translates to:
  /// **'用逗号分隔，如：亚克力,徽章'**
  String get tagsHint;

  /// No description provided for @kindSingle.
  ///
  /// In zh, this message translates to:
  /// **'单品'**
  String get kindSingle;

  /// No description provided for @kindVariants.
  ///
  /// In zh, this message translates to:
  /// **'多规格'**
  String get kindVariants;

  /// No description provided for @kindBundle.
  ///
  /// In zh, this message translates to:
  /// **'套装'**
  String get kindBundle;

  /// No description provided for @price.
  ///
  /// In zh, this message translates to:
  /// **'售价'**
  String get price;

  /// No description provided for @cost.
  ///
  /// In zh, this message translates to:
  /// **'成本'**
  String get cost;

  /// No description provided for @variantLabel.
  ///
  /// In zh, this message translates to:
  /// **'规格名'**
  String get variantLabel;

  /// No description provided for @variantLabelHint.
  ///
  /// In zh, this message translates to:
  /// **'如：红色 / 角色A'**
  String get variantLabelHint;

  /// No description provided for @addVariant.
  ///
  /// In zh, this message translates to:
  /// **'添加规格'**
  String get addVariant;

  /// No description provided for @needVariant.
  ///
  /// In zh, this message translates to:
  /// **'至少需要一个规格'**
  String get needVariant;

  /// No description provided for @bundlePrice.
  ///
  /// In zh, this message translates to:
  /// **'套装价'**
  String get bundlePrice;

  /// No description provided for @bundleComponents.
  ///
  /// In zh, this message translates to:
  /// **'套装内容'**
  String get bundleComponents;

  /// No description provided for @addComponent.
  ///
  /// In zh, this message translates to:
  /// **'添加商品'**
  String get addComponent;

  /// No description provided for @needComponent.
  ///
  /// In zh, this message translates to:
  /// **'套装至少要包含一件商品'**
  String get needComponent;

  /// No description provided for @componentsValue.
  ///
  /// In zh, this message translates to:
  /// **'单买合计 {amount}'**
  String componentsValue(String amount);

  /// No description provided for @chooseImage.
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get chooseImage;

  /// No description provided for @removeImage.
  ///
  /// In zh, this message translates to:
  /// **'移除图片'**
  String get removeImage;

  /// No description provided for @deleteProductTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这个商品？'**
  String get deleteProductTitle;

  /// No description provided for @deleteProductBody.
  ///
  /// In zh, this message translates to:
  /// **'历史订单不受影响。'**
  String get deleteProductBody;

  /// No description provided for @variantCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个规格'**
  String variantCount(int count);

  /// No description provided for @bundleSummary.
  ///
  /// In zh, this message translates to:
  /// **'套装 · {count} 件'**
  String bundleSummary(int count);

  /// No description provided for @noComponentsAvailable.
  ///
  /// In zh, this message translates to:
  /// **'先添加单品或多规格商品，才能组成套装'**
  String get noComponentsAvailable;

  /// No description provided for @events.
  ///
  /// In zh, this message translates to:
  /// **'场次'**
  String get events;

  /// No description provided for @newEvent.
  ///
  /// In zh, this message translates to:
  /// **'新建场次'**
  String get newEvent;

  /// No description provided for @editEvent.
  ///
  /// In zh, this message translates to:
  /// **'编辑场次'**
  String get editEvent;

  /// No description provided for @eventName.
  ///
  /// In zh, this message translates to:
  /// **'展会名称'**
  String get eventName;

  /// No description provided for @eventNameHint.
  ///
  /// In zh, this message translates to:
  /// **'如：CP30'**
  String get eventNameHint;

  /// No description provided for @eventDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get eventDate;

  /// No description provided for @eventBooth.
  ///
  /// In zh, this message translates to:
  /// **'摊位号'**
  String get eventBooth;

  /// No description provided for @noEvents.
  ///
  /// In zh, this message translates to:
  /// **'还没有场次，点右下角新建'**
  String get noEvents;

  /// No description provided for @currentEvent.
  ///
  /// In zh, this message translates to:
  /// **'当前场次'**
  String get currentEvent;

  /// No description provided for @stockForEvent.
  ///
  /// In zh, this message translates to:
  /// **'备货'**
  String get stockForEvent;

  /// No description provided for @eventQty.
  ///
  /// In zh, this message translates to:
  /// **'本场数量'**
  String get eventQty;

  /// No description provided for @bundleAvailable.
  ///
  /// In zh, this message translates to:
  /// **'本场可售 {count} 套（按成分库存自动计算）'**
  String bundleAvailable(int count);

  /// No description provided for @noOrders.
  ///
  /// In zh, this message translates to:
  /// **'本场还没有订单'**
  String get noOrders;

  /// No description provided for @searchOrders.
  ///
  /// In zh, this message translates to:
  /// **'搜索单号'**
  String get searchOrders;

  /// No description provided for @ordersSummary.
  ///
  /// In zh, this message translates to:
  /// **'{count} 单 · 实收 {amount}'**
  String ordersSummary(int count, String amount);

  /// No description provided for @refunded.
  ///
  /// In zh, this message translates to:
  /// **'已退款'**
  String get refunded;

  /// No description provided for @refund.
  ///
  /// In zh, this message translates to:
  /// **'整单退款'**
  String get refund;

  /// No description provided for @refundTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认退款？'**
  String get refundTitle;

  /// No description provided for @refundBody.
  ///
  /// In zh, this message translates to:
  /// **'将记录退款并把商品加回本场库存。'**
  String get refundBody;

  /// No description provided for @refundReason.
  ///
  /// In zh, this message translates to:
  /// **'原因（可选）'**
  String get refundReason;

  /// No description provided for @refundDone.
  ///
  /// In zh, this message translates to:
  /// **'已退款'**
  String get refundDone;

  /// No description provided for @orderDetail.
  ///
  /// In zh, this message translates to:
  /// **'订单详情'**
  String get orderDetail;

  /// No description provided for @paymentMethods.
  ///
  /// In zh, this message translates to:
  /// **'支付方式'**
  String get paymentMethods;

  /// No description provided for @addPaymentMethod.
  ///
  /// In zh, this message translates to:
  /// **'添加支付方式'**
  String get addPaymentMethod;

  /// No description provided for @editPaymentMethod.
  ///
  /// In zh, this message translates to:
  /// **'编辑支付方式'**
  String get editPaymentMethod;

  /// No description provided for @paymentName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get paymentName;

  /// No description provided for @paymentKindCash.
  ///
  /// In zh, this message translates to:
  /// **'现金'**
  String get paymentKindCash;

  /// No description provided for @paymentKindQr.
  ///
  /// In zh, this message translates to:
  /// **'收款码'**
  String get paymentKindQr;

  /// No description provided for @paymentKindCard.
  ///
  /// In zh, this message translates to:
  /// **'刷卡'**
  String get paymentKindCard;

  /// No description provided for @paymentKindOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get paymentKindOther;

  /// No description provided for @uploadQr.
  ///
  /// In zh, this message translates to:
  /// **'上传收款码'**
  String get uploadQr;

  /// No description provided for @enabled.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enabled;

  /// No description provided for @thisDevice.
  ///
  /// In zh, this message translates to:
  /// **'本机设备'**
  String get thisDevice;

  /// No description provided for @deviceCode.
  ///
  /// In zh, this message translates to:
  /// **'设备号 {code} · 单号前缀 {prefix}'**
  String deviceCode(String code, String prefix);

  /// No description provided for @priceFrom.
  ///
  /// In zh, this message translates to:
  /// **'{price}起'**
  String priceFrom(String price);

  /// No description provided for @teamAndDevices.
  ///
  /// In zh, this message translates to:
  /// **'团队与设备'**
  String get teamAndDevices;

  /// No description provided for @teamName.
  ///
  /// In zh, this message translates to:
  /// **'团队名称'**
  String get teamName;

  /// No description provided for @devicesInTeam.
  ///
  /// In zh, this message translates to:
  /// **'团队里的设备'**
  String get devicesInTeam;

  /// No description provided for @thisDeviceTag.
  ///
  /// In zh, this message translates to:
  /// **'本机'**
  String get thisDeviceTag;

  /// No description provided for @online.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get offline;

  /// No description provided for @inviteDevice.
  ///
  /// In zh, this message translates to:
  /// **'邀请新设备'**
  String get inviteDevice;

  /// No description provided for @inviteTitle.
  ///
  /// In zh, this message translates to:
  /// **'邀请新设备'**
  String get inviteTitle;

  /// No description provided for @inviteBody.
  ///
  /// In zh, this message translates to:
  /// **'在新设备上打开 App，进入「设置 › 团队与设备 › 加入团队」，扫描这个二维码。新设备的订单号前缀将是 {code}。'**
  String inviteBody(String code);

  /// No description provided for @copyInviteCode.
  ///
  /// In zh, this message translates to:
  /// **'复制邀请码'**
  String get copyInviteCode;

  /// No description provided for @inviteCopied.
  ///
  /// In zh, this message translates to:
  /// **'邀请码已复制'**
  String get inviteCopied;

  /// No description provided for @inviteWarning.
  ///
  /// In zh, this message translates to:
  /// **'二维码里包含团队密钥，只给自己团队的设备扫。'**
  String get inviteWarning;

  /// No description provided for @joinTeam.
  ///
  /// In zh, this message translates to:
  /// **'加入团队'**
  String get joinTeam;

  /// No description provided for @joinTeamHint.
  ///
  /// In zh, this message translates to:
  /// **'扫描团队里任意一台设备上的邀请二维码，或粘贴邀请码。'**
  String get joinTeamHint;

  /// No description provided for @pasteInvite.
  ///
  /// In zh, this message translates to:
  /// **'邀请码'**
  String get pasteInvite;

  /// No description provided for @invalidInvite.
  ///
  /// In zh, this message translates to:
  /// **'邀请码无效'**
  String get invalidInvite;

  /// No description provided for @joinConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'加入「{team}」？'**
  String joinConfirmTitle(String team);

  /// No description provided for @joinConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'本机现有的商品、场次和订单都会被清空，然后从团队里的其他设备同步数据。'**
  String get joinConfirmBody;

  /// No description provided for @join.
  ///
  /// In zh, this message translates to:
  /// **'加入'**
  String get join;

  /// No description provided for @cameraUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法使用相机，请粘贴邀请码'**
  String get cameraUnavailable;

  /// No description provided for @syncConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接 {count} 台'**
  String syncConnected(int count);

  /// No description provided for @syncAlone.
  ///
  /// In zh, this message translates to:
  /// **'单机'**
  String get syncAlone;

  /// No description provided for @syncHelp.
  ///
  /// In zh, this message translates to:
  /// **'同一团队的设备连在同一个 Wi-Fi 或手机热点下会自动互相同步，不需要外网。'**
  String get syncHelp;

  /// No description provided for @syncError.
  ///
  /// In zh, this message translates to:
  /// **'同步服务启动失败：{error}'**
  String syncError(String error);

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'改名'**
  String get rename;

  /// No description provided for @deviceName.
  ///
  /// In zh, this message translates to:
  /// **'设备名称'**
  String get deviceName;

  /// No description provided for @topSellers.
  ///
  /// In zh, this message translates to:
  /// **'热销榜'**
  String get topSellers;

  /// No description provided for @byCreator.
  ///
  /// In zh, this message translates to:
  /// **'按作者分账'**
  String get byCreator;

  /// No description provided for @byPayment.
  ///
  /// In zh, this message translates to:
  /// **'按支付方式'**
  String get byPayment;

  /// No description provided for @noCreator.
  ///
  /// In zh, this message translates to:
  /// **'未设置作者'**
  String get noCreator;

  /// No description provided for @revenue.
  ///
  /// In zh, this message translates to:
  /// **'实收'**
  String get revenue;

  /// No description provided for @orders.
  ///
  /// In zh, this message translates to:
  /// **'订单'**
  String get orders;

  /// No description provided for @itemsSold.
  ///
  /// In zh, this message translates to:
  /// **'售出件数'**
  String get itemsSold;

  /// No description provided for @averageOrder.
  ///
  /// In zh, this message translates to:
  /// **'客单价'**
  String get averageOrder;

  /// No description provided for @discountTotal.
  ///
  /// In zh, this message translates to:
  /// **'优惠合计'**
  String get discountTotal;

  /// No description provided for @refunds.
  ///
  /// In zh, this message translates to:
  /// **'退款'**
  String get refunds;

  /// No description provided for @orderCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 单'**
  String orderCount(int count);

  /// No description provided for @exportCsv.
  ///
  /// In zh, this message translates to:
  /// **'导出订单 CSV'**
  String get exportCsv;

  /// No description provided for @cloudBackup.
  ///
  /// In zh, this message translates to:
  /// **'云端备份'**
  String get cloudBackup;

  /// No description provided for @cloudSignedOutHint.
  ///
  /// In zh, this message translates to:
  /// **'用邮箱登录后自动备份到云端，换手机也能找回数据；不在一起的设备也能互相同步。'**
  String get cloudSignedOutHint;

  /// No description provided for @signInWithEmail.
  ///
  /// In zh, this message translates to:
  /// **'用邮箱登录'**
  String get signInWithEmail;

  /// No description provided for @signOut.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get signOut;

  /// No description provided for @signOutTitle.
  ///
  /// In zh, this message translates to:
  /// **'退出云端登录？'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In zh, this message translates to:
  /// **'本机数据不会删除，只是不再备份到云端。'**
  String get signOutBody;

  /// No description provided for @cloudConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接云端…'**
  String get cloudConnecting;

  /// No description provided for @cloudConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接，实时备份中'**
  String get cloudConnected;

  /// No description provided for @cloudOffline.
  ///
  /// In zh, this message translates to:
  /// **'暂时连不上云端，有网后自动同步'**
  String get cloudOffline;

  /// No description provided for @lastSync.
  ///
  /// In zh, this message translates to:
  /// **'上次同步 {time}'**
  String lastSync(String time);

  /// No description provided for @neverSynced.
  ///
  /// In zh, this message translates to:
  /// **'还没有同步过'**
  String get neverSynced;

  /// No description provided for @email.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get email;

  /// No description provided for @sendCode.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get sendCode;

  /// No description provided for @verificationCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get verificationCode;

  /// No description provided for @codeSentTo.
  ///
  /// In zh, this message translates to:
  /// **'验证码已发送到 {email}，10 分钟内有效'**
  String codeSentTo(String email);

  /// No description provided for @devCodeHint.
  ///
  /// In zh, this message translates to:
  /// **'开发模式：验证码已自动填好'**
  String get devCodeHint;

  /// No description provided for @signIn.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get signIn;

  /// No description provided for @resendCode.
  ///
  /// In zh, this message translates to:
  /// **'重新发送'**
  String get resendCode;

  /// No description provided for @cloudSignedIn.
  ///
  /// In zh, this message translates to:
  /// **'已开启云端备份'**
  String get cloudSignedIn;

  /// No description provided for @restoreFromCloud.
  ///
  /// In zh, this message translates to:
  /// **'用邮箱从云端恢复'**
  String get restoreFromCloud;

  /// No description provided for @restoreHint.
  ///
  /// In zh, this message translates to:
  /// **'登录后选择要恢复的团队，所有商品、场次和订单会下载到本机。'**
  String get restoreHint;

  /// No description provided for @chooseTeamToRestore.
  ///
  /// In zh, this message translates to:
  /// **'选择要恢复的团队'**
  String get chooseTeamToRestore;

  /// No description provided for @noCloudTeams.
  ///
  /// In zh, this message translates to:
  /// **'这个邮箱下还没有备份过的团队'**
  String get noCloudTeams;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复「{team}」？'**
  String restoreConfirmTitle(String team);

  /// No description provided for @restoreConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'本机现有的数据会被清空，然后从云端下载这个团队的全部数据。'**
  String get restoreConfirmBody;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restore;

  /// No description provided for @restoring.
  ///
  /// In zh, this message translates to:
  /// **'正在从云端下载…'**
  String get restoring;

  /// No description provided for @errInvalidEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱格式不对'**
  String get errInvalidEmail;

  /// No description provided for @errTooSoon.
  ///
  /// In zh, this message translates to:
  /// **'发送太频繁，请 1 分钟后再试'**
  String get errTooSoon;

  /// No description provided for @errTooManyToday.
  ///
  /// In zh, this message translates to:
  /// **'今天发送次数太多，请明天再试'**
  String get errTooManyToday;

  /// No description provided for @errWrongCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码不对'**
  String get errWrongCode;

  /// No description provided for @errCodeExpired.
  ///
  /// In zh, this message translates to:
  /// **'验证码已过期，请重新发送'**
  String get errCodeExpired;

  /// No description provided for @errTooManyAttempts.
  ///
  /// In zh, this message translates to:
  /// **'输错次数太多，请重新发送验证码'**
  String get errTooManyAttempts;

  /// No description provided for @errNetwork.
  ///
  /// In zh, this message translates to:
  /// **'连不上云端，请检查网络'**
  String get errNetwork;

  /// No description provided for @errGeneric.
  ///
  /// In zh, this message translates to:
  /// **'出错了：{code}'**
  String errGeneric(String code);

  /// No description provided for @endEvent.
  ///
  /// In zh, this message translates to:
  /// **'结束场次'**
  String get endEvent;

  /// No description provided for @reopenEvent.
  ///
  /// In zh, this message translates to:
  /// **'重新开启'**
  String get reopenEvent;

  /// No description provided for @eventEnded.
  ///
  /// In zh, this message translates to:
  /// **'已结束'**
  String get eventEnded;

  /// No description provided for @endEventTitle.
  ///
  /// In zh, this message translates to:
  /// **'结束「{name}」？'**
  String endEventTitle(String name);

  /// No description provided for @endEventSales.
  ///
  /// In zh, this message translates to:
  /// **'本场 {count} 单 · 实收 {amount}'**
  String endEventSales(int count, String amount);

  /// No description provided for @endEventReturn.
  ///
  /// In zh, this message translates to:
  /// **'本场剩余 {count} 件：'**
  String endEventReturn(int count);

  /// No description provided for @endEventNothing.
  ///
  /// In zh, this message translates to:
  /// **'本场没有剩余的货。'**
  String get endEventNothing;

  /// No description provided for @endEventOversold.
  ///
  /// In zh, this message translates to:
  /// **'{name} 卖超 {count} 件'**
  String endEventOversold(String name, int count);

  /// No description provided for @endEventMore.
  ///
  /// In zh, this message translates to:
  /// **'等共 {count} 种'**
  String endEventMore(int count);

  /// No description provided for @endEventHint.
  ///
  /// In zh, this message translates to:
  /// **'结束后收银台不再显示这个场次，订单和统计照常保留；点错了可以重新开启。'**
  String get endEventHint;

  /// No description provided for @eventEndedDone.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」已结束，剩余 {count} 件'**
  String eventEndedDone(String name, int count);

  /// No description provided for @reopenEventTitle.
  ///
  /// In zh, this message translates to:
  /// **'重新开启「{name}」？'**
  String reopenEventTitle(String name);

  /// No description provided for @reopenEventBody.
  ///
  /// In zh, this message translates to:
  /// **'重新开启后可以继续在这个场次收银。'**
  String get reopenEventBody;

  /// No description provided for @eventEndedTitle.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」已结束'**
  String eventEndedTitle(String name);

  /// No description provided for @eventEndedBody.
  ///
  /// In zh, this message translates to:
  /// **'选择另一个场次继续收银，或重新开启这个场次。'**
  String get eventEndedBody;

  /// No description provided for @endPromptTitle.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」的日期已经过了，结束了吗？'**
  String endPromptTitle(String name);

  /// No description provided for @endPromptBody.
  ///
  /// In zh, this message translates to:
  /// **'结束后收银台不再显示这个场次，剩余数量会保留，下一场备货时可以沿用。'**
  String get endPromptBody;

  /// No description provided for @notYet.
  ///
  /// In zh, this message translates to:
  /// **'还没结束'**
  String get notYet;

  /// No description provided for @endPreviousTitle.
  ///
  /// In zh, this message translates to:
  /// **'上一场「{name}」还没结束'**
  String endPreviousTitle(String name);

  /// No description provided for @endPreviousBody.
  ///
  /// In zh, this message translates to:
  /// **'还剩 {count} 件，要先结束它吗？剩余数量会保留，新场次备货时可以沿用。'**
  String endPreviousBody(int count);

  /// No description provided for @endPreviousConfirm.
  ///
  /// In zh, this message translates to:
  /// **'结束「{name}」'**
  String endPreviousConfirm(String name);

  /// No description provided for @later.
  ///
  /// In zh, this message translates to:
  /// **'先不'**
  String get later;

  /// No description provided for @paymentRemarkHint.
  ///
  /// In zh, this message translates to:
  /// **'请客人付款时在备注里填写'**
  String get paymentRemarkHint;

  /// No description provided for @paymentReceived.
  ///
  /// In zh, this message translates to:
  /// **'已收到付款'**
  String get paymentReceived;

  /// No description provided for @confirmLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后确认收款'**
  String get confirmLater;

  /// No description provided for @orderSavedPending.
  ///
  /// In zh, this message translates to:
  /// **'已保存订单 {number}，待确认收款'**
  String orderSavedPending(String number);

  /// No description provided for @pendingPayment.
  ///
  /// In zh, this message translates to:
  /// **'待确认收款'**
  String get pendingPayment;

  /// No description provided for @filterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterAll;

  /// No description provided for @filterPending.
  ///
  /// In zh, this message translates to:
  /// **'待确认收款'**
  String get filterPending;

  /// No description provided for @confirmReceived.
  ///
  /// In zh, this message translates to:
  /// **'确认已收款'**
  String get confirmReceived;

  /// No description provided for @paymentCode.
  ///
  /// In zh, this message translates to:
  /// **'付款备注码'**
  String get paymentCode;

  /// No description provided for @paymentConfirmedAt.
  ///
  /// In zh, this message translates to:
  /// **'{time} 确认收款'**
  String paymentConfirmedAt(String time);

  /// No description provided for @paymentPendingBody.
  ///
  /// In zh, this message translates to:
  /// **'核对到客人备注 {code} 的付款后，点下面的按钮。'**
  String paymentPendingBody(String code);

  /// No description provided for @ordersPendingSummary.
  ///
  /// In zh, this message translates to:
  /// **'待确认 {count} 单 · {amount}'**
  String ordersPendingSummary(int count, String amount);

  /// No description provided for @paymentConfirmedDone.
  ///
  /// In zh, this message translates to:
  /// **'已确认收款'**
  String get paymentConfirmedDone;

  /// No description provided for @searchOrdersHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索单号或付款备注码'**
  String get searchOrdersHint;

  /// No description provided for @allEvents.
  ///
  /// In zh, this message translates to:
  /// **'全部场次'**
  String get allEvents;

  /// No description provided for @eventComparison.
  ///
  /// In zh, this message translates to:
  /// **'各场对比'**
  String get eventComparison;

  /// No description provided for @comparisonOrders.
  ///
  /// In zh, this message translates to:
  /// **'{count} 单'**
  String comparisonOrders(int count);

  /// No description provided for @noEventDate.
  ///
  /// In zh, this message translates to:
  /// **'未设日期'**
  String get noEventDate;

  /// No description provided for @useLeftover.
  ///
  /// In zh, this message translates to:
  /// **'沿用上一场剩余'**
  String get useLeftover;

  /// No description provided for @useLeftoverBody.
  ///
  /// In zh, this message translates to:
  /// **'把「{name}」剩下的 {count} 件设为本场数量？'**
  String useLeftoverBody(String name, int count);

  /// No description provided for @noLeftover.
  ///
  /// In zh, this message translates to:
  /// **'之前的场次没有剩余的货'**
  String get noLeftover;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
