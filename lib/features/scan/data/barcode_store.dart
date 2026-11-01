import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';

/// The barcodes printed on the shop's products, learned from scans the
/// shopkeeper confirmed. A known barcode names its product exactly, whatever
/// script or lettering the pack is printed in, so it outranks the photo and
/// the label text.
class BarcodeStore {
  BarcodeStore(this._db);

  final AppDatabase _db;

  /// The active product the first known code in [codes] belongs to.
  Future<String?> productFor(List<String> codes) async {
    if (codes.isEmpty) return null;
    final rows = await _db.db.rawQuery(
      'SELECT b.barcode, b.product_id FROM product_barcodes b '
      'JOIN products p ON p.id = b.product_id '
      'WHERE p.is_archived = 0 AND b.barcode IN '
      '(${List.filled(codes.length, '?').join(', ')})',
      codes,
    );
    final byCode = {
      for (final r in rows) r['barcode']! as String: r['product_id']! as String,
    };
    for (final c in codes) {
      if (byCode[c] case final String id) return id;
    }
    return null;
  }

  /// Links [code] to [productId]. A code already linked to another product
  /// moves: the shopkeeper's latest correction wins.
  Future<void> learn(String productId, String code) async {
    await _db.db.rawInsert(
      'INSERT OR REPLACE INTO product_barcodes (barcode, product_id, created_at) '
      'VALUES (?, ?, ?)',
      [code, productId, nowMicros()],
    );
    _db.notify({'product_barcodes'});
  }
}

final barcodeStoreProvider = Provider<BarcodeStore>(
  (ref) => BarcodeStore(ref.watch(appDatabaseProvider)),
);
