import 'dart:typed_data';

import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/scan/data/vision_embedder.dart';
import 'package:ai_shopkeeper/features/scan/data/vision_scan_repository.dart';
import 'package:ai_shopkeeper/features/scan/domain/recognition_result.dart';

/// A scan recogniser for tests that answers with catalogue INDEXES ('0',
/// '1', ...) -- easier to script than ids -- and maps them to the real
/// product ids the on-device recogniser returns.
abstract class IndexedScanRepo implements VisionScanRepository {
  final learned = <String>[];

  Future<Result<RecognitionResult>> recognizeIndexed({
    required Uint8List imageBytes,
    required List<Product> products,
  });

  @override
  Future<Result<ScanRecognition>> recognize({
    required Uint8List imageBytes,
    required List<Product> products,
  }) async {
    final r = await recognizeIndexed(imageBytes: imageBytes, products: products);
    return r.when(
      success: (rec) => Result.success(
        ScanRecognition(
          RecognitionResult(
            status: rec.status,
            matches: [
              for (final m in rec.matches)
                if (int.tryParse(m.productId) case final int i
                    when i >= 0 && i < products.length)
                  ProductMatch(
                    productId: products[i].id,
                    confidence: m.confidence,
                  ),
            ],
            readBrand: rec.readBrand,
            readName: rec.readName,
            readSize: rec.readSize,
          ),
          null,
        ),
      ),
      failure: (f) => Result.failure(f),
    );
  }

  @override
  Future<void> learn(String productId, Embedding embedding) async =>
      learned.add(productId);
}
