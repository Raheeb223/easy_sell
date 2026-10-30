import 'dart:async';
import 'dart:typed_data';

import 'package:ai_shopkeeper/core/error/failure.dart';
import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/auth/data/auth_repository.dart';
import 'package:ai_shopkeeper/features/auth/domain/shop.dart';
import 'package:ai_shopkeeper/features/cart/presentation/cart_controller.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/inventory_controller.dart';
import 'package:ai_shopkeeper/features/scan/data/scan_camera.dart';
import 'package:ai_shopkeeper/features/scan/data/vision_scan_repository.dart';
import 'package:ai_shopkeeper/features/scan/domain/recognition_result.dart';
import 'package:ai_shopkeeper/features/scan/domain/scan_item.dart';
import 'package:ai_shopkeeper/features/scan/presentation/scan_session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/scan_fakes.dart';

const _pepsi = Product(
  id: 'p-pepsi',
  shopId: 's1',
  name: 'Pepsi',
  sellingPrice: 50,
  quantity: 10,
  unit: ProductUnit.pcs,
);
const _rice = Product(
  id: 'p-rice',
  shopId: 's1',
  name: 'Rice',
  sellingPrice: 80,
  quantity: 20,
  unit: ProductUnit.kg,
  unitType: UnitType.weight,
);
const _catalog = [_pepsi, _rice];

/// Recognition the test drives by hand: each call parks on a completer so the
/// test controls exactly when (and in what order) answers land.
class _ScriptedRepo extends IndexedScanRepo {
  final pending = <Completer<Result<RecognitionResult>>>[];
  int calls = 0;

  @override
  Future<Result<RecognitionResult>> recognizeIndexed({
    required Uint8List imageBytes,
    required List<Product> products,
  }) {
    calls++;
    final c = Completer<Result<RecognitionResult>>();
    pending.add(c);
    return c.future;
  }
}

/// A repository that always THROWS rather than returning `Result.failure` --
/// the case `VisionScanRepository.recognize` promises never to hit (it
/// catches internally) but nothing in the type system enforces. Regression
/// coverage for the "one bad chip never kills the session" rule applying to
/// a rejected future exactly as much as to a `Result.failure`.
class _ThrowingRepo extends IndexedScanRepo {
  int calls = 0;

  @override
  Future<Result<RecognitionResult>> recognizeIndexed({
    required Uint8List imageBytes,
    required List<Product> products,
  }) async {
    calls++;
    throw StateError('boom');
  }
}

Result<RecognitionResult> _match(int index, {double confidence = 0.95}) =>
    Result.success(
      RecognitionResult(
        status: RecognitionStatus.match,
        matches: [ProductMatch(productId: '$index', confidence: confidence)],
        readName: 'read-$index',
      ),
    );

