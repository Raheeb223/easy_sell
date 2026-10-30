// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get settings_title => 'সেটিংস';

  @override
  String get common_signOut => 'লগ আউট';

  @override
  String get settings_sectionProfile => 'প্রোফাইল';

  @override
  String get settings_sectionShop => 'দোকান';

  @override
  String get settings_sectionAppearance => 'চেহারা';

  @override
  String get settings_sectionInventory => 'পণ্য';

  @override
  String get settings_sectionLanguage => 'ভাষা';

  @override
  String get settings_appLanguage => 'অ্যাপের ভাষা';

  @override
  String get settings_guestSession => 'গেস্ট সেশন';

  @override
  String get settings_signedIn => 'সাইন ইন করা আছে';

  @override
  String get settings_anonymousData => 'বেনামী — ডেটা এই ডিভাইসে সংরক্ষিত';

  @override
  String get settings_shopName => 'দোকানের নাম';

  @override
  String get settings_address => 'ঠিকানা';

  @override
  String get settings_phone => 'ফোন';

  @override
  String get settings_currency => 'মুদ্রা';

  @override
  String get settings_themeLight => 'লাইট';

  @override
  String get settings_themeDark => 'ডার্ক';

  @override
  String get settings_manageCategories => 'ক্যাটাগরি পরিচালনা';

  @override
  String get settings_manageCategoriesSub => 'যোগ, নাম বদল বা মুছুন';

  @override
  String get settings_archivedProducts => 'আর্কাইভ পণ্য';

  @override
  String get settings_archivedProductsSub => 'সরানো পণ্য দেখুন ও ফেরান';

  @override
  String get common_restock => 'রিস্টক';

  @override
  String get common_sell => 'বিক্রি';

  @override
  String get common_period_today => 'আজ';

  @override
  String get common_period_week => 'সপ্তাহ';

  @override
  String get common_period_month => 'মাস';

  @override
  String get common_period_all => 'সব';

  @override
  String get dashboard_yourShop => 'আপনার দোকান';

  @override
  String get dashboard_notificationsCaughtUp => 'সব দেখা হয়ে গেছে';

  @override
  String get dashboard_notificationsHint =>
      'যে স্টকের মেয়াদ শেষ হচ্ছে বা শেষ হয়েছে, তা এখানে দেখাব।';

  @override
  String get dashboard_salesLast7 => 'বিক্রি · গত ৭ দিন';

  @override
  String dashboard_bestDay(String day) {
    return '$day সেরা';
  }

  @override
  String get dashboard_topPerformer => 'সেরা বিক্রেতা';

  @override
  String get dashboard_mvpBadge => 'সেরা';

  @override
  String get dashboard_noSalesYet =>
      'এখনো বিক্রি নেই — সেরা বিক্রেতা এখানে দেখাবে।';

  @override
  String dashboard_soldRevenue(String units, String revenue) {
    return '$units বিক্রি · $revenue আয়';
  }

  @override
  String get dashboard_viewAll => 'সব দেখুন';

  @override
  String get dashboard_couldNotLoadSummary => 'সারসংক্ষেপ লোড করা যায়নি।';

  @override
  String get dashboard_couldNotLoadSales => 'বিক্রি লোড করা যায়নি।';

  @override
  String dashboard_revenuePeriod(String period) {
    return 'আয় · $period';
  }

  @override
  String get dashboard_profit => 'লাভ';

  @override
  String get dashboard_margin => 'মার্জিন';

  @override
  String get dashboard_itemsSold => 'বিক্রি';

  @override
  String get dashboard_vsYesterday => 'গতকালের চেয়ে';

  @override
  String get dashboard_breakdown => 'বিস্তারিত';

  @override
  String dashboard_exactFigures(String period) {
    return '$period · সঠিক হিসাব';
  }

  @override
  String get dashboard_revenue => 'আয়';

  @override
  String get dashboard_costOfGoods => 'পণ্যের খরচ';

  @override
  String get dashboard_grossProfit => 'মোট লাভ';

  @override
  String get dashboard_avgItemPrice => 'গড় দাম';

  @override
  String get dashboard_viewFullReport => 'পূর্ণ রিপোর্ট দেখুন';

  @override
  String get common_cancel => 'বাতিল';

  @override
  String get common_delete => 'মুছুন';

  @override
  String get common_edit => 'এডিট';

  @override
  String get common_retry => 'আবার চেষ্টা';

  @override
  String get common_undo => 'ফিরিয়ে আনুন';

  @override
  String get common_off => 'বন্ধ';

  @override
  String get common_addToCart => 'কার্টে যোগ';

  @override
  String get common_addedToCart => 'কার্টে যোগ হয়েছে';

  @override
  String get common_stockAdded => 'স্টক যোগ হয়েছে';

  @override
  String get common_somethingWrong => 'কিছু ভুল হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get common_noInternet => 'ইন্টারনেট সংযোগ নেই';

  @override
  String get common_searchItems => 'পণ্য খুঁজুন';

  @override
  String get common_restore => 'ফেরান';

  @override
  String get inventory_title => 'পণ্যতালিকা';

  @override
  String inventory_itemsValue(int count, String value) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countStringটি পণ্য · $value';
  }

  @override
  String get inventory_valueTitle => 'স্টকের মূল্য';

  @override
  String get inventory_valueExact => 'সঠিক হিসাব';

  @override
  String get inventory_valueProducts => 'পণ্য';

  @override
  String get inventory_valueRetail => 'বিক্রয় মূল্য';

  @override
  String get inventory_valuePotentialProfit => 'সম্ভাব্য লাভ';

  @override
  String get inventory_filterAll => 'সব';

  @override
  String get inventory_filterLowStock => 'কম স্টক';

  @override
  String inventory_inStock(String qty) {
    return '$qty স্টকে';
  }

  @override
  String get inventory_noProducts =>
      'এখনো কোনো পণ্য নেই।\nশুরু করতে \"পণ্য যোগ\" চাপুন।';

  @override
  String get inventory_noMatch => 'আপনার ফিল্টারে কোনো পণ্য মেলেনি।';

  @override
  String get inventory_couldNotLoad =>
      'পণ্যতালিকা লোড করা যায়নি। রিফ্রেশ করুন।';

  @override
  String get inventory_addProduct => 'পণ্য যোগ';

  @override
  String get inventory_scanProduct => 'পণ্য স্ক্যান';

  @override
  String get inventory_couldNotLoadProduct => 'পণ্য লোড করা যায়নি।';

  @override
  String get inventory_productGone => 'এই পণ্যটি আর নেই।';

  @override
  String get inventory_removeTitle => 'পণ্য সরাবেন?';

  @override
  String inventory_removeBody(String name) {
    return '\"$name\" আপনার পণ্যতালিকা থেকে সরে যাবে। এর আগের বিক্রি রেকর্ডে থাকবে।';
  }

  @override
  String inventory_removed(String name) {
    return '\"$name\" সরানো হয়েছে';
  }

  @override
  String get inventory_lowStock => 'কম স্টক';

  @override
  String inventory_reorderThresholdNote(String threshold) {
    return 'রিঅর্ডার সীমার নিচে বা সমান ($threshold)।';
  }

  @override
  String get inventory_statInStock => 'স্টকে আছে';

  @override
  String get inventory_statBuyingPrice => 'কেনা দাম';

  @override
  String get inventory_statSellingPrice => 'বিক্রি দাম';

  @override
  String get inventory_statMarginPerUnit => 'মার্জিন / একক';

  @override
  String get inventory_statInventoryValue => 'স্টকের মূল্য (খরচ)';

  @override
  String get inventory_statReorderThreshold => 'রিঅর্ডার সীমা';

  @override
  String get inventory_couldNotLoadArchived =>
      'আর্কাইভ পণ্য লোড করা যায়নি। রিফ্রেশ করুন।';

  @override
  String inventory_restored(String name) {
    return '\"$name\" পণ্যতালিকায় ফিরেছে।';
  }

  @override
  String inventory_couldNotRestore(String name) {
    return '\"$name\" ফেরানো যায়নি। আবার চেষ্টা করুন।';
  }

  @override
  String get inventory_noArchived => 'কোনো আর্কাইভ পণ্য নেই।';

  @override
  String get inventory_archivedHint =>
      'পণ্যতালিকা থেকে সরানো পণ্য এখানে দেখাবে।';

  @override
  String get form_required => 'আবশ্যক';

  @override
  String get form_enterNumber => 'একটি সংখ্যা দিন';

  @override
  String get form_cannotBeNegative => 'ঋণাত্মক হতে পারে না';

  @override
  String get form_wholeNumberOnly => 'শুধু পূর্ণ সংখ্যা';

  @override
  String get form_enterValidAmount => 'সঠিক পরিমাণ দিন';

  @override
  String get unit_byPiece => 'পিস হিসেবে';

  @override
  String get unit_byWeight => 'ওজন হিসেবে';

  @override
  String get unit_byVolume => 'আয়তন হিসেবে';

  @override
  String get unit_hintPiece =>
      'পুরো পিস হিসেবে গোনা — সাবান, বোতলজাত পানীয়, প্যাকেট।';

  @override
  String get unit_hintWeight => 'ওজনে বিক্রি — চাল, আলু, ডাল, চিনি।';

  @override
  String get unit_hintVolume => 'আয়তনে বিক্রি — খোলা তেল, দুধ, কেরোসিন।';

  @override
  String get inventory_formAddTitle => 'পণ্য যোগ';

  @override
  String get inventory_formEditTitle => 'পণ্য এডিট';

  @override
  String get inventory_formHowSold => 'এই পণ্য কীভাবে বিক্রি হয়?';

  @override
  String get inventory_formName => 'নাম *';

  @override
  String get inventory_formBrand => 'ব্র্যান্ড';

  @override
  String get inventory_formVariant =>
      'ভ্যারিয়েন্ট (যেমন ৫০০ মিলি, ১ কেজি প্যাক)';

  @override
  String get inventory_formReorderAt => 'রিঅর্ডার সীমা';

  @override
  String inventory_formBuyingPrice(String perUnit) {
    return 'কেনা দাম$perUnit *';
  }

  @override
  String inventory_formSellingPrice(String perUnit) {
    return 'বিক্রি দাম$perUnit *';
  }

  @override
  String get inventory_formCreate => 'তৈরি করুন';

  @override
  String get inventory_formSaveChanges => 'পরিবর্তন সংরক্ষণ';

  @override
  String get inventory_formTryExample => 'একটি উদাহরণ দেখুন';

  @override
  String get inventory_formStockPieces => 'স্টক (পিস) *';

  @override
  String get inventory_formStock => 'স্টক *';

  @override
  String get common_save => 'সংরক্ষণ';

  @override
  String get common_add => 'যোগ';

  @override
  String get common_rename => 'নাম বদল';

  @override
  String get category_noShop => 'এই অ্যাকাউন্টে কোনো দোকান নেই।';

  @override
  String get category_renameTitle => 'ক্যাটাগরির নাম বদল';

  @override
  String get category_deleteTitle => 'ক্যাটাগরি মুছবেন?';

  @override
  String category_deleteBodyEmpty(String name) {
    return '\"$name\" সরিয়ে ফেলা হবে।';
  }

  @override
  String category_deleteBodyUsed(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি পণ্য',
      one: '১টি পণ্য',
    );
    return '\"$name\" সরিয়ে ফেলা হবে। $_temp0 ক্যাটাগরিহীন হবে (মুছে যাবে না)।';
  }

  @override
  String get category_addTooltip => 'ক্যাটাগরি যোগ';

  @override
  String get category_couldNotLoad => 'ক্যাটাগরি লোড করা যায়নি। রিফ্রেশ করুন।';

  @override
  String category_productCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি পণ্য',
      one: '১টি পণ্য',
    );
    return '$_temp0';
  }

  @override
  String get category_noneYet => 'এখনো কোনো ক্যাটাগরি নেই।';

  @override
  String get category_tapToAdd => 'যোগ করতে + চাপুন।';

  @override
  String get category_fieldLabel => 'ক্যাটাগরি';

  @override
  String get category_none => 'কোনো ক্যাটাগরি নয়';

  @override
  String get category_addNew => 'নতুন ক্যাটাগরি যোগ';

  @override
  String get category_alreadyExists => 'আগে থেকেই আছে — বেছে দেওয়া হলো';

  @override
  String get category_newTitle => 'নতুন ক্যাটাগরি';

  @override
  String get category_nameLabel => 'ক্যাটাগরির নাম';

  @override
  String get category_nameHint => 'যেমন ফ্রোজেন আইটেম';

  @override
  String get common_clear => 'খালি করুন';

  @override
  String get common_remove => 'মুছুন';

  @override
  String get common_quantity => 'পরিমাণ';

  @override
  String get common_subtotal => 'সাবটোটাল';

  @override
  String get common_couldNotRecognize =>
      'পণ্য শনাক্ত করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get cart_title => 'কার্ট';

  @override
  String cart_itemsInCart(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি পণ্য কার্টে',
      one: '১টি পণ্য কার্টে',
    );
    return '$_temp0';
  }

  @override
  String get cart_clearTitle => 'কার্ট খালি করবেন?';

  @override
  String get cart_clearBody =>
      'এটি কার্টের সব পণ্য সরিয়ে দেবে। কিছু বিক্রি হবে না।';

  @override
  String get cart_keep => 'থাক';

  @override
  String cart_totalItems(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি পণ্য',
      one: '১টি পণ্য',
    );
    return 'মোট · $_temp0';
  }

  @override
  String get cart_checkout => 'চেকআউট';

  @override
  String get cart_selling => 'বিক্রি হচ্ছে…';

  @override
  String get cart_empty => 'আপনার কার্ট খালি';

  @override
  String get cart_emptyHint =>
      'পণ্য বা স্ক্যান থেকে পণ্য যোগ করে বিক্রি শুরু করুন, তারপর এখানে চেকআউট করুন।';

  @override
  String cart_itemsSold(int count, String total) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি পণ্য বিক্রি',
      one: '১টি পণ্য বিক্রি',
    );
    return '$_temp0 · $total';
  }

  @override
  String get cart_checkoutFailed => 'চেকআউট ব্যর্থ। আবার চেষ্টা করুন।';

  @override
  String error_insufficientStock(String product) {
    return '$product স্টকে যথেষ্ট নেই';
  }

  @override
  String get error_cartEmpty => 'কার্ট খালি।';

  @override
  String get error_productNotFound => 'পণ্যটি আর নেই।';

  @override
  String get error_customerNotFound => 'গ্রাহকটি আর নেই।';

  @override
  String get error_discountExceedsTotal => 'ছাড় বিলের চেয়ে বেশি।';

  @override
  String get error_discountNegative => 'ছাড় ঋণাত্মক হতে পারে না।';

  @override
  String get error_quantityNotPositive => 'পরিমাণ শূন্যের বেশি হতে হবে।';

  @override
  String get cart_addDiscount => 'ছাড় দিন';

  @override
  String get cart_discount => 'ছাড়';

  @override
  String get cart_discountTitle => 'ছাড়';

  @override
  String get cart_discountAmount => 'ছাড়ের পরিমাণ';

  @override
  String get cart_discountEdit => 'ছাড় সম্পাদনা';

  @override
  String get cart_discountRemove => 'ছাড় সরান';

  @override
  String cart_discountBelowCost(String amount) {
    return 'এই বিক্রিতে $amount লোকসান হবে';
  }

  @override
  String get cart_discountInvalid => 'সঠিক পরিমাণ লিখুন';

  @override
  String get cart_apply => 'প্রয়োগ করুন';

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
      other: '$countStringটি পণ্য',
      one: '১টি পণ্য',
    );
    return '$_temp0 · $total';
  }

  @override
  String get addToCart_noMore => 'যোগ করার মতো আর নেই।';

  @override
  String addToCart_available(String qty, String unit) {
    return '$qty $unit যোগ করা যাবে';
  }

  @override
  String get restock_confirmTitle => 'রিস্টক নিশ্চিত করুন';

  @override
  String restock_inStock(String qty) {
    return 'স্টকে: $qty';
  }

  @override
  String get restock_unitCost => 'একক খরচ';

  @override
  String get restock_totalCost => 'মোট খরচ';

  @override
  String get scan_failed => 'স্ক্যান ব্যর্থ। আবার চেষ্টা করুন।';

  @override
  String scan_addedToCart(String name) {
    return '$name কার্টে যোগ হয়েছে';
  }

  @override
  String scan_read(String details) {
    return 'পড়া হয়েছে: $details';
  }

  @override
  String get scan_didYouMean => 'আপনি কি এটি বোঝাতে চেয়েছেন?';

  @override
  String get scan_noMatchPick => 'মেলেনি — পণ্য বেছে নিন';

  @override
  String get scan_searchProducts => 'পণ্য খুঁজুন';

  @override
  String scan_recognizing(int count) {
    return '$countটি শনাক্ত করা হচ্ছে…';
  }

  @override
  String scan_addItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি যোগ করুন',
      one: '১টি যোগ করুন',
    );
    return '$_temp0';
  }

  @override
  String get scan_addEmpty => 'যোগ করুন';

  @override
  String get scan_nothingYet => 'শুরু করতে স্ক্যান করুন';

  @override
  String get scan_tapToPick => 'বেছে নিতে চাপ দিন';

  @override
  String get scan_notIdentified => 'শনাক্ত করা যায়নি';

  @override
  String get scan_topSellers => 'সেরা বিক্রি';

  @override
  String get scan_outOfStock => 'স্টক নেই';

  @override
  String get scan_cameraDenied =>
      'স্ক্যান করতে ক্যামেরার অনুমতি দরকার। সেটিংসে গিয়ে অনুমতি দিন, তারপর আবার চেষ্টা করুন।';

  @override
  String get scan_openSettings => 'আবার চেষ্টা করুন';

  @override
  String get scan_cameraUnavailable =>
      'এই ডিভাইসে স্ক্যান করার মতো কোনো ক্যামেরা নেই।';

  @override
  String get scan_leaveTitle => 'যোগ না করেই চলে যাবেন?';

  @override
  String scan_leaveBody(int count) {
    return '$countটি স্ক্যান করা পণ্য এখনও কার্টে যোগ করা হয়নি।';
  }

  @override
  String get scan_discardTitle => 'বাকিগুলো যোগ করবেন?';

  @override
  String scan_discardBody(int count) {
    return '$countটি পণ্য যোগ করার মতো প্রস্তুত নয় (শনাক্ত হয়নি বা স্টকে নেই), সেগুলো বাদ পড়বে।';
  }

  @override
  String get common_discard => 'বাতিল করুন';

  @override
  String get history_title => 'বিক্রির হিসাব';

  @override
  String get history_search => 'বিক্রি খুঁজুন';

  @override
  String get history_couldNotLoad =>
      'বিক্রির হিসাব লোড করা যায়নি। রিফ্রেশ করুন।';

  @override
  String get history_noSalesYet => 'এখনো কোনো বিক্রি হয়নি।';

  @override
  String history_noSalesOnDay(String date) {
    return '$date তারিখে কোনো বিক্রি নেই।';
  }

  @override
  String get history_emptyHint =>
      'পণ্য থেকে একটি পণ্যে চাপ দিন → কার্টে যোগ করুন, অথবা কার্ট বার দিয়ে চেকআউট করে বিক্রি রেকর্ড করুন।';

  @override
  String get history_noMatch => 'আপনার খোঁজার সাথে কোনো বিক্রি মেলেনি।';

  @override
  String get history_saleFallback => 'বিক্রি';

  @override
  String get history_colTime => 'সময়';

  @override
  String get history_colItem => 'পণ্য';

  @override
  String get history_colQty => 'পরিমাণ';

  @override
  String get history_colAmount => 'মোট';

  @override
  String get saleDetail_title => 'বিক্রির বিবরণ';

  @override
  String get saleDetail_soldOn => 'বিক্রির সময়';

  @override
  String get saleDetail_quantity => 'পরিমাণ';

  @override
  String get saleDetail_priceEach => 'প্রতি একক দাম';

  @override
  String get saleDetail_total => 'মোট';

  @override
  String get saleDetail_discount => 'ছাড়';

  @override
  String get saleDetail_cost => 'খরচ';

  @override
  String get saleDetail_profit => 'লাভ';

  @override
  String get saleDetail_enteredBy => 'যেভাবে এন্ট্রি হয়েছে';

  @override
  String get saleDetail_paidBy => 'যেভাবে পরিশোধ';

  @override
  String get saleDetail_frozenNote => 'দাম বিক্রির মুহূর্তেই স্থির হয়ে যায়।';

  @override
  String get saleDetail_notFound => 'বিক্রি খুঁজে পাওয়া যায়নি।';

  @override
  String get saleDetail_sourceManual => 'ম্যানুয়াল';

  @override
  String get saleDetail_sourceVoice => 'ভয়েস';

  @override
  String get saleDetail_sourcePhoto => 'ছবি স্ক্যান';

  @override
  String get analytics_kicker => 'ব্যবসার রিপোর্ট';

  @override
  String get analytics_title => 'রিপোর্ট';

  @override
  String get analytics_noSalesPeriod => 'এই সময়ে এখনো কোনো বিক্রি নেই।';

  @override
  String get analytics_revenueSource => 'আয় কোথা থেকে আসছে';

  @override
  String get analytics_topShare => 'সেরা অংশ';

  @override
  String get analytics_biggestWins => 'সেরা বিক্রি';

  @override
  String analytics_carrying(String name, String scope) {
    return '$scope $name সবচেয়ে এগিয়ে।';
  }

  @override
  String get analytics_scopeToday => 'আজ';

  @override
  String get analytics_scopeWeek => 'এই সপ্তাহে';

  @override
  String get analytics_scopeMonth => 'এই মাসে';

  @override
  String get analytics_scopeAll => 'সব সময়';

  @override
  String analytics_scopeDay(String date) {
    return '$date তারিখে';
  }

  @override
  String analytics_units(String qty) {
    return '$qty একক';
  }

  @override
  String get auth_createAccount => 'আপনার অ্যাকাউন্ট তৈরি করুন';

  @override
  String get auth_welcomeBack => 'আবার স্বাগতম';

  @override
  String get auth_noInternet =>
      'ইন্টারনেট সংযোগ নেই। ইন্টারনেটে সংযুক্ত হয়ে আবার চেষ্টা করুন।';

  @override
  String get auth_fullName => 'পুরো নাম';

  @override
  String get auth_nameRequired => 'নাম দিতে হবে';

  @override
  String get auth_email => 'ইমেইল';

  @override
  String get auth_emailRequired => 'ইমেইল দিতে হবে';

  @override
  String get auth_emailInvalid => 'সঠিক ইমেইল দিন';

  @override
  String get auth_password => 'পাসওয়ার্ড';

  @override
  String get auth_passwordRequired => 'পাসওয়ার্ড দিতে হবে';

  @override
  String get auth_passwordMin => 'কমপক্ষে ৬ অক্ষর';

  @override
  String get auth_signUp => 'সাইন আপ';

  @override
  String get auth_signIn => 'সাইন ইন';

  @override
  String get auth_continueGoogle => 'Google দিয়ে চালিয়ে যান';

  @override
  String get auth_haveAccount => 'অ্যাকাউন্ট আছে? সাইন ইন করুন';

  @override
  String get auth_noAccount => 'অ্যাকাউন্ট নেই? সাইন আপ করুন';

  @override
  String get profile_tellUs => 'আপনার দোকান সম্পর্কে বলুন';

  @override
  String get profile_shopName => 'দোকানের নাম *';

  @override
  String get profile_shopNameRequired => 'দোকানের নাম দিতে হবে';

  @override
  String get profile_address => 'ঠিকানা (ঐচ্ছিক)';

  @override
  String get profile_phone => 'ফোন (ঐচ্ছিক)';

  @override
  String get profile_createShop => 'দোকান তৈরি করুন';

  @override
  String get welcome_headline => 'আপনার দোকান\nআরও স্মার্টভাবে চালান';

  @override
  String get welcome_subtitle =>
      'পণ্য হিসাব রাখুন, কথা বা ছবিতে বিক্রি রেকর্ড করুন, আর এক নজরে লাভ দেখুন।';

  @override
  String get welcome_getStarted => 'শুরু করুন';

  @override
  String get nav_home => 'হোম';

  @override
  String get nav_items => 'পণ্য';

  @override
  String get nav_reports => 'রিপোর্ট';

  @override
  String get nav_history => 'হিসাব';

  @override
  String get common_continue => 'চালিয়ে যান';

  @override
  String get onboarding_languageTitle => 'আপনার ভাষা বেছে নিন';

  @override
  String get onboarding_languageSubtitle =>
      'পরে যেকোনো সময় সেটিংসে এটি বদলাতে পারবেন।';

  @override
  String onboarding_step(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'ধাপ $currentString/$totalString';
  }

  @override
  String get onboarding_defaultCurrency => 'ডিফল্ট মুদ্রা *';

  @override
  String get customers_title => 'গ্রাহক';

  @override
  String customers_receivablesHeader(String amount, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString জন গ্রাহকের',
      one: '১ জন গ্রাহকের',
    );
    return '$_temp0 কাছে $amount পাওনা';
  }

  @override
  String get customers_empty => 'এখনো কোনো গ্রাহক নেই';

  @override
  String get customers_emptyHint =>
      'খাতা শুরু করতে একজন গ্রাহক যোগ করুন, অথবা চেকআউটে বাকি বেছে নিন।';

  @override
  String get customers_searchHint => 'নাম বা ফোন নম্বর দিয়ে খুঁজুন';

  @override
  String get customers_add => 'গ্রাহক যোগ';

  @override
  String get customers_edit => 'গ্রাহক এডিট';

  @override
  String get customers_fieldName => 'নাম';

  @override
  String get customers_fieldPhone => 'ফোন';

  @override
  String get customers_fieldNote => 'নোট (ঐচ্ছিক)';

  @override
  String get customers_nameRequired => 'নাম দিন';

  @override
  String get customers_phoneRequired => 'ফোন নম্বর দিন';

  @override
  String get customers_save => 'সংরক্ষণ';

  @override
  String get customers_delete => 'গ্রাহক মুছুন';

  @override
  String customers_deleteConfirmTitle(String name) {
    return '$name মুছবেন?';
  }

  @override
  String get customers_deleteConfirmBody =>
      'এটি গ্রাহক এবং তার খাতার হিসাব মুছে দেবে। শুধু হিসাব মেটানো গ্রাহকদের মুছা যাবে।';

  @override
  String customers_owes(String amount) {
    return '$amount বাকি';
  }

  @override
  String get customers_settled => 'পরিশোধিত';

  @override
  String get customers_balance => 'ব্যালেন্স';

  @override
  String get customers_ledgerEmpty => 'এখনো খাতায় কোনো হিসাব নেই';

  @override
  String get customers_recordPayment => 'টাকা জমা করুন';

  @override
  String get customers_paymentAmount => 'পরিমাণ';

  @override
  String get customers_paymentNote => 'নোট (ঐচ্ছিক)';

  @override
  String get customers_paymentAmountRequired => 'পরিমাণ দিন';

  @override
  String get customers_paymentTooLarge => 'বাকির চেয়ে বেশি';

  @override
  String get customers_paymentRecorded => 'টাকা জমা হয়েছে';

  @override
  String get customers_ledgerCreditSale => 'বাকিতে বিক্রি';

  @override
  String get customers_ledgerPayment => 'জমা';

  @override
  String get cart_paymentCash => 'নগদ';

  @override
  String get cart_paymentCredit => 'বাকি';

  @override
  String get cart_paymentDigital => 'ডিজিটাল';

  @override
  String get cart_selectCustomer => 'গ্রাহক বেছে নিন';

  @override
  String cart_addToKhata(String name) {
    return '$name-এর খাতায় যোগ করুন';
  }

  @override
  String cart_addedToKhata(String name, String total) {
    return '$name-এর খাতায় যোগ হয়েছে · $total';
  }

  @override
  String get dashboard_receivablesTitle => 'পাওনা';

  @override
  String get voice_title => 'বিক্রির কথা বলুন';

  @override
  String get voice_hintIdle => 'মাইকে ট্যাপ করে বলুন কী বিক্রি হয়েছে';

  @override
  String get voice_recording => 'শুনছি…';

  @override
  String get voice_thinking => 'বুঝে নিচ্ছি…';

  @override
  String get voice_stageHeard => 'শুনেছি';

  @override
  String get voice_stageUnderstanding => 'কী বললেন বুঝছি';

  @override
  String get voice_stageMatching => 'আপনার পণ্য খুঁজছি';

  @override
  String get voice_thinkingDismissHint => 'তৈরি হলে জানিয়ে দেব';

  @override
  String get voice_thinkingMinimize => 'পিছনে চলতে থাকুক';

  @override
  String get voice_bannerWorking => 'ভয়েস বিক্রি নিয়ে কাজ চলছে…';

  @override
  String get voice_bannerCancel => 'এই ভয়েস বিক্রি বাতিল করুন';

  @override
  String get voice_bannerReady => 'আপনার ভয়েস বিক্রি তৈরি';

  @override
  String get voice_bannerFailed => 'ভয়েস বিক্রিটি একবার দেখুন';

  @override
  String get voice_bannerAction => 'দেখুন';

  @override
  String get voice_heard => 'আমি শুনেছি';

  @override
  String get voice_recheck => 'আবার দেখুন';

  @override
  String get voice_whichOne => 'কোনটি?';

  @override
  String get voice_pick => 'বেছে নিন';

  @override
  String get voice_addToCart => 'কার্টে যোগ করুন';

  @override
  String get voice_assumedQty => '১ ধরে নেওয়া হয়েছে — দেখে নিন';

  @override
  String voice_lowStock(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'স্টকে আছে মাত্র $countStringটি';
  }

  @override
  String get voice_errNoSpeech => 'শুনতে পাইনি। আবার চেষ্টা করুন।';

  @override
  String get voice_errNoMatch => 'আপনার বলা কিছুই মেলাতে পারিনি।';

  @override
  String get voice_errMicDenied =>
      'মাইক্রোফোনের অনুমতি বন্ধ আছে। সেটিংসে গিয়ে চালু করুন।';

  @override
  String get voice_errOffline =>
      'আপনি অফলাইনে আছেন। ইন্টারনেট চালু করে আবার চেষ্টা করুন।';

  @override
  String get voice_errTooQuiet =>
      'মাইক্রোফোন কোনো শব্দ পায়নি। ফোনটি আরও কাছে ধরে আবার চেষ্টা করুন।';

  @override
  String get voice_retry => 'আবার চেষ্টা করুন';

  @override
  String get voice_recordAgain => 'আবার রেকর্ড করুন';

  @override
  String get voice_typeInstead => 'লিখে দিন';

  @override
  String voice_stoppingIn(int seconds) {
    return '$seconds সেকেন্ডে বন্ধ হবে';
  }

  @override
  String get voice_speakCloser => 'শুনতে পাচ্ছি না — ফোনটি আরও কাছে ধরুন';

  @override
  String get voice_levelLabel => 'মাইক্রোফোনের মাত্রা';

  @override
  String get expiry_dateLabel => 'মেয়াদ শেষের তারিখ';

  @override
  String get expiry_dateOptional => 'ঐচ্ছিক';

  @override
  String get expiry_dateClear => 'তারিখ মুছুন';

  @override
  String get expiry_pastDateTitle => 'এই তারিখ পার হয়ে গেছে';

  @override
  String get expiry_pastDateBody => 'তবুও সংরক্ষণ করবেন?';

  @override
  String get expiry_farDateTitle => 'সালটা কি ঠিক আছে?';

  @override
  String expiry_farDateBody(String date) {
    return '$date পাঁচ বছরেরও বেশি পরে।';
  }

  @override
  String get expiry_saveAnyway => 'তবুও সংরক্ষণ';

  @override
  String get expiry_changeDate => 'তারিখ বদলান';

  @override
  String get expiry_moreOptions => 'আরও অপশন';

  @override
  String get expiry_warnDaysLabel => 'মেয়াদ শেষের কত দিন আগে জানাবে';

  @override
  String get expiry_warnDaysHint => 'খালি রাখলে অ্যাপ নিজে ঠিক করবে';

  @override
  String get expiry_unitChangeBlocked =>
      'একক বদলানোর আগে এই পণ্যের ডেলিভারিগুলো বন্ধ করুন';

  @override
  String get expiry_savedWithoutDate =>
      'পণ্য সংরক্ষিত হয়েছে, কিন্তু মেয়াদের তারিখ হয়নি। পণ্যের পাতা থেকে যোগ করুন।';

  @override
  String get expiry_deliveries => 'ডেলিভারি';

  @override
  String get expiry_addDate => 'মেয়াদের তারিখ যোগ করুন';

  @override
  String expiry_rowDates(String added, String expiry) {
    return 'যোগ $added · মেয়াদ $expiry';
  }

  @override
  String expiry_rowLeft(String qty, String unit) {
    return 'আনুমানিক $qty $unit বাকি';
  }

  @override
  String get expiry_statusGood => 'ভালো';

  @override
  String get expiry_statusSoon => 'মেয়াদ শেষ হচ্ছে';

  @override
  String get expiry_statusExpired => 'মেয়াদোত্তীর্ণ';

  @override
  String get expiry_removeFromStock => 'স্টক থেকে বাদ দিন';

  @override
  String expiry_thrownAway(String qty, String unit, String amount) {
    return 'ফেলে দেওয়া: $qty $unit · $amount ক্ষতি';
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
      other: 'আমি প্রতি $daysString দিনে রিস্টক করি',
      one: 'আমি প্রতিদিন রিস্টক করি',
    );
    return '$_temp0';
  }

  @override
  String get settings_restockEveryTitle => 'কত দিন পরপর রিস্টক করেন?';

  @override
  String restockPlan_daysShort(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString দিন',
      one: '১ দিন',
    );
    return '$_temp0';
  }

  @override
  String get restockPlan_title => 'রিস্টক তালিকা';

  @override
  String get restockPlan_buyNow => 'এখন কিনুন';

  @override
  String restockPlan_enough(String count) {
    return 'আপাতত যথেষ্ট ($count)';
  }

  @override
  String get restockPlan_runsOutToday => 'আজই শেষ হবে';

  @override
  String restockPlan_runsOutIn(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString দিনে শেষ হবে',
      one: '১ দিনে শেষ হবে',
    );
    return '$_temp0';
  }

  @override
  String get restockPlan_today => 'আজ';

  @override
  String get restockPlan_atReorderLevel => 'রিঅর্ডার লেভেলে পৌঁছেছে';

  @override
  String get restockPlan_lowShort => 'কম স্টক';

  @override
  String restockPlan_buyAbout(String qty, String unit) {
    return 'প্রায় $qty $unit কিনুন';
  }

  @override
  String restockPlan_inStock(String qty, String unit) {
    return 'স্টকে $qty $unit';
  }

  @override
  String get restockPlan_empty =>
      'এখনো রিস্টক করার কিছু নেই। কয়েক দিনের বিক্রির পর পরামর্শ দেখা যাবে।';

  @override
  String get restockPlan_loadError => 'রিস্টক তালিকা লোড করা যায়নি।';

  @override
  String get restockPlan_cardTitle => 'শীঘ্রই রিস্টক করুন';

  @override
  String restockPlan_cardSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি পণ্য রিস্টক করতে হবে',
      one: '১টি পণ্য রিস্টক করতে হবে',
    );
    return '$_temp0';
  }

  @override
  String restockPlan_cardItem(String name, String days) {
    return '$name · $days';
  }

  @override
  String get expiry_formAddTitle => 'মেয়াদের তারিখ যোগ করুন';

  @override
  String get expiry_formEditTitle => 'ডেলিভারি সম্পাদনা';

  @override
  String get expiry_formAmount => 'পরিমাণ';

  @override
  String get expiry_formReceived => 'যোগের তারিখ';

  @override
  String get expiry_amountInvalid => '০-এর বেশি পরিমাণ লিখুন';

  @override
  String get expiry_dateRequired => 'মেয়াদের তারিখ বেছে নিন';

  @override
  String expiry_removeConfirmTitle(String qty, String unit, String name) {
    return '$name-এর $qty $unit বাদ দেবেন?';
  }

  @override
  String get expiry_removeConfirmBody =>
      'স্টক কমবে এবং ক্ষতি লেখা থাকবে। বিক্রির হিসাব বদলাবে না।';

  @override
  String get expiry_removed => 'স্টক থেকে বাদ দেওয়া হয়েছে';

  @override
  String expiry_removeAmountTitle(String name) {
    return '$name স্টক থেকে বাদ দেবেন?';
  }

  @override
  String get expiry_removeAmountLabel => 'কতগুলো?';

  @override
  String expiry_cartOnlyGood(String good, String name, String expired) {
    return 'ভালো $name মাত্র $good বাকি ($expired মেয়াদোত্তীর্ণ)';
  }

  @override
  String expiry_cartOnlyExpired(String name, String expired) {
    return 'শুধু মেয়াদোত্তীর্ণ $name বাকি ($expired)';
  }

  @override
  String get expiry_cartRemoveExpired => 'মেয়াদোত্তীর্ণ বাদ দিন';

  @override
  String get expiry_cartNotExpired => 'মেয়াদ শেষ হয়নি';

  @override
  String expiry_cartOnlyLeft(String qty, String unit) {
    return 'মাত্র $qty $unit বাকি';
  }

  @override
  String expiry_addSheetExpiredNote(String qty, String unit) {
    return '$qty $unit মেয়াদোত্তীর্ণ — গণনা হয়নি';
  }

  @override
  String get error_expiredStockInCart =>
      'কার্টের কিছু পণ্যের মেয়াদ শেষ। চেকআউটের আগে ঠিক করুন।';

  @override
  String get error_batchShortInCart =>
      'আপনার বাছাই করা ব্যাচে যথেষ্ট নেই। কার্ট দেখুন।';

  @override
  String get error_batchNotAvailable =>
      'ওই ব্যাচটি আর নেই। কার্টে অন্য ব্যাচ বাছুন।';

  @override
  String cart_batchLabel(String choice) {
    return 'ব্যাচ: $choice';
  }

  @override
  String get cart_batchMix => 'একাধিক ব্যাচ, আগে যার মেয়াদ শেষ';

  @override
  String get cart_batchChoose => 'বাছুন';

  @override
  String get cart_batchChooseNotice => 'কোন ব্যাচ থেকে দিচ্ছেন বাছুন';

  @override
  String get error_batchNotChosen => 'কার্টে চিহ্নিত পণ্যের ব্যাচ বাছুন।';

  @override
  String get cart_batchNoDate => 'মেয়াদের তারিখ নেই';

  @override
  String cart_batchExpires(String date) {
    return 'মেয়াদ $date';
  }

  @override
  String get cart_batchPickTitle => 'কোন ব্যাচ থেকে বিক্রি করবেন?';

  @override
  String cart_batchOptionLeft(String qty, String unit) {
    return '$qty $unit বাকি';
  }

  @override
  String cart_batchShort(String qty, String unit) {
    return 'এই ব্যাচে মাত্র $qty $unit বাকি';
  }

  @override
  String get cart_batchGone => 'এই ব্যাচটি আর নেই। অন্যটি বাছুন।';

  @override
  String expiry_alertExpired(String qty, String name) {
    return 'মেয়াদোত্তীর্ণ: $qty $name';
  }

  @override
  String expiry_alertSoonToday(String name, String qty) {
    return '$name: $qty আজ মেয়াদ শেষ';
  }

  @override
  String expiry_alertSoonTomorrow(String name, String qty) {
    return '$name: $qty আগামীকাল মেয়াদ শেষ';
  }

  @override
  String expiry_alertSoonDays(String name, String qty, String days) {
    return '$name: $qty $days দিনে মেয়াদ শেষ';
  }

  @override
  String get expiry_cardTitle => 'মেয়াদ শেষ ও শেষ হচ্ছে';

  @override
  String get expiry_alertsTitle => 'মেয়াদের সতর্কতা';

  @override
  String get expiry_filter => 'মেয়াদ শেষ হচ্ছে';

  @override
  String get reminder_title => 'মেয়াদ যাচাই';

  @override
  String reminder_more(String count) {
    return '+আরও $countটি';
  }

  @override
  String get reminder_channelName => 'মেয়াদের রিমাইন্ডার';

  @override
  String get settings_sectionExpiry => 'মেয়াদ';

  @override
  String settings_expiryWarnDays(String days) {
    return 'সর্বোচ্চ $days দিন আগে জানাবে';
  }

  @override
  String get settings_expiryWarnDaysTitle => 'সতর্কতার সময়';

  @override
  String settings_expiryDaysOption(String days) {
    return '$days দিন';
  }

  @override
  String get settings_expiryReminder => 'প্রতিদিনের মেয়াদ রিমাইন্ডার';

  @override
  String get settings_expiryReminderSub => 'কিছু দেখার থাকলে সকাল ৯টায়';

  @override
  String get settings_expiryReminderBlocked =>
      'বন্ধ — ফোনের সেটিংসে নোটিফিকেশন চালু করুন';

  @override
  String get finance_title => 'টাকার অবস্থা';

  @override
  String get finance_last7Days => 'গত ৭ দিন';

  @override
  String get finance_in => 'এসেছে';

  @override
  String get finance_out => 'গেছে';

  @override
  String get finance_net => 'নিট';

  @override
  String get finance_allGood => 'এই সপ্তাহে টাকা নিয়ে কোনো সতর্কতা নেই';

  @override
  String finance_alertOverdue(String name, String amount, String days) {
    return '$name-এর কাছে $amount বাকি, $days দিন ধরে';
  }

  @override
  String finance_alertOverdueMore(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'আরও $countString জন গ্রাহকের বাকি দেরি হয়েছে',
      one: 'আরও ১ জন গ্রাহকের বাকি দেরি হয়েছে',
    );
    return '$_temp0';
  }

  @override
  String finance_alertCashShort(String amount) {
    return 'রিস্টকের খরচ আসা টাকার চেয়ে $amount বেশি';
  }

  @override
  String finance_alertCreditGrowing(String rise, String total) {
    return 'এই সপ্তাহে বাকি বেড়েছে $rise (এখন $total)';
  }

  @override
  String finance_alertSalesDrop(String percent) {
    return 'আগের সপ্তাহের চেয়ে বিক্রি $percent কমেছে';
  }

  @override
  String finance_financingFooter(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringটি ঋণের বিকল্প আপনার দোকানের সাথে মেলে',
      one: '১টি ঋণের বিকল্প আপনার দোকানের সাথে মেলে',
      zero: 'আপনার দোকানের ঋণের বিকল্প দেখুন',
    );
    return '$_temp0';
  }

  @override
  String get finance_rowCashSales => 'নগদ বিক্রি';

  @override
  String get finance_rowDigitalSales => 'ডিজিটাল বিক্রি';

  @override
  String get finance_rowCollected => 'বাকি আদায়';

  @override
  String get finance_rowMoneyIn => 'মোট এসেছে';

  @override
  String get finance_rowRestocks => 'রিস্টক';

  @override
  String get finance_rowMoneyOut => 'মোট গেছে';

  @override
  String get finance_rowCreditGiven => 'বাকিতে বিক্রি (এখনো পাওয়া যায়নি)';

  @override
  String get finance_outNote => 'খরচে শুধু রিস্টক ধরা হয়েছে।';

  @override
  String get finance_alertsTitle => 'সতর্কতা';

  @override
  String get finance_financingTitle => 'আপনার দোকানের জন্য ঋণ';

  @override
  String get finance_financingIntro => 'গত ৯০ দিনের বিক্রি দেখে মেলানো হয়েছে।';

  @override
  String get finance_fits => 'মেলে';

  @override
  String get finance_notYet => 'এখনো না';

  @override
  String finance_upTo(String amount) {
    return 'সর্বোচ্চ প্রায় $amount';
  }

  @override
  String get finance_kindSupplier => 'সাপ্লায়ারের কাছে বাকি';

  @override
  String get finance_kindSupplierSub =>
      'এখন মাল নিন, ৩০ দিনে সাপ্লায়ারকে টাকা দিন';

  @override
  String get finance_kindWallet => 'মোবাইল ওয়ালেটের ছোট ঋণ';

  @override
  String get finance_kindWalletSub => 'ডিজিটাল বিক্রি দেখে দ্রুত ছোট ঋণ';

  @override
  String get finance_kindMicro => 'দোকানের ক্ষুদ্রঋণ';

  @override
  String get finance_kindMicroSub =>
      'সাপ্তাহিক কিস্তি, নিয়মিত চলা ছোট দোকানের জন্য';

  @override
  String get finance_kindSme => 'ব্যাংকের SME ঋণ';

  @override
  String get finance_kindSmeSub => 'দোকান বড় করার জন্য বড় ঋণ';

  @override
  String finance_whySupplier(String amount) {
    return 'আপনি মাসে প্রায় $amount-এর মাল তোলেন';
  }

  @override
  String finance_whyWallet(String percent) {
    return 'আপনার বিক্রির $percent ডিজিটালে';
  }

  @override
  String finance_whyMicro(String weeks) {
    return 'গত ১২ সপ্তাহের $weeks সপ্তাহে বিক্রি হয়েছে';
  }

  @override
  String finance_whySme(String months, String percent) {
    return '$months মাসের ব্যবসা, লাভের হার $percent';
  }

  @override
  String finance_gapTrade(int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'আরও $monthsString মাস ব্যবসা চালিয়ে যান',
      one: 'আরও ১ মাস ব্যবসা চালিয়ে যান',
    );
    return '$_temp0';
  }

  @override
  String get finance_gapRestock => 'আগে অ্যাপে রিস্টক লিখে রাখুন';

  @override
  String finance_gapWeeks(String needed, String have) {
    return 'প্রতি ১২ সপ্তাহের $needed সপ্তাহে বিক্রি করুন (এখন $have)';
  }

  @override
  String finance_gapDigital(String target, String have) {
    return 'অন্তত $target বিক্রি ডিজিটালে নিন (এখন $have)';
  }

  @override
  String finance_gapMargin(String target, String have) {
    return 'লাভের হার $target করুন (এখন $have)';
  }

  @override
  String get finance_gapCredit =>
      'বাকি আদায় করে অর্ধেক মাসের বিক্রির নিচে আনুন';

  @override
  String get finance_disclaimer =>
      'এগুলো মেলানো কীভাবে কাজ করে তা দেখানোর উদাহরণ, ঋণের প্রস্তাব নয়। আসল শর্তের জন্য ঋণদাতার সাথে কথা বলুন।';

  @override
  String get finance_loadError =>
      'টাকার অবস্থা আনা যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।';

  @override
  String get finance_tipsAsk => 'EasySell AI থেকে পরামর্শ নিন';

  @override
  String get finance_tipsThinking => 'ভাবছে…';

  @override
  String get finance_tipsTitle => 'AI পরামর্শ';

  @override
  String get finance_tipsNote =>
      'ওপরের হিসাব দেখে বলা। কিছু করার আগে মিলিয়ে নিন।';

  @override
  String get finance_tipsError => 'এখন পরামর্শ আনা যায়নি।';

  @override
  String finance_tipOverdue(String name, String amount) {
    return 'এই সপ্তাহে $name-এর কাছে যান বা ফোন করুন, বাকি $amount থেকে কিছু আদায় করুন।';
  }

  @override
  String finance_tipCashShort(String amount) {
    return 'এই সপ্তাহে কম করে রিস্টক করুন: রিস্টকের খরচ আসা টাকার চেয়ে $amount বেশি।';
  }

  @override
  String finance_tipCreditGrowing(String total) {
    return 'এই সপ্তাহে নতুন বাকি কম দিন, আগে পুরনো বাকি আদায় করুন। এখন মোট বাকি $total।';
  }

  @override
  String finance_tipSalesDrop(String percent) {
    return 'বিক্রি $percent কমেছে। কোন মাল শেষ হয়ে গেছে দেখুন, বেশি বিক্রির মাল আগে আনুন।';
  }

  @override
  String finance_tipCollectEarly(String amount) {
    return 'গ্রাহকদের কাছে বাকি $amount পুরনো হওয়ার আগেই আদায় করুন। অল্প অল্প করে নিয়মিত তোলা সহজ।';
  }

  @override
  String get finance_tipGoDigital =>
      'গ্রাহকদের বেশি করে মোবাইল ওয়ালেটে টাকা দিতে বলুন। ডিজিটাল বিক্রির হিসাব ঋণদাতারা বেশি বিশ্বাস করে।';

  @override
  String finance_tipFinancing(String option) {
    return '$option আপনার দোকানের কাজে আসতে পারে। সিদ্ধান্ত নেওয়ার আগে ঋণদাতার শর্ত মিলিয়ে দেখুন।';
  }

  @override
  String get finance_tipKeepRecording =>
      'প্রতিটি বিক্রি আর রিস্টক অ্যাপে তুলে রাখুন, তাহলে টাকার হিসাব ঠিক থাকবে।';

  @override
  String get backup_section => 'আপনার ডেটা';

  @override
  String get backup_now => 'এখনই ব্যাকআপ নিন';

  @override
  String get backup_never =>
      'কখনো ব্যাকআপ নেওয়া হয়নি। আপনার দোকানের সব হিসাব শুধু এই ফোনে আছে।';

  @override
  String backup_daysAgo(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'শেষ ব্যাকআপ: $daysString দিন আগে',
      one: 'শেষ ব্যাকআপ: গতকাল',
      zero: 'শেষ ব্যাকআপ: আজ',
    );
    return '$_temp0';
  }

  @override
  String get backup_restore => 'ব্যাকআপ ফেরত আনুন';

  @override
  String get backup_restoreSub => 'ব্যাকআপ ফাইল থেকে দোকানের হিসাব ফেরত আনুন';

  @override
  String get backup_restoreConfirmTitle => 'এই ফোনের সব হিসাব বদলে দেবেন?';

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

    return '$shop-এর এই ব্যাকআপে $productsStringটি পণ্য আর $salesStringটি বিক্রি আছে, তৈরি $date। এই ফোনের এখনকার সব হিসাব বদলে যাবে।';
  }

  @override
  String get backup_restoreButton => 'ফেরত আনুন';

  @override
  String get backup_restored => 'ব্যাকআপ থেকে দোকান ফেরত আনা হয়েছে';

  @override
  String get backup_failed => 'শেষ করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get backup_notBackup => 'এই ফাইলটি EasySell ব্যাকআপ নয়।';

  @override
  String get backup_shareSubject => 'EasySell দোকানের ব্যাকআপ';

  @override
  String get teach_title => 'স্ক্যানের জন্য ছবি';

  @override
  String get teach_none =>
      'বিভিন্ন দিক থেকে ২–৩টি ছবি তুলুন, তাহলে লেবেল ছাড়াও স্ক্যান এই পণ্যটি চিনবে।';

  @override
  String teach_count(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'স্ক্যান এই পণ্যটি $countStringটি ছবি থেকে চেনে। প্রতিটি স্ক্যান করা বিক্রি থেকে আরও শেখে।',
      one: 'স্ক্যান এই পণ্যটি ১টি ছবি থেকে চেনে। অন্য দিক থেকে আরেকটি তুলুন।',
    );
    return '$_temp0';
  }

  @override
  String get teach_add => 'ছবি তুলুন';

  @override
  String get teach_learning => 'শিখছে…';

  @override
  String get teach_failed => 'এই ছবি থেকে শেখা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get teach_removeTitle => 'এই ছবিটি সরাবেন?';

  @override
  String get teach_remove => 'সরান';

  @override
  String get teach_fromScan => 'স্ক্যান থেকে শেখা';
}
