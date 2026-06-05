import 'dart:convert';
import 'dart:math';

import '../database_schema.dart';
import '../database_service.dart';

/// Offline write queue — stores API calls that failed due to no connectivity.
class PendingOpsDao {
  PendingOpsDao(this._db);
  final DatabaseService _db;

  static const _t = DatabaseSchema.tPendingOperations;
  static const _maxRetries = 3;

  // ── Enqueue ────────────────────────────────────────────────────────────────

  Future<void> enqueue({
    required String type,
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
  }) async {
    await _db.insert(_t, {
      'id': _generateId(),
      'type': type,
      'method': method,
      'endpoint': endpoint,
      'body': body != null ? jsonEncode(body) : null,
      'retry_count': 0,
      'status': PendingOpStatus.pending,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPending() async {
    return _db.query(
      _t,
      where: 'status = ?',
      whereArgs: [PendingOpStatus.pending],
      orderBy: 'created_at ASC',
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> markSuccess(String id) async {
    await _db.delete(_t, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markRetry(String id, int currentRetryCount) async {
    final newCount = currentRetryCount + 1;
    final newStatus = newCount >= _maxRetries
        ? PendingOpStatus.failed
        : PendingOpStatus.pending;

    await _db.update(
      _t,
      {
        'retry_count': newCount,
        'status': newStatus,
        'last_tried_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearFailed() async {
    await _db.delete(_t,
        where: 'status = ?', whereArgs: [PendingOpStatus.failed]);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${bytes.sublist(0, 4).map(hex).join()}'
        '-${bytes.sublist(4, 6).map(hex).join()}'
        '-${bytes.sublist(6, 8).map(hex).join()}'
        '-${bytes.sublist(8, 10).map(hex).join()}'
        '-${bytes.sublist(10, 16).map(hex).join()}';
  }

  static Map<String, dynamic> decodeBody(String raw) =>
      jsonDecode(raw) as Map<String, dynamic>;
}

abstract final class PendingOpStatus {
  static const pending = 'pending';
  static const failed  = 'failed';
}

abstract final class PendingOpType {
  static const react          = 'react';
  static const comment        = 'comment';
  static const save           = 'save';
  static const unsave         = 'unsave';
  static const follow         = 'follow';
  static const unfollow       = 'unfollow';
  static const publishDraft   = 'publish_draft';
  static const markNotifRead  = 'mark_notif_read';
}
