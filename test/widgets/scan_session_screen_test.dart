import 'dart:async';
import 'dart:typed_data';

import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/cart/presentation/cart_controller.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/inventory_controller.dart';
import 'package:ai_shopkeeper/features/scan/data/scan_camera.dart';
import 'package:ai_shopkeeper/features/scan/data/vision_scan_repository.dart';
import 'package:ai_shopkeeper/features/scan/domain/recognition_result.dart';
import 'package:ai_shopkeeper/features/scan/presentation/scan_session_controller.dart';
import 'package:ai_shopkeeper/features/scan/presentation/scan_session_screen.dart';
import 'package:ai_shopkeeper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/scan_fakes.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const _pepsi = Product(
  id: 'p-pepsi',
  shopId: 's1',
  name: 'Pepsi',
  sellingPrice: 50,
  quantity: 10,
  unit: ProductUnit.pcs,
);

const _outOfStock = Product(
  id: 'p-oos',
  shopId: 's1',
  name: 'Sold Out Soda',
  sellingPrice: 40,
  quantity: 0,
  unit: ProductUnit.pcs,
);

class _InstantRepo extends IndexedScanRepo {
  @override
  Future<Result<RecognitionResult>> recognizeIndexed({
    required Uint8List imageBytes,
    required List<Product> products,
  }) async => Result.success(
    const RecognitionResult(
      status: RecognitionStatus.match,
      matches: [ProductMatch(productId: '0', confidence: 0.95)],
    ),
  );
}

/// Always throws [CameraUnavailable] on `initialize()` -- the
/// no-camera-hardware case, distinct from a refused permission.
class _UnavailableCamera implements ScanCamera {
  @override
  Future<void> initialize() async => throw const CameraUnavailable();

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: Color(0xFF202020));

  @override
  Future<Uint8List> capture() async =>
      throw StateError('capture() before initialize()');

  @override
  Future<void> dispose() async {}
}

/// Always throws a generic, untyped `CameraException` on `initialize()` --
/// neither a permission refusal nor "no hardware". Regression coverage for
/// the case that used to fall through both `on` clauses in `_start()` and
/// leave the screen on an indeterminate spinner forever.
class _FaultyCamera implements ScanCamera {
  @override
  Future<void> initialize() async => throw Exception('boom');

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: Color(0xFF202020));

  @override
  Future<Uint8List> capture() async =>
      throw StateError('capture() before initialize()');

  @override
  Future<void> dispose() async {}
}

