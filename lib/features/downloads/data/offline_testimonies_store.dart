// Témoignages gardés dans la base SQLite du téléphone (table `offline_testimonies`) :
//
//   • source « mine »     : tous les témoignages de la personne connectée, copiés à
//                           chaque chargement de « Mes témoignages » (JSON de l'API),
//                           relisibles hors connexion ; elle peut les retirer du
//                           téléphone (ils restent publiés en ligne) ;
//   • source « download » : index des témoignages téléchargés (DownloadEntry), les
//                           fichiers restant dans <documents>/downloads/.
//
// Un témoignage retiré par la personne est marqué `excluded` : il n'est plus recopié
// aux chargements suivants.

import 'dart:convert';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../../core/local_db/database_schema.dart';
import '../../../core/local_db/database_service.dart';

/// Témoignage de la personne gardé sur le téléphone.
typedef StoredTestimony = ({String id, Map<String, dynamic> json, DateTime savedAt});

class OfflineTestimoniesStore {
  const OfflineTestimoniesStore();

  static const _t = DatabaseSchema.tOfflineTestimonies;
  static const mineSource = 'mine';
  static const downloadSource = 'download';

  DatabaseService get _db => DatabaseService();

  // ── Mes témoignages ─────────────────────────────────────────────────────────

  /// Remplace la copie par la liste reçue du serveur (les retirés restent retirés,
  /// les témoignages supprimés en ligne disparaissent).
  Future<void> saveMine(String userId, List<Map<String, dynamic>> items) async {
    final now = DateTime.now().toIso8601String();
    final ids = {for (final j in items) '${j['id']}'};
    await _db.transaction((txn) async {
      final rows = await txn.query(_t,
          columns: ['id', 'excluded'], where: 'owner_id = ? AND source = ?', whereArgs: [userId, mineSource]);
      final excluded = {for (final r in rows) if (r['excluded'] == 1) r['id'] as String};
      for (final r in rows) {
        if (!ids.contains(r['id'])) {
          await txn.delete(_t,
              where: 'owner_id = ? AND source = ? AND id = ?', whereArgs: [userId, mineSource, r['id']]);
        }
      }
      for (final j in items) {
        final id = '${j['id']}';
        if (id.isEmpty || excluded.contains(id)) continue;
        await txn.insert(
          _t,
          {'owner_id': userId, 'source': mineSource, 'id': id, 'payload': jsonEncode(j), 'excluded': 0, 'saved_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Témoignages de la personne gardés sur le téléphone, dans l'ordre reçu du serveur.
  Future<List<StoredTestimony>> mine(String userId) async {
    final rows = await _db.query(_t,
        where: 'owner_id = ? AND source = ? AND excluded = 0', whereArgs: [userId, mineSource], orderBy: 'rowid ASC');
    return [
      for (final r in rows)
        if (_decode(r['payload'] as String?) case final j?)
          (
            id: r['id'] as String,
            json: j,
            savedAt: DateTime.tryParse(r['saved_at'] as String? ?? '') ?? DateTime.now(),
          ),
    ];
  }

  Future<StoredTestimony?> mineById(String userId, String id) async {
    final rows = await _db.query(_t,
        where: 'owner_id = ? AND source = ? AND id = ? AND excluded = 0',
        whereArgs: [userId, mineSource, id],
        limit: 1);
    if (rows.isEmpty) return null;
    final j = _decode(rows.first['payload'] as String?);
    if (j == null) return null;
    return (id: id, json: j, savedAt: DateTime.tryParse(rows.first['saved_at'] as String? ?? '') ?? DateTime.now());
  }

  /// Retire un témoignage du téléphone (il n'est plus recopié ensuite).
  Future<void> removeMine(String userId, String id) => _db.update(
        _t,
        {'payload': '', 'excluded': 1},
        where: 'owner_id = ? AND source = ? AND id = ?',
        whereArgs: [userId, mineSource, id],
      );

  /// Retire tous les témoignages de la personne du téléphone.
  Future<void> removeAllMine(String userId) => _db.update(
        _t,
        {'payload': '', 'excluded': 1},
        where: 'owner_id = ? AND source = ?',
        whereArgs: [userId, mineSource],
      );

  /// Efface tout ce qui concerne la personne (suppression du compte).
  Future<void> forgetUser(String userId) =>
      _db.delete(_t, where: 'owner_id = ? AND source = ?', whereArgs: [userId, mineSource]);

  // ── Index des téléchargements ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> downloads() async {
    final rows = await _db.query(_t,
        where: 'source = ?', whereArgs: [downloadSource], orderBy: 'saved_at DESC');
    return [
      for (final r in rows)
        ?_decode(r['payload'] as String?),
    ];
  }

  Future<bool> hasDownloadRows() async =>
      (await _db.query(_t, where: 'source = ?', whereArgs: [downloadSource], limit: 1)).isNotEmpty;

  /// Remplace l'index des téléchargements.
  Future<void> saveDownloads(List<Map<String, dynamic>> entries) async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      await txn.delete(_t, where: 'source = ?', whereArgs: [downloadSource]);
      for (final j in entries) {
        await txn.insert(
          _t,
          {
            'owner_id': '',
            'source': downloadSource,
            'id': '${j['id']}',
            'payload': jsonEncode(j),
            'excluded': 0,
            'saved_at': j['downloaded_at'] as String? ?? now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Map<String, dynamic>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (_) {
      return null;
    }
  }
}
