// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings_title => 'Settings';

  @override
  String get common_signOut => 'Sign out';

  @override
  String get settings_sectionProfile => 'Profile';

  @override
  String get settings_sectionShop => 'Shop';

  @override
  String get settings_sectionAppearance => 'Appearance';

  @override
  String get settings_sectionInventory => 'Inventory';

  @override
  String get settings_sectionLanguage => 'Language';

  @override
  String get settings_appLanguage => 'App language';

  @override
  String get settings_guestSession => 'Guest session';

  @override
  String get settings_signedIn => 'Signed in';

  @override
  String get settings_anonymousData =>
      'Anonymous — data is tied to this device';

  @override
  String get settings_shopName => 'Shop name';

  @override
  String get settings_address => 'Address';

  @override
  String get settings_phone => 'Phone';

  @override
  String get settings_currency => 'Currency';

  @override
  String get settings_themeLight => 'Light';

  @override
  String get settings_themeDark => 'Dark';

  @override
  String get settings_manageCategories => 'Manage categories';

  @override
  String get settings_manageCategoriesSub =>
      'Rename, add, or remove categories';

  @override
  String get settings_archivedProducts => 'Archived products';

  @override
  String get settings_archivedProductsSub =>
      'View and restore removed products';

  @override
  String get common_restock => 'Restock';

  @override
  String get common_sell => 'Sell';

  @override
  String get common_period_today => 'Today';

  @override
  String get common_period_week => 'Week';

  @override
  String get common_period_month => 'Month';

  @override
  String get common_period_all => 'All';

  @override
  String get dashboard_yourShop => 'Your shop';

  @override
  String get dashboard_notificationsCaughtUp => 'You\'re all caught up';

  @override
  String get dashboard_notificationsHint =>
      'We\'ll show stock that is about to expire, or has expired, here.';

  @override
  String get dashboard_salesLast7 => 'Sales · last 7 days';

  @override
  String dashboard_bestDay(String day) {
    return '$day best';
  }

  @override
  String get dashboard_topPerformer => 'TOP PERFORMER';

  @override
  String get dashboard_mvpBadge => 'MVP';

  @override
  String get dashboard_noSalesYet =>
      'No sales yet — your best seller will appear here.';

  @override
  String dashboard_soldRevenue(String units, String revenue) {
    return '$units sold · $revenue revenue';
  }

  @override
  String get dashboard_viewAll => 'View all';

  @override
  String get dashboard_couldNotLoadSummary => 'Could not load summary.';

  @override
  String get dashboard_couldNotLoadSales => 'Could not load sales.';

  @override
  String dashboard_revenuePeriod(String period) {
    return 'Revenue · $period';
  }

  @override
  String get dashboard_profit => 'Profit';

  @override
  String get dashboard_margin => 'Margin';

  @override
  String get dashboard_itemsSold => 'Items sold';

  @override
  String get dashboard_vsYesterday => 'vs yesterday';

  @override
  String get dashboard_breakdown => 'Breakdown';

  @override
  String dashboard_exactFigures(String period) {
    return '$period · exact figures';
  }

  @override
  String get dashboard_revenue => 'Revenue';

  @override
  String get dashboard_costOfGoods => 'Cost of goods';

  @override
  String get dashboard_grossProfit => 'Gross profit';

  @override
  String get dashboard_avgItemPrice => 'Avg item price';

  @override
  String get dashboard_viewFullReport => 'View full report';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_edit => 'Edit';

  @override
  String get common_retry => 'Retry';

  @override
  String get common_undo => 'Undo';

  @override
  String get common_off => 'Off';

  @override
  String get common_addToCart => 'Add to cart';

  @override
  String get common_addedToCart => 'Added to cart';

  @override
  String get common_stockAdded => 'Stock added';

  @override
  String get common_somethingWrong => 'Something went wrong. Please try again.';

  @override
  String get common_noInternet => 'No internet connection';

  @override
  String get common_searchItems => 'Search items';

  @override
  String get common_restore => 'Restore';

  @override
  String get inventory_title => 'Inventory';

  @override
  String inventory_itemsValue(int count, String value) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString items · $value';
  }

  @override
  String get inventory_valueTitle => 'Inventory value';

  @override
  String get inventory_valueExact => 'Exact figures';

  @override
  String get inventory_valueProducts => 'Products';

  @override
  String get inventory_valueRetail => 'Retail value';

  @override
  String get inventory_valuePotentialProfit => 'Potential profit';

  @override
  String get inventory_filterAll => 'All';

  @override
  String get inventory_filterLowStock => 'Low stock';

  @override
  String inventory_inStock(String qty) {
    return '$qty in stock';
  }

  @override
  String get inventory_noProducts =>
      'No products yet.\nTap \"Add product\" to start.';

  @override
  String get inventory_noMatch => 'No products match your filters.';

  @override
  String get inventory_couldNotLoad =>
      'Could not load inventory. Pull to retry.';

  @override
  String get inventory_addProduct => 'Add product';

  @override
  String get inventory_scanProduct => 'Scan product';

  @override
  String get inventory_couldNotLoadProduct => 'Could not load product.';

  @override
  String get inventory_productGone => 'This product no longer exists.';

  @override
  String get inventory_removeTitle => 'Remove product?';

  @override
  String inventory_removeBody(String name) {
    return '\"$name\" will be removed from your inventory. Its past sales stay in your records.';
  }

  @override
  String inventory_removed(String name) {
    return '\"$name\" removed';
  }

  @override
  String get inventory_lowStock => 'Low stock';

  @override
  String inventory_reorderThresholdNote(String threshold) {
    return 'At or below reorder threshold ($threshold).';
  }

  @override
  String get inventory_statInStock => 'In stock';

  @override
  String get inventory_statBuyingPrice => 'Buying price';

  @override
  String get inventory_statSellingPrice => 'Selling price';

  @override
  String get inventory_statMarginPerUnit => 'Margin / unit';

  @override
  String get inventory_statInventoryValue => 'Inventory value (cost)';

  @override
  String get inventory_statReorderThreshold => 'Reorder threshold';

  @override
  String get inventory_couldNotLoadArchived =>
      'Could not load archived products. Pull to retry.';

  @override
  String inventory_restored(String name) {
    return '\"$name\" restored to inventory.';
  }

  @override
  String inventory_couldNotRestore(String name) {
    return 'Couldn\'t restore \"$name\". Please try again.';
  }

  @override
  String get inventory_noArchived => 'No archived products.';

  @override
  String get inventory_archivedHint =>
      'Products you remove from inventory show up here.';

  @override
  String get form_required => 'Required';

  @override
  String get form_enterNumber => 'Enter a number';

  @override
  String get form_cannotBeNegative => 'Cannot be negative';

  @override
  String get form_wholeNumberOnly => 'Whole number only';

  @override
  String get form_enterValidAmount => 'Enter a valid amount';

  @override
  String get unit_byPiece => 'By piece';

  @override
  String get unit_byWeight => 'By weight';

  @override
  String get unit_byVolume => 'By volume';

  @override
  String get unit_hintPiece =>
      'Counted as whole pieces — soap, bottled drinks, packets.';

  @override
  String get unit_hintWeight =>
      'Sold by weight — rice, potato, lentils, sugar.';

  @override
  String get unit_hintVolume => 'Sold by volume — loose oil, milk, kerosene.';

  @override
  String get inventory_formAddTitle => 'Add product';

  @override
  String get inventory_formEditTitle => 'Edit product';

  @override
  String get inventory_formHowSold => 'How is this item sold?';

  @override
  String get inventory_formName => 'Name *';

  @override
  String get inventory_formBrand => 'Brand';

  @override
  String get inventory_formVariant => 'Variant (e.g. 500ml, 1kg pack)';

  @override
  String get inventory_formReorderAt => 'Reorder at';

  @override
  String inventory_formBuyingPrice(String perUnit) {
    return 'Buying price$perUnit *';
  }

  @override
  String inventory_formSellingPrice(String perUnit) {
    return 'Selling price$perUnit *';
  }

  @override
  String get inventory_formCreate => 'Create';

  @override
  String get inventory_formSaveChanges => 'Save changes';

  @override
  String get inventory_formTryExample => 'Try a real example';

  @override
  String get inventory_formStockPieces => 'Stock (pieces) *';

  @override
  String get inventory_formStock => 'Stock *';

  @override
  String get common_save => 'Save';

  @override
  String get common_add => 'Add';

  @override
  String get common_rename => 'Rename';

  @override
  String get category_noShop => 'No shop found for this account.';

  @override
  String get category_renameTitle => 'Rename category';

  @override
  String get category_deleteTitle => 'Delete category?';

  @override
  String category_deleteBodyEmpty(String name) {
    return '\"$name\" will be removed.';
  }

  @override
  String category_deleteBodyUsed(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString products',
      one: '1 product',
    );
    return '\"$name\" will be removed. $_temp0 will become uncategorized (not deleted).';
  }

  @override
  String get category_addTooltip => 'Add category';

  @override
  String get category_couldNotLoad =>
      'Could not load categories. Pull to retry.';

  @override
  String category_productCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString products',
      one: '1 product',
    );
    return '$_temp0';
  }

  @override
  String get category_noneYet => 'No categories yet.';

  @override
  String get category_tapToAdd => 'Tap + to add one.';

  @override
  String get category_fieldLabel => 'Category';

  @override
  String get category_none => 'No category';

  @override
  String get category_addNew => 'Add new category';

  @override
  String get category_alreadyExists => 'Already exists — selected it for you';

  @override
  String get category_newTitle => 'New category';

  @override
  String get category_nameLabel => 'Category name';

  @override
  String get category_nameHint => 'e.g. Frozen items';

  @override
  String get common_clear => 'Clear';

  @override
  String get common_remove => 'Remove';

  @override
  String get common_quantity => 'Quantity';

  @override
  String get common_subtotal => 'Subtotal';

  @override
  String get common_couldNotRecognize =>
      'Could not recognize the product. Please try again.';

  @override
  String get cart_title => 'Cart';

  @override
  String cart_itemsInCart(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString items in cart',
      one: '1 item in cart',
    );
    return '$_temp0';
  }

  @override
  String get cart_clearTitle => 'Clear cart?';

  @override
  String get cart_clearBody =>
      'This removes every item from the cart. Nothing is sold.';

  @override
  String get cart_keep => 'Keep';

  @override
  String cart_totalItems(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString items',
      one: '1 item',
    );
    return 'Total · $_temp0';
  }

  @override
  String get cart_checkout => 'Checkout';

  @override
  String get cart_selling => 'Selling…';

  @override
  String get cart_empty => 'Your cart is empty';

  @override
  String get cart_emptyHint =>
      'Add products from Items or Scan to build a sale, then check out here.';

  @override
  String cart_itemsSold(int count, String total) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString items sold',
      one: '1 item sold',
    );
    return '$_temp0 · $total';
  }

  @override
  String get cart_checkoutFailed => 'Checkout failed. Please try again.';

  @override
  String error_insufficientStock(String product) {
    return 'Not enough $product in stock';
  }

  @override
  String get error_cartEmpty => 'The cart is empty.';

  @override
  String get error_productNotFound => 'That product no longer exists.';

  @override
  String get error_customerNotFound => 'That customer no longer exists.';

  @override
  String get error_discountExceedsTotal =>
      'The discount is more than the bill.';

  @override
  String get error_discountNegative => 'A discount cannot be negative.';

  @override
  String get error_quantityNotPositive => 'Quantity must be more than zero.';

  @override
  String get cart_addDiscount => 'Add discount';

  @override
  String get cart_discount => 'Discount';

  @override
  String get cart_discountTitle => 'Discount';

  @override
  String get cart_discountAmount => 'Amount off';

  @override
  String get cart_discountEdit => 'Edit discount';

  @override
  String get cart_discountRemove => 'Remove discount';

  @override
  String cart_discountBelowCost(String amount) {
    return 'You\'d lose $amount on this sale';
  }

  @override
  String get cart_discountInvalid => 'Enter a valid amount';

  @override
  String get cart_apply => 'Apply';

  @override
  String cart_pricePerUnit(String price, String unit) {
    return '$price / $unit';
  }

  @override
  String cart_barSummary(int count, String total) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString items',
      one: '1 item',
    );
    return '$_temp0 · $total';
  }

  @override
  String get addToCart_noMore => 'No more available to add.';

  @override
  String addToCart_available(String qty, String unit) {
    return '$qty $unit available to add';
  }

  @override
  String get restock_confirmTitle => 'Confirm restock';

  @override
  String restock_inStock(String qty) {
    return 'In stock: $qty';
  }

  @override
  String get restock_unitCost => 'Unit cost';

  @override
  String get restock_totalCost => 'Total cost';

  @override
  String get scan_failed => 'Scan failed. Try again.';

  @override
  String scan_addedToCart(String name) {
    return 'Added $name to cart';
  }

  @override
  String scan_read(String details) {
    return 'Read: $details';
  }

  @override
  String get scan_didYouMean => 'Did you mean?';

  @override
  String get scan_noMatchPick => 'No match — pick the product';

  @override
  String get scan_searchProducts => 'Search products';

  @override
  String scan_recognizing(int count) {
    return 'Recognizing $count…';
  }

  @override
  String scan_addItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count items',
      one: 'Add 1 item',
    );
    return '$_temp0';
  }

  @override
  String get scan_addEmpty => 'Add';

  @override
  String get scan_nothingYet => 'Scan something to begin';

  @override
  String get scan_tapToPick => 'Tap to pick';

  @override
  String get scan_notIdentified => 'Not identified';

  @override
  String get scan_topSellers => 'Top sellers';

  @override
  String get scan_outOfStock => 'Out of stock';

  @override
  String get scan_cameraDenied =>
      'Camera access is needed to scan. Open Settings and allow it, then try again.';

  @override
  String get scan_openSettings => 'Try again';

  @override
  String get scan_cameraUnavailable =>
      'This device has no camera to scan with.';

  @override
  String get scan_leaveTitle => 'Leave without adding?';

  @override
  String scan_leaveBody(int count) {
    return '$count scanned items have not been added to the cart.';
  }

  @override
  String get scan_discardTitle => 'Add the rest?';

  @override
  String scan_discardBody(int count) {
    return '$count items are not ready to add (unresolved or out of stock) and will be discarded.';
  }

  @override
  String get common_discard => 'Discard';

  @override
  String get history_title => 'Sales history';

  @override
  String get history_search => 'Search sales';

  @override
  String get history_couldNotLoad =>
      'Could not load sales history. Pull to retry.';

  @override
  String get history_noSalesYet => 'No sales recorded yet.';

  @override
  String history_noSalesOnDay(String date) {
    return 'No sales on $date.';
  }

  @override
  String get history_emptyHint =>
      'Record a sale from Items → tap a product → Add to cart, or use the cart bar to checkout.';

  @override
  String get history_noMatch => 'No sales match your search.';

  @override
  String get history_saleFallback => 'Sale';

  @override
  String get history_colTime => 'Time';

  @override
  String get history_colItem => 'Item';

  @override
  String get history_colQty => 'Qty';

  @override
  String get history_colAmount => 'Amount';

  @override
  String get saleDetail_title => 'Sale details';

  @override
  String get saleDetail_soldOn => 'Sold on';

  @override
  String get saleDetail_quantity => 'Quantity';

  @override
  String get saleDetail_priceEach => 'Price each';

  @override
  String get saleDetail_total => 'Total';

  @override
  String get saleDetail_discount => 'Discount';

  @override
  String get saleDetail_cost => 'Cost';

  @override
  String get saleDetail_profit => 'Profit';

  @override
  String get saleDetail_enteredBy => 'Entered by';

  @override
  String get saleDetail_paidBy => 'Paid by';

  @override
  String get saleDetail_frozenNote =>
      'Prices are locked in from the moment of sale.';

  @override
  String get saleDetail_notFound => 'Sale not found.';

  @override
  String get saleDetail_sourceManual => 'Manual';

  @override
  String get saleDetail_sourceVoice => 'Voice';

  @override
  String get saleDetail_sourcePhoto => 'Photo scan';

  @override
  String get analytics_kicker => 'BUSINESS REPORT';

  @override
  String get analytics_title => 'Reports';

  @override
  String get analytics_noSalesPeriod => 'No sales in this period yet.';

  @override
  String get analytics_revenueSource => 'Where revenue comes from';

  @override
  String get analytics_topShare => 'top share';

  @override
  String get analytics_biggestWins => 'Biggest wins';

  @override
  String analytics_carrying(String name, String scope) {
    return '$name is carrying $scope.';
  }

  @override
  String get analytics_scopeToday => 'today';

  @override
  String get analytics_scopeWeek => 'this week';

  @override
  String get analytics_scopeMonth => 'this month';

  @override
  String get analytics_scopeAll => 'all time';

  @override
  String analytics_scopeDay(String date) {
    return 'on $date';
  }

  @override
  String analytics_units(String qty) {
    return '$qty units';
  }

  @override
  String get auth_createAccount => 'Create your account';

  @override
  String get auth_welcomeBack => 'Welcome back';

  @override
  String get auth_noInternet =>
      'No internet connection. Connect to the internet and try again.';

  @override
  String get auth_fullName => 'Full name';

  @override
  String get auth_nameRequired => 'Name is required';

  @override
  String get auth_email => 'Email';

  @override
  String get auth_emailRequired => 'Email is required';

  @override
  String get auth_emailInvalid => 'Enter a valid email';

  @override
  String get auth_password => 'Password';

  @override
  String get auth_passwordRequired => 'Password is required';

  @override
  String get auth_passwordMin => 'At least 6 characters';

  @override
  String get auth_signUp => 'Sign up';

  @override
  String get auth_signIn => 'Sign in';

  @override
  String get auth_continueGoogle => 'Continue with Google';

  @override
  String get auth_haveAccount => 'Already have an account? Sign in';

  @override
  String get auth_noAccount => 'Don\'t have an account? Sign up';

  @override
  String get profile_tellUs => 'Tell us about your shop';

  @override
  String get profile_shopName => 'Shop name *';

  @override
  String get profile_shopNameRequired => 'Shop name is required';

  @override
  String get profile_address => 'Address (optional)';

  @override
  String get profile_phone => 'Phone (optional)';

  @override
  String get profile_createShop => 'Create shop';

  @override
  String get welcome_headline => 'Run your shop\nsmarter';

  @override
  String get welcome_subtitle =>
      'Track inventory, record sales by voice or photo, and see your profit at a glance.';

  @override
  String get welcome_getStarted => 'Get started';

  @override
  String get nav_home => 'Home';

  @override
  String get nav_items => 'Items';

  @override
  String get nav_reports => 'Reports';

  @override
  String get nav_history => 'History';

  @override
  String get common_continue => 'Continue';

  @override
  String get onboarding_languageTitle => 'Choose your language';

  @override
  String get onboarding_languageSubtitle =>
      'You can change this anytime in Settings.';

  @override
  String onboarding_step(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Step $currentString of $totalString';
  }

  @override
  String get onboarding_defaultCurrency => 'Default currency *';

  @override
  String get customers_title => 'Customers';

  @override
  String customers_receivablesHeader(String amount, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString customers',
      one: '1 customer',
    );
    return '$amount owed by $_temp0';
  }

  @override
  String get customers_empty => 'No customers yet';

  @override
  String get customers_emptyHint =>
      'Add a customer to start a khata, or choose Credit at checkout.';

  @override
  String get customers_searchHint => 'Search by name or phone';

  @override
  String get customers_add => 'Add customer';

  @override
  String get customers_edit => 'Edit customer';

  @override
  String get customers_fieldName => 'Name';

  @override
  String get customers_fieldPhone => 'Phone';

  @override
  String get customers_fieldNote => 'Note (optional)';

  @override
  String get customers_nameRequired => 'Enter a name';

  @override
  String get customers_phoneRequired => 'Enter a phone number';

  @override
  String get customers_save => 'Save';

  @override
  String get customers_delete => 'Delete customer';

  @override
  String customers_deleteConfirmTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get customers_deleteConfirmBody =>
      'This removes the customer and their khata history. Only settled customers can be deleted.';

  @override
  String customers_owes(String amount) {
    return 'Owes $amount';
  }

  @override
  String get customers_settled => 'Settled';

  @override
  String get customers_balance => 'Balance';

  @override
  String get customers_ledgerEmpty => 'No khata activity yet';

  @override
  String get customers_recordPayment => 'Record payment';

  @override
  String get customers_paymentAmount => 'Amount';

  @override
  String get customers_paymentNote => 'Note (optional)';

  @override
  String get customers_paymentAmountRequired => 'Enter an amount';

  @override
  String get customers_paymentTooLarge => 'More than what is owed';

  @override
  String get customers_paymentRecorded => 'Payment recorded';

  @override
  String get customers_ledgerCreditSale => 'Credit sale';

  @override
  String get customers_ledgerPayment => 'Payment';

  @override
  String get cart_paymentCash => 'Cash';

  @override
  String get cart_paymentCredit => 'Credit';

  @override
  String get cart_paymentDigital => 'Digital';

  @override
  String get cart_selectCustomer => 'Select customer';

  @override
  String cart_addToKhata(String name) {
    return 'Add to $name\'s khata';
  }

  @override
  String cart_addedToKhata(String name, String total) {
    return 'Added to $name\'s khata · $total';
  }

  @override
  String get dashboard_receivablesTitle => 'Receivables';

  @override
  String get voice_title => 'Speak a sale';

  @override
  String get voice_hintIdle => 'Tap the mic and say what you sold';

  @override
  String get voice_recording => 'Listening…';

  @override
  String get voice_thinking => 'Working it out…';

  @override
  String get voice_stageHeard => 'Heard you';

  @override
  String get voice_stageUnderstanding => 'Understanding what you said';

  @override
  String get voice_stageMatching => 'Finding your items';

  @override
  String get voice_thinkingDismissHint => 'We\'ll buzz you when it\'s ready';

  @override
  String get voice_thinkingMinimize => 'Continue in background';

  @override
  String get voice_bannerWorking => 'Working on your voice sale…';

  @override
  String get voice_bannerCancel => 'Discard this voice sale';

  @override
  String get voice_bannerReady => 'Your voice sale is ready';

  @override
  String get voice_bannerFailed => 'Your voice sale needs a look';

  @override
  String get voice_bannerAction => 'Review';

  @override
  String get voice_heard => 'I heard';

  @override
  String get voice_recheck => 'Re-check';

  @override
  String get voice_whichOne => 'Which one?';

  @override
  String get voice_pick => 'Pick';

  @override
  String get voice_addToCart => 'Add to cart';

  @override
  String get voice_assumedQty => 'Assumed 1 — check this';

  @override
  String voice_lowStock(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Only $countString in stock';
  }

  @override
  String get voice_errNoSpeech => 'Didn\'t catch that. Try again.';

  @override
  String get voice_errNoMatch => 'Couldn\'t match anything you said.';

  @override
  String get voice_errMicDenied =>
      'Microphone access is off. Turn it on in Settings.';

  @override
  String get voice_errOffline => 'You\'re offline. Reconnect and try again.';

  @override
  String get voice_errTooQuiet =>
      'The microphone didn\'t pick up any sound. Hold the phone closer and try again.';

  @override
  String get voice_retry => 'Try again';

  @override
  String get voice_recordAgain => 'Record again';

  @override
  String get voice_typeInstead => 'Type it instead';

  @override
  String voice_stoppingIn(int seconds) {
    return 'Stopping in ${seconds}s';
  }

  @override
  String get voice_speakCloser => 'Can\'t hear you — hold the phone closer';

  @override
  String get voice_levelLabel => 'Microphone level';

  @override
  String get expiry_dateLabel => 'Expiry date';

  @override
  String get expiry_dateOptional => 'Optional';

  @override
  String get expiry_dateClear => 'Remove date';

  @override
  String get expiry_pastDateTitle => 'This date has already passed';

  @override
  String get expiry_pastDateBody => 'Save it anyway?';

  @override
  String get expiry_farDateTitle => 'Is this year right?';

  @override
  String expiry_farDateBody(String date) {
    return '$date is more than 5 years away.';
  }

  @override
  String get expiry_saveAnyway => 'Save anyway';

  @override
  String get expiry_changeDate => 'Change date';

  @override
  String get expiry_moreOptions => 'More options';

  @override
  String get expiry_warnDaysLabel => 'Warn me this many days before expiry';

  @override
  String get expiry_warnDaysHint => 'Leave empty to let the app decide';

  @override
  String get expiry_unitChangeBlocked =>
      'Clear this product\'s deliveries before changing its unit';

  @override
  String get expiry_savedWithoutDate =>
      'Product saved, but its expiry date wasn\'t. Add it from the product page.';

  @override
  String get expiry_deliveries => 'Deliveries';

  @override
  String get expiry_addDate => 'Add expiry date';

  @override
  String expiry_rowDates(String added, String expiry) {
    return 'Added $added · Expires $expiry';
  }

  @override
  String expiry_rowLeft(String qty, String unit) {
    return 'About $qty $unit left';
  }

  @override
  String get expiry_statusGood => 'Good';

  @override
  String get expiry_statusSoon => 'Expiring soon';

  @override
  String get expiry_statusExpired => 'Expired';

  @override
  String get expiry_removeFromStock => 'Remove from stock';

  @override
  String expiry_thrownAway(String qty, String unit, String amount) {
    return 'Thrown away: $qty $unit · $amount lost';
  }

  @override
  String settings_restockEvery(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'I restock every $daysString days',
      one: 'I restock every day',
    );
    return '$_temp0';
  }

  @override
  String get settings_restockEveryTitle => 'How often do you restock?';

  @override
  String restockPlan_daysShort(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get restockPlan_title => 'Restock list';

  @override
  String get restockPlan_buyNow => 'Buy now';

  @override
  String restockPlan_enough(String count) {
    return 'Enough for now ($count)';
  }

  @override
  String get restockPlan_runsOutToday => 'Runs out today';

  @override
  String restockPlan_runsOutIn(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Runs out in $daysString days',
      one: 'Runs out in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get restockPlan_today => 'today';

  @override
  String get restockPlan_atReorderLevel => 'At your reorder level';

  @override
  String get restockPlan_lowShort => 'low stock';

  @override
  String restockPlan_buyAbout(String qty, String unit) {
    return 'Buy about $qty $unit';
  }

  @override
  String restockPlan_inStock(String qty, String unit) {
    return '$qty $unit in stock';
  }

  @override
  String get restockPlan_empty =>
      'Nothing to restock yet. Suggestions appear after a few days of sales.';

  @override
  String get restockPlan_loadError => 'Could not load the restock list.';

  @override
  String get restockPlan_cardTitle => 'Restock soon';

  @override
  String restockPlan_cardSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString items to restock',
      one: '1 item to restock',
    );
    return '$_temp0';
  }

  @override
  String restockPlan_cardItem(String name, String days) {
    return '$name · $days';
  }

  @override
  String get expiry_formAddTitle => 'Add expiry date';

  @override
  String get expiry_formEditTitle => 'Edit delivery';

  @override
  String get expiry_formAmount => 'Amount';

  @override
  String get expiry_formReceived => 'Date added';

  @override
  String get expiry_amountInvalid => 'Enter an amount above 0';

  @override
  String get expiry_dateRequired => 'Choose an expiry date';

  @override
  String expiry_removeConfirmTitle(String qty, String unit, String name) {
    return 'Remove $qty $unit of $name?';
  }

  @override
  String get expiry_removeConfirmBody =>
      'Stock goes down and the loss is recorded. Your sales figures don\'t change.';

  @override
  String get expiry_removed => 'Removed from stock';

  @override
  String expiry_removeAmountTitle(String name) {
    return 'Remove $name from stock?';
  }

  @override
  String get expiry_removeAmountLabel => 'How many?';

  @override
  String expiry_cartOnlyGood(String good, String name, String expired) {
    return 'Only $good good $name left ($expired expired)';
  }

  @override
  String expiry_cartOnlyExpired(String name, String expired) {
    return 'Only expired $name left ($expired)';
  }

  @override
  String get expiry_cartRemoveExpired => 'Remove expired';

  @override
  String get expiry_cartNotExpired => 'They\'re not expired';

  @override
  String expiry_cartOnlyLeft(String qty, String unit) {
    return 'Only $qty $unit left';
  }

  @override
  String expiry_addSheetExpiredNote(String qty, String unit) {
    return '$qty $unit expired — not counted';
  }

  @override
  String get error_expiredStockInCart =>
      'Some items in the cart are expired. Fix them before checkout.';

  @override
  String get error_batchShortInCart =>
      'A batch you picked doesn\'t have enough left. Check the cart.';

  @override
  String get error_batchNotAvailable =>
      'That batch is no longer available. Pick another one in the cart.';

  @override
  String cart_batchLabel(String choice) {
    return 'Batch: $choice';
  }

  @override
  String get cart_batchMix => 'Several batches, soonest expiry first';

  @override
  String get cart_batchChoose => 'Choose';

  @override
  String get cart_batchChooseNotice => 'Choose which batch this comes from';

  @override
  String get error_batchNotChosen =>
      'Choose a batch for each marked item in the cart.';

  @override
  String get cart_batchNoDate => 'No expiry date';

  @override
  String cart_batchExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get cart_batchPickTitle => 'Sell from which batch?';

  @override
  String cart_batchOptionLeft(String qty, String unit) {
    return '$qty $unit left';
  }

  @override
  String cart_batchShort(String qty, String unit) {
    return 'Only $qty $unit left in this batch';
  }

  @override
  String get cart_batchGone =>
      'This batch is no longer available. Pick another.';

  @override
  String expiry_alertExpired(String qty, String name) {
    return 'Expired: $qty $name';
  }

  @override
  String expiry_alertSoonToday(String name, String qty) {
    return '$name: $qty expire today';
  }

  @override
  String expiry_alertSoonTomorrow(String name, String qty) {
    return '$name: $qty expire tomorrow';
  }

  @override
  String expiry_alertSoonDays(String name, String qty, String days) {
    return '$name: $qty expire in $days days';
  }

  @override
  String get expiry_cardTitle => 'Expiring & expired';

  @override
  String get expiry_alertsTitle => 'Expiry alerts';

  @override
  String get expiry_filter => 'Expiring';

  @override
  String get reminder_title => 'Expiry check';

  @override
  String reminder_more(String count) {
    return '+$count more';
  }

  @override
  String get reminder_channelName => 'Expiry reminders';

  @override
  String get settings_sectionExpiry => 'Expiry';

  @override
  String settings_expiryWarnDays(String days) {
    return 'Warn me up to $days days before';
  }

  @override
  String get settings_expiryWarnDaysTitle => 'Warning time';

  @override
  String settings_expiryDaysOption(String days) {
    return '$days days';
  }

  @override
  String get settings_expiryReminder => 'Daily expiry reminder';

  @override
  String get settings_expiryReminderSub =>
      'At 9 AM on days something needs attention';

  @override
  String get settings_expiryReminderBlocked =>
      'Blocked — turn on notifications in phone settings';

  @override
  String get finance_title => 'Money health';

  @override
  String get finance_last7Days => 'Last 7 days';

  @override
  String get finance_in => 'In';

  @override
  String get finance_out => 'Out';

  @override
  String get finance_net => 'Net';

  @override
  String get finance_allGood => 'No money warnings this week';

  @override
  String finance_alertOverdue(String name, String amount, String days) {
    return '$name owes $amount for $days days';
  }

  @override
  String finance_alertOverdueMore(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $countString more customers are late',
      one: 'and 1 more customer is late',
    );
    return '$_temp0';
  }

  @override
  String finance_alertCashShort(String amount) {
    return 'Restocks cost $amount more than the money that came in';
  }

  @override
  String finance_alertCreditGrowing(String rise, String total) {
    return 'Credit owed went up $rise this week (now $total)';
  }

  @override
  String finance_alertSalesDrop(String percent) {
    return 'Sales fell $percent from the week before';
  }

  @override
  String finance_financingFooter(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString financing options fit your shop',
      one: '1 financing option fits your shop',
      zero: 'See financing options for your shop',
    );
    return '$_temp0';
  }

  @override
  String get finance_rowCashSales => 'Cash sales';

  @override
  String get finance_rowDigitalSales => 'Digital sales';

  @override
  String get finance_rowCollected => 'Credit collected';

  @override
  String get finance_rowMoneyIn => 'Money in';

  @override
  String get finance_rowRestocks => 'Restocks';

  @override
  String get finance_rowMoneyOut => 'Money out';

  @override
  String get finance_rowCreditGiven => 'Sold on credit (not paid yet)';

  @override
  String get finance_outNote => 'Money out counts restocks only.';

  @override
  String get finance_alertsTitle => 'Warnings';

  @override
  String get finance_financingTitle => 'Financing for your shop';

  @override
  String get finance_financingIntro =>
      'Matched from your last 90 days of sales.';

  @override
  String get finance_fits => 'Fits you';

  @override
  String get finance_notYet => 'Not yet';

  @override
  String finance_upTo(String amount) {
    return 'Up to about $amount';
  }

  @override
  String get finance_kindSupplier => 'Supplier credit';

  @override
  String get finance_kindSupplierSub =>
      'Get stock now, pay the supplier in 30 days';

  @override
  String get finance_kindWallet => 'Mobile-wallet small loan';

  @override
  String get finance_kindWalletSub =>
      'A quick small loan based on your digital sales';

  @override
  String get finance_kindMicro => 'Microfinance shop loan';

  @override
  String get finance_kindMicroSub =>
      'Weekly repayments, for steady small shops';

  @override
  String get finance_kindSme => 'Bank SME loan';

  @override
  String get finance_kindSmeSub => 'A bigger loan to grow the shop';

  @override
  String finance_whySupplier(String amount) {
    return 'You restock about $amount a month';
  }

  @override
  String finance_whyWallet(String percent) {
    return '$percent of your sales are digital';
  }

  @override
  String finance_whyMicro(String weeks) {
    return 'You sold in $weeks of the last 12 weeks';
  }

  @override
  String finance_whySme(String months, String percent) {
    return '$months months of trading and a $percent profit margin';
  }

  @override
  String finance_gapTrade(int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Keep trading $monthsString more months',
      one: 'Keep trading 1 more month',
    );
    return '$_temp0';
  }

  @override
  String get finance_gapRestock => 'Record your restocks in the app first';

  @override
  String finance_gapWeeks(String needed, String have) {
    return 'Sell in $needed of every 12 weeks (now $have)';
  }

  @override
  String finance_gapDigital(String target, String have) {
    return 'Take at least $target of sales digitally (now $have)';
  }

  @override
  String finance_gapMargin(String target, String have) {
    return 'Reach a $target profit margin (now $have)';
  }

  @override
  String get finance_gapCredit =>
      'Collect credit until less than half a month\'s sales is owed';

  @override
  String get finance_disclaimer =>
      'These are examples that show how matching works, not loan offers. Ask a lender for real terms.';

  @override
  String get finance_loadError =>
      'Couldn\'t load money health. Check your connection and try again.';

  @override
  String get finance_tipsAsk => 'Get advice from EasySell AI';

  @override
  String get finance_tipsThinking => 'Thinking…';

  @override
  String get finance_tipsTitle => 'AI advice';

  @override
  String get finance_tipsNote =>
      'Based on the numbers above. Check them before you act.';

  @override
  String get finance_tipsError => 'Couldn\'t get advice right now.';

  @override
  String finance_tipOverdue(String name, String amount) {
    return 'Visit or call $name this week and collect part of the $amount they owe.';
  }

  @override
  String finance_tipCashShort(String amount) {
    return 'Restock smaller this week: restocks cost $amount more than the money that came in.';
  }

  @override
  String finance_tipCreditGrowing(String total) {
    return 'Give less new credit this week and collect old dues first. $total is owed now.';
  }

  @override
  String finance_tipSalesDrop(String percent) {
    return 'Sales fell $percent. Check which items ran out and restock your best sellers first.';
  }

  @override
  String finance_tipCollectEarly(String amount) {
    return 'Collect the $amount customers owe before it gets old. Small, regular collections are easiest.';
  }

  @override
  String get finance_tipGoDigital =>
      'Ask customers to pay by mobile wallet more often. Digital sales build a record lenders trust.';

  @override
  String finance_tipFinancing(String option) {
    return '$option could help your shop. Compare the lender\'s terms before you decide.';
  }

  @override
  String get finance_tipKeepRecording =>
      'Keep recording every sale and restock so your money picture stays accurate.';

  @override
  String get backup_section => 'Your data';

  @override
  String get backup_now => 'Back up now';

  @override
  String get backup_never =>
      'Never backed up. Your shop lives only on this phone.';

  @override
  String backup_daysAgo(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Last backup: $daysString days ago',
      one: 'Last backup: yesterday',
      zero: 'Last backup: today',
    );
    return '$_temp0';
  }

  @override
  String get backup_restore => 'Restore backup';

  @override
  String get backup_restoreSub => 'Bring the shop back from a backup file';

  @override
  String get backup_restoreConfirmTitle => 'Replace everything on this phone?';

  @override
  String backup_restoreConfirmBody(
    String shop,
    int products,
    int sales,
    String date,
  ) {
    final intl.NumberFormat productsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String productsString = productsNumberFormat.format(products);
    final intl.NumberFormat salesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String salesString = salesNumberFormat.format(sales);

    return 'This backup of $shop has $productsString products and $salesString sales, made $date. Everything on this phone now will be replaced.';
  }

  @override
  String get backup_restoreButton => 'Restore';

  @override
  String get backup_restored => 'Shop restored from backup';

  @override
  String get backup_failed => 'Couldn\'t finish. Please try again.';

  @override
  String get backup_notBackup => 'That file isn\'t an EasySell backup.';

  @override
  String get backup_shareSubject => 'EasySell shop backup';

  @override
  String get teach_title => 'Photos for scanning';

  @override
  String get teach_none =>
      'Take 2–3 photos from different sides so Scan can recognise this product, even without a label.';

  @override
  String teach_count(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Scan knows this product from $countString photos. Every sale you scan teaches it more.',
      one:
          'Scan knows this product from 1 photo. Add one more from another side.',
    );
    return '$_temp0';
  }

  @override
  String get teach_add => 'Take photo';

  @override
  String get teach_learning => 'Learning…';

  @override
  String get teach_failed =>
      'Couldn\'t learn from that photo. Please try again.';

  @override
  String get teach_removeTitle => 'Remove this photo?';

  @override
  String get teach_remove => 'Remove';

  @override
  String get teach_fromScan => 'Learned from a scan';
}
