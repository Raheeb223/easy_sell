import 'dart:typed_data';

import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/auth/data/auth_repository.dart';
import 'package:ai_shopkeeper/features/auth/domain/shop.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/inventory_controller.dart';
import 'package:ai_shopkeeper/features/scan/data/scan_camera.dart';
import 'package:ai_shopkeeper/features/scan/data/vision_scan_repository.dart';
import 'package:ai_shopkeeper/features/scan/domain/recognition_result.dart';
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

/// Answers every `recognize()` call with a confident match on Pepsi (index 0)
/// carrying the given read fields, so the resulting chip resolves and its
/// `readLabel` reflects the join.
class _StubRepo extends IndexedScanRepo {
  _StubRepo({this.brand, this.name, this.size});
  final String? brand;
  final String? name;
  final String? size;

  @override
  Future<Result<RecognitionResult>> recognizeIndexed({
    required Uint8List imageBytes,
    required List<Product> products,
  }) async => Result.success(
    RecognitionResult(
      status: RecognitionStatus.match,
      matches: const [ProductMatch(productId: '0', confidence: 0.95)],
      readBrand: brand,
      readName: name,
      readSize: size,
    ),
  );
}

Future<ProviderContainer> _container(VisionScanRepository repo) async {
  final cam = FakeScanCamera();
  await cam.initialize();
  final c = ProviderContainer(
    overrides: [
      visionScanRepositoryProvider.overrideWithValue(repo),
      scanCameraProvider.overrideWithValue(cam),
      productsStreamProvider.overrideWith(
        (ref) => Stream.value(const [_pepsi]),
      ),
      myShopProvider.overrideWith(
        (ref) async =>
            const Shop(id: 's1', ownerId: 'o1', name: 'Shop', currency: 'BDT'),
      ),
    ],
  );
  addTearDown(c.dispose);
  final sub = c.listen(productsStreamProvider, (_, _) {});
  addTearDown(sub.close);
  await c.read(productsStreamProvider.future);
  await c.read(myShopProvider.future);
  return c;
}

/// `ScanOutcome.readLabel` (joining what the model read off the packaging
/// into one display line, e.g. "Pepsi · 1L") lived on the serial scan
/// controller this branch deletes. The join logic moved into
/// `ScanSessionController._readLabel`, which is private to that file, so this
/// pins the same behaviour through the public `capture()` -> resolved-chip
/// path instead of calling it directly.
void main() {
  test('readLabel joins two non-empty parts with a middot', () async {
    final c = await _container(_StubRepo(brand: 'Pepsi', size: '1L'));
    await c.read(scanSessionProvider.notifier).capture();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(scanSessionProvider).single.readLabel, 'Pepsi · 1L');
  });

  test('readLabel joins all three parts when present', () async {
    final c = await _container(
      _StubRepo(brand: 'Pepsi', name: 'Cola', size: '500ml'),
    );
    await c.read(scanSessionProvider.notifier).capture();
    await Future<void>.delayed(Duration.zero);
    expect(
      c.read(scanSessionProvider).single.readLabel,
      'Pepsi · Cola · 500ml',
    );
  });

  test('readLabel is null when nothing was read', () async {
    final c = await _container(_StubRepo());
    await c.read(scanSessionProvider.notifier).capture();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(scanSessionProvider).single.readLabel, isNull);
  });

  test('readLabel is null when the read fields are blank', () async {
    final c = await _container(_StubRepo(brand: '   ', name: ''));
    await c.read(scanSessionProvider.notifier).capture();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(scanSessionProvider).single.readLabel, isNull);
  });
}
