
import 'package:ai_shopkeeper/core/config/theme.dart';
import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/auth/data/auth_repository.dart';
import 'package:ai_shopkeeper/features/inventory/domain/category.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/category_controller.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/inventory_controller.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/inventory_list_screen.dart';
import 'package:ai_shopkeeper/features/voice/data/speech_capture.dart';
import 'package:ai_shopkeeper/features/voice/data/voice_sale_repository.dart';
import 'package:ai_shopkeeper/features/voice/domain/voice_parse_result.dart';
import 'package:ai_shopkeeper/features/voice/presentation/voice_controller.dart';
import 'package:ai_shopkeeper/features/voice/presentation/voice_sale_sheet.dart';
import 'package:ai_shopkeeper/features/restock/domain/restock_plan.dart';
import 'package:ai_shopkeeper/features/restock/presentation/restock_providers.dart';
import 'package:ai_shopkeeper/l10n/app_localizations.dart';
import 'package:ai_shopkeeper/shared/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/voice_fakes.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeVoiceRepo extends FakeVoiceRepo {
  _FakeVoiceRepo(Result<VoiceParseResult> result) : super(result);
}

Product _p(String id, {required String name}) =>
    Product(id: id, shopId: 's', name: name, quantity: 10);

ProviderContainer _container({
  required FakeSpeechCapture recorder,
  Result<VoiceParseResult>? parseResult,
  List<Product> products = const [],
}) {
  return ProviderContainer(
    overrides: [
      speechCaptureProvider.overrideWithValue(recorder),
      voiceSaleRepositoryProvider.overrideWithValue(
        _FakeVoiceRepo(
          parseResult ?? Result.success(VoiceParseResult(items: const [])),
        ),
      ),
      productsStreamProvider.overrideWith((ref) => Stream.value(products)),
    ],
  );
}

Widget _harness(ProviderContainer container, {required Widget child}) =>
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
        home: Scaffold(body: child),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('idle shows the mic hint; tapping mic transitions to listening', (
    tester,
  ) async {
    final recorder = FakeSpeechCapture();
    final container = _container(recorder: recorder);
    addTearDown(container.dispose);

    await tester.pumpWidget(_harness(container, child: const VoiceSaleSheet()));
    await tester.pumpAndSettle();

    expect(find.text('Tap the mic and say what you sold'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);

    // Not pumpAndSettle: the listening pane's pulsing mic repeats forever, so
    // pumpAndSettle would never observe animations settling.
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();

    expect(container.read(voiceControllerProvider).phase, VoicePhase.listening);
    expect(find.text('Listening…'), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsOneWidget);

    // Leaves `listening` before the test body returns: the controller arms a
    // real auto-stop Timer on entering listening, and Flutter's pending-timer
    // invariant check runs before addTearDown callbacks, so relying on
    // container.dispose() alone here would fail even though the timer is
    // correctly cancelled on disposal.
    container.read(voiceControllerProvider.notifier).reset();
  });

  testWidgets(
    'error phase with micDenied shows the mapped l10n string and Retry '
    'resets to idle',
    (tester) async {
      final recorder = FakeSpeechCapture(permissionOk: false);
      final container = _container(recorder: recorder);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(container, child: const VoiceSaleSheet()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();

      expect(container.read(voiceControllerProvider).phase, VoicePhase.error);
      expect(
        find.text('Microphone access is off. Turn it on in Settings.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(container.read(voiceControllerProvider).phase, VoicePhase.idle);
      expect(find.text('Tap the mic and say what you sold'), findsOneWidget);
    },
  );

  testWidgets('reviewing phase renders the review sheet\'s title', (
    tester,
  ) async {
    final recorder = FakeSpeechCapture();
    final parsed = VoiceParseResult(
      items: [
        VoiceItem(
          heard: 'pepsi',
          quantity: 2,
          quantityAssumed: false,
          matches: const [VoiceMatch(productId: 'p1', confidence: 0.93)],
        ),
      ],
    );
    final container = _container(
      recorder: recorder,
      parseResult: Result.success(parsed),
      products: [_p('p1', name: 'Pepsi 500ml')],
    );
    addTearDown(container.dispose);

    final notifier = container.read(voiceControllerProvider.notifier);
    await notifier.startListening();
    await notifier.stopAndParse();

    expect(container.read(voiceControllerProvider).phase, VoicePhase.reviewing);

    await tester.pumpWidget(_harness(container, child: const VoiceSaleSheet()));
    await tester.pumpAndSettle();

    expect(find.text('Speak a sale'), findsOneWidget); // voice_title
    expect(find.text('Add to cart'), findsOneWidget); // VoiceReviewSheet footer
  });

  testWidgets(
    'showVoiceSaleSheet resets the controller and cancels the recorder '
    'when the sheet is dismissed without completing the flow',
    (tester) async {
      final recorder = FakeSpeechCapture();
      final container = _container(recorder: recorder);
      addTearDown(container.dispose);

      // Goes through the real showVoiceSaleSheet entry point (not
      // VoiceSaleSheet pumped directly) so the `.whenComplete(reset)` wiring
      // itself is exercised, not bypassed.
      await tester.pumpWidget(
        _harness(
          container,
          child: Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () => showVoiceSaleSheet(context, ref),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Enter `listening` with the fake recorder live -- not pumpAndSettle:
      // the listening pane's pulsing mic repeats forever.
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();

      expect(
        container.read(voiceControllerProvider).phase,
        VoicePhase.listening,
      );
      expect(recorder.cancelled, isFalse);

      // Dismiss the sheet by popping its route directly -- deterministic,
      // and exercises the exact same Future the sheet's swipe-to-dismiss and
      // back button resolve through.
      Navigator.of(tester.element(find.byIcon(Icons.stop))).pop();
      await tester.pumpAndSettle();

      expect(container.read(voiceControllerProvider).phase, VoicePhase.idle);
      expect(
        recorder.cancelled,
        isTrue,
        reason:
            'showVoiceSaleSheet must reset() on dismissal so a live '
            'recording never keeps running in the background',
      );
    },
  );

  group('entry point flag gating', () {
    // FeatureFlags.voiceSaleEnabled is a compile-time `bool.fromEnvironment`
    // read, which is fixed at compile time -- a widget test process can't
    // flip it mid-run. `flutter test --dart-define=VOICE_SALE_ENABLED=true`
    // would flip the *whole* compilation, not just this test, so a single
    // `flutter test` invocation can only ever observe one value of the flag.
    // This test instead pins down the behavior that actually matters for the
    // default (and CI/release) build: with no dart-define passed -- the flag's
    // documented default -- the host screen must build cleanly with the mic
    // action entirely absent. A manual check that the flag flips the button
    // on is recorded in task-12-report.md (`flutter test
    // --dart-define=VOICE_SALE_ENABLED=true`).
    testWidgets('with the flag at its default (off), the inventory screen builds '
        'without a mic action', (tester) async {
      final container = ProviderContainer(
        overrides: [
          myShopProvider.overrideWith((ref) async => null),
          productsStreamProvider.overrideWith(
            (ref) => Stream.value(const <Product>[]),
          ),
          usedCategoriesProvider.overrideWith((ref) => const <Category>[]),
          // The header's restock count; unstubbed it starts the real date timer.
          restockPlanProvider.overrideWithValue(
            const AsyncValue.data(RestockPlan.empty),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _harness(container, child: const InventoryListScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.byTooltip('Speak a sale'), findsNothing);
    });
  });
}
