// lib/services/sync_service.dart
//
// Delta sync engine — WhatsApp-style offline-first strategy.
//
// Strategy:
//   1. On app foreground → deltaSync() fetches only records newer than last cursor.
//   2. All reads go through SQLite (instant, 0ms perceived latency).
//   3. Writes made offline go through the outbox (lib/features/offline/outbox_controller.dart),
//      flushed on reconnect, on foreground and every 30 s (main.dart).

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/app_constants.dart';
import '../core/local_db/daos/notification_dao.dart';
import '../core/local_db/daos/sync_dao.dart';
import '../core/local_db/database_service.dart';
import 'api_service.dart';

class SyncService {
  SyncService({
    required this.api,
    required this.db,
  })  : _notifDao     = NotificationDao(db),
        _syncDao      = SyncDao(db);

  final ApiService api;
  final DatabaseService db;

  final NotificationDao _notifDao;
  final SyncDao         _syncDao;

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

    // Le fil n'est pas copié dans SQLite : seuls les témoignages que
    // l'utilisateur télécharge sont gardés sur l'appareil (Téléchargements).
    await Future.wait([
      if (userId != null) _syncNotifications(userId),
      _syncCategories(),
    ]);
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

  // ── Row mappers ───────────────────────────────────────────────────────────────

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
