import 'dart:async';

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
import 'package:ai_shopkeeper/features/transactions/presentation/sales_providers.dart';
import 'package:ai_shopkeeper/l10n/app_localizations.dart';
import 'package:ai_shopkeeper/shared/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/voice_fakes.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fails the first parse, then succeeds; records what it was asked.
class _FlakyRepo extends FakeVoiceRepo {
  _FlakyRepo(this.success);

  final Result<VoiceParseResult> success;
  final transcriptsSeen = <String>[];

  int get audioCalls => parseCalls;

  @override
  Future<Result<VoiceParseResult>> parseTranscript({
    required String transcript,
    required List<Product> products,
    List<String> alternatives = const [],
    Map<String, double> recentUnits = const {},
  }) async {
    transcriptsSeen.add(transcript);
    await super.parseTranscript(transcript: transcript, products: products);
    return parseCalls == 1
        ? const Result<VoiceParseResult>.failure(
            DatabaseFailure('Could not understand that. Please try again.'),
          )
        : resolveVoiceIndexes(success, products);
  }
}

ProviderContainer _container({
  required FakeSpeechCapture recorder,
  required VoiceSaleRepository repo,
  Duration cap = const Duration(seconds: 15),
}) {
  final container = ProviderContainer(
    overrides: [
      speechCaptureProvider.overrideWithValue(recorder),
      voiceSaleRepositoryProvider.overrideWithValue(repo),
      productsStreamProvider.overrideWith((ref) => Stream.value(const [])),
      recentUnitsSoldProvider.overrideWith((ref) => const <String, double>{}),
      maxRecordingDurationProvider.overrideWithValue(cap),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Ends the recording inside the test body so the duration-cap Timer does not
/// outlive it -- exactly what `showVoiceSaleSheet`'s `whenComplete` does when
/// the sheet is dismissed mid-recording. Must be called in the body, not an
/// `addTearDown`: the binding's pending-timer assertion runs before teardowns.
Future<void> _endRecording(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(voiceControllerProvider.notifier).reset();
  await tester.pump();
  // Riverpod's zero-length housekeeping timers from the session.
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _pumpSheet(
  WidgetTester tester,
  ProviderContainer container,
) async {
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
  await tester.pump();
}

final _oneLine = VoiceParseResult(
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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('mic level meter', () {
    testWidgets('reflects what the microphone is actually hearing', (
      tester,
    ) async {
      final recorder = FakeSpeechCapture();
      final container = _container(
        recorder: recorder,
        repo: _FlakyRepo(Result.success(_oneLine)),
      );

      await container.read(voiceControllerProvider.notifier).startListening();
      await _pumpSheet(tester, container);

      // A silent room lights no bars.
      expect(container.read(micLevelProvider), 0);

      recorder.level(0.9); // loud, clear speech
      await tester.pump();

      expect(container.read(micLevelProvider), greaterThan(0.7));

      recorder.level(0.0); // digital silence
      await tester.pump();

      expect(container.read(micLevelProvider), 0);
      await _endRecording(tester, container);
    });

    testWidgets('warns the shopkeeper when nothing is reaching the mic', (
      tester,
    ) async {
      final recorder = FakeSpeechCapture();
      final container = _container(
        recorder: recorder,
        repo: _FlakyRepo(Result.success(_oneLine)),
      );

      await container.read(voiceControllerProvider.notifier).startListening();
      await _pumpSheet(tester, container);

      // Nothing yet: people take a beat before speaking, and an instant nag
      // would be noise.
      expect(find.textContaining('hold the phone closer'), findsNothing);

      await tester.pump(const Duration(seconds: 3));

      expect(find.textContaining('hold the phone closer'), findsOneWidget);
      await _endRecording(tester, container);
    });

    testWidgets('does not warn once real speech has been heard', (
      tester,
    ) async {
      final recorder = FakeSpeechCapture();
      final container = _container(
        recorder: recorder,
        repo: _FlakyRepo(Result.success(_oneLine)),
      );

      await container.read(voiceControllerProvider.notifier).startListening();
      await _pumpSheet(tester, container);

      recorder.level(0.9);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(find.textContaining('hold the phone closer'), findsNothing);
      await _endRecording(tester, container);
    });
  });

  group('auto-stop countdown', () {
    testWidgets('stays hidden for most of the recording, then counts down', (
      tester,
    ) async {
      final recorder = FakeSpeechCapture();
      final container = _container(
        recorder: recorder,
        repo: _FlakyRepo(Result.success(_oneLine)),
        cap: const Duration(seconds: 15),
      );

      await container.read(voiceControllerProvider.notifier).startListening();
      await _pumpSheet(tester, container);

      expect(find.textContaining('Stopping in'), findsNothing);

      // Into the warning window (15s cap, 5s warning).
      await tester.pump(const Duration(seconds: 11));
      expect(find.text('Stopping in 4s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Stopping in 2s'), findsOneWidget);

      // Let the cap's backstop fire so no timer outlives the test.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('retrying a failed parse', () {
    testWidgets('re-sends the same recording instead of making the shopkeeper '
        'say the sale again', (tester) async {
      final recorder = FakeSpeechCapture();
      final repo = _FlakyRepo(Result.success(_oneLine));
      final container = _container(recorder: recorder, repo: repo);
      final notifier = container.read(voiceControllerProvider.notifier);

      await notifier.startListening();
      await notifier.stopAndParse();
      await _pumpSheet(tester, container);

      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Record again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(repo.audioCalls, 2);
      expect(repo.transcriptsSeen.first, repo.transcriptsSeen.last);
      expect(
        container.read(voiceControllerProvider).phase,
        VoicePhase.reviewing,
      );
    });

    testWidgets('offers only a fresh recording when nothing was heard', (
      tester,
    ) async {
      final recorder = FakeSpeechCapture(heard: const Heard(''));
      final container = _container(
        recorder: recorder,
        repo: _FlakyRepo(Result.success(_oneLine)),
      );
      final notifier = container.read(voiceControllerProvider.notifier);

      await notifier.startListening();
      await notifier.stopAndParse();
      await _pumpSheet(tester, container);

      expect(find.text('Try again'), findsOneWidget);
      // There are no words to re-read, so no second, confusing choice.
      expect(find.text('Record again'), findsNothing);
      await _endRecording(tester, container);
    });
  });
}