/// `ScanSessionScreen` calls `context.pop()` (go_router) from both the leave
/// confirmation and after "Add", so a bare `MaterialApp` throws the moment
/// either fires. Pushed from a base route so there is something to pop back
/// to, matching the pattern `cart_checkout_snackbar_test.dart` already uses
/// for the same reason.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  ScanCamera? camera,
  List<Product> catalog = const [_pepsi],
}) async {
  final c = ProviderContainer(
    overrides: [
      visionScanRepositoryProvider.overrideWithValue(_InstantRepo()),
      scanCameraProvider.overrideWithValue(camera ?? FakeScanCamera()),
      productsStreamProvider.overrideWith((ref) => Stream.value(catalog)),
    ],
  );
  addTearDown(c.dispose);
  final sub = c.listen(productsStreamProvider, (_, _) {});
  addTearDown(sub.close);
  await c.read(productsStreamProvider.future);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/scan'),
            child: const Text('to scan'),
          ),
        ),
      ),
      GoRoute(path: '/scan', builder: (_, _) => const ScanSessionScreen()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.tap(find.text('to scan'));
  await tester.pump();
  // `FakeScanCamera.initialize()` (and `_UnavailableCamera.initialize()`) is
  // async, so `_start()`'s await needs a couple of pumps to land -- one for
  // the initialize() microtask, one for the setState rebuild -- before the
  // viewfinder settles into ready/denied/unavailable. Deliberately bounded
  // pump()s rather than pumpAndSettle(): the `!_ready` branch renders an
  // indeterminate `CircularProgressIndicator`, whose animation never
  // settles, so pumpAndSettle() here would hang exactly like the bug this
  // fix is for.
  await tester.pump();
  await tester.pump();
  return c;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the shutter stays usable while a chip is still recognizing', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('scan-shutter')));
    await tester.pump();
    // The critical property: no per-item confirmation modal, no spinner
    // blocking the camera. Checked directly against `AlertDialog` /
    // `BottomSheet` rather than `ModalBarrier`: both `showDialog` and
    // `showModalBottomSheet` default to a non-null `barrierColor`, so their
    // scrim is Flutter's `AnimatedModalBarrier` (a sibling of
    // `ModalBarrier`, not a subtype) and `find.byType(ModalBarrier)` cannot
    // see them -- confirmed by mutation-testing this assertion with a real
    // `showDialog` in the shutter handler (see the task-5 report).
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const Key('scan-shutter')), findsOneWidget);
  });

  testWidgets('an empty tray gives the Add button no count to announce', (
    tester,
  ) async {
    await _pump(tester);
    // "Add 0 items" on a disabled button reads as an error rather than as
    // "nothing staged yet", which is the ordinary state you land on when the
    // screen opens. Pinned by digit so it fails for either locale's numerals.
    final label = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('scan-add-all')),
            matching: find.byType(Text),
          ),
        )
        .data!;
    expect(
      RegExp(r'[0-9০-৯]').hasMatch(label),
      isFalse,
      reason: 'empty-tray Add label must carry no number, got "$label"',
    );
  });

  testWidgets('three shutter taps of one product show a single x3 chip', (
    tester,
  ) async {
    await _pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('scan-shutter')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Pepsi'), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('Add stages the tray into the cart and empties it', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const Key('scan-shutter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-add-all')));
    await tester.pumpAndSettle();

    expect(c.read(cartControllerProvider).length, 1);
    expect(c.read(cartControllerProvider).single.product.id, 'p-pepsi');
  });

  testWidgets('a denied camera explains itself instead of showing black', (
    tester,
  ) async {
    await _pump(tester, camera: FakeScanCamera(permissionGranted: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera access'), findsOneWidget);
    // Deliberately "Try again", not "Open settings": the button is a plain
    // retry with no permission_handler/app_settings dependency wired up, and
    // the label must not promise a system-settings deep link it cannot do.
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a device with no camera hardware explains itself, with no '
      '"Try again" button -- there is no permission to grant, retrying just '
      'fails the same way', (tester) async {
    await _pump(tester, camera: _UnavailableCamera());
    await tester.pumpAndSettle();
    expect(find.textContaining('no camera'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets(
    'a generic camera fault shows an error with retry instead of an infinite '
    'spinner',
    (tester) async {
      await _pump(tester, camera: _FaultyCamera());
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Scan failed. Try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'a second shutter tap while the first capture is still in flight is '
    'ignored, not dispatched as a second call',
    (tester) async {
      // FakeScanCamera.capture() is otherwise near-instant, too fast for a
      // widget test to ever observe an overlap -- gate it open so the first
      // capture is still pending when the second tap lands, the way a real
      // ~300ms capture would be for two taps 50ms apart.
      final cam = FakeScanCamera()..captureGate = Completer<void>();
      await _pump(tester, camera: cam);
      await tester.tap(find.byKey(const Key('scan-shutter')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('scan-shutter')));
      await tester.pump();
      cam.captureGate!.complete();
      await tester.pumpAndSettle();
      expect(
        cam.captureCount,
        1,
        reason: 'the FAB must guard itself while a capture is in flight',
      );
    },
  );

  testWidgets(
    'a capture whose camera call throws surfaces feedback instead of an '
    'uncaught error, and the shutter stays usable after',
    (tester) async {
      final cam = FakeScanCamera()..failNextCapture = true;
      await _pump(tester, camera: cam);
      await tester.tap(find.byKey(const Key('scan-shutter')));
      await tester.pumpAndSettle();

      expect(find.text('Scan failed. Try again.'), findsOneWidget);
      expect(find.byKey(const Key('scan-shutter')), findsOneWidget);

      // The fault was transient; the shutter must still work afterward.
      await tester.tap(find.byKey(const Key('scan-shutter')));
      await tester.pumpAndSettle();
      expect(find.text('Pepsi'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the scrim during the leave-confirm dialog does not discard the '
    'tray or leave the screen',
    (tester) async {
      final c = await _pump(tester);
      await tester.tap(find.byKey(const Key('scan-shutter')));
      await tester.pumpAndSettle();
      expect(c.read(scanSessionProvider).length, 1);

      await tester.pageBack();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);

      // barrierDismissible is now false -- a tap on the scrim must not
      // dismiss it and must not be treated as Discard.
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();

      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'a scrim tap must not dismiss the dialog',
      );
      expect(
        c.read(scanSessionProvider).length,
        1,
        reason: 'the tray must survive an accidental scrim tap',
      );
      expect(
        find.byKey(const Key('scan-shutter')),
        findsOneWidget,
        reason: 'still on the scan screen, not popped',
      );
    },
  );

  testWidgets(
    'an out-of-stock product resolves to a visible flagged chip instead of '
    'silently vanishing',
    (tester) async {
      await _pump(tester, catalog: const [_outOfStock]);
      await tester.tap(find.byKey(const Key('scan-shutter')));
      await tester.pumpAndSettle();

      expect(find.text('Sold Out Soda'), findsOneWidget);
      expect(find.text('Out of stock'), findsOneWidget);
      // Flagged, not addable: the bar stays disabled with nothing to add.
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('scan-add-all')),
      );
      expect(button.onPressed, isNull);
    },
  );
}
