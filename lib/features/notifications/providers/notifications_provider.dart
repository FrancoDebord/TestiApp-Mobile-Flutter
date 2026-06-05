import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_models.dart';

// =============================================================================
// Stub data — replace with Dio repository calls
// =============================================================================

final _now = DateTime.now();

final _stubNotifications = <AppNotification>[
  // Today
  AppNotification(
    id: 'n1',
    type: NotificationType.comment,
    actorName: 'Marie Dubois',
    testimonyTitle: 'Ma guérison miraculeuse',
    createdAt: _now.subtract(const Duration(minutes: 5)),
    isRead: false,
  ),
  AppNotification(
    id: 'n2',
    type: NotificationType.prayer,
    actorName: 'Jean-Paul Koffi',
    testimonyTitle: 'Délivrance de l\'addiction',
    createdAt: _now.subtract(const Duration(minutes: 23)),
    isRead: false,
  ),
  AppNotification(
    id: 'n3',
    type: NotificationType.like,
    actorName: 'Esther Nkomo',
    testimonyTitle: 'Mon mariage restauré',
    createdAt: _now.subtract(const Duration(hours: 1)),
    isRead: false,
  ),
  AppNotification(
    id: 'n4',
    type: NotificationType.approved,
    actorName: 'Modérateur',
    testimonyTitle: 'Protection divine sur la route',
    createdAt: _now.subtract(const Duration(hours: 3)),
    isRead: true,
  ),
  // Yesterday
  AppNotification(
    id: 'n5',
    type: NotificationType.comment,
    actorName: 'Samuel Ouédraogo',
    testimonyTitle: 'Finances rétablies par la foi',
    createdAt: _now.subtract(const Duration(hours: 26)),
    isRead: true,
  ),
  AppNotification(
    id: 'n6',
    type: NotificationType.newFollowedTestimony,
    actorName: 'Grace Mensah',
    testimonyTitle: 'Conversion de mon frère',
    createdAt: _now.subtract(const Duration(hours: 30)),
    isRead: true,
  ),
  // This week
  AppNotification(
    id: 'n7',
    type: NotificationType.pendingCorrection,
    actorName: 'Modérateur',
    testimonyTitle: 'Miracle de guérison',
    createdAt: _now.subtract(const Duration(days: 3)),
    isRead: true,
  ),
  AppNotification(
    id: 'n8',
    type: NotificationType.prayer,
    actorName: 'Abigail Mensah',
    testimonyTitle: 'Bénédiction familiale',
    createdAt: _now.subtract(const Duration(days: 4)),
    isRead: true,
  ),
];

// =============================================================================
// Filter notifier
// =============================================================================

class NotificationFilterNotifier extends Notifier<NotificationFilterTab> {
  @override
  NotificationFilterTab build() => NotificationFilterTab.all;

  void setTab(NotificationFilterTab tab) => state = tab;
}

final notificationFilterProvider =
    NotifierProvider<NotificationFilterNotifier, NotificationFilterTab>(
  NotificationFilterNotifier.new,
);

// =============================================================================
// Notifications list notifier (marks read, etc.)
// =============================================================================

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => List.unmodifiable(_stubNotifications);

  void markRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
  }

  void markAllRead() {
    state = [for (final n in state) n.copyWith(isRead: true)];
  }
}

final notificationsNotifierProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

// =============================================================================
// Filtered list provider
// =============================================================================

final filteredNotificationsProvider =
    Provider<List<AppNotification>>((ref) {
  final filter = ref.watch(notificationFilterProvider);
  final all = ref.watch(notificationsNotifierProvider);

  switch (filter) {
    case NotificationFilterTab.all:
      return all;
    case NotificationFilterTab.comments:
      return all.where((n) => n.isCommentType).toList();
    case NotificationFilterTab.reactions:
      return all.where((n) => n.isReactionType).toList();
    case NotificationFilterTab.system:
      return all.where((n) => n.isSystemType).toList();
  }
});

// =============================================================================
// Unread count (used by bottom-nav badge)
// =============================================================================

final unreadCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationsNotifierProvider)
      .where((n) => !n.isRead)
      .length;
});
