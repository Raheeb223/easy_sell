import 'dart:async';

import 'package:ai_shopkeeper/core/config/theme.dart';
import 'package:ai_shopkeeper/core/error/failure.dart';
import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/inventory_controller.dart';
import 'package:ai_shopkeeper/features/transactions/presentation/sales_providers.dart';
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

class _PendingRepo extends FakeVoiceRepo {
  _PendingRepo() : this._(Completer<Result<VoiceParseResult>>());
  _PendingRepo._(this.completer) : super(null, completer);
  final Completer<Result<VoiceParseResult>> completer;
}

/// The wait pane used to be two static grey boxes, which made a three-second
/// parse indistinguishable from a hang. These tests pin down what replaced it:
/// named stages that visibly advance, and -- load-bearing for the backgrounding
/// feature -- an explicit invitation to close the sheet and walk away.
///
/// Never `pumpAndSettle` here: the active stage carries a
/// [CircularProgressIndicator], which by design never settles.

ProviderContainer _container(VoiceSaleRepository repo) {
  final container = ProviderContainer(
    overrides: [
      speechCaptureProvider.overrideWithValue(FakeSpeechCapture()),
      voiceSaleRepositoryProvider.overrideWithValue(repo),
      productsStreamProvider.overrideWith(
        (ref) =>
            Stream.value([const Product(id: 'p1', shopId: 's', name: 'Pepsi')]),
      ),
      recentUnitsSoldProvider.overrideWith((ref) => const <String, double>{}),
      autoStopOnSilenceProvider.overrideWithValue(false),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
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
);

/// Leaves the controller in `thinking` with the pane on screen.
Future<void> _intoThinking(
  WidgetTester tester,
  ProviderContainer container,
  _PendingRepo repo,
) async {
  final notifier = container.read(voiceControllerProvider.notifier);
  await notifier.startListening();
  unawaited(notifier.stopAndParse());
  for (var i = 0; i < 10 && !repo.parseCalled; i++) {
    await tester.pump();
  }
  expect(repo.parseCalled, isTrue);
  await tester.pump();
}

/// Lets the pending parse finish so no timer outlives the test.
Future<void> _finish(WidgetTester tester, _PendingRepo repo) async {
  repo.completer.complete(const Result.failure(UnexpectedFailure('done')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('names every stage and says the sheet can be closed', (
    tester,
  ) async {
    final repo = _PendingRepo();
    final container = _container(repo);
    await tester.pumpWidget(_app(container));
    await _intoThinking(tester, container, repo);

    expect(find.text('Heard you'), findsOneWidget);
    expect(find.text('Understanding what you said'), findsOneWidget);
    expect(find.text('Finding your items'), findsOneWidget);
    expect(
      find.text('Continue in background'),
      findsOneWidget,
      reason:
          'the hint used to stand alone, leaving people to guess the gesture',
    );
    expect(
      find.textContaining("buzz you"),
      findsOneWidget,
      reason: 'without this nobody discovers they can walk away',
    );

    await _finish(tester, repo);
  });

  testWidgets('stages tick over as the wait goes on', (tester) async {
    final repo = _PendingRepo();
    final container = _container(repo);
    await tester.pumpWidget(_app(container));
    await _intoThinking(tester, container, repo);

    // Nothing is done yet -- the first stage is the live one.
    expect(find.byIcon(Icons.check_circle), findsNothing);

    // Past the first stage's 900ms.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // Past the second stage's further 1500ms.
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

    // The last stage never self-completes: it waits for the real answer rather
    // than claiming to be finished.
    await tester.pump(const Duration(seconds: 10));
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

    await _finish(tester, repo);
  });

  testWidgets('the progress bar advances but never reaches full', (
    tester,
  ) async {
    final repo = _PendingRepo();
    final container = _container(repo);
    await tester.pumpWidget(_app(container));
    await _intoThinking(tester, container, repo);

    double value() => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    final early = value();
    await tester.pump(const Duration(seconds: 2));
    final later = value();

    expect(later, greaterThan(early));
    // A bar that hits 100% before the answer lands is worse than none at all.
    await tester.pump(const Duration(seconds: 30));
    expect(value(), lessThan(1.0));

    await _finish(tester, repo);
  });
}
