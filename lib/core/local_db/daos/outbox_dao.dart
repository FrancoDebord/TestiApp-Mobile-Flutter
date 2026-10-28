import '../../../features/offline/outbox_models.dart';
import '../database_schema.dart';
import '../database_service.dart';

/// Lecture et écriture de la file hors connexion (tables `outbox` et `outbox_ids`).
class OutboxDao {
  OutboxDao(this._db);
  final DatabaseService _db;

  static const _t = DatabaseSchema.tOutbox;
  static const _ids = DatabaseSchema.tOutboxIds;

  /// Actions de [userId] (et celles reprises de l'ancienne file, sans compte), plus anciennes d'abord.
  Future<List<OutboxItem>> forUser(String userId) async {
    final rows = await _db.query(_t,
        where: "user_id = ? OR user_id = ''", whereArgs: [userId], orderBy: 'created_at ASC');
    return rows.map(OutboxItem.fromRow).toList();
  }

  Future<OutboxItem?> byId(String id) async {
    final rows = await _db.query(_t, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : OutboxItem.fromRow(rows.first);
  }

  /// Ajoute une action ; une action en attente avec la même [OutboxItem.dedupeKey] est remplacée.
  /// Renvoie les actions remplacées (pour supprimer leurs fichiers).
  Future<List<OutboxItem>> insert(OutboxItem item) async {
    final replaced = <OutboxItem>[];
    if (item.dedupeKey != null) {
      final rows = await _db.query(_t,
          where: 'user_id = ? AND dedupe_key = ? AND status = ?',
          whereArgs: [item.userId, item.dedupeKey, OutboxStatus.pending.name]);
      replaced.addAll(rows.map(OutboxItem.fromRow));
      await _db.delete(_t,
          where: 'user_id = ? AND dedupe_key = ? AND status = ?',
          whereArgs: [item.userId, item.dedupeKey, OutboxStatus.pending.name]);
    }
    final now = DateTime.now().toIso8601String();
    await _db.insert(_t, {
      'id': item.id,
      'user_id': item.userId,
      'act_as': item.actAs,
      'kind': item.kind.name,
      'target_id': item.targetId,
      'local_id': item.localId,
      'dedupe_key': item.dedupeKey,
      'payload': item.payload.encode(),
      'label': item.label,
      'status': item.status.name,
      'attempts': item.attempts,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': now,
    });
    return replaced;
  }

  /// Étape franchie : ce qu'il reste à faire.
  Future<void> savePayload(String id, OutboxPayload payload) => _db.update(
        _t,
        {'payload': payload.encode(), 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Nouvelle tentative plus tard (serveur momentanément indisponible).
  Future<void> postpone(String id, int attempts, DateTime nextTryAt) => _db.update(
        _t,
        {
          'attempts': attempts,
          'next_try_at': nextTryAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> markFailed(String id, String error) => _db.update(
        _t,
        {
          'status': OutboxStatus.failed.name,
          'error': error,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  /// « Réessayer » : remet l'action en attente, sans délai.
  Future<void> resetForRetry(String id) => _db.update(
        _t,
        {
          'status': OutboxStatus.pending.name,
          'error': null,
          'attempts': 0,
          'next_try_at': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Rattache les actions reprises de l'ancienne file au compte connecté.
  Future<void> adoptOrphans(String userId) =>
      _db.update(_t, {'user_id': userId}, where: "user_id = ''");

  Future<void> delete(String id) => _db.delete(_t, where: 'id = ?', whereArgs: [id]);

  // ── Identifiants locaux → serveur ─────────────────────────────────────────

  Future<void> mapId(String localId, String remoteId) => _db.insert(_ids, {
        'local_id': localId,
        'remote_id': remoteId,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<Map<String, String>> idMap(Iterable<String> localIds) async {
    final ids = localIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await _db.query(_ids,
        where: 'local_id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
    return {for (final r in rows) r['local_id'] as String: r['remote_id'] as String};
  }

  /// Une action en file crée ce contenu (pas encore envoyé).
  Future<bool> isQueuedCreation(String localId) async {
    final rows = await _db.query(_t, where: 'local_id = ?', whereArgs: [localId], limit: 1);
    return rows.isNotEmpty;
  }
}
