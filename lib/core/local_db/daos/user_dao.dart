import '../database_schema.dart';
import '../database_service.dart';

class UserDao {
  UserDao(this._db);
  final DatabaseService _db;

  static const _t = DatabaseSchema.tUsers;

  Future<void> upsert(Map<String, dynamic> row) async {
    await _db.insert(_t, row);
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    final rows = await _db.query(_t, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateProfile(String id, Map<String, dynamic> fields) async {
    await _db.update(_t, fields, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    await _db.delete(_t, where: 'id = ?', whereArgs: [id]);
  }
}
