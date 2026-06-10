import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../models/notification_models.dart';

// ============================================================================
// Helper : JSON API → AppNotification
// ============================================================================

AppNotification? _fromJson(dynamic raw) {
  try {
    final m = raw as Map<String, dynamic>;
    return AppNotification(
      id:                   m['id']             as String,
      type:                 _parseType(m['type'] as String? ?? ''),
      actorName:            m['actorName']      as String? ?? '',
      testimonyTitle:       m['testimonyTitle'] as String? ?? '',
      createdAt:            DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      actorAvatarUrl:       m['actorAvatar']    as String?,
      isRead:               m['isRead']         as bool? ?? false,
    );
  } catch (_) {
    return null;
  }
}

NotificationType _parseType(String v) => switch (v) {
      'like'                  => NotificationType.like,
      'comment'               => NotificationType.comment,
      'reply'                 => NotificationType.comment,
      'mention'               => NotificationType.comment,
      'testimony_approved'    => NotificationType.approved,
      'testimony_rejected'    => NotificationType.pendingCorrection,
      'pending_correction'    => NotificationType.pendingCorrection,
      'new_followed_testimony'=> NotificationType.newFollowedTestimony,
      'prayer'                => NotificationType.prayer,
      _                       => NotificationType.like,
    };

// ============================================================================
// Filter notifier
// ============================================================================

class NotificationFilterNotifier extends Notifier<NotificationFilterTab> {
  @override
  NotificationFilterTab build() => NotificationFilterTab.all;
  void setTab(NotificationFilterTab tab) => state = tab;
}

final notificationFilterProvider =
    NotifierProvider<NotificationFilterNotifier, NotificationFilterTab>(
  NotificationFilterNotifier.new,
);

// ============================================================================
// Notifications list notifier — chargé depuis l'API
// ============================================================================

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() => _fetchFromApi();

  Future<List<AppNotification>> _fetchFromApi() async {
    final api      = ref.read(apiServiceProvider);
    final response = await api.get<List<dynamic>>(AppConstants.notifications);
    return response.data
        .map(_fromJson)
        .whereType<AppNotification>()
        .toList();
  }

  Future<void> markRead(String id) async {
    // Mise à jour optimiste locale
    state = AsyncValue.data([
      for (final n in state.value ?? [])
        if (n.id == id) n.copyWith(isRead: true) else n,
    ]);
    // Appel API (fire-and-forget)
    try {
      final api = ref.read(apiServiceProvider);
      await api.post<void>(AppConstants.notificationRead(id));
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    state = AsyncValue.data([
      for (final n in state.value ?? []) n.copyWith(isRead: true),
    ]);
    try {
      final api = ref.read(apiServiceProvider);
      await api.post<void>(AppConstants.notificationsReadAll);
    } catch (_) {}
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchFromApi);
  }
}

final notificationsNotifierProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

// ============================================================================
// Filtered list provider
// ============================================================================

final filteredNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final filter = ref.watch(notificationFilterProvider);
  final all    = ref.watch(notificationsNotifierProvider).value ?? const [];

  return switch (filter) {
    NotificationFilterTab.all       => all,
    NotificationFilterTab.comments  => all.where((n) => n.isCommentType).toList(),
    NotificationFilterTab.reactions => all.where((n) => n.isReactionType).toList(),
    NotificationFilterTab.system    => all.where((n) => n.isSystemType).toList(),
  };
});

// ============================================================================
// Unread count (used by bottom-nav badge)
// ============================================================================

final unreadCountProvider = Provider<int>((ref) {
  return (ref.watch(notificationsNotifierProvider).value ?? const [])
      .where((n) => !n.isRead)
      .length;
});
