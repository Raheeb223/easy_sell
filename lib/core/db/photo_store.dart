import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Product photos and scan thumbnails, kept in the app's private folder.
///
/// The database stores RELATIVE paths (`photos/<name>.jpg`) so a backup
/// restored on another phone still finds its pictures.
class PhotoStore {
  PhotoStore(this.root);

  /// The app documents directory.
  final Directory root;

  static const folder = 'photos';

  static Future<PhotoStore> open() async =>
      PhotoStore(await getApplicationDocumentsDirectory());

  Directory get dir => Directory(p.join(root.path, folder));

  /// Saves [bytes] as a new photo and returns its relative path.
  Future<String> save(List<int> bytes, String name) async {
    await dir.create(recursive: true);
    final rel = p.posix.join(folder, name);
    await File(resolve(rel)).writeAsBytes(bytes, flush: true);
    return rel;
  }

  /// The absolute path of a stored relative path (absolute paths and URLs
  /// from older rows are returned unchanged).
  String resolve(String stored) {
    if (stored.startsWith('http') || p.isAbsolute(stored)) return stored;
    return p.join(root.path, p.joinAll(p.posix.split(stored)));
  }

  Future<void> delete(String stored) async {
    final f = File(resolve(stored));
    if (await f.exists()) await f.delete();
  }
}

/// Opened once in `main()` and injected with `overrideWithValue`.
final photoStoreProvider = Provider<PhotoStore>(
  (ref) => throw StateError('photoStoreProvider must be overridden in main()'),
);
