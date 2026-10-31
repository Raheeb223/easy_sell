import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/db/photo_store.dart';
import 'features/expiry/data/reminder_service.dart';
import 'features/expiry/presentation/expiry_prefs.dart';
import 'features/restock/presentation/restock_prefs.dart';
import 'shared/providers/locale_provider.dart';
import 'shared/providers/onboarding_provider.dart';
import 'shared/providers/theme_mode_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw behind the status and navigation bars; the per-theme overlay style
  // (icon contrast) is set in App's builder so it tracks light/dark.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Credits the EasySell Vision model's training data and teacher require
  // (shown on Settings -> About & licenses).
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(['EasySell Vision'], _visionCredits),
    ),
  );

  // The shop's whole database lives on this phone (phone-only design).
  final db = await AppDatabase.open();
  final photos = await PhotoStore.open();

  final seenOnboarding = await loadOnboardingSeen();
  final themeMode = await loadThemeMode();
  await initializeDateFormatting();
  final locale = await loadLocale();
  final expiryPrefs = await loadExpiryPrefs();
  final restockDays = await loadRestockDays();
  // The plugin can fail on an odd device or emulator; reminders are a nicety,
  // so fall back to no reminders rather than failing to start.
  ReminderService reminders = const NoopReminderService();
  try {
    final local = LocalReminderService();
    await local.init();
    reminders = local;
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        initialOnboardingSeenProvider.overrideWithValue(seenOnboarding),
        initialThemeModeProvider.overrideWithValue(themeMode),
        initialLocaleProvider.overrideWithValue(locale),
        initialExpiryPrefsProvider.overrideWithValue(expiryPrefs),
        initialRestockDaysProvider.overrideWithValue(restockDays),
        reminderServiceProvider.overrideWithValue(reminders),
        appDatabaseProvider.overrideWithValue(db),
        photoStoreProvider.overrideWithValue(photos),
      ],
      child: const App(),
    ),
  );
}

const _visionCredits = '''
EasySell Vision, the on-device product recognition model, was trained with:

Product photos and data from Open Food Facts, Open Beauty Facts, Open Pet Food
Facts and Open Products Facts (https://world.openfoodfacts.org), contributed
by their community. Photos: Creative Commons Attribution-ShareAlike 3.0.
Database: Open Database License (ODbL).

Grocery Store Dataset, M. Klasson, C. Zhang, H. Kjellstrom (2019), MIT License.

Teacher model: SigLIP (Google), Apache License 2.0.
Student backbone: MobileNetV3 weights from timm (Ross Wightman), Apache License 2.0.''';
