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

  // Credits the EasySell Vision model's training data and teacher, the
  // bundled Bangla speech model and the Bangla-English dictionary require
  // (Settings -> About & licenses).
  LicenseRegistry.addLicense(
    () => Stream.fromIterable(const [
      LicenseEntryWithLineBreaks(['EasySell Vision'], _visionCredits),
      LicenseEntryWithLineBreaks(['Bangla speech model'], _speechCredits),
      LicenseEntryWithLineBreaks(['Bangla-English dictionary'], _dictionaryCredits),
    ]),
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

const _speechCredits = '''
Offline Bangla speech recognition uses the streaming Zipformer model
vosk-model-small-streaming-bn by Alpha Cephei Inc.
(https://huggingface.co/alphacep/vosk-model-small-streaming-bn),
Apache License 2.0, run with sherpa-onnx (k2-fsa), Apache License 2.0.
Modified: fine-tuned for EasySell with shop-noise augmentation on
  - Large Bengali ASR training data (OpenSLR 53) and Crowdsourced
    high-quality Bengali multi-speaker speech (OpenSLR 37), Google,
    CC BY-SA 4.0 (https://openslr.org/53, https://openslr.org/37);
  - FLEURS Bengali, Google, CC BY 4.0
    (https://huggingface.co/datasets/google/fleurs);
and the weights quantised to 8-bit for the app.

Licensed under the Apache License, Version 2.0 (the "License"); you may not
use this file except in compliance with the License. You may obtain a copy of
the License at http://www.apache.org/licenses/LICENSE-2.0. Unless required by
applicable law or agreed to in writing, software distributed under the
License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
OF ANY KIND, either express or implied.''';

const _dictionaryCredits = '''
Product names are matched across Bangla and English (a cover reading
পদার্থবিজ্ঞান finds a book saved as Physics) with word meanings from English
Wiktionary's Bengali entries (https://en.wiktionary.org), by Wiktionary
contributors, as extracted by wiktextract (Tatu Ylonen,
https://kaikki.org/dictionary/Bengali/). Licensed under the Creative Commons
Attribution-ShareAlike 4.0 License
(https://creativecommons.org/licenses/by-sa/4.0/). Modified: reduced to
single-word English meanings (lib/core/matching/bilingual_lexicon.dart,
built by ml/build_lexicon.py).''';
