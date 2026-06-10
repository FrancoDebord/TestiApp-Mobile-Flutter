import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../models/notification_models.dart';
import '../providers/notifications_provider.dart';

// =============================================================================
// NotificationsScreen
// =============================================================================
//
// Widget tree:
//
// Scaffold
//   CustomScrollView
//     SliverAppBar              ← sticky "Notifications" + "Tout marquer lu"
//     SliverPersistentHeader    ← filter tabs (Tout | Commentaires | Réactions | Système)
//     SliverList                ← grouped date sections
//       _DateGroupHeader        ← "Aujourd'hui", "Hier", "Cette semaine"
//       _NotificationTile(...)  ← 72 px row per notification
//   _EmptyState                 ← shown when filtered list is empty

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredNotificationsProvider);
    final notifier = ref.read(notificationsNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 20,
            title: Text(
              AppLocalizations.of(context).notifTitle,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: notifier.markAllRead,
                child: Text(
                  AppLocalizations.of(context).notifMarkAllRead,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Filter tabs ──────────────────────────────────────────────────
          const SliverPersistentHeader(
            pinned: true,
            delegate: _FilterTabsDelegate(),
          ),

          // ── Notification list or empty state ─────────────────────────────
          if (filtered.isEmpty)
            const SliverFillRemaining(child: _EmptyState())
          else
            _NotificationSliverList(notifications: filtered),
        ],
      ),
    );
  }
}

// =============================================================================
// Filter tabs — SliverPersistentHeaderDelegate
// =============================================================================

class _FilterTabsDelegate extends SliverPersistentHeaderDelegate {
  const _FilterTabsDelegate();

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return const _FilterTabBar();
  }

  @override
  bool shouldRebuild(_FilterTabsDelegate old) => false;
}

class _FilterTabBar extends ConsumerWidget {
  const _FilterTabBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(notificationFilterProvider);
    final notifier = ref.read(notificationFilterProvider.notifier);

    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: NotificationFilterTab.values.map((tab) {
                final selected = tab == current;
                return GestureDetector(
                  onTap: () => notifier.setTab(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        tab.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }
}

// =============================================================================
// Grouped sliver list
// =============================================================================

class _NotificationSliverList extends StatelessWidget {
  const _NotificationSliverList({required this.notifications});

  final List<AppNotification> notifications;

  /// Returns label + items for each date bucket.
  List<({String label, List<AppNotification> items})> _group(
      BuildContext context, List<AppNotification> all) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 6));

    final today = all.where((n) => n.createdAt.isAfter(todayStart)).toList();
    final yesterday = all
        .where((n) =>
            n.createdAt.isAfter(yesterdayStart) &&
            n.createdAt.isBefore(todayStart))
        .toList();
    final thisWeek = all
        .where((n) =>
            n.createdAt.isAfter(weekStart) &&
            n.createdAt.isBefore(yesterdayStart))
        .toList();

    final l10n = AppLocalizations.of(context);
    return [
      if (today.isNotEmpty) (label: l10n.notifToday, items: today),
      if (yesterday.isNotEmpty) (label: l10n.notifYesterday, items: yesterday),
      if (thisWeek.isNotEmpty) (label: l10n.notifThisWeek, items: thisWeek),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final groups = _group(context, notifications);

    // Flatten into a list of either header strings or notification items.
    final rows = <Object>[];
    for (final g in groups) {
      rows.add(g.label);
      rows.addAll(g.items);
    }

    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is String) return _DateGroupHeader(label: row);
        return _NotificationTile(notification: row as AppNotification);
      },
    );
  }
}

// =============================================================================
// Date group header
// =============================================================================

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// =============================================================================
// Notification tile  (72 px height)
// =============================================================================

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  // ── Type metadata ──────────────────────────────────────────────────────────

  static const Map<NotificationType, IconData> _icons = {
    NotificationType.comment: Icons.chat_bubble_rounded,
    NotificationType.like: Icons.favorite_rounded,
    NotificationType.prayer: Icons.front_hand_rounded,
    NotificationType.approved: Icons.check_circle_rounded,
    NotificationType.newFollowedTestimony: Icons.notifications_rounded,
    NotificationType.pendingCorrection: Icons.warning_rounded,
  };

  static const Map<NotificationType, Color> _iconColors = {
    NotificationType.comment: Color(0xFF3B82F6),
    NotificationType.like: AppColors.danger,
    NotificationType.prayer: AppColors.secondary,
    NotificationType.approved: AppColors.success,
    NotificationType.newFollowedTestimony: AppColors.primary,
    NotificationType.pendingCorrection: Color(0xFFF97316),
  };

  String _timeAgo(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    final l10n = AppLocalizations.of(context);
    if (diff.inMinutes < 1) return l10n.notifToday;
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markRead =
        ref.read(notificationsNotifierProvider.notifier).markRead;
    final color = _iconColors[notification.type]!;

    return InkWell(
      onTap: () => markRead(notification.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 72,
        color: notification.isRead
            ? AppColors.surface
            : AppColors.primary.withAlpha(8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // ── Avatar / system icon ───────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                notification.actorAvatarUrl != null
                    ? CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            NetworkImage(notification.actorAvatarUrl!),
                      )
                    : CircleAvatar(
                        radius: 20,
                        backgroundColor: color.withAlpha(30),
                        child: Text(
                          notification.actorName.isNotEmpty
                              ? notification.actorName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: color,
                          ),
                        ),
                      ),
                // Type icon badge
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      _icons[notification.type],
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // ── Body text + time ──────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.w500,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _timeAgo(context, notification.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // ── Right: unread dot or thumbnail ────────────────────────────
            if (notification.testimonyThumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  notification.testimonyThumbnailUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              )
            else if (!notification.isRead)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Empty state
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 44,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context).notifEmpty,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).notifEmptyDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
