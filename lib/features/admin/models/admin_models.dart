// =============================================================================
// Admin domain models
// =============================================================================

import '../../../core/providers/auth_provider.dart';
import '../../moderation/models/moderation_models.dart';

// ── App-wide metrics ──────────────────────────────────────────────────────────

class AdminMetrics {
  const AdminMetrics({
    required this.totalUsers,
    required this.newUsersToday,
    required this.totalTestimonies,
    required this.viewsThisMonth,
    required this.approvalRate,
    required this.pendingTestimonies,
    required this.avgEngagement,
    required this.commentsThisMonth,
  });

  final int totalUsers;
  final int newUsersToday;
  final int totalTestimonies;
  final int viewsThisMonth;
  final double approvalRate; // 0–100
  final int pendingTestimonies;
  final double avgEngagement; // avg interactions per testimony
  final int commentsThisMonth;
}

// ── User management ───────────────────────────────────────────────────────────

enum UserAccountStatus { active, suspended, banned }

class AdminUser {
  const AdminUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.status,
    this.avatarUrl,
    this.country,
    this.joinedAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final UserRole role;
  final UserAccountStatus status;
  final String? avatarUrl;
  final String? country;
  final DateTime? joinedAt;
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.visiteur => 'Visiteur',
        UserRole.utilisateur => 'Utilisateur',
        UserRole.moderateur => 'Modérateur',
        UserRole.administrateur => 'Admin',
      };
}

extension UserAccountStatusLabel on UserAccountStatus {
  String get label {
    switch (this) {
      case UserAccountStatus.active:
        return 'Actif';
      case UserAccountStatus.suspended:
        return 'Suspendu';
      case UserAccountStatus.banned:
        return 'Banni';
    }
  }
}

// ── Published testimony (content management) ──────────────────────────────────

class PublishedTestimony {
  const PublishedTestimony({
    required this.id,
    required this.title,
    required this.authorName,
    required this.category,
    required this.type,
    required this.publishedAt,
    required this.views,
    required this.likes,
  });

  final String id;
  final String title;
  final String authorName;
  final String category;
  final TestimonyType type;
  final DateTime publishedAt;
  final int views;
  final int likes;
}

// ── App category ──────────────────────────────────────────────────────────────

class AppCategory {
  const AppCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.order,
    required this.testimonyCount,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final int order;
  final int testimonyCount;
  final bool isActive;
}

// ── App settings ──────────────────────────────────────────────────────────────

class AppSettings {
  const AppSettings({
    this.maintenanceMode = false,
    this.allowNewRegistrations = true,
    this.allowGuestView = true,
    this.requireEmailVerification = true,
    this.autoModerationEnabled = false,
    this.pushNotificationsEnabled = true,
  });

  final bool maintenanceMode;
  final bool allowNewRegistrations;
  final bool allowGuestView;
  final bool requireEmailVerification;
  final bool autoModerationEnabled;
  final bool pushNotificationsEnabled;

  AppSettings copyWith({
    bool? maintenanceMode,
    bool? allowNewRegistrations,
    bool? allowGuestView,
    bool? requireEmailVerification,
    bool? autoModerationEnabled,
    bool? pushNotificationsEnabled,
  }) {
    return AppSettings(
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      allowNewRegistrations:
          allowNewRegistrations ?? this.allowNewRegistrations,
      allowGuestView: allowGuestView ?? this.allowGuestView,
      requireEmailVerification:
          requireEmailVerification ?? this.requireEmailVerification,
      autoModerationEnabled:
          autoModerationEnabled ?? this.autoModerationEnabled,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
    );
  }
}
