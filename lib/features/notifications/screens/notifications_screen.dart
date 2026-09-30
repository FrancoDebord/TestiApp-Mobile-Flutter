import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../models/notification_models.dart';
import '../providers/notifications_provider.dart';

// =============================================================================
// NotificationsScreen — écran 10 de la maquette
// =============================================================================
//
// Scaffold
//   AppBar « Notifications » + « Tout marquer lu »
//   _FilterPills               ← Toutes | Nouveaux (non lues) | Populaires
//   RefreshIndicator → ListView de _NotificationTile
//   _EmptyState                ← liste filtrée vide

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredNotificationsProvider);
    final async = ref.watch(notificationsNotifierProvider);
    final notifier = ref.read(notificationsNotifierProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final hasUnread = (async.value ?? const []).any((n) => !n.isRead);

    Widget body;
    if (async.isLoading && !async.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (filtered.isEmpty) {
      body = LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: const _EmptyState(),
          ),
        ),
      );
    } else {
      body = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxxl),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _NotificationTile(notification: filtered[i]),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: Text(l10n.notifTitle,
            style: AppTextStyles.h4.copyWith(fontSize: 18)),
        actions: [
          if (hasUnread)
            IconButton(
              tooltip: l10n.notifMarkAllRead,
              onPressed: notifier.markAllRead,
              icon: const Icon(Icons.done_all_rounded, color: AppColors.primary),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, AppSpacing.sm),
            child: _FilterPills(),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: notifier.refresh,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Onglets pilule
// =============================================================================

class _FilterPills extends ConsumerWidget {
  const _FilterPills();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(notificationFilterProvider);
    final notifier = ref.read(notificationFilterProvider.notifier);
    final l10n = AppLocalizations.of(context);

    String label(NotificationFilterTab t) => switch (t) {
          NotificationFilterTab.all => l10n.notifTabAll,
          NotificationFilterTab.unread => l10n.notifTabNew,
          NotificationFilterTab.popular => l10n.notifTabPopular,
        };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final tab in NotificationFilterTab.values)
            Expanded(
              child: Semantics(
                selected: tab == current,
                button: true,
                child: GestureDetector(
                  onTap: () => notifier.setTab(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: tab == current ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label(tab),
                        maxLines: 1,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tab == current
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Ligne de notification
// =============================================================================

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  /// Icône, couleur et fond doux de la bulle selon le type.
  static (IconData, Color, Color) _style(NotificationType t) => switch (t) {
        NotificationType.comment =>
          (Icons.chat_bubble_rounded, AppColors.primary, AppColors.primarySoft),
        NotificationType.like =>
          (Icons.star_rounded, AppColors.sunText, AppColors.sunSoft),
        NotificationType.prayer =>
          (Icons.volunteer_activism_rounded, AppColors.secondary, AppColors.secondarySoft),
        NotificationType.approved =>
          (Icons.check_circle_rounded, AppColors.success, AppColors.successSoft),
        NotificationType.newFollowedTestimony =>
          (Icons.auto_stories_rounded, AppColors.primary, AppColors.primarySoft),
        NotificationType.pendingCorrection =>
          (Icons.edit_note_rounded, AppColors.secondaryDark, AppColors.secondarySoft),
        NotificationType.organizationVerified =>
          (Icons.verified_rounded, AppColors.success, AppColors.successSoft),
        NotificationType.organizationRejected =>
          (Icons.gpp_bad_rounded, AppColors.danger, AppColors.dangerSoft),
        NotificationType.liveStarted =>
          (Icons.sensors_rounded, AppColors.danger, AppColors.dangerSoft),
      };

  static String _timeAgo(AppLocalizations l10n, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    final fr = l10n.isFr;
    if (diff.inMinutes < 1) return fr ? "à l'instant" : 'just now';
    if (diff.inMinutes < 60) {
      return fr ? 'il y a ${diff.inMinutes} min' : '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return fr ? 'il y a ${diff.inHours} h' : '${diff.inHours} h ago';
    }
    if (diff.inDays < 30) {
      return fr ? 'il y a ${diff.inDays} j' : '${diff.inDays} d ago';
    }
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markRead =
        ref.read(notificationsNotifierProvider.notifier).markRead;
    final (icon, color, soft) = _style(notification.type);
    final unread = !notification.isRead;
    final l10n = AppLocalizations.of(context);

    final bubble = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
      child: Icon(icon, size: 22, color: color),
    );

    final leading = notification.actorAvatarUrl != null
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: soft,
                backgroundImage: NetworkImage(notification.actorAvatarUrl!),
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                  child: Icon(icon, size: 11, color: Colors.white),
                ),
              ),
            ],
          )
        : bubble;

    return Material(
      color: unread ? AppColors.primarySoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(
            color: unread ? AppColors.primarySoft : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          markRead(notification.id);
          final liveId = notification.liveId;
          final testimonyId = notification.testimonyId;
          if (notification.type == NotificationType.liveStarted) {
            if (liveId != null && liveId.isNotEmpty) {
              context.push('/lives/$liveId');
            }
          } else if (testimonyId != null && testimonyId.isNotEmpty) {
            context.push('/testimony/$testimonyId');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: unread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(l10n, notification.createdAt),
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (notification.testimonyThumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.network(
                    notification.testimonyThumbnailUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(width: 44, height: 44),
                  ),
                )
              else if (unread)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// État vide
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 42,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.notifEmpty,
            textAlign: TextAlign.center,
            style: AppTextStyles.h4,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.notifEmptyDesc,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
