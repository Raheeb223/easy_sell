
import 'package:ai_shopkeeper/core/config/theme.dart';
import 'package:ai_shopkeeper/core/error/failure.dart';
import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/inventory_controller.dart';
import 'package:ai_shopkeeper/features/voice/data/speech_capture.dart';
import 'package:ai_shopkeeper/features/voice/data/voice_sale_repository.dart';
import 'package:ai_shopkeeper/features/voice/domain/voice_parse_result.dart';
import 'package:ai_shopkeeper/features/voice/presentation/voice_controller.dart';
import 'package:ai_shopkeeper/features/voice/presentation/voice_sale_sheet.dart';
import 'package:ai_shopkeeper/l10n/app_localizations.dart';
import 'package:ai_shopkeeper/shared/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/voice_fakes.dart';
import 'package:google_fonts/google_fonts.dart';

/// The spoken parse fails the way a noisy-room mishear does; the typed text
/// path then succeeds.
class _FakeRepo extends FakeVoiceRepo {
  _FakeRepo(this.text)
      : audio = const Result<VoiceParseResult>.failure(
          DatabaseFailure('Could not understand that. Please try again.'),
        );
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

  testWidgets('the error pane can recover by typing the sale instead', (
    tester,
  ) async {
    final typed = VoiceParseResult(
      heardText: '2 pepsi',
      items: [
        VoiceItem(
          heard: 'pepsi',
          quantity: 2,
          quantityAssumed: false,
          matches: const [VoiceMatch(productId: 'p1', confidence: 0.95)],
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        speechCaptureProvider.overrideWithValue(FakeSpeechCapture()),
        voiceSaleRepositoryProvider.overrideWithValue(
          _FakeRepo(Result.success(typed)),
        ),
        productsStreamProvider.overrideWith(
          (ref) => Stream.value(const [
            Product(id: 'p1', shopId: 's', name: 'Pepsi 1L', quantity: 9),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final n = container.read(voiceControllerProvider.notifier);
    await n.startListening();
    await n.stopAndParse();
    expect(container.read(voiceControllerProvider).phase, VoicePhase.error);

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
          home: const Scaffold(body: VoiceSaleSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type it instead'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '2 pepsi');
    await tester.tap(find.text('Re-check'));
    await tester.pumpAndSettle();

    final state = container.read(voiceControllerProvider);
    expect(state.phase, VoicePhase.reviewing);
    expect(state.lines, hasLength(1));
    expect(state.lines.single.quantity, 2);
  });
}
