import 'package:sqflite/sqflite.dart';

import '../database_schema.dart';
import '../database_service.dart';

/// Data Access Object for the testimonies table.
class TestimonyDao {
  TestimonyDao(this._db);
  final DatabaseService _db;

  static const _t = DatabaseSchema.tTestimonies;

  // ── Write ──────────────────────────────────────────────────────────────────

  Future<void> upsert(Map<String, dynamic> row) async {
    await _db.insert(_t, row);
  }

  Future<void> upsertAll(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await _db.db;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(_t, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateUserInteraction({
    required String testimonyId,
    bool? liked,
    bool? prayed,
    bool? saved,
  }) async {
    final updates = <String, Object?>{};
    if (liked != null) updates['user_liked'] = liked ? 1 : 0;
    if (prayed != null) updates['user_prayed'] = prayed ? 1 : 0;
    if (saved != null) updates['user_saved'] = saved ? 1 : 0;
    if (updates.isEmpty) return;
    await _db.update(_t, updates, where: 'id = ?', whereArgs: [testimonyId]);
  }

  Future<void> softDelete(String id) async {
    await _db.update(
      _t,
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFeed({
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    final where = StringBuffer('deleted_at IS NULL AND status = ?');
    final args = <Object?>['published'];

    if (category != null) {
      where.write(' AND category = ?');
      args.add(category);
    }

    return _db.query(
      _t,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> getFeatured() async {
    return _db.query(
      _t,
      where: 'is_featured = 1 AND deleted_at IS NULL AND status = ?',
      whereArgs: ['published'],
      orderBy: 'created_at DESC',
      limit: 5,
    );
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    final rows = await _db.query(_t, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getByUser(String userId) async {
    return _db.query(
      _t,
      where: 'user_id = ? AND deleted_at IS NULL',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getSaved(String userId) async {
    final db = await _db.db;
    return db.rawQuery('''
      SELECT t.* FROM $_t t
      INNER JOIN ${DatabaseSchema.tSavedTestimonies} s
        ON t.id = s.testimony_id
      WHERE s.user_id = ? AND t.deleted_at IS NULL
      ORDER BY s.saved_at DESC
    ''', [userId]);
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    return _db.query(
      _t,
      where:
          '(title LIKE ? OR body_text LIKE ?) AND deleted_at IS NULL AND status = ?',
      whereArgs: ['%$query%', '%$query%', 'published'],
      orderBy: 'created_at DESC',
      limit: 30,
    );
  }
}
