import '../database_schema.dart';
import '../database_service.dart';

/// Manages sync cursors (last sync timestamps per entity).
class SyncDao {
  SyncDao(this._db);
  final DatabaseService _db;

  static const _t = DatabaseSchema.tSyncCursors;

  Future<String?> getLastSyncAt(String entity) async {
    final rows =
        await _db.query(_t, where: 'entity = ?', whereArgs: [entity]);
    if (rows.isEmpty) return null;
    return rows.first['last_sync_at'] as String?;
  }

  Future<String?> getNextCursor(String entity) async {
    final rows =
        await _db.query(_t, where: 'entity = ?', whereArgs: [entity]);
    if (rows.isEmpty) return null;
    return rows.first['next_cursor'] as String?;
  }

  Future<void> updateCursor({
    required String entity,
    required String lastSyncAt,
    String? nextCursor,
  }) async {
    await _db.insert(_t, {
      'entity': entity,
      'last_sync_at': lastSyncAt,
      'next_cursor': nextCursor,
    });
  }

  Future<void> resetAll() async {
    await _db.delete(_t);
  }
}

/// Canonical entity keys used as sync cursor identifiers.
abstract final class SyncEntity {
  static const feed          = 'feed';
  static const notifications = 'notifications';
  static const categories    = 'categories';
  static const profile       = 'profile';
}
