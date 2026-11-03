// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '小算盘';

  @override
  String get navPos => '收银';

  @override
  String get navOrders => '订单';

  @override
  String get navProducts => '商品';

  @override
  String get navStats => '统计';

  @override
  String get navSettings => '设置';

  @override
  String get comingSoon => '即将推出';

  @override
  String get offlineReady => '离线可用';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get confirm => '确定';

  @override
  String get add => '添加';

  @override
  String get required => '必填';

  @override
  String get invalidAmount => '请输入正确的金额';

  @override
  String get invalidNumber => '请输入整数';

  @override
  String get none => '无';

  @override
  String get cart => '购物车';

  @override
  String get cartEmpty => '点左边的商品加入购物车';

  @override
  String get checkout => '结账';

  @override
  String get clearCart => '清空';

  @override
  String itemCount(int count) {
    return '$count 件';
  }

  @override
  String get subtotal => '小计';

  @override
  String get discount => '优惠';

  @override
  String get total => '合计';

  @override
  String get all => '全部';

  @override
  String get chooseEvent => '选择场次';

  @override
  String get noEventTitle => '还没有选择场次';

  @override
  String get noEventBody => '先新建或选择一个场次，收银台只显示本场带来的货。';

  @override
  String get noStockTitle => '本场还没有备货';

  @override
  String get noStockBody => '在「备货」里选择要带到本场的商品和数量。';

  @override
  String get goStock => '去备货';

  @override
  String stockLeft(int count) {
    return '剩 $count';
  }

  @override
  String get chooseVariant => '选择规格';

  @override
  String get discountTitle => '整单优惠';

  @override
  String get discountAmountOff => '立减';

  @override
  String get discountPercentOff => '打折';

  @override
  String get discountFixedTotal => '一口价';

  @override
  String get discountPercentHint => '优惠百分比，如 20 表示 8 折';

  @override
  String get removeDiscount => '取消优惠';

  @override
  String get paymentMethod => '支付方式';

  @override
  String get cashTendered => '实收现金';

  @override
  String get change => '找零';

  @override
  String get notEnoughCash => '实收不足';

  @override
  String get exactAmount => '刚好';

  @override
  String get noQrImage => '还没有上传收款码，可在「设置 › 支付方式」里上传';

  @override
  String get confirmPayment => '确认收款';

  @override
  String orderSaved(String number) {
    return '已保存订单 $number';
  }

  @override
  String get noPaymentMethods => '没有可用的支付方式，请在设置里启用';

  @override
  String get addProduct => '添加商品';

  @override
  String get editProduct => '编辑商品';

  @override
  String get noProducts => '还没有商品';

  @override
  String get productName => '名称';

  @override
  String get creator => '作者';

  @override
  String get newCreator => '新建作者…';

  @override
  String get creatorName => '作者名';

  @override
  String get tags => '标签';

  @override
  String get tagsHint => '用逗号分隔，如：亚克力,徽章';

  @override
  String get kindSingle => '单品';

  @override
  String get kindVariants => '多规格';

  @override
  String get kindBundle => '套装';

  @override
  String get price => '售价';

  @override
  String get cost => '成本';

  @override
  String get variantLabel => '规格名';

  @override
  String get variantLabelHint => '如：红色 / 角色A';

  @override
  String get addVariant => '添加规格';

  @override
  String get needVariant => '至少需要一个规格';

  @override
  String get bundlePrice => '套装价';

  @override
  String get bundleComponents => '套装内容';

  @override
  String get addComponent => '添加商品';

  @override
  String get needComponent => '套装至少要包含一件商品';

  @override
  String componentsValue(String amount) {
    return '单买合计 $amount';
  }

  @override
  String get chooseImage => '选择图片';

  @override
  String get removeImage => '移除图片';

  @override
  String get deleteProductTitle => '删除这个商品？';

  @override
  String get deleteProductBody => '历史订单不受影响。';

  @override
  String variantCount(int count) {
    return '$count 个规格';
  }

  @override
  String bundleSummary(int count) {
    return '套装 · $count 件';
  }

  @override
  String get noComponentsAvailable => '先添加单品或多规格商品，才能组成套装';

  @override
  String get events => '场次';

  @override
  String get newEvent => '新建场次';

  @override
  String get editEvent => '编辑场次';

  @override
  String get eventName => '展会名称';

  @override
  String get eventNameHint => '如：CP30';

  @override
  String get eventDate => '日期';

  @override
  String get eventDateHint => '多天的展可以选一个日期范围';

  @override
  String get eventBooth => '摊位号';

  @override
  String get noEvents => '还没有场次，点右下角新建';

  @override
  String get currentEvent => '当前场次';

  @override
  String get stockForEvent => '备货';

  @override
  String get eventQty => '本场数量';

  @override
  String bundleAvailable(int count) {
    return '本场可售 $count 套（按成分库存自动计算）';
  }

  @override
  String get noOrders => '本场还没有订单';

  @override
  String get searchOrders => '搜索单号';

  @override
  String ordersSummary(int count, String amount) {
    return '$count 单 · 实收 $amount';
  }

  @override
  String get refunded => '已退款';

  @override
  String get refund => '整单退款';

  @override
  String get refundTitle => '确认退款？';

  @override
  String get refundBody => '将记录退款并把商品加回本场库存。';

  @override
  String get refundReason => '原因（可选）';

  @override
  String get refundDone => '已退款';

  @override
  String get orderDetail => '订单详情';

  @override
  String get paymentMethods => '支付方式';

  @override
  String get addPaymentMethod => '添加支付方式';

  @override
  String get editPaymentMethod => '编辑支付方式';

  @override
  String get paymentName => '名称';

  @override
  String get paymentKindCash => '现金';

  @override
  String get paymentKindQr => '收款码';

  @override
  String get paymentKindCard => '刷卡';

  @override
  String get paymentKindOther => '其他';

  @override
  String get uploadQr => '上传收款码';

  @override
  String get enabled => '启用';

  @override
  String get thisDevice => '本机设备';

  @override
  String deviceCode(String code, String prefix) {
    return '设备号 $code · 单号前缀 $prefix';
  }

  @override
  String priceFrom(String price) {
    return '$price起';
  }

  @override
  String get teamAndDevices => '团队与设备';

  @override
  String get teamName => '团队名称';

  @override
  String get devicesInTeam => '团队里的设备';

  @override
  String get thisDeviceTag => '本机';

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String get inviteDevice => '邀请新设备';

  @override
  String get inviteTitle => '邀请新设备';

  @override
  String inviteBody(String code) {
    return '在新设备上打开 App，进入「设置 › 团队与设备 › 加入团队」，扫描这个二维码。新设备的订单号前缀将是 $code。';
  }

  @override
  String get copyInviteCode => '复制邀请码';

  @override
  String get inviteCopied => '邀请码已复制';

  @override
  String get inviteWarning => '二维码里包含团队密钥，只给自己团队的设备扫。';

  @override
  String get joinTeam => '加入团队';

  @override
  String get joinTeamHint => '扫描团队里任意一台设备上的邀请二维码，或粘贴邀请码。';

  @override
  String get pasteInvite => '邀请码';

  @override
  String get invalidInvite => '邀请码无效';

  @override
  String joinConfirmTitle(String team) {
    return '加入「$team」？';
  }

  @override
  String get joinConfirmBody => '本机现有的商品、场次和订单都会被清空，然后从团队里的其他设备同步数据。';

  @override
  String get join => '加入';

  @override
  String get cameraUnavailable => '无法使用相机，请粘贴邀请码';

  @override
  String syncConnected(int count) {
    return '已连接 $count 台';
  }

  @override
  String get syncAlone => '单机';

  @override
  String get syncHelp => '同一团队的设备连在同一个 Wi-Fi 或手机热点下会自动互相同步，不需要外网。';

  @override
  String syncError(String error) {
    return '同步服务启动失败：$error';
  }

  @override
  String get rename => '改名';

  @override
  String get deviceName => '设备名称';

  @override
  String get topSellers => '热销榜';

  @override
  String get byCreator => '按作者分账';

  @override
  String get byPayment => '按支付方式';

  @override
  String get noCreator => '未设置作者';

  @override
  String get revenue => '实收';

  @override
  String get orders => '订单';

  @override
  String get itemsSold => '售出件数';

  @override
  String get averageOrder => '客单价';

  @override
  String get discountTotal => '优惠合计';

  @override
  String get refunds => '退款';

  @override
  String orderCount(int count) {
    return '$count 单';
  }

  @override
  String get exportCsv => '导出 CSV（订单和支出）';

  @override
  String get cloudBackup => '云端备份';

  @override
  String get cloudSignedOutHint => '用邮箱登录后自动备份到云端，换手机也能找回数据；不在一起的设备也能互相同步。';

  @override
  String get signInWithEmail => '用邮箱登录';

  @override
  String get signOut => '退出登录';

  @override
  String get signOutTitle => '退出云端登录？';

  @override
  String get signOutBody => '本机数据不会删除，只是不再备份到云端。';

  @override
  String get cloudConnecting => '正在连接云端…';

  @override
  String get cloudConnected => '已连接，实时备份中';

  @override
  String get cloudOffline => '暂时连不上云端，有网后自动同步';

  @override
  String lastSync(String time) {
    return '上次同步 $time';
  }

  @override
  String get neverSynced => '还没有同步过';

  @override
  String get email => '邮箱';

  @override
  String get sendCode => '发送验证码';

  @override
  String get verificationCode => '验证码';

  @override
  String codeSentTo(String email) {
    return '验证码已发送到 $email，10 分钟内有效';
  }

  @override
  String get devCodeHint => '开发模式：验证码已自动填好';

  @override
  String get signIn => '登录';

  @override
  String get resendCode => '重新发送';

  @override
  String get cloudSignedIn => '已开启云端备份';

  @override
  String get restoreFromCloud => '用邮箱从云端恢复';

  @override
  String get restoreHint => '登录后选择要恢复的团队，所有商品、场次和订单会下载到本机。';

  @override
  String get chooseTeamToRestore => '选择要恢复的团队';

  @override
  String cloudHasTeamsTitle(int count) {
    return '这个邮箱在云端还有 $count 个其他团队';
  }

  @override
  String get cloudHasTeamsBody =>
      '要用其他团队的商品和订单，选「恢复其他团队」，本机现在的数据会被替换。选「继续用本机团队」就把本机现在这个团队同步到云端。';

  @override
  String get restoreExistingTeam => '恢复其他团队';

  @override
  String get backupThisDevice => '继续用本机团队';

  @override
  String teamCreatedOn(String date) {
    return '创建于 $date';
  }

  @override
  String teamDeviceCount(int count) {
    return '$count 台设备';
  }

  @override
  String teamRecordCount(int count) {
    return '$count 条记录';
  }

  @override
  String get currentTeamTag => '本机当前团队';

  @override
  String get switchCloudTeam => '换成云端的其他团队';

  @override
  String get switchTeam => '切换团队';

  @override
  String get teamsOnDevice => '本机的团队';

  @override
  String get teamInUse => '正在使用';

  @override
  String get unnamedTeam => '未命名团队';

  @override
  String get addTeamFromCloud => '从云端添加团队';

  @override
  String get newTeam => '新建团队';

  @override
  String get newTeamConfirmTitle => '新建一个团队？';

  @override
  String get newTeamConfirmBody => '会在本机新建一个空的团队并切换过去。现在的团队和数据都保留，随时可以切回来。';

  @override
  String get removeFromDevice => '从本机移除';

  @override
  String removeTeamTitle(String team) {
    return '从本机移除「$team」？';
  }

  @override
  String get removeTeamBody =>
      '这台设备上这个团队的数据会被删除。已经备份到云端或在其他设备上的数据不受影响，之后可以再添加回来。';

  @override
  String get teamOnDeviceTag => '已在本机';

  @override
  String get cloudOtherTeams => '这个邮箱的其他团队';

  @override
  String get signInToSwitchTeamsHint => '登录后，这个邮箱下的团队都能直接切换';

  @override
  String switchingToTeam(String name) {
    return '正在切换到「$name」…';
  }

  @override
  String downloadingTeamNamed(String name) {
    return '正在下载「$name」…';
  }

  @override
  String joiningTeam(String name) {
    return '正在加入「$name」…';
  }

  @override
  String get creatingTeam => '正在新建团队…';

  @override
  String get downloadingTeam => '正在下载到本机…';

  @override
  String get noOtherCloudTeams => '这个邮箱下没有其他团队';

  @override
  String get addTeamConfirmBody => '会把这个团队下载到本机并切换过去，现在的团队和数据都保留。';

  @override
  String get joinAddConfirmBody =>
      '会在本机新增这个团队并切换过去，然后从团队里的其他设备同步数据。现在的团队和数据都保留。';

  @override
  String get chooseTeamHint => '同名的团队可以看创建时间和记录数来区分，记录多的那个通常就是有商品的。';

  @override
  String get noCloudTeams => '这个邮箱下还没有备份过的团队';

  @override
  String restoreConfirmTitle(String team) {
    return '恢复「$team」？';
  }

  @override
  String get restoreConfirmBody => '本机现有的数据会被清空，然后从云端下载这个团队的全部数据。';

  @override
  String get restore => '恢复';

  @override
  String get restoring => '正在从云端下载…';

  @override
  String get errInvalidEmail => '邮箱格式不对';

  @override
  String get errTooSoon => '发送太频繁，请 1 分钟后再试';

  @override
  String get errTooManyToday => '今天发送次数太多，请明天再试';

  @override
  String get errWrongCode => '验证码不对';

  @override
  String get errCodeExpired => '验证码已过期，请重新发送';

  @override
  String get errTooManyAttempts => '输错次数太多，请重新发送验证码';

  @override
  String get errNetwork => '连不上云端，请检查网络';

  @override
  String errGeneric(String code) {
    return '出错了：$code';
  }

  @override
  String get endEvent => '结束场次';

  @override
  String get reopenEvent => '重新开启';

  @override
  String get eventEnded => '已结束';

  @override
  String endEventTitle(String name) {
    return '结束「$name」？';
  }

  @override
  String endEventSales(int count, String amount) {
    return '本场 $count 单 · 实收 $amount';
  }

  @override
  String endEventReturn(int count) {
    return '本场剩余 $count 件：';
  }

  @override
  String get endEventNothing => '本场没有剩余的货。';

  @override
  String endEventOversold(String name, int count) {
    return '$name 卖超 $count 件';
  }

  @override
  String endEventMore(int count) {
    return '等共 $count 种';
  }

  @override
  String get endEventHint => '结束后收银台不再显示这个场次，订单和统计照常保留；点错了可以重新开启。';

  @override
  String eventEndedDone(String name, int count) {
    return '「$name」已结束，剩余 $count 件';
  }

  @override
  String reopenEventTitle(String name) {
    return '重新开启「$name」？';
  }

  @override
  String get reopenEventBody => '重新开启后可以继续在这个场次收银。';

  @override
  String eventEndedTitle(String name) {
    return '「$name」已结束';
  }

  @override
  String get eventEndedBody => '选择另一个场次继续收银，或重新开启这个场次。';

  @override
  String endPromptTitle(String name) {
    return '「$name」的日期已经过了，结束了吗？';
  }

  @override
  String get endPromptBody => '结束后收银台不再显示这个场次，剩余数量会保留，下一场备货时可以沿用。';

  @override
  String get notYet => '还没结束';

  @override
  String endPreviousTitle(String name) {
    return '上一场「$name」还没结束';
  }

  @override
  String endPreviousBody(int count) {
    return '还剩 $count 件，要先结束它吗？剩余数量会保留，新场次备货时可以沿用。';
  }

  @override
  String endPreviousConfirm(String name) {
    return '结束「$name」';
  }

  @override
  String get later => '先不';

  @override
  String get paymentRemarkHint => '请客人付款时在备注里填写';

  @override
  String get paymentReceived => '已收到付款';

  @override
  String get confirmLater => '稍后确认收款';

  @override
  String orderSavedPending(String number) {
    return '已保存订单 $number，待确认收款';
  }

  @override
  String get pendingPayment => '待确认收款';

  @override
  String get filterAll => '全部';

  @override
  String get filterPending => '待确认收款';

  @override
  String get confirmReceived => '确认已收款';

  @override
  String get paymentCode => '付款备注码';

  @override
  String paymentConfirmedAt(String time) {
    return '$time 确认收款';
  }

  @override
  String paymentPendingBody(String code) {
    return '核对到客人备注 $code 的付款后，点下面的按钮。';
  }

  @override
  String ordersPendingSummary(int count, String amount) {
    return '待确认 $count 单 · $amount';
  }

  @override
  String get paymentConfirmedDone => '已确认收款';

  @override
  String get searchOrdersHint => '搜索单号或付款备注码';

  @override
  String get allEvents => '全部场次';

  @override
  String get eventComparison => '各场对比';

  @override
  String comparisonOrders(int count) {
    return '$count 单';
  }

  @override
  String get noEventDate => '未设日期';

  @override
  String get useLeftover => '沿用上一场剩余';

  @override
  String useLeftoverBody(String name, int count) {
    return '把「$name」剩下的 $count 件设为本场数量？';
  }

  @override
  String get noLeftover => '之前的场次没有剩余的货';

  @override
  String get displayName => '用户名';

  @override
  String get setDisplayName => '设置用户名';

  @override
  String get editDisplayName => '修改用户名';

  @override
  String get displayNameHint => '显示在云端账号上，方便认出是谁的账号。登录仍用邮箱验证码。';

  @override
  String get skip => '跳过';

  @override
  String get errInvalidName => '用户名最多 30 个字';

  @override
  String get displayNameSaved => '用户名已保存';

  @override
  String get cashierLock => '收银锁';

  @override
  String get cashierLockHint => '锁上后只显示收银台，客人看不到订单、商品、统计和设置。解锁需要输入 PIN。';

  @override
  String get changeLockPin => '修改收银锁 PIN';

  @override
  String get setLockPin => '设置收银锁 PIN';

  @override
  String get confirmLockPin => '再输一遍 PIN';

  @override
  String get pinMismatch => '两次输入的 PIN 不一样';

  @override
  String get unlockTitle => '输入 PIN 解锁';

  @override
  String get wrongPin => 'PIN 不对';

  @override
  String pinHint(int count) {
    return '$count 位数字';
  }

  @override
  String get unlock => '解锁';

  @override
  String get lockedTooltip => '已锁定，点此解锁';

  @override
  String get expenses => '支出';

  @override
  String get addExpense => '记支出';

  @override
  String get newExpense => '记一笔支出';

  @override
  String get editExpense => '修改支出';

  @override
  String get expenseCategory => '分类';

  @override
  String get expenseAmount => '金额';

  @override
  String get expenseNote => '备注（可选）';

  @override
  String get expenseNoteHint => '如：高铁往返、两晚酒店';

  @override
  String get expenseDate => '日期';

  @override
  String get expenseEvent => '场次';

  @override
  String get expenseNoEvent => '不属于某个场次';

  @override
  String get noExpenses => '还没有记支出';

  @override
  String get deleteExpenseTitle => '删除这笔支出？';

  @override
  String get netIncome => '净收入';

  @override
  String netShort(String amount) {
    return '净 $amount';
  }

  @override
  String expenseSaved(String amount) {
    return '已记下支出 $amount';
  }

  @override
  String get expenseCat_travel => '差旅交通';

  @override
  String get expenseCat_booth => '摊位费';

  @override
  String get expenseCat_lodging => '住宿';

  @override
  String get expenseCat_food => '餐饮';

  @override
  String get expenseCat_supplies => '物料制作';

  @override
  String get expenseCat_shipping => '快递运费';

  @override
  String get expenseCat_other => '其他';

  @override
  String get nothingToExport => '没有可导出的订单或支出';

  @override
  String get otherCategory => '其他';

  @override
  String get addOne => '加一件';

  @override
  String get removeOne => '减一件';

  @override
  String get categories => '分类';

  @override
  String get manageCategories => '管理分类';

  @override
  String get newCategory => '新建分类';

  @override
  String get categoryName => '分类名称';

  @override
  String deleteCategoryTitle(String name) {
    return '删除分类「$name」？';
  }

  @override
  String get deleteCategoryBody => '商品不会被删除，只是不再属于这个分类。';

  @override
  String get noCategories => '还没有分类';

  @override
  String get noCategoriesBody => '建几个分类（如 吧唧、立牌、色纸），再在商品里勾上，收银台左边就按分类显示。';

  @override
  String get categoriesHint => '按住右边的把手拖动排序，收银台左边按这个顺序显示。点一行改名。';

  @override
  String categoryProductCount(int count) {
    return '$count 个商品';
  }

  @override
  String get moveHandle => '拖动排序';

  @override
  String orderedCount(int count) {
    return '已点 $count 件';
  }

  @override
  String get collapseCart => '收起已点';

  @override
  String get expandCart => '展开已点';

  @override
  String get collapseCartPanel => '收起购物车';

  @override
  String get expandCartPanel => '展开购物车';

  @override
  String categorySize(int count) {
    return '$count 款';
  }

  @override
  String get searchProductsHint => '搜索商品、作者或标签';

  @override
  String productTotal(int count) {
    return '共 $count 款';
  }

  @override
  String get noMatchingProducts => '没有符合条件的商品';

  @override
  String get optional => '选填';

  @override
  String get productKindAndPrice => '类型与价格';

  @override
  String get deleteProduct => '删除商品';

  @override
  String get changeImage => '更换图片';

  @override
  String get editPaymentCode => '修改备注码';

  @override
  String get editPaymentCodeBody => '可以改成客人方便填写的内容，比如名字或手机尾号。留空就用单号。';
}
