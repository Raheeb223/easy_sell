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
import 'package:ai_shopkeeper/features/voice/presentation/voice_ready_banner.dart';
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

/// The banner is the only route back to a voice sale whose sheet was dismissed
/// mid-parse, so "it appears exactly when a result is waiting, and tapping it
/// reopens the sheet" is the whole contract.

const _parsed = VoiceParseResult(
  heardText: 'two pepsi',
  items: [
    VoiceItem(
      heard: 'pepsi',
      quantity: 2,
      quantityAssumed: false,
      matches: [VoiceMatch(productId: '0', confidence: 0.95)],
    ),
  ],
);

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

/// Deliberately NOT how `app.dart` mounts the banner. `MaterialApp(home:)`
/// builds a Navigator around its child, so here the banner has one overhead;
/// in the app it is inside `MaterialApp.router`'s builder, above the router,
/// with no Navigator ancestor at all. That gap let a crash-on-tap ship past a
/// green suite -- `voice_banner_reopen_test.dart` exists to cover the real
/// mounting. Keep this harness for behaviour that does not involve pushing a
/// route, and add navigation cases there.
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
    home: const Scaffold(
      body: Column(
        children: [
          VoiceReadyBanner(),
          Expanded(child: SizedBox()),
        ],
      ),
    ),
  ),
);

/// Speaks a sale and dismisses the sheet, leaving the parse in flight -- the
/// state that used to render nothing at all.
///
/// Never `pumpAndSettle` from here on: the pending banner carries a
/// [CircularProgressIndicator], which by design never settles.
Future<void> _dismissMidParse(
  WidgetTester tester,
  ProviderContainer container,
  _PendingRepo repo,
) async {
  final notifier = container.read(voiceControllerProvider.notifier);
  await notifier.startListening();
  // Not awaited: `stopAndParse` only completes when the parse does, and the
  // dismissal has to happen while it is still pending.
  unawaited(notifier.stopAndParse());
  // `tester.pump()`, not `Future.delayed`: inside `testWidgets` time is fake,
  // so a bare delay would never fire and this would spin forever. Bounded so a
  // regression fails the expectation below instead of hanging the suite.
  for (var i = 0; i < 10 && !repo.parseCalled; i++) {
    await tester.pump();
  }
  expect(repo.parseCalled, isTrue, reason: 'parse must be genuinely in flight');

  notifier.releaseSheet();
  // Past the banner's AnimatedSwitcher entrance. A single pump leaves it
  // mid-transition, where it is still wrapped in an IgnorePointer and taps miss
  // it -- but `pumpAndSettle` is not an option, because the pending banner's
  // spinner never settles.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Lets the pending parse resolve so no spinner or timer outlives the test.
Future<void> _finish(WidgetTester tester, _PendingRepo repo) async {
  repo.completer.complete(const Result.failure(NetworkFailure('done')));
  await tester.pumpAndSettle();
}

/// Drives a sale all the way to a finished-but-unclaimed state.
Future<void> _backgroundResult(
  WidgetTester tester,
  ProviderContainer container,
  _PendingRepo repo, {
  required Result<VoiceParseResult> result,
}) async {
  await _dismissMidParse(tester, container, repo);
  repo.completer.complete(result);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('nothing is shown while no result is waiting', (tester) async {
    final container = _container(_PendingRepo());
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('Your voice sale is ready'), findsNothing);
    expect(find.byKey(const ValueKey('voice-ready-banner')), findsNothing);
  });

  testWidgets('a sale still parsing is announced, not hidden', (tester) async {
    // The regression that prompted all of this: dismissing the sheet mid-parse
    // used to leave nothing on screen until the result landed.
    final repo = _PendingRepo();
    final container = _container(repo);
    await tester.pumpWidget(_app(container));
    await tester.pump();

    await _dismissMidParse(tester, container, repo);

    expect(find.text('Working on your voice sale…'), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: 'the spinner is what reads as "still going" at a glance',
    );
    // Not offered as finished work.
    expect(find.text('Review'), findsNothing);

    await _finish(tester, repo);
  });

  testWidgets('tapping a parsing sale reopens it without restarting', (
    tester,
  ) async {
    final repo = _PendingRepo();
    final container = _container(repo);
    await tester.pumpWidget(_app(container));
    await tester.pump();
    await _dismissMidParse(tester, container, repo);

    await tester.tap(find.text('Working on your voice sale…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Back in the sheet, still in the same parse.
    expect(container.read(voiceControllerProvider).phase, VoicePhase.thinking);
    expect(container.read(voiceControllerProvider).background, isFalse);
    expect(find.text('Heard you'), findsOneWidget);

    await _finish(tester, repo);
  });

  testWidgets('the parsing banner can discard the sale deliberately', (
    tester,
  ) async {
    final repo = _PendingRepo();
    final container = _container(repo);
    await tester.pumpWidget(_app(container));
    await tester.pump();
    await _dismissMidParse(tester, container, repo);

    await tester.tap(find.byTooltip('Discard this voice sale'));
    await tester.pumpAndSettle();

    expect(container.read(voiceControllerProvider).phase, VoicePhase.idle);
    expect(find.text('Working on your voice sale…'), findsNothing);

    // A late result must not resurrect it.
    repo.completer.complete(const Result.success(_parsed));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('voice-ready-banner')), findsNothing);
  });

  testWidgets('a finished background sale offers itself for review', (
    tester,
  ) async {
    final repo = _PendingRepo();
    final container = _container(repo);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await _backgroundResult(
      tester,
      container,
      repo,
      result: const Result.success(_parsed),
    );

    expect(find.text('Your voice sale is ready'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('a failed background sale is not dressed up as good news', (
    tester,
  ) async {
    final repo = _PendingRepo();
    final container = _container(repo);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await _backgroundResult(
      tester,
      container,
      repo,
      result: const Result.failure(NetworkFailure('no internet')),
    );

    expect(find.text('Your voice sale needs a look'), findsOneWidget);
    expect(find.text('Your voice sale is ready'), findsNothing);
  });

  testWidgets('tapping reopens the sheet and dismisses the banner', (
    tester,
  ) async {
    final repo = _PendingRepo();
    final container = _container(repo);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await _backgroundResult(
      tester,
      container,
      repo,
      result: const Result.success(_parsed),
    );

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    // The review step is on screen...
    expect(find.text('Speak a sale'), findsOneWidget);
    // ...so the offer to open it must be gone.
    expect(container.read(voiceControllerProvider).background, isFalse);
    expect(find.text('Your voice sale is ready'), findsNothing);
  });
}
