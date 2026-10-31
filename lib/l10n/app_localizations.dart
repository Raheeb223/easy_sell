import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

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
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// No description provided for @common_signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get common_signOut;

  /// No description provided for @settings_sectionProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settings_sectionProfile;

  /// No description provided for @settings_sectionShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get settings_sectionShop;

  /// No description provided for @settings_sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settings_sectionAppearance;

  /// No description provided for @settings_sectionInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get settings_sectionInventory;

  /// No description provided for @settings_sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_sectionLanguage;

  /// No description provided for @settings_appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settings_appLanguage;

  /// No description provided for @settings_guestSession.
  ///
  /// In en, this message translates to:
  /// **'Guest session'**
  String get settings_guestSession;

  /// No description provided for @settings_signedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get settings_signedIn;

  /// No description provided for @settings_anonymousData.
  ///
  /// In en, this message translates to:
  /// **'Anonymous — data is tied to this device'**
  String get settings_anonymousData;

  /// No description provided for @settings_shopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get settings_shopName;

  /// No description provided for @settings_address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get settings_address;

  /// No description provided for @settings_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get settings_phone;

  /// No description provided for @settings_currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settings_currency;

  /// No description provided for @settings_themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settings_themeLight;

  /// No description provided for @settings_themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settings_themeDark;

  /// No description provided for @settings_manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get settings_manageCategories;

  /// No description provided for @settings_manageCategoriesSub.
  ///
  /// In en, this message translates to:
  /// **'Rename, add, or remove categories'**
  String get settings_manageCategoriesSub;

  /// No description provided for @settings_archivedProducts.
  ///
  /// In en, this message translates to:
  /// **'Archived products'**
  String get settings_archivedProducts;

  /// No description provided for @settings_archivedProductsSub.
  ///
  /// In en, this message translates to:
  /// **'View and restore removed products'**
  String get settings_archivedProductsSub;

  /// No description provided for @common_restock.
  ///
  /// In en, this message translates to:
  /// **'Restock'**
  String get common_restock;

  /// No description provided for @common_sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get common_sell;

  /// No description provided for @common_period_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get common_period_today;

  /// No description provided for @common_period_week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get common_period_week;

  /// No description provided for @common_period_month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get common_period_month;

  /// No description provided for @common_period_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get common_period_all;

  /// No description provided for @dashboard_yourShop.
  ///
  /// In en, this message translates to:
  /// **'Your shop'**
  String get dashboard_yourShop;

  /// No description provided for @dashboard_notificationsCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get dashboard_notificationsCaughtUp;

  /// No description provided for @dashboard_notificationsHint.
  ///
  /// In en, this message translates to:
  /// **'We\'ll show stock that is about to expire, or has expired, here.'**
  String get dashboard_notificationsHint;

  /// No description provided for @dashboard_salesLast7.
  ///
  /// In en, this message translates to:
  /// **'Sales · last 7 days'**
  String get dashboard_salesLast7;

  /// No description provided for @dashboard_bestDay.
  ///
  /// In en, this message translates to:
  /// **'{day} best'**
  String dashboard_bestDay(String day);

  /// No description provided for @dashboard_topPerformer.
  ///
  /// In en, this message translates to:
  /// **'TOP PERFORMER'**
  String get dashboard_topPerformer;

  /// No description provided for @dashboard_mvpBadge.
  ///
  /// In en, this message translates to:
  /// **'MVP'**
  String get dashboard_mvpBadge;

  /// No description provided for @dashboard_noSalesYet.
  ///
  /// In en, this message translates to:
  /// **'No sales yet — your best seller will appear here.'**
  String get dashboard_noSalesYet;

  /// No description provided for @dashboard_soldRevenue.
  ///
  /// In en, this message translates to:
  /// **'{units} sold · {revenue} revenue'**
  String dashboard_soldRevenue(String units, String revenue);

  /// No description provided for @dashboard_viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get dashboard_viewAll;

  /// No description provided for @dashboard_couldNotLoadSummary.
  ///
  /// In en, this message translates to:
  /// **'Could not load summary.'**
  String get dashboard_couldNotLoadSummary;

  /// No description provided for @dashboard_couldNotLoadSales.
  ///
  /// In en, this message translates to:
  /// **'Could not load sales.'**
  String get dashboard_couldNotLoadSales;

  /// No description provided for @dashboard_revenuePeriod.
  ///
  /// In en, this message translates to:
  /// **'Revenue · {period}'**
  String dashboard_revenuePeriod(String period);

  /// No description provided for @dashboard_profit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get dashboard_profit;

  /// No description provided for @dashboard_margin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get dashboard_margin;

  /// No description provided for @dashboard_itemsSold.
  ///
  /// In en, this message translates to:
  /// **'Items sold'**
  String get dashboard_itemsSold;

  /// No description provided for @dashboard_vsYesterday.
  ///
  /// In en, this message translates to:
  /// **'vs yesterday'**
  String get dashboard_vsYesterday;

  /// No description provided for @dashboard_breakdown.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get dashboard_breakdown;

  /// No description provided for @dashboard_exactFigures.
  ///
  /// In en, this message translates to:
  /// **'{period} · exact figures'**
  String dashboard_exactFigures(String period);

  /// No description provided for @dashboard_revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get dashboard_revenue;

  /// No description provided for @dashboard_costOfGoods.
  ///
  /// In en, this message translates to:
  /// **'Cost of goods'**
  String get dashboard_costOfGoods;

  /// No description provided for @dashboard_grossProfit.
  ///
  /// In en, this message translates to:
  /// **'Gross profit'**
  String get dashboard_grossProfit;

  /// No description provided for @dashboard_avgItemPrice.
  ///
  /// In en, this message translates to:
  /// **'Avg item price'**
  String get dashboard_avgItemPrice;

  /// No description provided for @dashboard_viewFullReport.
  ///
  /// In en, this message translates to:
  /// **'View full report'**
  String get dashboard_viewFullReport;

  /// No description provided for @common_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// No description provided for @common_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get common_delete;

  /// No description provided for @common_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get common_edit;

  /// No description provided for @common_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get common_retry;

  /// No description provided for @common_undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get common_undo;

  /// No description provided for @common_off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get common_off;

  /// No description provided for @common_addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get common_addToCart;

  /// No description provided for @common_addedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added to cart'**
  String get common_addedToCart;

  /// No description provided for @common_stockAdded.
  ///
  /// In en, this message translates to:
  /// **'Stock added'**
  String get common_stockAdded;

  /// No description provided for @common_somethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get common_somethingWrong;

  /// No description provided for @common_noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get common_noInternet;

  /// No description provided for @common_searchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items'**
  String get common_searchItems;

  /// No description provided for @common_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get common_restore;

  /// No description provided for @inventory_title.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory_title;

  /// Items screen subtitle. The trailing 'value' word was dropped so the line fits a cramped header; the tap-to-expand sheet names the figure.
  ///
  /// In en, this message translates to:
  /// **'{count} items · {value}'**
  String inventory_itemsValue(int count, String value);

  /// No description provided for @inventory_valueTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory value'**
  String get inventory_valueTitle;

  /// No description provided for @inventory_valueExact.
  ///
  /// In en, this message translates to:
  /// **'Exact figures'**
  String get inventory_valueExact;

  /// No description provided for @inventory_valueProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get inventory_valueProducts;

  /// No description provided for @inventory_valueRetail.
  ///
  /// In en, this message translates to:
  /// **'Retail value'**
  String get inventory_valueRetail;

  /// No description provided for @inventory_valuePotentialProfit.
  ///
  /// In en, this message translates to:
  /// **'Potential profit'**
  String get inventory_valuePotentialProfit;

  /// No description provided for @inventory_filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get inventory_filterAll;

  /// No description provided for @inventory_filterLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get inventory_filterLowStock;

  /// No description provided for @inventory_inStock.
  ///
  /// In en, this message translates to:
  /// **'{qty} in stock'**
  String inventory_inStock(String qty);

  /// No description provided for @inventory_noProducts.
  ///
  /// In en, this message translates to:
  /// **'No products yet.\nTap \"Add product\" to start.'**
  String get inventory_noProducts;

  /// No description provided for @inventory_noMatch.
  ///
  /// In en, this message translates to:
  /// **'No products match your filters.'**
  String get inventory_noMatch;

  /// No description provided for @inventory_couldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load inventory. Pull to retry.'**
  String get inventory_couldNotLoad;

  /// No description provided for @inventory_addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get inventory_addProduct;

  /// No description provided for @inventory_scanProduct.
  ///
  /// In en, this message translates to:
  /// **'Scan product'**
  String get inventory_scanProduct;

  /// No description provided for @inventory_couldNotLoadProduct.
  ///
  /// In en, this message translates to:
  /// **'Could not load product.'**
  String get inventory_couldNotLoadProduct;

  /// No description provided for @inventory_productGone.
  ///
  /// In en, this message translates to:
  /// **'This product no longer exists.'**
  String get inventory_productGone;

  /// No description provided for @inventory_removeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove product?'**
  String get inventory_removeTitle;

  /// No description provided for @inventory_removeBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed from your inventory. Its past sales stay in your records.'**
  String inventory_removeBody(String name);

  /// No description provided for @inventory_removed.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" removed'**
  String inventory_removed(String name);

  /// No description provided for @inventory_lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get inventory_lowStock;

  /// No description provided for @inventory_reorderThresholdNote.
  ///
  /// In en, this message translates to:
  /// **'At or below reorder threshold ({threshold}).'**
  String inventory_reorderThresholdNote(String threshold);

  /// No description provided for @inventory_statInStock.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get inventory_statInStock;

  /// No description provided for @inventory_statBuyingPrice.
  ///
  /// In en, this message translates to:
  /// **'Buying price'**
  String get inventory_statBuyingPrice;

  /// No description provided for @inventory_statSellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price'**
  String get inventory_statSellingPrice;

  /// No description provided for @inventory_statMarginPerUnit.
  ///
  /// In en, this message translates to:
  /// **'Margin / unit'**
  String get inventory_statMarginPerUnit;

  /// No description provided for @inventory_statInventoryValue.
  ///
  /// In en, this message translates to:
  /// **'Inventory value (cost)'**
  String get inventory_statInventoryValue;

  /// No description provided for @inventory_statReorderThreshold.
  ///
  /// In en, this message translates to:
  /// **'Reorder threshold'**
  String get inventory_statReorderThreshold;

  /// No description provided for @inventory_couldNotLoadArchived.
  ///
  /// In en, this message translates to:
  /// **'Could not load archived products. Pull to retry.'**
  String get inventory_couldNotLoadArchived;

  /// No description provided for @inventory_restored.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" restored to inventory.'**
  String inventory_restored(String name);

  /// No description provided for @inventory_couldNotRestore.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore \"{name}\". Please try again.'**
  String inventory_couldNotRestore(String name);

  /// No description provided for @inventory_noArchived.
  ///
  /// In en, this message translates to:
  /// **'No archived products.'**
  String get inventory_noArchived;

  /// No description provided for @inventory_archivedHint.
  ///
  /// In en, this message translates to:
  /// **'Products you remove from inventory show up here.'**
  String get inventory_archivedHint;

  /// No description provided for @form_required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get form_required;

  /// No description provided for @form_enterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get form_enterNumber;

  /// No description provided for @form_cannotBeNegative.
  ///
  /// In en, this message translates to:
  /// **'Cannot be negative'**
  String get form_cannotBeNegative;

  /// No description provided for @form_wholeNumberOnly.
  ///
  /// In en, this message translates to:
  /// **'Whole number only'**
  String get form_wholeNumberOnly;

  /// No description provided for @form_enterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get form_enterValidAmount;

  /// No description provided for @unit_byPiece.
  ///
  /// In en, this message translates to:
  /// **'By piece'**
  String get unit_byPiece;

  /// No description provided for @unit_byWeight.
  ///
  /// In en, this message translates to:
  /// **'By weight'**
  String get unit_byWeight;

  /// No description provided for @unit_byVolume.
  ///
  /// In en, this message translates to:
  /// **'By volume'**
  String get unit_byVolume;

  /// No description provided for @unit_hintPiece.
  ///
  /// In en, this message translates to:
  /// **'Counted as whole pieces — soap, bottled drinks, packets.'**
  String get unit_hintPiece;

  /// No description provided for @unit_hintWeight.
  ///
  /// In en, this message translates to:
  /// **'Sold by weight — rice, potato, lentils, sugar.'**
  String get unit_hintWeight;

  /// No description provided for @unit_hintVolume.
  ///
  /// In en, this message translates to:
  /// **'Sold by volume — loose oil, milk, kerosene.'**
  String get unit_hintVolume;

  /// No description provided for @inventory_formAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get inventory_formAddTitle;

  /// No description provided for @inventory_formEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get inventory_formEditTitle;

  /// No description provided for @inventory_formHowSold.
  ///
  /// In en, this message translates to:
  /// **'How is this item sold?'**
  String get inventory_formHowSold;

  /// No description provided for @inventory_formName.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get inventory_formName;

  /// No description provided for @inventory_formBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get inventory_formBrand;

  /// No description provided for @inventory_formVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant (e.g. 500ml, 1kg pack)'**
  String get inventory_formVariant;

  /// No description provided for @inventory_formReorderAt.
  ///
  /// In en, this message translates to:
  /// **'Reorder at'**
  String get inventory_formReorderAt;

  /// No description provided for @inventory_formBuyingPrice.
  ///
  /// In en, this message translates to:
  /// **'Buying price{perUnit} *'**
  String inventory_formBuyingPrice(String perUnit);

  /// No description provided for @inventory_formSellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price{perUnit} *'**
  String inventory_formSellingPrice(String perUnit);

  /// No description provided for @inventory_formCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get inventory_formCreate;

  /// No description provided for @inventory_formSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get inventory_formSaveChanges;

  /// No description provided for @inventory_formTryExample.
  ///
  /// In en, this message translates to:
  /// **'Try a real example'**
  String get inventory_formTryExample;

  /// No description provided for @inventory_formStockPieces.
  ///
  /// In en, this message translates to:
  /// **'Stock (pieces) *'**
  String get inventory_formStockPieces;

  /// No description provided for @inventory_formStock.
  ///
  /// In en, this message translates to:
  /// **'Stock *'**
  String get inventory_formStock;

  /// No description provided for @common_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_save;

  /// No description provided for @common_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get common_add;

  /// No description provided for @common_rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get common_rename;

  /// No description provided for @category_noShop.
  ///
  /// In en, this message translates to:
  /// **'No shop found for this account.'**
  String get category_noShop;

  /// No description provided for @category_renameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get category_renameTitle;

  /// No description provided for @category_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete category?'**
  String get category_deleteTitle;

  /// No description provided for @category_deleteBodyEmpty.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed.'**
  String category_deleteBodyEmpty(String name);

  /// No description provided for @category_deleteBodyUsed.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed. {count, plural, =1{1 product} other{{count} products}} will become uncategorized (not deleted).'**
  String category_deleteBodyUsed(String name, int count);

  /// No description provided for @category_addTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get category_addTooltip;

  /// No description provided for @category_couldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories. Pull to retry.'**
  String get category_couldNotLoad;

  /// No description provided for @category_productCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 product} other{{count} products}}'**
  String category_productCount(int count);

  /// No description provided for @category_noneYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet.'**
  String get category_noneYet;

  /// No description provided for @category_tapToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add one.'**
  String get category_tapToAdd;

  /// No description provided for @category_fieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category_fieldLabel;

  /// No description provided for @category_none.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get category_none;

  /// No description provided for @category_addNew.
  ///
  /// In en, this message translates to:
  /// **'Add new category'**
  String get category_addNew;

  /// No description provided for @category_alreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Already exists — selected it for you'**
  String get category_alreadyExists;

  /// No description provided for @category_newTitle.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get category_newTitle;

  /// No description provided for @category_nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get category_nameLabel;

  /// No description provided for @category_nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Frozen items'**
  String get category_nameHint;

  /// No description provided for @common_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get common_clear;

  /// No description provided for @common_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get common_remove;

  /// No description provided for @common_quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get common_quantity;

  /// No description provided for @common_subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get common_subtotal;

  /// No description provided for @common_couldNotRecognize.
  ///
  /// In en, this message translates to:
  /// **'Could not recognize the product. Please try again.'**
  String get common_couldNotRecognize;

  /// No description provided for @cart_title.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart_title;

  /// No description provided for @cart_itemsInCart.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item in cart} other{{count} items in cart}}'**
  String cart_itemsInCart(int count);

  /// No description provided for @cart_clearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cart?'**
  String get cart_clearTitle;

  /// No description provided for @cart_clearBody.
  ///
  /// In en, this message translates to:
  /// **'This removes every item from the cart. Nothing is sold.'**
  String get cart_clearBody;

  /// No description provided for @cart_keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get cart_keep;

  /// No description provided for @cart_totalItems.
  ///
  /// In en, this message translates to:
  /// **'Total · {count, plural, =1{1 item} other{{count} items}}'**
  String cart_totalItems(int count);

  /// No description provided for @cart_checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get cart_checkout;

  /// No description provided for @cart_selling.
  ///
  /// In en, this message translates to:
  /// **'Selling…'**
  String get cart_selling;

  /// No description provided for @cart_empty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cart_empty;

  /// No description provided for @cart_emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add products from Items or Scan to build a sale, then check out here.'**
  String get cart_emptyHint;

  /// No description provided for @cart_itemsSold.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item sold} other{{count} items sold}} · {total}'**
  String cart_itemsSold(int count, String total);

  /// No description provided for @cart_checkoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Checkout failed. Please try again.'**
  String get cart_checkoutFailed;

  /// No description provided for @error_insufficientStock.
  ///
  /// In en, this message translates to:
  /// **'Not enough {product} in stock'**
  String error_insufficientStock(String product);

  /// No description provided for @error_cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'The cart is empty.'**
  String get error_cartEmpty;

  /// No description provided for @error_productNotFound.
  ///
  /// In en, this message translates to:
  /// **'That product no longer exists.'**
  String get error_productNotFound;

  /// No description provided for @error_customerNotFound.
  ///
  /// In en, this message translates to:
  /// **'That customer no longer exists.'**
  String get error_customerNotFound;

  /// No description provided for @error_discountExceedsTotal.
  ///
  /// In en, this message translates to:
  /// **'The discount is more than the bill.'**
  String get error_discountExceedsTotal;

  /// No description provided for @error_discountNegative.
  ///
  /// In en, this message translates to:
  /// **'A discount cannot be negative.'**
  String get error_discountNegative;

  /// No description provided for @error_quantityNotPositive.
  ///
  /// In en, this message translates to:
  /// **'Quantity must be more than zero.'**
  String get error_quantityNotPositive;

  /// No description provided for @cart_addDiscount.
  ///
  /// In en, this message translates to:
  /// **'Add discount'**
  String get cart_addDiscount;

  /// No description provided for @cart_discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get cart_discount;

  /// No description provided for @cart_discountTitle.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get cart_discountTitle;

  /// No description provided for @cart_discountAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount off'**
  String get cart_discountAmount;

  /// No description provided for @cart_discountEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit discount'**
  String get cart_discountEdit;

  /// No description provided for @cart_discountRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove discount'**
  String get cart_discountRemove;

  /// No description provided for @cart_discountBelowCost.
  ///
  /// In en, this message translates to:
  /// **'You\'d lose {amount} on this sale'**
  String cart_discountBelowCost(String amount);

  /// No description provided for @cart_discountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get cart_discountInvalid;

  /// No description provided for @cart_apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get cart_apply;

  /// No description provided for @cart_pricePerUnit.
  ///
  /// In en, this message translates to:
  /// **'{price} / {unit}'**
  String cart_pricePerUnit(String price, String unit);

  /// No description provided for @cart_barSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}} · {total}'**
  String cart_barSummary(int count, String total);

  /// No description provided for @addToCart_noMore.
  ///
  /// In en, this message translates to:
  /// **'No more available to add.'**
  String get addToCart_noMore;

  /// No description provided for @addToCart_available.
  ///
  /// In en, this message translates to:
  /// **'{qty} {unit} available to add'**
  String addToCart_available(String qty, String unit);

  /// No description provided for @restock_confirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm restock'**
  String get restock_confirmTitle;

  /// No description provided for @restock_inStock.
  ///
  /// In en, this message translates to:
  /// **'In stock: {qty}'**
  String restock_inStock(String qty);

  /// No description provided for @restock_unitCost.
  ///
  /// In en, this message translates to:
  /// **'Unit cost'**
  String get restock_unitCost;

  /// No description provided for @restock_totalCost.
  ///
  /// In en, this message translates to:
  /// **'Total cost'**
  String get restock_totalCost;

  /// No description provided for @scan_failed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed. Try again.'**
  String get scan_failed;

  /// No description provided for @scan_addedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added {name} to cart'**
  String scan_addedToCart(String name);

  /// No description provided for @scan_read.
  ///
  /// In en, this message translates to:
  /// **'Read: {details}'**
  String scan_read(String details);

  /// No description provided for @scan_didYouMean.
  ///
  /// In en, this message translates to:
  /// **'Did you mean?'**
  String get scan_didYouMean;

  /// No description provided for @scan_noMatchPick.
  ///
  /// In en, this message translates to:
  /// **'No match — pick the product'**
  String get scan_noMatchPick;

  /// No description provided for @scan_searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get scan_searchProducts;

  /// No description provided for @scan_recognizing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing {count}…'**
  String scan_recognizing(int count);

  /// No description provided for @scan_addItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 item} other{Add {count} items}}'**
  String scan_addItems(int count);

  /// Add button with an empty tray -- deliberately carries no count, since a disabled button announcing zero reads as an error rather than as 'nothing staged yet'
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get scan_addEmpty;

  /// No description provided for @scan_nothingYet.
  ///
  /// In en, this message translates to:
  /// **'Scan something to begin'**
  String get scan_nothingYet;

  /// No description provided for @scan_tapToPick.
  ///
  /// In en, this message translates to:
  /// **'Tap to pick'**
  String get scan_tapToPick;

  /// No description provided for @scan_notIdentified.
  ///
  /// In en, this message translates to:
  /// **'Not identified'**
  String get scan_notIdentified;

  /// No description provided for @scan_topSellers.
  ///
  /// In en, this message translates to:
  /// **'Top sellers'**
  String get scan_topSellers;

  /// No description provided for @scan_outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get scan_outOfStock;

  /// No description provided for @scan_cameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed to scan. Open Settings and allow it, then try again.'**
  String get scan_cameraDenied;

  /// No description provided for @scan_openSettings.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get scan_openSettings;

  /// No description provided for @scan_cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device has no camera to scan with.'**
  String get scan_cameraUnavailable;

  /// No description provided for @scan_leaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without adding?'**
  String get scan_leaveTitle;

  /// No description provided for @scan_leaveBody.
  ///
  /// In en, this message translates to:
  /// **'{count} scanned items have not been added to the cart.'**
  String scan_leaveBody(int count);

  /// No description provided for @scan_discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Add the rest?'**
  String get scan_discardTitle;

  /// No description provided for @scan_discardBody.
  ///
  /// In en, this message translates to:
  /// **'{count} items are not ready to add (unresolved or out of stock) and will be discarded.'**
  String scan_discardBody(int count);

  /// No description provided for @common_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get common_discard;

  /// No description provided for @history_title.
  ///
  /// In en, this message translates to:
  /// **'Sales history'**
  String get history_title;

  /// No description provided for @history_search.
  ///
  /// In en, this message translates to:
  /// **'Search sales'**
  String get history_search;

  /// No description provided for @history_couldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load sales history. Pull to retry.'**
  String get history_couldNotLoad;

  /// No description provided for @history_noSalesYet.
  ///
  /// In en, this message translates to:
  /// **'No sales recorded yet.'**
  String get history_noSalesYet;

  /// No description provided for @history_noSalesOnDay.
  ///
  /// In en, this message translates to:
  /// **'No sales on {date}.'**
  String history_noSalesOnDay(String date);

  /// No description provided for @history_emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Record a sale from Items → tap a product → Add to cart, or use the cart bar to checkout.'**
  String get history_emptyHint;

  /// No description provided for @history_noMatch.
  ///
  /// In en, this message translates to:
  /// **'No sales match your search.'**
  String get history_noMatch;

  /// No description provided for @history_saleFallback.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get history_saleFallback;

  /// No description provided for @history_colTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get history_colTime;

  /// No description provided for @history_colItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get history_colItem;

  /// No description provided for @history_colQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get history_colQty;

  /// No description provided for @history_colAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get history_colAmount;

  /// No description provided for @saleDetail_title.
  ///
  /// In en, this message translates to:
  /// **'Sale details'**
  String get saleDetail_title;

  /// No description provided for @saleDetail_soldOn.
  ///
  /// In en, this message translates to:
  /// **'Sold on'**
  String get saleDetail_soldOn;

  /// No description provided for @saleDetail_quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get saleDetail_quantity;

  /// No description provided for @saleDetail_priceEach.
  ///
  /// In en, this message translates to:
  /// **'Price each'**
  String get saleDetail_priceEach;

  /// No description provided for @saleDetail_total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get saleDetail_total;

  /// No description provided for @saleDetail_discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get saleDetail_discount;

  /// No description provided for @saleDetail_cost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get saleDetail_cost;

  /// No description provided for @saleDetail_profit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get saleDetail_profit;

  /// No description provided for @saleDetail_enteredBy.
  ///
  /// In en, this message translates to:
  /// **'Entered by'**
  String get saleDetail_enteredBy;

  /// No description provided for @saleDetail_paidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get saleDetail_paidBy;

  /// No description provided for @saleDetail_frozenNote.
  ///
  /// In en, this message translates to:
  /// **'Prices are locked in from the moment of sale.'**
  String get saleDetail_frozenNote;

  /// No description provided for @saleDetail_notFound.
  ///
  /// In en, this message translates to:
  /// **'Sale not found.'**
  String get saleDetail_notFound;

  /// No description provided for @saleDetail_sourceManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get saleDetail_sourceManual;

  /// No description provided for @saleDetail_sourceVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get saleDetail_sourceVoice;

  /// No description provided for @saleDetail_sourcePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo scan'**
  String get saleDetail_sourcePhoto;

  /// No description provided for @analytics_kicker.
  ///
  /// In en, this message translates to:
  /// **'BUSINESS REPORT'**
  String get analytics_kicker;

  /// No description provided for @analytics_title.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get analytics_title;

  /// No description provided for @analytics_noSalesPeriod.
  ///
  /// In en, this message translates to:
  /// **'No sales in this period yet.'**
  String get analytics_noSalesPeriod;

  /// No description provided for @analytics_revenueSource.
  ///
  /// In en, this message translates to:
  /// **'Where revenue comes from'**
  String get analytics_revenueSource;

  /// No description provided for @analytics_topShare.
  ///
  /// In en, this message translates to:
  /// **'top share'**
  String get analytics_topShare;

  /// No description provided for @analytics_biggestWins.
  ///
  /// In en, this message translates to:
  /// **'Biggest wins'**
  String get analytics_biggestWins;

  /// No description provided for @analytics_carrying.
  ///
  /// In en, this message translates to:
  /// **'{name} is carrying {scope}.'**
  String analytics_carrying(String name, String scope);

  /// No description provided for @analytics_scopeToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get analytics_scopeToday;

  /// No description provided for @analytics_scopeWeek.
  ///
  /// In en, this message translates to:
  /// **'this week'**
  String get analytics_scopeWeek;

  /// No description provided for @analytics_scopeMonth.
  ///
  /// In en, this message translates to:
  /// **'this month'**
  String get analytics_scopeMonth;

  /// No description provided for @analytics_scopeAll.
  ///
  /// In en, this message translates to:
  /// **'all time'**
  String get analytics_scopeAll;

  /// No description provided for @analytics_scopeDay.
  ///
  /// In en, this message translates to:
  /// **'on {date}'**
  String analytics_scopeDay(String date);

  /// No description provided for @analytics_units.
  ///
  /// In en, this message translates to:
  /// **'{qty} units'**
  String analytics_units(String qty);

  /// No description provided for @auth_createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get auth_createAccount;

  /// No description provided for @auth_welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get auth_welcomeBack;

  /// No description provided for @auth_noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Connect to the internet and try again.'**
  String get auth_noInternet;

  /// No description provided for @auth_fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get auth_fullName;

  /// No description provided for @auth_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get auth_nameRequired;

  /// No description provided for @auth_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get auth_email;

  /// No description provided for @auth_emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get auth_emailRequired;

  /// No description provided for @auth_emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get auth_emailInvalid;

  /// No description provided for @auth_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get auth_password;

  /// No description provided for @auth_passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get auth_passwordRequired;

  /// No description provided for @auth_passwordMin.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get auth_passwordMin;

  /// No description provided for @auth_signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get auth_signUp;

  /// No description provided for @auth_signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get auth_signIn;

  /// No description provided for @auth_continueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get auth_continueGoogle;

  /// No description provided for @auth_haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get auth_haveAccount;

  /// No description provided for @auth_noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get auth_noAccount;

  /// No description provided for @profile_tellUs.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your shop'**
  String get profile_tellUs;

  /// No description provided for @profile_shopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name *'**
  String get profile_shopName;

  /// No description provided for @profile_shopNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Shop name is required'**
  String get profile_shopNameRequired;

  /// No description provided for @profile_address.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get profile_address;

  /// No description provided for @profile_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get profile_phone;

  /// No description provided for @profile_createShop.
  ///
  /// In en, this message translates to:
  /// **'Create shop'**
  String get profile_createShop;

  /// No description provided for @welcome_headline.
  ///
  /// In en, this message translates to:
  /// **'Run your shop\nsmarter'**
  String get welcome_headline;

  /// No description provided for @welcome_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Track inventory, record sales by voice or photo, and see your profit at a glance.'**
  String get welcome_subtitle;

  /// No description provided for @welcome_getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get welcome_getStarted;

  /// No description provided for @nav_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get nav_home;

  /// No description provided for @nav_items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get nav_items;

  /// No description provided for @nav_reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get nav_reports;

  /// No description provided for @nav_history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get nav_history;

  /// No description provided for @common_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get common_continue;

  /// No description provided for @onboarding_languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onboarding_languageTitle;

  /// No description provided for @onboarding_languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime in Settings.'**
  String get onboarding_languageSubtitle;

  /// No description provided for @onboarding_step.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboarding_step(int current, int total);

  /// No description provided for @onboarding_defaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default currency *'**
  String get onboarding_defaultCurrency;

  /// No description provided for @customers_title.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers_title;

  /// No description provided for @customers_receivablesHeader.
  ///
  /// In en, this message translates to:
  /// **'{amount} owed by {count, plural, =1{1 customer} other{{count} customers}}'**
  String customers_receivablesHeader(String amount, int count);

  /// No description provided for @customers_empty.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get customers_empty;

  /// No description provided for @customers_emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add a customer to start a khata, or choose Credit at checkout.'**
  String get customers_emptyHint;

  /// No description provided for @customers_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get customers_searchHint;

  /// No description provided for @customers_add.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get customers_add;

  /// No description provided for @customers_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get customers_edit;

  /// No description provided for @customers_fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get customers_fieldName;

  /// No description provided for @customers_fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get customers_fieldPhone;

  /// No description provided for @customers_fieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get customers_fieldNote;

  /// No description provided for @customers_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get customers_nameRequired;

  /// No description provided for @customers_phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number'**
  String get customers_phoneRequired;

  /// No description provided for @customers_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get customers_save;

  /// No description provided for @customers_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete customer'**
  String get customers_delete;

  /// No description provided for @customers_deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String customers_deleteConfirmTitle(String name);

  /// No description provided for @customers_deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the customer and their khata history. Only settled customers can be deleted.'**
  String get customers_deleteConfirmBody;

  /// No description provided for @customers_owes.
  ///
  /// In en, this message translates to:
  /// **'Owes {amount}'**
  String customers_owes(String amount);

  /// No description provided for @customers_settled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get customers_settled;

  /// No description provided for @customers_balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get customers_balance;

  /// No description provided for @customers_ledgerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No khata activity yet'**
  String get customers_ledgerEmpty;

  /// No description provided for @customers_recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get customers_recordPayment;

  /// No description provided for @customers_paymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get customers_paymentAmount;

  /// No description provided for @customers_paymentNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get customers_paymentNote;

  /// No description provided for @customers_paymentAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get customers_paymentAmountRequired;

  /// No description provided for @customers_paymentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'More than what is owed'**
  String get customers_paymentTooLarge;

  /// No description provided for @customers_paymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get customers_paymentRecorded;

  /// No description provided for @customers_ledgerCreditSale.
  ///
  /// In en, this message translates to:
  /// **'Credit sale'**
  String get customers_ledgerCreditSale;

  /// No description provided for @customers_ledgerPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get customers_ledgerPayment;

  /// No description provided for @cart_paymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cart_paymentCash;

  /// No description provided for @cart_paymentCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get cart_paymentCredit;

  /// No description provided for @cart_paymentDigital.
  ///
  /// In en, this message translates to:
  /// **'Digital'**
  String get cart_paymentDigital;

  /// No description provided for @cart_selectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select customer'**
  String get cart_selectCustomer;

  /// No description provided for @cart_addToKhata.
  ///
  /// In en, this message translates to:
  /// **'Add to {name}\'s khata'**
  String cart_addToKhata(String name);

  /// No description provided for @cart_addedToKhata.
  ///
  /// In en, this message translates to:
  /// **'Added to {name}\'s khata · {total}'**
  String cart_addedToKhata(String name, String total);

  /// No description provided for @dashboard_receivablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Receivables'**
  String get dashboard_receivablesTitle;

  /// No description provided for @voice_title.
  ///
  /// In en, this message translates to:
  /// **'Speak a sale'**
  String get voice_title;

  /// No description provided for @voice_hintIdle.
  ///
  /// In en, this message translates to:
  /// **'Tap the mic and say what you sold'**
  String get voice_hintIdle;

  /// No description provided for @voice_recording.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get voice_recording;

  /// No description provided for @voice_thinking.
  ///
  /// In en, this message translates to:
  /// **'Working it out…'**
  String get voice_thinking;

  /// First step of the voice-parse progress checklist, shown once the recording has been captured.
  ///
  /// In en, this message translates to:
  /// **'Heard you'**
  String get voice_stageHeard;

  /// Second step of the voice-parse progress checklist, while the audio is being transcribed and read.
  ///
  /// In en, this message translates to:
  /// **'Understanding what you said'**
  String get voice_stageUnderstanding;

  /// Final step of the voice-parse progress checklist, while spoken names are matched to shop products.
  ///
  /// In en, this message translates to:
  /// **'Finding your items'**
  String get voice_stageMatching;

  /// Reassurance under the minimize button: parsing continues after the sheet is dismissed.
  ///
  /// In en, this message translates to:
  /// **'We\'ll buzz you when it\'s ready'**
  String get voice_thinkingDismissHint;

  /// Button that dismisses the voice sheet while the parse keeps running.
  ///
  /// In en, this message translates to:
  /// **'Continue in background'**
  String get voice_thinkingMinimize;

  /// Banner shown while a backgrounded voice sale is still being parsed.
  ///
  /// In en, this message translates to:
  /// **'Working on your voice sale…'**
  String get voice_bannerWorking;

  /// Tooltip on the banner button that abandons a voice sale still being parsed.
  ///
  /// In en, this message translates to:
  /// **'Discard this voice sale'**
  String get voice_bannerCancel;

  /// Banner shown when a backgrounded voice sale finished parsing successfully.
  ///
  /// In en, this message translates to:
  /// **'Your voice sale is ready'**
  String get voice_bannerReady;

  /// Banner shown when a backgrounded voice sale finished with an error.
  ///
  /// In en, this message translates to:
  /// **'Your voice sale needs a look'**
  String get voice_bannerFailed;

  /// Call-to-action on the backgrounded voice sale banner; tapping reopens the sheet.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get voice_bannerAction;

  /// No description provided for @voice_heard.
  ///
  /// In en, this message translates to:
  /// **'I heard'**
  String get voice_heard;

  /// No description provided for @voice_recheck.
  ///
  /// In en, this message translates to:
  /// **'Re-check'**
  String get voice_recheck;

  /// No description provided for @voice_whichOne.
  ///
  /// In en, this message translates to:
  /// **'Which one?'**
  String get voice_whichOne;

  /// No description provided for @voice_pick.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get voice_pick;

  /// No description provided for @voice_addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get voice_addToCart;

  /// No description provided for @voice_assumedQty.
  ///
  /// In en, this message translates to:
  /// **'Assumed 1 — check this'**
  String get voice_assumedQty;

  /// No description provided for @voice_lowStock.
  ///
  /// In en, this message translates to:
  /// **'Only {count} in stock'**
  String voice_lowStock(int count);

  /// No description provided for @voice_errNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t catch that. Try again.'**
  String get voice_errNoSpeech;

  /// No description provided for @voice_errNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t match anything you said.'**
  String get voice_errNoMatch;

  /// No description provided for @voice_errMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off. Turn it on in Settings.'**
  String get voice_errMicDenied;

  /// No description provided for @voice_errOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Reconnect and try again.'**
  String get voice_errOffline;

  /// No description provided for @voice_errTooQuiet.
  ///
  /// In en, this message translates to:
  /// **'The microphone didn\'t pick up any sound. Hold the phone closer and try again.'**
  String get voice_errTooQuiet;

  /// No description provided for @voice_retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get voice_retry;

  /// No description provided for @voice_recordAgain.
  ///
  /// In en, this message translates to:
  /// **'Record again'**
  String get voice_recordAgain;

  /// No description provided for @voice_typeInstead.
  ///
  /// In en, this message translates to:
  /// **'Type it instead'**
  String get voice_typeInstead;

  /// No description provided for @voice_stoppingIn.
  ///
  /// In en, this message translates to:
  /// **'Stopping in {seconds}s'**
  String voice_stoppingIn(int seconds);

  /// No description provided for @voice_speakCloser.
  ///
  /// In en, this message translates to:
  /// **'Can\'t hear you — hold the phone closer'**
  String get voice_speakCloser;

  /// No description provided for @voice_levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Microphone level'**
  String get voice_levelLabel;

  /// No description provided for @expiry_dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get expiry_dateLabel;

  /// No description provided for @expiry_dateOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get expiry_dateOptional;

  /// No description provided for @expiry_dateClear.
  ///
  /// In en, this message translates to:
  /// **'Remove date'**
  String get expiry_dateClear;

  /// No description provided for @expiry_pastDateTitle.
  ///
  /// In en, this message translates to:
  /// **'This date has already passed'**
  String get expiry_pastDateTitle;

  /// No description provided for @expiry_pastDateBody.
  ///
  /// In en, this message translates to:
  /// **'Save it anyway?'**
  String get expiry_pastDateBody;

  /// No description provided for @expiry_farDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Is this year right?'**
  String get expiry_farDateTitle;

  /// No description provided for @expiry_farDateBody.
  ///
  /// In en, this message translates to:
  /// **'{date} is more than 5 years away.'**
  String expiry_farDateBody(String date);

  /// No description provided for @expiry_saveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get expiry_saveAnyway;

  /// No description provided for @expiry_changeDate.
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get expiry_changeDate;

  /// No description provided for @expiry_moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get expiry_moreOptions;

  /// No description provided for @expiry_warnDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Warn me this many days before expiry'**
  String get expiry_warnDaysLabel;

  /// No description provided for @expiry_warnDaysHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to let the app decide'**
  String get expiry_warnDaysHint;

  /// No description provided for @expiry_unitChangeBlocked.
  ///
  /// In en, this message translates to:
  /// **'Clear this product\'s deliveries before changing its unit'**
  String get expiry_unitChangeBlocked;

  /// No description provided for @expiry_savedWithoutDate.
  ///
  /// In en, this message translates to:
  /// **'Product saved, but its expiry date wasn\'t. Add it from the product page.'**
  String get expiry_savedWithoutDate;

  /// No description provided for @expiry_deliveries.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get expiry_deliveries;

  /// No description provided for @expiry_addDate.
  ///
  /// In en, this message translates to:
  /// **'Add expiry date'**
  String get expiry_addDate;

  /// No description provided for @expiry_rowDates.
  ///
  /// In en, this message translates to:
  /// **'Added {added} · Expires {expiry}'**
  String expiry_rowDates(String added, String expiry);

  /// No description provided for @expiry_rowLeft.
  ///
  /// In en, this message translates to:
  /// **'About {qty} {unit} left'**
  String expiry_rowLeft(String qty, String unit);

  /// No description provided for @expiry_statusGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get expiry_statusGood;

  /// No description provided for @expiry_statusSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get expiry_statusSoon;

  /// No description provided for @expiry_statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expiry_statusExpired;

  /// No description provided for @expiry_removeFromStock.
  ///
  /// In en, this message translates to:
  /// **'Remove from stock'**
  String get expiry_removeFromStock;

  /// No description provided for @expiry_thrownAway.
  ///
  /// In en, this message translates to:
  /// **'Thrown away: {qty} {unit} · {amount} lost'**
  String expiry_thrownAway(String qty, String unit, String amount);

  /// No description provided for @settings_restockEvery.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{I restock every day} other{I restock every {days} days}}'**
  String settings_restockEvery(int days);

  /// No description provided for @settings_restockEveryTitle.
  ///
  /// In en, this message translates to:
  /// **'How often do you restock?'**
  String get settings_restockEveryTitle;

  /// No description provided for @restockPlan_daysShort.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String restockPlan_daysShort(int days);

  /// No description provided for @restockPlan_title.
  ///
  /// In en, this message translates to:
  /// **'Restock list'**
  String get restockPlan_title;

  /// No description provided for @restockPlan_buyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get restockPlan_buyNow;

  /// No description provided for @restockPlan_enough.
  ///
  /// In en, this message translates to:
  /// **'Enough for now ({count})'**
  String restockPlan_enough(String count);

  /// No description provided for @restockPlan_runsOutToday.
  ///
  /// In en, this message translates to:
  /// **'Runs out today'**
  String get restockPlan_runsOutToday;

  /// No description provided for @restockPlan_runsOutIn.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Runs out in 1 day} other{Runs out in {days} days}}'**
  String restockPlan_runsOutIn(int days);

  /// No description provided for @restockPlan_today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get restockPlan_today;

  /// No description provided for @restockPlan_atReorderLevel.
  ///
  /// In en, this message translates to:
  /// **'At your reorder level'**
  String get restockPlan_atReorderLevel;

  /// No description provided for @restockPlan_lowShort.
  ///
  /// In en, this message translates to:
  /// **'low stock'**
  String get restockPlan_lowShort;

  /// No description provided for @restockPlan_buyAbout.
  ///
  /// In en, this message translates to:
  /// **'Buy about {qty} {unit}'**
  String restockPlan_buyAbout(String qty, String unit);

  /// No description provided for @restockPlan_inStock.
  ///
  /// In en, this message translates to:
  /// **'{qty} {unit} in stock'**
  String restockPlan_inStock(String qty, String unit);

  /// No description provided for @restockPlan_empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to restock yet. Suggestions appear after a few days of sales.'**
  String get restockPlan_empty;

  /// No description provided for @restockPlan_loadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the restock list.'**
  String get restockPlan_loadError;

  /// No description provided for @restockPlan_cardTitle.
  ///
  /// In en, this message translates to:
  /// **'Restock soon'**
  String get restockPlan_cardTitle;

  /// No description provided for @restockPlan_cardSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item to restock} other{{count} items to restock}}'**
  String restockPlan_cardSummary(int count);

  /// No description provided for @restockPlan_cardItem.
  ///
  /// In en, this message translates to:
  /// **'{name} · {days}'**
  String restockPlan_cardItem(String name, String days);

  /// No description provided for @expiry_formAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add expiry date'**
  String get expiry_formAddTitle;

  /// No description provided for @expiry_formEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit delivery'**
  String get expiry_formEditTitle;

  /// No description provided for @expiry_formAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expiry_formAmount;

  /// No description provided for @expiry_formReceived.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get expiry_formReceived;

  /// No description provided for @expiry_amountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above 0'**
  String get expiry_amountInvalid;

  /// No description provided for @expiry_dateRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose an expiry date'**
  String get expiry_dateRequired;

  /// No description provided for @expiry_removeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {qty} {unit} of {name}?'**
  String expiry_removeConfirmTitle(String qty, String unit, String name);

  /// No description provided for @expiry_removeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Stock goes down and the loss is recorded. Your sales figures don\'t change.'**
  String get expiry_removeConfirmBody;

  /// No description provided for @expiry_removed.
  ///
  /// In en, this message translates to:
  /// **'Removed from stock'**
  String get expiry_removed;

  /// No description provided for @expiry_removeAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from stock?'**
  String expiry_removeAmountTitle(String name);

  /// No description provided for @expiry_removeAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'How many?'**
  String get expiry_removeAmountLabel;

  /// No description provided for @expiry_cartOnlyGood.
  ///
  /// In en, this message translates to:
  /// **'Only {good} good {name} left ({expired} expired)'**
  String expiry_cartOnlyGood(String good, String name, String expired);

  /// No description provided for @expiry_cartOnlyExpired.
  ///
  /// In en, this message translates to:
  /// **'Only expired {name} left ({expired})'**
  String expiry_cartOnlyExpired(String name, String expired);

  /// No description provided for @expiry_cartRemoveExpired.
  ///
  /// In en, this message translates to:
  /// **'Remove expired'**
  String get expiry_cartRemoveExpired;

  /// No description provided for @expiry_cartNotExpired.
  ///
  /// In en, this message translates to:
  /// **'They\'re not expired'**
  String get expiry_cartNotExpired;

  /// No description provided for @expiry_cartOnlyLeft.
  ///
  /// In en, this message translates to:
  /// **'Only {qty} {unit} left'**
  String expiry_cartOnlyLeft(String qty, String unit);

  /// No description provided for @expiry_addSheetExpiredNote.
  ///
  /// In en, this message translates to:
  /// **'{qty} {unit} expired — not counted'**
  String expiry_addSheetExpiredNote(String qty, String unit);

  /// No description provided for @error_expiredStockInCart.
  ///
  /// In en, this message translates to:
  /// **'Some items in the cart are expired. Fix them before checkout.'**
  String get error_expiredStockInCart;

  /// No description provided for @error_batchShortInCart.
  ///
  /// In en, this message translates to:
  /// **'A batch you picked doesn\'t have enough left. Check the cart.'**
  String get error_batchShortInCart;

  /// No description provided for @error_batchNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'That batch is no longer available. Pick another one in the cart.'**
  String get error_batchNotAvailable;

  /// No description provided for @cart_batchLabel.
  ///
  /// In en, this message translates to:
  /// **'Batch: {choice}'**
  String cart_batchLabel(String choice);

  /// No description provided for @cart_batchMix.
  ///
  /// In en, this message translates to:
  /// **'Several batches, soonest expiry first'**
  String get cart_batchMix;

  /// No description provided for @cart_batchChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get cart_batchChoose;

  /// No description provided for @cart_batchChooseNotice.
  ///
  /// In en, this message translates to:
  /// **'Choose which batch this comes from'**
  String get cart_batchChooseNotice;

  /// No description provided for @error_batchNotChosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a batch for each marked item in the cart.'**
  String get error_batchNotChosen;

  /// No description provided for @cart_batchNoDate.
  ///
  /// In en, this message translates to:
  /// **'No expiry date'**
  String get cart_batchNoDate;

  /// No description provided for @cart_batchExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String cart_batchExpires(String date);

  /// No description provided for @cart_batchPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Sell from which batch?'**
  String get cart_batchPickTitle;

  /// No description provided for @cart_batchOptionLeft.
  ///
  /// In en, this message translates to:
  /// **'{qty} {unit} left'**
  String cart_batchOptionLeft(String qty, String unit);

  /// No description provided for @cart_batchShort.
  ///
  /// In en, this message translates to:
  /// **'Only {qty} {unit} left in this batch'**
  String cart_batchShort(String qty, String unit);

  /// No description provided for @cart_batchGone.
  ///
  /// In en, this message translates to:
  /// **'This batch is no longer available. Pick another.'**
  String get cart_batchGone;

  /// No description provided for @expiry_alertExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired: {qty} {name}'**
  String expiry_alertExpired(String qty, String name);

  /// No description provided for @expiry_alertSoonToday.
  ///
  /// In en, this message translates to:
  /// **'{name}: {qty} expire today'**
  String expiry_alertSoonToday(String name, String qty);

  /// No description provided for @expiry_alertSoonTomorrow.
  ///
  /// In en, this message translates to:
  /// **'{name}: {qty} expire tomorrow'**
  String expiry_alertSoonTomorrow(String name, String qty);

  /// No description provided for @expiry_alertSoonDays.
  ///
  /// In en, this message translates to:
  /// **'{name}: {qty} expire in {days} days'**
  String expiry_alertSoonDays(String name, String qty, String days);

  /// No description provided for @expiry_cardTitle.
  ///
  /// In en, this message translates to:
  /// **'Expiring & expired'**
  String get expiry_cardTitle;

  /// No description provided for @expiry_alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Expiry alerts'**
  String get expiry_alertsTitle;

  /// No description provided for @expiry_filter.
  ///
  /// In en, this message translates to:
  /// **'Expiring'**
  String get expiry_filter;

  /// No description provided for @reminder_title.
  ///
  /// In en, this message translates to:
  /// **'Expiry check'**
  String get reminder_title;

  /// No description provided for @reminder_more.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String reminder_more(String count);

  /// No description provided for @reminder_channelName.
  ///
  /// In en, this message translates to:
  /// **'Expiry reminders'**
  String get reminder_channelName;

  /// No description provided for @settings_sectionExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get settings_sectionExpiry;

  /// No description provided for @settings_expiryWarnDays.
  ///
  /// In en, this message translates to:
  /// **'Warn me up to {days} days before'**
  String settings_expiryWarnDays(String days);

  /// No description provided for @settings_expiryWarnDaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Warning time'**
  String get settings_expiryWarnDaysTitle;

  /// No description provided for @settings_expiryDaysOption.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String settings_expiryDaysOption(String days);

  /// No description provided for @settings_expiryReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily expiry reminder'**
  String get settings_expiryReminder;

  /// No description provided for @settings_expiryReminderSub.
  ///
  /// In en, this message translates to:
  /// **'At 9 AM on days something needs attention'**
  String get settings_expiryReminderSub;

  /// No description provided for @settings_expiryReminderBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked — turn on notifications in phone settings'**
  String get settings_expiryReminderBlocked;

  /// No description provided for @finance_title.
  ///
  /// In en, this message translates to:
  /// **'Money health'**
  String get finance_title;

  /// No description provided for @finance_last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get finance_last7Days;

  /// No description provided for @finance_in.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get finance_in;

  /// No description provided for @finance_out.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get finance_out;

  /// No description provided for @finance_net.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get finance_net;

  /// No description provided for @finance_allGood.
  ///
  /// In en, this message translates to:
  /// **'No money warnings this week'**
  String get finance_allGood;

  /// No description provided for @finance_alertOverdue.
  ///
  /// In en, this message translates to:
  /// **'{name} owes {amount} for {days} days'**
  String finance_alertOverdue(String name, String amount, String days);

  /// No description provided for @finance_alertOverdueMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{and 1 more customer is late} other{and {count} more customers are late}}'**
  String finance_alertOverdueMore(int count);

  /// No description provided for @finance_alertCashShort.
  ///
  /// In en, this message translates to:
  /// **'Restocks cost {amount} more than the money that came in'**
  String finance_alertCashShort(String amount);

  /// No description provided for @finance_alertCreditGrowing.
  ///
  /// In en, this message translates to:
  /// **'Credit owed went up {rise} this week (now {total})'**
  String finance_alertCreditGrowing(String rise, String total);

  /// No description provided for @finance_alertSalesDrop.
  ///
  /// In en, this message translates to:
  /// **'Sales fell {percent} from the week before'**
  String finance_alertSalesDrop(String percent);

  /// No description provided for @finance_financingFooter.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{See financing options for your shop} =1{1 financing option fits your shop} other{{count} financing options fit your shop}}'**
  String finance_financingFooter(int count);

  /// No description provided for @finance_rowCashSales.
  ///
  /// In en, this message translates to:
  /// **'Cash sales'**
  String get finance_rowCashSales;

  /// No description provided for @finance_rowDigitalSales.
  ///
  /// In en, this message translates to:
  /// **'Digital sales'**
  String get finance_rowDigitalSales;

  /// No description provided for @finance_rowCollected.
  ///
  /// In en, this message translates to:
  /// **'Credit collected'**
  String get finance_rowCollected;

  /// No description provided for @finance_rowMoneyIn.
  ///
  /// In en, this message translates to:
  /// **'Money in'**
  String get finance_rowMoneyIn;

  /// No description provided for @finance_rowRestocks.
  ///
  /// In en, this message translates to:
  /// **'Restocks'**
  String get finance_rowRestocks;

  /// No description provided for @finance_rowMoneyOut.
  ///
  /// In en, this message translates to:
  /// **'Money out'**
  String get finance_rowMoneyOut;

  /// No description provided for @finance_rowCreditGiven.
  ///
  /// In en, this message translates to:
  /// **'Sold on credit (not paid yet)'**
  String get finance_rowCreditGiven;

  /// No description provided for @finance_outNote.
  ///
  /// In en, this message translates to:
  /// **'Money out counts restocks only.'**
  String get finance_outNote;

  /// No description provided for @finance_alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get finance_alertsTitle;

  /// No description provided for @finance_financingTitle.
  ///
  /// In en, this message translates to:
  /// **'Financing for your shop'**
  String get finance_financingTitle;

  /// No description provided for @finance_financingIntro.
  ///
  /// In en, this message translates to:
  /// **'Matched from your last 90 days of sales.'**
  String get finance_financingIntro;

  /// No description provided for @finance_fits.
  ///
  /// In en, this message translates to:
  /// **'Fits you'**
  String get finance_fits;

  /// No description provided for @finance_notYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get finance_notYet;

  /// No description provided for @finance_upTo.
  ///
  /// In en, this message translates to:
  /// **'Up to about {amount}'**
  String finance_upTo(String amount);

  /// No description provided for @finance_kindSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier credit'**
  String get finance_kindSupplier;

  /// No description provided for @finance_kindSupplierSub.
  ///
  /// In en, this message translates to:
  /// **'Get stock now, pay the supplier in 30 days'**
  String get finance_kindSupplierSub;

  /// No description provided for @finance_kindWallet.
  ///
  /// In en, this message translates to:
  /// **'Mobile-wallet small loan'**
  String get finance_kindWallet;

  /// No description provided for @finance_kindWalletSub.
  ///
  /// In en, this message translates to:
  /// **'A quick small loan based on your digital sales'**
  String get finance_kindWalletSub;

  /// No description provided for @finance_kindMicro.
  ///
  /// In en, this message translates to:
  /// **'Microfinance shop loan'**
  String get finance_kindMicro;

  /// No description provided for @finance_kindMicroSub.
  ///
  /// In en, this message translates to:
  /// **'Weekly repayments, for steady small shops'**
  String get finance_kindMicroSub;

  /// No description provided for @finance_kindSme.
  ///
  /// In en, this message translates to:
  /// **'Bank SME loan'**
  String get finance_kindSme;

  /// No description provided for @finance_kindSmeSub.
  ///
  /// In en, this message translates to:
  /// **'A bigger loan to grow the shop'**
  String get finance_kindSmeSub;

  /// No description provided for @finance_whySupplier.
  ///
  /// In en, this message translates to:
  /// **'You restock about {amount} a month'**
  String finance_whySupplier(String amount);

  /// No description provided for @finance_whyWallet.
  ///
  /// In en, this message translates to:
  /// **'{percent} of your sales are digital'**
  String finance_whyWallet(String percent);

  /// No description provided for @finance_whyMicro.
  ///
  /// In en, this message translates to:
  /// **'You sold in {weeks} of the last 12 weeks'**
  String finance_whyMicro(String weeks);

  /// No description provided for @finance_whySme.
  ///
  /// In en, this message translates to:
  /// **'{months} months of trading and a {percent} profit margin'**
  String finance_whySme(String months, String percent);

  /// No description provided for @finance_gapTrade.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{Keep trading 1 more month} other{Keep trading {months} more months}}'**
  String finance_gapTrade(int months);

  /// No description provided for @finance_gapRestock.
  ///
  /// In en, this message translates to:
  /// **'Record your restocks in the app first'**
  String get finance_gapRestock;

  /// No description provided for @finance_gapWeeks.
  ///
  /// In en, this message translates to:
  /// **'Sell in {needed} of every 12 weeks (now {have})'**
  String finance_gapWeeks(String needed, String have);

  /// No description provided for @finance_gapDigital.
  ///
  /// In en, this message translates to:
  /// **'Take at least {target} of sales digitally (now {have})'**
  String finance_gapDigital(String target, String have);

  /// No description provided for @finance_gapMargin.
  ///
  /// In en, this message translates to:
  /// **'Reach a {target} profit margin (now {have})'**
  String finance_gapMargin(String target, String have);

  /// No description provided for @finance_gapCredit.
  ///
  /// In en, this message translates to:
  /// **'Collect credit until less than half a month\'s sales is owed'**
  String get finance_gapCredit;

  /// No description provided for @finance_disclaimer.
  ///
  /// In en, this message translates to:
  /// **'These are examples that show how matching works, not loan offers. Ask a lender for real terms.'**
  String get finance_disclaimer;

  /// No description provided for @finance_loadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load money health. Check your connection and try again.'**
  String get finance_loadError;

  /// No description provided for @finance_tipsAsk.
  ///
  /// In en, this message translates to:
  /// **'Get advice from EasySell AI'**
  String get finance_tipsAsk;

  /// No description provided for @finance_tipsThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get finance_tipsThinking;

  /// No description provided for @finance_tipsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI advice'**
  String get finance_tipsTitle;

  /// No description provided for @finance_tipsNote.
  ///
  /// In en, this message translates to:
  /// **'Based on the numbers above. Check them before you act.'**
  String get finance_tipsNote;

  /// No description provided for @finance_tipsError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get advice right now.'**
  String get finance_tipsError;

  /// No description provided for @finance_tipOverdue.
  ///
  /// In en, this message translates to:
  /// **'Visit or call {name} this week and collect part of the {amount} they owe.'**
  String finance_tipOverdue(String name, String amount);

  /// No description provided for @finance_tipCashShort.
  ///
  /// In en, this message translates to:
  /// **'Restock smaller this week: restocks cost {amount} more than the money that came in.'**
  String finance_tipCashShort(String amount);

  /// No description provided for @finance_tipCreditGrowing.
  ///
  /// In en, this message translates to:
  /// **'Give less new credit this week and collect old dues first. {total} is owed now.'**
  String finance_tipCreditGrowing(String total);

  /// No description provided for @finance_tipSalesDrop.
  ///
  /// In en, this message translates to:
  /// **'Sales fell {percent}. Check which items ran out and restock your best sellers first.'**
  String finance_tipSalesDrop(String percent);

  /// No description provided for @finance_tipCollectEarly.
  ///
  /// In en, this message translates to:
  /// **'Collect the {amount} customers owe before it gets old. Small, regular collections are easiest.'**
  String finance_tipCollectEarly(String amount);

  /// No description provided for @finance_tipGoDigital.
  ///
  /// In en, this message translates to:
  /// **'Ask customers to pay by mobile wallet more often. Digital sales build a record lenders trust.'**
  String get finance_tipGoDigital;

  /// No description provided for @finance_tipFinancing.
  ///
  /// In en, this message translates to:
  /// **'{option} could help your shop. Compare the lender\'s terms before you decide.'**
  String finance_tipFinancing(String option);

  /// No description provided for @finance_tipKeepRecording.
  ///
  /// In en, this message translates to:
  /// **'Keep recording every sale and restock so your money picture stays accurate.'**
  String get finance_tipKeepRecording;

  /// No description provided for @backup_section.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get backup_section;

  /// No description provided for @backup_now.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backup_now;

  /// No description provided for @backup_never.
  ///
  /// In en, this message translates to:
  /// **'Never backed up. Your shop lives only on this phone.'**
  String get backup_never;

  /// No description provided for @backup_daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Last backup: today} =1{Last backup: yesterday} other{Last backup: {days} days ago}}'**
  String backup_daysAgo(int days);

  /// No description provided for @backup_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get backup_restore;

  /// No description provided for @backup_restoreSub.
  ///
  /// In en, this message translates to:
  /// **'Bring the shop back from a backup file'**
  String get backup_restoreSub;

  /// No description provided for @backup_restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace everything on this phone?'**
  String get backup_restoreConfirmTitle;

  /// No description provided for @backup_restoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This backup of {shop} has {products} products and {sales} sales, made {date}. Everything on this phone now will be replaced.'**
  String backup_restoreConfirmBody(
    String shop,
    int products,
    int sales,
    String date,
  );

  /// No description provided for @backup_restoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backup_restoreButton;

  /// No description provided for @backup_restored.
  ///
  /// In en, this message translates to:
  /// **'Shop restored from backup'**
  String get backup_restored;

  /// No description provided for @backup_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t finish. Please try again.'**
  String get backup_failed;

  /// No description provided for @backup_notBackup.
  ///
  /// In en, this message translates to:
  /// **'That file isn\'t an EasySell backup.'**
  String get backup_notBackup;

  /// No description provided for @backup_shareSubject.
  ///
  /// In en, this message translates to:
  /// **'EasySell shop backup'**
  String get backup_shareSubject;

  /// No description provided for @teach_title.
  ///
  /// In en, this message translates to:
  /// **'Photos for scanning'**
  String get teach_title;

  /// No description provided for @teach_none.
  ///
  /// In en, this message translates to:
  /// **'Take 2–3 photos from different sides so Scan can recognise this product, even without a label.'**
  String get teach_none;

  /// No description provided for @teach_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Scan knows this product from 1 photo. Add one more from another side.} other{Scan knows this product from {count} photos. Every sale you scan teaches it more.}}'**
  String teach_count(int count);

  /// No description provided for @teach_add.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get teach_add;

  /// No description provided for @teach_learning.
  ///
  /// In en, this message translates to:
  /// **'Learning…'**
  String get teach_learning;

  /// No description provided for @teach_failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t learn from that photo. Please try again.'**
  String get teach_failed;

  /// No description provided for @teach_removeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this photo?'**
  String get teach_removeTitle;

  /// No description provided for @teach_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get teach_remove;

  /// No description provided for @teach_fromScan.
  ///
  /// In en, this message translates to:
  /// **'Learned from a scan'**
  String get teach_fromScan;

  /// No description provided for @settings_licenses.
  ///
  /// In en, this message translates to:
  /// **'About & licenses'**
  String get settings_licenses;

  /// No description provided for @settings_licensesSub.
  ///
  /// In en, this message translates to:
  /// **'Open-source software and AI training credits'**
  String get settings_licensesSub;
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
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
