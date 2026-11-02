// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Abacus';

  @override
  String get navPos => 'Till';

  @override
  String get navOrders => 'Orders';

  @override
  String get navProducts => 'Goods';

  @override
  String get navStats => 'Stats';

  @override
  String get navSettings => 'Settings';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get offlineReady => 'Works offline';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'OK';

  @override
  String get add => 'Add';

  @override
  String get required => 'Required';

  @override
  String get invalidAmount => 'Enter a valid amount';

  @override
  String get invalidNumber => 'Enter a whole number';

  @override
  String get none => 'None';

  @override
  String get cart => 'Cart';

  @override
  String get cartEmpty => 'Tap a product to add it';

  @override
  String get checkout => 'Check out';

  @override
  String get clearCart => 'Clear';

  @override
  String itemCount(int count) {
    return '$count items';
  }

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Discount';

  @override
  String get total => 'Total';

  @override
  String get all => 'All';

  @override
  String get chooseEvent => 'Choose event';

  @override
  String get noEventTitle => 'No event selected';

  @override
  String get noEventBody =>
      'Create or choose an event. The till only lists what you brought to it.';

  @override
  String get noStockTitle => 'Nothing stocked for this event';

  @override
  String get noStockBody =>
      'Use Stock to choose which goods to bring and how many.';

  @override
  String get goStock => 'Stock';

  @override
  String stockLeft(int count) {
    return '$count left';
  }

  @override
  String get chooseVariant => 'Choose a variant';

  @override
  String get discountTitle => 'Order discount';

  @override
  String get discountAmountOff => 'Amount off';

  @override
  String get discountPercentOff => 'Percent off';

  @override
  String get discountFixedTotal => 'Set total';

  @override
  String get discountPercentHint => 'Percent off, e.g. 20';

  @override
  String get removeDiscount => 'Remove discount';

  @override
  String get paymentMethod => 'Payment';

  @override
  String get cashTendered => 'Cash received';

  @override
  String get change => 'Change';

  @override
  String get notEnoughCash => 'Not enough cash';

  @override
  String get exactAmount => 'Exact';

  @override
  String get noQrImage =>
      'No QR code yet. Upload one in Settings › Payment methods.';

  @override
  String get confirmPayment => 'Confirm payment';

  @override
  String orderSaved(String number) {
    return 'Order $number saved';
  }

  @override
  String get noPaymentMethods =>
      'No payment methods enabled. Turn one on in Settings.';

  @override
  String get addProduct => 'Add goods';

  @override
  String get editProduct => 'Edit goods';

  @override
  String get noProducts => 'No products yet';

  @override
  String get productName => 'Name';

  @override
  String get creator => 'Creator';

  @override
  String get newCreator => 'New creator…';

  @override
  String get creatorName => 'Creator name';

  @override
  String get tags => 'Tags';

  @override
  String get tagsHint => 'Comma separated, e.g. acrylic,badge';

  @override
  String get kindSingle => 'Single';

  @override
  String get kindVariants => 'Variants';

  @override
  String get kindBundle => 'Set';

  @override
  String get price => 'Price';

  @override
  String get cost => 'Cost';

  @override
  String get variantLabel => 'Variant';

  @override
  String get variantLabelHint => 'e.g. Red / Character A';

  @override
  String get addVariant => 'Add variant';

  @override
  String get needVariant => 'Add at least one variant';

  @override
  String get bundlePrice => 'Set price';

  @override
  String get bundleComponents => 'In this set';

  @override
  String get addComponent => 'Add item';

  @override
  String get needComponent => 'A set needs at least one item';

  @override
  String componentsValue(String amount) {
    return 'Sold separately: $amount';
  }

  @override
  String get chooseImage => 'Choose image';

  @override
  String get removeImage => 'Remove image';

  @override
  String get deleteProductTitle => 'Delete these goods?';

  @override
  String get deleteProductBody => 'Past orders are not affected.';

  @override
  String variantCount(int count) {
    return '$count variants';
  }

  @override
  String bundleSummary(int count) {
    return 'Set · $count items';
  }

  @override
  String get noComponentsAvailable =>
      'Add single items or variants first to build a set';

  @override
  String get events => 'Events';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get eventName => 'Event name';

  @override
  String get eventNameHint => 'e.g. Comic Con';

  @override
  String get eventDate => 'Date';

  @override
  String get eventDateHint => 'Pick a range for multi-day events';

  @override
  String get eventBooth => 'Table';

  @override
  String get noEvents => 'No events yet. Tap + to create one.';

  @override
  String get currentEvent => 'Current event';

  @override
  String get stockForEvent => 'Stock';

  @override
  String get eventQty => 'At this event';

  @override
  String bundleAvailable(int count) {
    return '$count sets available (from item stock)';
  }

  @override
  String get noOrders => 'No orders at this event yet';

  @override
  String get searchOrders => 'Search order number';

  @override
  String ordersSummary(int count, String amount) {
    return '$count orders · $amount received';
  }

  @override
  String get refunded => 'Refunded';

  @override
  String get refund => 'Refund order';

  @override
  String get refundTitle => 'Refund this order?';

  @override
  String get refundBody =>
      'The refund is recorded and the goods go back into this event\'s stock.';

  @override
  String get refundReason => 'Reason (optional)';

  @override
  String get refundDone => 'Refunded';

  @override
  String get orderDetail => 'Order';

  @override
  String get paymentMethods => 'Payment methods';

  @override
  String get addPaymentMethod => 'Add payment method';

  @override
  String get editPaymentMethod => 'Edit payment method';

  @override
  String get paymentName => 'Name';

  @override
  String get paymentKindCash => 'Cash';

  @override
  String get paymentKindQr => 'QR code';

  @override
  String get paymentKindCard => 'Card';

  @override
  String get paymentKindOther => 'Other';

  @override
  String get uploadQr => 'Upload QR code';

  @override
  String get enabled => 'Enabled';

  @override
  String get thisDevice => 'This device';

  @override
  String deviceCode(String code, String prefix) {
    return 'Device $code · order prefix $prefix';
  }

  @override
  String priceFrom(String price) {
    return 'from $price';
  }

  @override
  String get teamAndDevices => 'Team & devices';

  @override
  String get teamName => 'Team name';

  @override
  String get devicesInTeam => 'Devices in this team';

  @override
  String get thisDeviceTag => 'This device';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get inviteDevice => 'Invite a device';

  @override
  String get inviteTitle => 'Invite a device';

  @override
  String inviteBody(String code) {
    return 'On the new device, open the app and go to Settings › Team & devices › Join team, then scan this code. Its order numbers will start with $code.';
  }

  @override
  String get copyInviteCode => 'Copy invite code';

  @override
  String get inviteCopied => 'Invite code copied';

  @override
  String get inviteWarning =>
      'This code contains your team key. Only show it to your own devices.';

  @override
  String get joinTeam => 'Join team';

  @override
  String get joinTeamHint =>
      'Scan the invite QR code on any device in the team, or paste the invite code.';

  @override
  String get pasteInvite => 'Invite code';

  @override
  String get invalidInvite => 'This invite code is not valid';

  @override
  String joinConfirmTitle(String team) {
    return 'Join “$team”?';
  }

  @override
  String get joinConfirmBody =>
      'Goods, events and orders on this device will be cleared, then synced from the other devices in the team.';

  @override
  String get join => 'Join';

  @override
  String get cameraUnavailable =>
      'Camera unavailable. Paste the invite code instead.';

  @override
  String syncConnected(int count) {
    return '$count connected';
  }

  @override
  String get syncAlone => 'On its own';

  @override
  String get syncHelp =>
      'Devices in the same team sync automatically when they are on the same Wi-Fi or phone hotspot. No internet needed.';

  @override
  String syncError(String error) {
    return 'Sync could not start: $error';
  }

  @override
  String get rename => 'Rename';

  @override
  String get deviceName => 'Device name';

  @override
  String get topSellers => 'Best sellers';

  @override
  String get byCreator => 'By creator';

  @override
  String get byPayment => 'By payment method';

  @override
  String get noCreator => 'No creator';

  @override
  String get revenue => 'Revenue';

  @override
  String get orders => 'Orders';

  @override
  String get itemsSold => 'Items sold';

  @override
  String get averageOrder => 'Average order';

  @override
  String get discountTotal => 'Discounts';

  @override
  String get refunds => 'Refunds';

  @override
  String orderCount(int count) {
    return '$count orders';
  }

  @override
  String get exportCsv => 'Export orders and expenses as CSV';

  @override
  String get cloudBackup => 'Cloud backup';

  @override
  String get cloudSignedOutHint =>
      'Sign in with email to back up automatically, restore on a new phone, and sync devices that are not together.';

  @override
  String get signInWithEmail => 'Sign in with email';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutTitle => 'Sign out of the cloud?';

  @override
  String get signOutBody =>
      'Data on this device stays. It just stops backing up.';

  @override
  String get cloudConnecting => 'Connecting to the cloud…';

  @override
  String get cloudConnected => 'Connected, backing up live';

  @override
  String get cloudOffline => 'Can\'t reach the cloud. Will sync when online.';

  @override
  String lastSync(String time) {
    return 'Last synced $time';
  }

  @override
  String get neverSynced => 'Not synced yet';

  @override
  String get email => 'Email';

  @override
  String get sendCode => 'Send code';

  @override
  String get verificationCode => 'Code';

  @override
  String codeSentTo(String email) {
    return 'Code sent to $email. Valid for 10 minutes.';
  }

  @override
  String get devCodeHint => 'Development mode: the code was filled in for you';

  @override
  String get signIn => 'Sign in';

  @override
  String get resendCode => 'Resend';

  @override
  String get cloudSignedIn => 'Cloud backup is on';

  @override
  String get restoreFromCloud => 'Restore from the cloud';

  @override
  String get restoreHint =>
      'After signing in, choose a team to restore. Its goods, events and orders will download to this device.';

  @override
  String get chooseTeamToRestore => 'Choose a team to restore';

  @override
  String get noCloudTeams => 'No teams are backed up under this email yet';

  @override
  String restoreConfirmTitle(String team) {
    return 'Restore “$team”?';
  }

  @override
  String get restoreConfirmBody =>
      'Data on this device will be cleared, then the team\'s data will download from the cloud.';

  @override
  String get restore => 'Restore';

  @override
  String get restoring => 'Downloading from the cloud…';

  @override
  String get errInvalidEmail => 'That email doesn\'t look right';

  @override
  String get errTooSoon => 'Too many requests. Try again in a minute.';

  @override
  String get errTooManyToday => 'Too many codes today. Try again tomorrow.';

  @override
  String get errWrongCode => 'Wrong code';

  @override
  String get errCodeExpired => 'The code expired. Send a new one.';

  @override
  String get errTooManyAttempts => 'Too many wrong tries. Send a new code.';

  @override
  String get errNetwork => 'Can\'t reach the cloud. Check your connection.';

  @override
  String errGeneric(String code) {
    return 'Something went wrong: $code';
  }

  @override
  String get endEvent => 'End event';

  @override
  String get reopenEvent => 'Reopen';

  @override
  String get eventEnded => 'Ended';

  @override
  String endEventTitle(String name) {
    return 'End “$name”?';
  }

  @override
  String endEventSales(int count, String amount) {
    return '$count orders · $amount received';
  }

  @override
  String endEventReturn(int count) {
    return '$count items left:';
  }

  @override
  String get endEventNothing => 'Nothing left at this event.';

  @override
  String endEventOversold(String name, int count) {
    return '$name: oversold by $count';
  }

  @override
  String endEventMore(int count) {
    return '$count kinds in total';
  }

  @override
  String get endEventHint =>
      'The event leaves the till. Orders and stats stay. You can reopen it if needed.';

  @override
  String eventEndedDone(String name, int count) {
    return '“$name” ended with $count items left';
  }

  @override
  String reopenEventTitle(String name) {
    return 'Reopen “$name”?';
  }

  @override
  String get reopenEventBody =>
      'You can sell at this event again after reopening.';

  @override
  String eventEndedTitle(String name) {
    return '“$name” has ended';
  }

  @override
  String get eventEndedBody =>
      'Choose another event to keep selling, or reopen this one.';

  @override
  String endPromptTitle(String name) {
    return '“$name” is in the past. Has it ended?';
  }

  @override
  String get endPromptBody =>
      'It leaves the till. Leftover counts are kept and can be reused when stocking the next event.';

  @override
  String get notYet => 'Not yet';

  @override
  String endPreviousTitle(String name) {
    return '“$name” hasn\'t ended yet';
  }

  @override
  String endPreviousBody(int count) {
    return '$count items left. End it first? Leftover counts are kept for stocking the new event.';
  }

  @override
  String endPreviousConfirm(String name) {
    return 'End “$name”';
  }

  @override
  String get later => 'Not now';

  @override
  String get paymentRemarkHint =>
      'Ask the customer to put this in the payment note';

  @override
  String get paymentReceived => 'Payment received';

  @override
  String get confirmLater => 'Confirm later';

  @override
  String orderSavedPending(String number) {
    return 'Order $number saved, payment to confirm';
  }

  @override
  String get pendingPayment => 'Payment to confirm';

  @override
  String get filterAll => 'All';

  @override
  String get filterPending => 'To confirm';

  @override
  String get confirmReceived => 'Mark as paid';

  @override
  String get paymentCode => 'Payment note code';

  @override
  String paymentConfirmedAt(String time) {
    return 'Paid, confirmed $time';
  }

  @override
  String paymentPendingBody(String code) {
    return 'Once you find a payment with the note $code, tap the button below.';
  }

  @override
  String ordersPendingSummary(int count, String amount) {
    return '$count to confirm · $amount';
  }

  @override
  String get paymentConfirmedDone => 'Marked as paid';

  @override
  String get searchOrdersHint => 'Search order number or note code';

  @override
  String get allEvents => 'All events';

  @override
  String get eventComparison => 'By event';

  @override
  String comparisonOrders(int count) {
    return '$count orders';
  }

  @override
  String get noEventDate => 'No date';

  @override
  String get useLeftover => 'Use last leftover';

  @override
  String useLeftoverBody(String name, int count) {
    return 'Set this event to the $count items left from “$name”?';
  }

  @override
  String get noLeftover => 'No leftover from previous events';

  @override
  String get displayName => 'Username';

  @override
  String get setDisplayName => 'Set username';

  @override
  String get editDisplayName => 'Change username';

  @override
  String get displayNameHint =>
      'Shown on your cloud account so you can tell accounts apart. You still sign in with an email code.';

  @override
  String get skip => 'Skip';

  @override
  String get errInvalidName => 'Username can be at most 30 characters';

  @override
  String get displayNameSaved => 'Username saved';

  @override
  String get cashierLock => 'Till lock';

  @override
  String get cashierLockHint =>
      'Only the till is shown while locked, so customers can’t see orders, products, stats or settings. Unlock with a PIN.';

  @override
  String get changeLockPin => 'Change till lock PIN';

  @override
  String get setLockPin => 'Set till lock PIN';

  @override
  String get confirmLockPin => 'Enter the PIN again';

  @override
  String get pinMismatch => 'The PINs don’t match';

  @override
  String get unlockTitle => 'Enter PIN to unlock';

  @override
  String get wrongPin => 'Wrong PIN';

  @override
  String pinHint(int count) {
    return '$count digits';
  }

  @override
  String get unlock => 'Unlock';

  @override
  String get lockedTooltip => 'Locked — tap to unlock';

  @override
  String get expenses => 'Expenses';

  @override
  String get addExpense => 'Expense';

  @override
  String get newExpense => 'Add expense';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get expenseCategory => 'Category';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get expenseNote => 'Note (optional)';

  @override
  String get expenseNoteHint => 'e.g. train tickets, two hotel nights';

  @override
  String get expenseDate => 'Date';

  @override
  String get expenseEvent => 'Event';

  @override
  String get expenseNoEvent => 'Not tied to an event';

  @override
  String get noExpenses => 'No expenses yet';

  @override
  String get deleteExpenseTitle => 'Delete this expense?';

  @override
  String get netIncome => 'Net income';

  @override
  String netShort(String amount) {
    return 'net $amount';
  }

  @override
  String expenseSaved(String amount) {
    return 'Expense $amount saved';
  }

  @override
  String get expenseCat_travel => 'Travel';

  @override
  String get expenseCat_booth => 'Booth fee';

  @override
  String get expenseCat_lodging => 'Lodging';

  @override
  String get expenseCat_food => 'Food';

  @override
  String get expenseCat_supplies => 'Supplies';

  @override
  String get expenseCat_shipping => 'Shipping';

  @override
  String get expenseCat_other => 'Other';

  @override
  String get nothingToExport => 'No orders or expenses to export';

  @override
  String get otherCategory => 'Other';

  @override
  String get addOne => 'Add one';

  @override
  String get removeOne => 'Remove one';

  @override
  String get categories => 'Categories';

  @override
  String get manageCategories => 'Categories';

  @override
  String get newCategory => 'New category';

  @override
  String get categoryName => 'Category name';

  @override
  String deleteCategoryTitle(String name) {
    return 'Delete category “$name”?';
  }

  @override
  String get deleteCategoryBody =>
      'Products are kept; they just leave this category.';

  @override
  String get noCategories => 'No categories yet';

  @override
  String get noCategoriesBody =>
      'Create categories (e.g. Badges, Stands) and tick them on products; the till groups products by them.';

  @override
  String get categoriesHint =>
      'Drag the handle to reorder; the till shows categories in this order. Tap a row to rename.';

  @override
  String categoryProductCount(int count) {
    return '$count products';
  }

  @override
  String get moveHandle => 'Drag to reorder';

  @override
  String orderedCount(int count) {
    return '$count in cart';
  }

  @override
  String get collapseCart => 'Hide cart items';

  @override
  String get expandCart => 'Show cart items';

  @override
  String get collapseCartPanel => 'Hide cart';

  @override
  String get expandCartPanel => 'Show cart';

  @override
  String categorySize(int count) {
    return '$count items';
  }

  @override
  String get searchProductsHint => 'Search products, creators or tags';

  @override
  String productTotal(int count) {
    return '$count items';
  }

  @override
  String get noMatchingProducts => 'No matching products';

  @override
  String get optional => 'Optional';

  @override
  String get productKindAndPrice => 'Type & price';

  @override
  String get deleteProduct => 'Delete product';

  @override
  String get changeImage => 'Change image';
}
