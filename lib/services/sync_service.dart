// lib/services/sync_service.dart
//
// Delta sync engine — WhatsApp-style offline-first strategy.
//
// Strategy:
//   1. On app foreground → deltaSync() fetches only records newer than last cursor.
//   2. All reads go through SQLite (instant, 0ms perceived latency).
//   3. Writes are optimistic: local SQLite first, then queued for remote sync.
//   4. On reconnect → flushPendingOps() replays the offline write queue.

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/app_constants.dart';
import '../core/local_db/daos/notification_dao.dart';
import '../core/local_db/daos/pending_ops_dao.dart';
import '../core/local_db/daos/sync_dao.dart';
import '../core/local_db/daos/testimony_dao.dart';
import '../core/local_db/database_service.dart';
import 'api_service.dart';

class SyncService {
  SyncService({
    required this.api,
    required this.db,
  })  : _testimonyDao = TestimonyDao(db),
        _notifDao     = NotificationDao(db),
        _syncDao      = SyncDao(db),
        _pendingDao   = PendingOpsDao(db);

  final ApiService api;
  final DatabaseService db;

  final TestimonyDao    _testimonyDao;
  final NotificationDao _notifDao;
  final SyncDao         _syncDao;
  final PendingOpsDao   _pendingDao;

  // ── Online check ─────────────────────────────────────────────────────────────

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((c) => c != ConnectivityResult.none);
  }

  // ── Full sync on app foreground ───────────────────────────────────────────────

  /// Called each time the app returns to foreground.
  /// Runs all delta syncs in order; silently ignores network errors.
  Future<void> deltaSync({String? userId}) async {
    if (!await _isOnline()) return;

    await Future.wait([
      _syncFeed(),
      if (userId != null) _syncNotifications(userId),
      _syncCategories(),
    ]);

    await flushPendingOps();
  }

  // ── Feed delta sync ───────────────────────────────────────────────────────────

  Future<void> _syncFeed() async {
    try {
      final since = await _syncDao.getLastSyncAt(SyncEntity.feed)
          ?? DateTime.now()
              .subtract(const Duration(days: 30))
              .toIso8601String();

      final response = await api.get<Map<String, dynamic>>(
        AppConstants.feedDelta(after: since, limit: 50),
      );

      final data = response.data as Map<String, dynamic>? ?? {};
      final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final nextCursor = data['next_cursor'] as String?;

      if (items.isNotEmpty) {
        await _testimonyDao.upsertAll(
          items.map(_flattenTestimony).toList(),
        );
      }

      await _syncDao.updateCursor(
        entity: SyncEntity.feed,
        lastSyncAt: DateTime.now().toIso8601String(),
        nextCursor: nextCursor,
      );
    } catch (_) {}
  }

  // ── Notifications delta sync ──────────────────────────────────────────────────

  Future<void> _syncNotifications(String userId) async {
    try {
      final since = await _syncDao.getLastSyncAt(SyncEntity.notifications)
          ?? DateTime.now()
              .subtract(const Duration(days: 7))
              .toIso8601String();

      final response = await api.get<Map<String, dynamic>>(
        AppConstants.notificationsDelta(after: since),
      );

      final data  = response.data as Map<String, dynamic>? ?? {};
      final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (items.isNotEmpty) {
        await _notifDao.upsertAll(
          items.map((n) => _flattenNotification(n, userId)).toList(),
        );
      }

      await _syncDao.updateCursor(
        entity: SyncEntity.notifications,
        lastSyncAt: DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }

  // ── Categories sync ───────────────────────────────────────────────────────────

  Future<void> _syncCategories() async {
    try {
      final since = await _syncDao.getLastSyncAt(SyncEntity.categories);
      // Categories change rarely — skip if synced within last hour.
      if (since != null) {
        final lastSync = DateTime.tryParse(since);
        if (lastSync != null &&
            DateTime.now().difference(lastSync).inMinutes < 60) {
          return;
        }
      }

      final response =
          await api.get<Map<String, dynamic>>(AppConstants.categories);
      final items =
          (response.data as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (items.isNotEmpty) {
        final catDb = db;
        final batch = (await catDb.db).batch();
        for (final cat in items) {
          batch.insert(
            'categories',
            {
              'id': cat['id'] as String,
              'name': cat['name'] as String,
              'slug': cat['slug'] as String,
              'icon': cat['icon'] as String?,
              'display_order': cat['display_order'] as int? ?? 0,
              'testimony_count': cat['testimony_count'] as int? ?? 0,
              'is_active': (cat['is_active'] as bool? ?? true) ? 1 : 0,
              'updated_at': cat['updated_at'] as String? ??
                  DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }

      await _syncDao.updateCursor(
        entity: SyncEntity.categories,
        lastSyncAt: DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }

  // ── Offline write queue flush ─────────────────────────────────────────────────

  /// Replays all pending offline operations against the remote API.
  Future<void> flushPendingOps() async {
    if (!await _isOnline()) return;

    final ops = await _pendingDao.getPending();
    for (final op in ops) {
      final id      = op['id'] as String;
      final method  = op['method'] as String;
      final endpoint = op['endpoint'] as String;
      final bodyRaw = op['body'] as String?;
      final retries = op['retry_count'] as int? ?? 0;

      final body = bodyRaw != null
          ? PendingOpsDao.decodeBody(bodyRaw)
          : null;

      try {
        switch (method) {
          case 'POST':   await api.post<void>(endpoint, data: body);
          case 'PUT':    await api.put<void>(endpoint, data: body);
          case 'DELETE': await api.delete<void>(endpoint, data: body);
        }
        await _pendingDao.markSuccess(id);
      } catch (_) {
        await _pendingDao.markRetry(id, retries);
      }
    }
  }

  // ── Optimistic local writes ───────────────────────────────────────────────────

  /// Like / unlike a testimony optimistically — updates SQLite immediately,
  /// queues the remote call for background sync.
  Future<void> toggleLike({
    required String testimonyId,
    required bool newLikedState,
  }) async {
    await _testimonyDao.updateUserInteraction(
      testimonyId: testimonyId,
      liked: newLikedState,
    );

    if (await _isOnline()) {
      try {
        await api.post<void>(
          AppConstants.testimonyReactions(testimonyId),
          data: {'type': 'like'},
        );
        return;
      } catch (_) {}
    }

    await _pendingDao.enqueue(
      type: PendingOpType.react,
      method: 'POST',
      endpoint: AppConstants.testimonyReactions(testimonyId),
      body: {'type': 'like'},
    );
  }

  /// Pray / unpray optimistically.
  Future<void> togglePray({
    required String testimonyId,
    required bool newPrayedState,
  }) async {
    await _testimonyDao.updateUserInteraction(
      testimonyId: testimonyId,
      prayed: newPrayedState,
    );

    if (await _isOnline()) {
      try {
        await api.post<void>(
          AppConstants.testimonyReactions(testimonyId),
          data: {'type': 'pray'},
        );
        return;
      } catch (_) {}
    }

    await _pendingDao.enqueue(
      type: PendingOpType.react,
      method: 'POST',
      endpoint: AppConstants.testimonyReactions(testimonyId),
      body: {'type': 'pray'},
    );
  }

  /// Save / unsave a testimony.
  Future<void> toggleSave({
    required String testimonyId,
    required String userId,
    required bool newSavedState,
  }) async {
    await _testimonyDao.updateUserInteraction(
        testimonyId: testimonyId, saved: newSavedState);

    final endpoint = newSavedState
        ? AppConstants.testimonySave(testimonyId)
        : AppConstants.testimonyUnsave(testimonyId);

    if (await _isOnline()) {
      try {
        await api.post<void>(endpoint);
        return;
      } catch (_) {}
    }

    await _pendingDao.enqueue(
      type: newSavedState ? PendingOpType.save : PendingOpType.unsave,
      method: 'POST',
      endpoint: endpoint,
    );
  }

  // ── Row mappers ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _flattenTestimony(Map<String, dynamic> t) {
    final author = t['author'] as Map<String, dynamic>? ?? {};
    final stats  = t['stats']  as Map<String, dynamic>? ?? {};
    return {
      'id':              t['id'] as String,
      'user_id':         t['user_id'] as String? ?? author['id'] as String? ?? '',
      'author_name':     author['display_name'] as String? ?? '',
      'author_avatar':   author['avatar_url'] as String?,
      'author_country':  author['country'] as String?,
      'title':           t['title'] as String? ?? '',
      'type':            t['type'] as String? ?? 'text',
      'category':        t['category'] as String? ?? '',
      'body_text':       t['body_text'] as String?,
      'media_url':       t['media_url'] as String?,
      'cover_url':       t['cover_url'] as String?,
      'duration_sec':    t['duration_sec'] as int?,
      'bible_verse':     t['bible_verse'] as String?,
      'bible_ref':       t['bible_ref'] as String?,
      'visibility':      t['visibility'] as String? ?? 'public',
      'status':          t['status'] as String? ?? 'published',
      'views':           stats['views'] as int? ?? 0,
      'like_count':      stats['likes'] as int? ?? 0,
      'prayer_count':    stats['prayers'] as int? ?? 0,
      'comment_count':   stats['comments'] as int? ?? 0,
      'is_featured':     (t['is_featured'] as bool? ?? false) ? 1 : 0,
      'user_liked':      (t['user_liked'] as bool? ?? false) ? 1 : 0,
      'user_prayed':     (t['user_prayed'] as bool? ?? false) ? 1 : 0,
      'user_saved':      (t['user_saved'] as bool? ?? false) ? 1 : 0,
      'created_at':      t['created_at'] as String? ?? DateTime.now().toIso8601String(),
      'updated_at':      t['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      'deleted_at':      t['deleted_at'] as String?,
      'synced_at':       DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> _flattenNotification(
      Map<String, dynamic> n, String recipientId) {
    final actor = n['actor'] as Map<String, dynamic>? ?? {};
    return {
      'id':               n['id'] as String,
      'recipient_id':     recipientId,
      'actor_id':         actor['id'] as String?,
      'actor_name':       actor['display_name'] as String?,
      'actor_avatar':     actor['avatar_url'] as String?,
      'type':             n['type'] as String? ?? '',
      'testimony_id':     n['testimony_id'] as String?,
      'testimony_title':  n['testimony_title'] as String?,
      'comment_id':       n['comment_id'] as String?,
      'is_read':          (n['is_read'] as bool? ?? false) ? 1 : 0,
      'payload':          n['payload'] != null ? jsonEncode(n['payload']) : null,
      'created_at':       n['created_at'] as String? ?? DateTime.now().toIso8601String(),
      'synced_at':        DateTime.now().toIso8601String(),
    };
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    api: ref.watch(apiServiceProvider),
    db:  ref.watch(databaseServiceProvider),
  );
});