ProviderContainer _container(VisionScanRepository repo, FakeScanCamera cam) {
  final c = ProviderContainer(
    overrides: [
      visionScanRepositoryProvider.overrideWithValue(repo),
      scanCameraProvider.overrideWithValue(cam),
      productsStreamProvider.overrideWith((ref) => Stream.value(_catalog)),
      // CartController.build() watches myShopProvider and rebuilds (wiping the
      // cart) whenever it settles. Left unresolved, it drifts from loading to
      // an error mid-test (Supabase isn't initialized here), resetting any
      // staged cart lines out from under the "clamps to remaining stock" test.
      // See test/support/cart_harness.dart's cartContainer() for the same fix.
      myShopProvider.overrideWith(
        (ref) async =>
            const Shop(id: 's1', ownerId: 'o1', name: 'Shop', currency: 'BDT'),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Spins up a fully-wired container around [repo], keeping
/// `productsStreamProvider` and `myShopProvider` settled exactly like
/// [setUp] does for the main suite. Used by tests that need a repository
/// other than [_ScriptedRepo].
Future<ProviderContainer> _readyContainer(
  VisionScanRepository repo,
  FakeScanCamera cam,
) async {
  final c = _container(repo, cam);
  final sub = c.listen(productsStreamProvider, (_, _) {});
  addTearDown(sub.close);
  await c.read(productsStreamProvider.future);
  await c.read(myShopProvider.future);
  return c;
}

void main() {
  late _ScriptedRepo repo;
  late FakeScanCamera cam;
  late ProviderContainer c;

  setUp(() async {
    repo = _ScriptedRepo();
    cam = FakeScanCamera();
    await cam.initialize();
    c = _container(repo, cam);
    // productsStreamProvider is autoDispose; a bare `.future` read with no
    // listener lets it dispose the instant it resolves (see the same fix in
    // voice_controller_test.dart). Keep a subscription alive for the session.
    final sub = c.listen(productsStreamProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(productsStreamProvider.future);
    await c.read(myShopProvider.future);
  });

  ScanSessionController ctl() => c.read(scanSessionProvider.notifier);
  List<ScanItem> items() => c.read(scanSessionProvider);

  test(
    'a capture appends a pending chip without waiting for the answer',
    () async {
      await ctl().capture();
      expect(items().single.status, ScanItemStatus.recognizing);
      expect(
        repo.calls,
        1,
        reason: 'recognition started, but capture returned',
      );
    },
  );

  test('three captures of the same product become ONE chip at x3', () async {
    await ctl().capture();
    await ctl().capture();
    await ctl().capture();
    for (final p in repo.pending) {
      p.complete(_match(0)); // index 0 == Pepsi
    }
    await Future<void>.delayed(Duration.zero);

    expect(items().length, 1, reason: 'merged on resolve, not three chips');
    expect(items().single.product?.id, 'p-pepsi');
    expect(items().single.quantity, 3);
  });

  test('answers landing out of order still merge correctly', () async {
    await ctl().capture();
    await ctl().capture();
    repo.pending[1].complete(_match(0));
    await Future<void>.delayed(Duration.zero);
    repo.pending[0].complete(_match(0));
    await Future<void>.delayed(Duration.zero);

    expect(items().length, 1);
    expect(items().single.quantity, 2);
  });

  test('never more than 3 recognitions in flight', () async {
    for (var i = 0; i < 10; i++) {
      await ctl().capture();
    }
    expect(repo.calls, 3, reason: 'the other 7 are queued');
    expect(items().length, 10, reason: 'every chip is visible immediately');

    repo.pending[0].complete(_match(0));
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, 4, reason: 'finishing one dispatches the next');
  });

  test(
    'quantity clamps to remaining stock, honouring what is already in the cart',
    () async {
      c.read(cartControllerProvider.notifier).addOrIncrement(_pepsi, 9);
      await ctl().capture();
      repo.pending[0].complete(_match(0));
      await Future<void>.delayed(Duration.zero);

      ctl().setQuantity(items().single.id, 5);
      expect(items().single.quantity, 1, reason: '10 stock - 9 staged = 1');
    },
  );

  test('a whole-unit product cannot be set to a fraction', () async {
    await ctl().capture();
    repo.pending[0].complete(_match(0));
    await Future<void>.delayed(Duration.zero);
    ctl().setQuantity(items().single.id, 2.7);
    expect(items().single.quantity, 2, reason: 'pcs floors');
  });

  test(
    'a failure marks only its own chip and keeps the frame for retry',
    () async {
      await ctl().capture();
      await ctl().capture();
      repo.pending[0].complete(const Result.failure(NetworkFailure('offline')));
      repo.pending[1].complete(_match(0));
      await Future<void>.delayed(Duration.zero);

      final failed = items().firstWhere(
        (i) => i.status == ScanItemStatus.failed,
      );
      expect(failed.frame, isNotNull, reason: 'retry must not need a re-shoot');
      expect(
        items().any((i) => i.status == ScanItemStatus.resolved),
        isTrue,
        reason: 'one bad chip must never kill the session',
      );

      await ctl().retry(failed.id);
      expect(repo.calls, 3, reason: 'resent the held frame');
    },
  );

  test('a resolved chip drops its frame', () async {
    await ctl().capture();
    repo.pending[0].complete(_match(0));
    await Future<void>.delayed(Duration.zero);
    expect(items().single.frame, isNull);
  });

  test('an invented index resolves to nothing, not a wrong product', () async {
    await ctl().capture();
    repo.pending[0].complete(_match(99));
    await Future<void>.delayed(Duration.zero);
    expect(items().single.status, ScanItemStatus.unmatched);
    expect(items().single.product, isNull);
  });

  test('choosing resolves an ambiguous chip and merges it', () async {
    await ctl().capture();
    repo.pending[0].complete(
      Result.success(
        const RecognitionResult(
          status: RecognitionStatus.multiple,
          matches: [
            ProductMatch(productId: '0', confidence: 0.6),
            ProductMatch(productId: '1', confidence: 0.55),
          ],
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(items().single.status, ScanItemStatus.ambiguous);
    expect(items().single.choices.length, 2);

    ctl().choose(items().single.id, _rice);
    expect(items().single.status, ScanItemStatus.resolved);
    expect(items().single.product?.id, 'p-rice');
    expect(items().single.quantity, 0.5, reason: 'kg steps by 0.5');
  });

  test('addAllToCart stages resolved chips and empties the tray', () async {
    await ctl().capture();
    await ctl().capture();
    repo.pending[0].complete(_match(0));
    repo.pending[1].complete(_match(1));
    await Future<void>.delayed(Duration.zero);

    ctl().addAllToCart();
    final cart = c.read(cartControllerProvider);
    expect(cart.length, 2);
    expect(cart.firstWhere((l) => l.product.id == 'p-pepsi').quantity, 1);
    expect(items(), isEmpty);
  });

  test('addAllToCart ignores chips that never resolved', () async {
    await ctl().capture();
    repo.pending[0].complete(_match(99)); // unmatched
    await Future<void>.delayed(Duration.zero);
    ctl().addAllToCart();
    expect(c.read(cartControllerProvider), isEmpty);
  });

  test('pendingCount tracks what is still in flight', () async {
    await ctl().capture();
    await ctl().capture();
    expect(ctl().pendingCount, 2);
    repo.pending[0].complete(_match(0));
    await Future<void>.delayed(Duration.zero);
    expect(ctl().pendingCount, 1);
  });

  test('a repository that THROWS (not Result.failure) still frees its slot and '
      'the session keeps working', () async {
    final throwing = _ThrowingRepo();
    final throwCam = FakeScanCamera();
    await throwCam.initialize();
    final tc = await _readyContainer(throwing, throwCam);
    final tCtl = tc.read(scanSessionProvider.notifier);

    await tCtl.capture();
    await tCtl.capture();
    await tCtl.capture();
    await Future<void>.delayed(Duration.zero);

    final tItems = tc.read(scanSessionProvider);
    expect(
      tItems.every((i) => i.status == ScanItemStatus.failed),
      isTrue,
      reason:
          'a throw must be treated exactly like a Result.failure, not '
          'strand the chip at recognizing forever',
    );
    expect(
      tItems.every((i) => i.frame != null),
      isTrue,
      reason: 'the frame must survive so retry needs no re-shoot',
    );

    // The real assertion: the in-flight slot from each throw must have
    // been freed, not leaked. A 4th capture has to dispatch immediately.
    await tCtl.capture();
    expect(
      throwing.calls,
      4,
      reason: 'a later capture still dispatches -- no slot was leaked',
    );
  });

  test(
    'choose with a stale id does not inflate an unrelated resolved chip',
    () async {
      await ctl().capture();
      repo.pending[0].complete(
        Result.success(
          const RecognitionResult(
            status: RecognitionStatus.multiple,
            matches: [
              ProductMatch(productId: '0', confidence: 0.6),
              ProductMatch(productId: '1', confidence: 0.55),
            ],
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      ctl().choose(items().single.id, _rice);
      expect(items().single.quantity, 0.5);

      // The chip this id once named is long gone; `_resolve`'s twin search
      // excludes `it.id != id`, so before the fix a nonexistent id could
      // never match itself and always fell into the merge branch.
      ctl().choose('chip-does-not-exist', _rice);

      expect(items().length, 1, reason: 'no phantom chip created');
      expect(
        items().single.quantity,
        0.5,
        reason: 'a stale id must not silently inflate an unrelated chip',
      );
    },
  );

  test('a capture whose camera call throws neither crashes nor leaves a chip '
      'behind, and the next capture still works', () async {
    cam.failNextCapture = true;
    await expectLater(ctl().capture(), throwsA(anything));
    expect(
      items(),
      isEmpty,
      reason: 'nothing was added before the throw -- no phantom chip',
    );

    // The fault was transient (FakeScanCamera.failNextCapture resets
    // itself); a following capture must behave completely normally.
    await ctl().capture();
    expect(items().single.status, ScanItemStatus.recognizing);
  });

  test('a sub-threshold single match asks instead of silently auto-resolving '
      '(the auto-resolve confidence lever from spec §8 must not move on its '
      'own)', () async {
    await ctl().capture();
    repo.pending[0].complete(
      Result.success(
        const RecognitionResult(
          status: RecognitionStatus.match,
          matches: [ProductMatch(productId: '0', confidence: 0.6)],
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(items().single.status, ScanItemStatus.ambiguous);
    expect(items().single.choices.length, 1);
    expect(items().single.isAddable, isFalse);
  });

  test(
    'a second retry while the first is still in flight does not double-dispatch, '
    'and the queue is not left stalled',
    () async {
      await ctl().capture();
      repo.pending[0].complete(const Result.failure(NetworkFailure('offline')));
      await Future<void>.delayed(Duration.zero);
      final failedId = items().single.id;
      expect(items().single.status, ScanItemStatus.failed);

      await ctl().retry(failedId);
      expect(repo.calls, 2, reason: 'first retry dispatches');
      expect(items().single.status, ScanItemStatus.recognizing);

      await ctl().retry(failedId);
      expect(
        repo.calls,
        2,
        reason:
            'the chip is mid-retry (not failed), so a second tap must not '
            'queue a duplicate, paid recognition call',
      );

      // Also proves _pump() was not skipped anywhere on the way here: the
      // in-flight slot accounting is still sane, so a fresh capture goes
      // straight out rather than sitting stuck behind a stalled queue.
      await ctl().capture();
      expect(
        repo.calls,
        3,
        reason: 'the queue keeps moving; nothing was left stalled',
      );
    },
  );
}
