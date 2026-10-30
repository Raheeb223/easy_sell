
import 'package:ai_shopkeeper/core/config/theme.dart';
import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/inventory_controller.dart';
import 'package:ai_shopkeeper/features/voice/data/speech_capture.dart';
import 'package:ai_shopkeeper/features/voice/data/voice_sale_repository.dart';
import 'package:ai_shopkeeper/features/voice/domain/voice_parse_result.dart';
import 'package:ai_shopkeeper/features/voice/presentation/voice_controller.dart';
import 'package:ai_shopkeeper/features/voice/presentation/voice_review_sheet.dart';
import 'package:ai_shopkeeper/l10n/app_localizations.dart';
import 'package:ai_shopkeeper/shared/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/voice_fakes.dart';
import 'package:google_fonts/google_fonts.dart';

/// First parse (speech) returns [audio]; later ones (typed text) [text].
class _FakeRepo extends FakeVoiceRepo {
  _FakeRepo(this.audio, this.text);
  final Result<VoiceParseResult> audio;
  final Result<VoiceParseResult> text;

  @override
  Future<Result<VoiceParseResult>> parseTranscript({
    required String transcript,
    required List<Product> products,
    List<String> alternatives = const [],
    Map<String, double> recentUnits = const {},
  }) async {
    final first = parseCalls == 0;
    await super.parseTranscript(transcript: transcript, products: products);
    return resolveVoiceIndexes(first ? audio : text, products);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('editing the heard text re-parses and updates the lines', (tester) async {
    final audio = VoiceParseResult(
      heardText: 'pepci',
      items: [VoiceItem(heard: 'pepci', quantity: 1, quantityAssumed: true, matches: const [VoiceMatch(productId: 'p1', confidence: 0.4)])],
    );
    final text = VoiceParseResult(
      heardText: '2 pepsi',
      items: [VoiceItem(heard: 'pepsi', quantity: 2, quantityAssumed: false, matches: const [VoiceMatch(productId: 'p1', confidence: 0.95)])],
    );
    final container = ProviderContainer(
      overrides: [
        speechCaptureProvider.overrideWithValue(FakeSpeechCapture()),
        voiceSaleRepositoryProvider.overrideWithValue(_FakeRepo(Result.success(audio), Result.success(text))),
        productsStreamProvider.overrideWith(
          (ref) => Stream.value(const [Product(id: 'p1', shopId: 's', name: 'Pepsi 1L', quantity: 9)]),
        ),
      ],
    );
    final n = container.read(voiceControllerProvider.notifier);
    await n.startListening();
    await n.stopAndParse();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: supportedAppLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: VoiceReviewSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the heard line to open the editor. Scoped to "I heard" (not just
    // "pepci") because the unsettled line below also renders its own
    // '"pepci"' text (the not-found row's raw heard text) -- a bare
    // `textContaining('pepci')` matches both and tap() rejects the ambiguity.
    await tester.tap(find.textContaining('I heard'));
    await tester.pumpAndSettle();

    // Replace the text and confirm.
    await tester.enterText(find.byType(TextField).last, '2 pepsi');
    await tester.tap(find.text('Re-check'));
    await tester.pumpAndSettle();

    // Lines rebuilt from the re-parse.
    expect(find.textContaining('2 pepsi'), findsWidgets);
    expect(container.read(voiceControllerProvider).lines.first.quantity, 2);
  });
}
