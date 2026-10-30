import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/category.dart';

/// CRUD + live access for `categories` in the phone's database.
class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  static const _table = 'categories';

  /// Live, name-ordered list of a shop's categories.
  Stream<List<Category>> watchCategories(String shopId) =>
      _db.watch({_table}, () => _list(shopId));

  Future<List<Category>> _list(String shopId) async {
    final rows = await _db.db.query(
      _table,
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'name COLLATE NOCASE',
    );
    return [for (final r in rows) Category.fromJson(decodeRow(r))];
  }

  /// One-shot fetch (name-ordered).
  Future<Result<List<Category>>> fetchCategories(String shopId) async {
    try {
      return Result.success(await _list(shopId));
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Normalized find-or-create (0003 `upsert_category`): an existing
  /// case/space-insensitive match is returned with its display name kept.
  Future<Result<Category>> upsertCategory({
    required String shopId,
    required String name,
  }) async {
    final display = normalizeCategoryDisplay(name);
    final norm = display.toLowerCase();
    if (norm.isEmpty) {
      return const Result.failure(
        DatabaseFailure('Category name cannot be empty'),
      );
    }
    try {
      await _db.db.insert(_table, {
        'id': newId(),
        'shop_id': shopId,
        'name': display,
        'name_normalized': norm,
        'created_at': nowMicros(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      _db.notify({_table});
      final rows = await _db.db.query(
        _table,
        where: 'shop_id = ? AND name_normalized = ?',
        whereArgs: [shopId, norm],
        limit: 1,
      );
      return Result.success(Category.fromJson(decodeRow(rows.first)));
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Renames a category (0004 `rename_category`); refuses a name another
  /// category of the shop already has.
  Future<Result<Category>> renameCategory({
    required String id,
    required String name,
  }) async {
    final display = normalizeCategoryDisplay(name);
    final norm = display.toLowerCase();
    if (norm.isEmpty) {
      return const Result.failure(
        DatabaseFailure('Category name cannot be empty'),
      );
    }
    try {
      final count = await _db.db.update(
        _table,
        {'name': display, 'name_normalized': norm},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        return const Result.failure(DatabaseFailure('Category not found'));
      }
      _db.notify({_table});
      final rows = await _db.db.query(_table, where: 'id = ?', whereArgs: [id]);
      return Result.success(Category.fromJson(decodeRow(rows.first)));
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        return Result.failure(
          DatabaseFailure('A category named "$display" already exists'),
        );
      }
      return Result.failure(_map(e));
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  /// Deletes a category; its products become uncategorized (ON DELETE SET
  /// NULL), never deleted.
  Future<Result<void>> deleteCategory(String id) async {
    try {
      await _db.db.delete(_table, where: 'id = ?', whereArgs: [id]);
      _db.notify({_table, 'products'});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(_map(e));
    }
  }

  Failure _map(Object e) =>
      const DatabaseFailure('Could not complete the request. Please try again.');
}

/// Trim and collapse internal whitespace (the SQL `regexp_replace('\s+', ' ')`).
String normalizeCategoryDisplay(String name) =>
    name.replaceAll(RegExp(r'\s+'), ' ').trim();

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(appDatabaseProvider));
});
