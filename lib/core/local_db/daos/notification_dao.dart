import 'package:sqflite/sqflite.dart';

import '../database_schema.dart';
import '../database_service.dart';

class NotificationDao {
  NotificationDao(this._db);
  final DatabaseService _db;

  static const _t = DatabaseSchema.tNotifications;

  Future<void> upsertAll(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await _db.db;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(_t, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getForUser(String userId,
      {int limit = 30}) async {
    return _db.query(
      _t,
      where: 'recipient_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<int> unreadCount(String userId) async {
    final db = await _db.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_t WHERE recipient_id = ? AND is_read = 0',
      [userId],
    );
    return result.first['cnt'] as int;
  }

  Future<void> markRead(String id) async {
    await _db.update(_t, {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAllRead(String userId) async {
    await _db.update(
      _t,
      {'is_read': 1},
      where: 'recipient_id = ?',
      whereArgs: [userId],
    );
  }
}
