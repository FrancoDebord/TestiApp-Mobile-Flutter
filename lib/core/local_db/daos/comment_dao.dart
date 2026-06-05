import 'package:sqflite/sqflite.dart';

import '../database_schema.dart';
import '../database_service.dart';

/// DAO pour la table `comments`.
class CommentDao {
  CommentDao(this._db);
  final DatabaseService _db;

  static const _t = DatabaseSchema.tComments;

  // ── Écriture ───────────────────────────────────────────────────────────────

  Future<void> insert(Map<String, dynamic> row) async {
    await _db.insert(_t, row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> softDelete(String id) async {
    await _db.update(
      _t,
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Lecture ────────────────────────────────────────────────────────────────

  /// Renvoie tous les commentaires non supprimés d'un témoignage,
  /// triés du plus ancien au plus récent.
  Future<List<Map<String, dynamic>>> getByTestimony(
      String testimonyId) async {
    return _db.query(
      _t,
      where: 'testimony_id = ? AND deleted_at IS NULL',
      whereArgs: [testimonyId],
      orderBy: 'created_at ASC',
    );
  }

  /// Compte les commentaires actifs d'un témoignage.
  Future<int> countByTestimony(String testimonyId) async {
    final db = await _db.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_t '
      'WHERE testimony_id = ? AND deleted_at IS NULL',
      [testimonyId],
    );
    return result.first['cnt'] as int? ?? 0;
  }
}
