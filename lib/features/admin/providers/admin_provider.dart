import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../moderation/models/moderation_models.dart';
import '../models/admin_models.dart';

// =============================================================================
// Stub data — replace bodies with Dio repository calls
// =============================================================================

final _stubUsers = <AdminUser>[
  AdminUser(
    uid: 'u1',
    displayName: 'Marie Dubois',
    email: 'marie.dubois@email.com',
    role: UserRole.utilisateur,
    status: UserAccountStatus.active,
    country: 'Côte d\'Ivoire',
    joinedAt: DateTime(2024, 3, 10),
  ),
  AdminUser(
    uid: 'u2',
    displayName: 'Jean-Paul Koffi',
    email: 'jpkoffi@email.com',
    role: UserRole.utilisateur,
    status: UserAccountStatus.active,
    country: 'Cameroun',
    joinedAt: DateTime(2024, 6, 22),
  ),
  AdminUser(
    uid: 'u3',
    displayName: 'Esther Nkomo',
    email: 'esther.nkomo@email.com',
    role: UserRole.moderateur,
    status: UserAccountStatus.active,
    country: 'Congo',
    joinedAt: DateTime(2023, 11, 5),
  ),
  AdminUser(
    uid: 'u4',
    displayName: 'Samuel Ouédraogo',
    email: 'samuel.o@email.com',
    role: UserRole.utilisateur,
    status: UserAccountStatus.suspended,
    country: 'Burkina Faso',
    joinedAt: DateTime(2024, 1, 18),
  ),
  AdminUser(
    uid: 'u5',
    displayName: 'Grace Mensah',
    email: 'grace.mensah@email.com',
    role: UserRole.utilisateur,
    status: UserAccountStatus.active,
    country: 'Ghana',
    joinedAt: DateTime(2025, 2, 3),
  ),
  AdminUser(
    uid: 'u6',
    displayName: 'Pierre Batumike',
    email: 'pierre.b@email.com',
    role: UserRole.administrateur,
    status: UserAccountStatus.active,
    country: 'RDC',
    joinedAt: DateTime(2023, 5, 14),
  ),
];

final _stubTestimonies = <PublishedTestimony>[
  PublishedTestimony(
    id: 't1',
    title: 'Comment Dieu m\'a guéri d\'une maladie incurable',
    authorName: 'Marie Dubois',
    category: 'Guérison',
    type: TestimonyType.text,
    publishedAt: DateTime(2025, 5, 20),
    views: 1420,
    likes: 312,
  ),
  PublishedTestimony(
    id: 't2',
    title: 'Délivrance de la dépendance à l\'alcool',
    authorName: 'Jean-Paul Koffi',
    category: 'Délivrance',
    type: TestimonyType.audio,
    publishedAt: DateTime(2025, 5, 18),
    views: 876,
    likes: 198,
  ),
  PublishedTestimony(
    id: 't3',
    title: 'Mon mariage restauré après deux ans de séparation',
    authorName: 'Esther Nkomo',
    category: 'Mariage',
    type: TestimonyType.video,
    publishedAt: DateTime(2025, 5, 15),
    views: 2310,
    likes: 507,
  ),
];

final _stubCategories = <AppCategory>[
  AppCategory(
      id: 'c1', name: 'Guérison', slug: 'guerison', order: 1, testimonyCount: 245),
  AppCategory(
      id: 'c2', name: 'Délivrance', slug: 'delivrance', order: 2, testimonyCount: 189),
  AppCategory(
      id: 'c3', name: 'Conversion', slug: 'conversion', order: 3, testimonyCount: 312),
  AppCategory(
      id: 'c4', name: 'Mariage', slug: 'mariage', order: 4, testimonyCount: 98),
  AppCategory(
      id: 'c5', name: 'Famille', slug: 'famille', order: 5, testimonyCount: 134),
  AppCategory(
      id: 'c6', name: 'Finances', slug: 'finances', order: 6, testimonyCount: 76),
  AppCategory(
      id: 'c7', name: 'Miracles', slug: 'miracles', order: 7, testimonyCount: 421),
  AppCategory(
      id: 'c8',
      name: 'Protection divine',
      slug: 'protection-divine',
      order: 8,
      testimonyCount: 167),
  AppCategory(
      id: 'c9', name: 'Ministère', slug: 'ministere', order: 9, testimonyCount: 55),
  AppCategory(
      id: 'c10', name: 'Salut', slug: 'salut', order: 10, testimonyCount: 203),
];

// =============================================================================
// Providers
// =============================================================================

// ── Metrics ───────────────────────────────────────────────────────────────────

final adminMetricsProvider = Provider<AdminMetrics>((ref) {
  return const AdminMetrics(
    totalUsers: 4_280,
    newUsersToday: 37,
    totalTestimonies: 1_900,
    viewsThisMonth: 128_400,
    approvalRate: 87.3,
    pendingTestimonies: 24,
    avgEngagement: 4.6,
    commentsThisMonth: 3_210,
  );
});

// ── Users ─────────────────────────────────────────────────────────────────────

class _AdminUserSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String query) => state = query;
}

final adminUserSearchProvider =
    NotifierProvider<_AdminUserSearchNotifier, String>(
  _AdminUserSearchNotifier.new,
);

final adminUsersProvider = Provider<List<AdminUser>>((ref) {
  final query = ref.watch(adminUserSearchProvider).toLowerCase();
  if (query.isEmpty) return _stubUsers;
  return _stubUsers.where((u) {
    return u.displayName.toLowerCase().contains(query) ||
        u.email.toLowerCase().contains(query);
  }).toList();
});

// ── Testimonies ───────────────────────────────────────────────────────────────

final adminTestimoniesProvider = Provider<List<PublishedTestimony>>((ref) {
  return _stubTestimonies;
});

// ── Categories ────────────────────────────────────────────────────────────────

class _AdminCategoriesNotifier extends Notifier<List<AppCategory>> {
  @override
  List<AppCategory> build() => _stubCategories;
  void update(List<AppCategory> categories) => state = categories;
}

final adminCategoriesProvider =
    NotifierProvider<_AdminCategoriesNotifier, List<AppCategory>>(
  _AdminCategoriesNotifier.new,
);

// ── App settings ──────────────────────────────────────────────────────────────

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void toggle(String key) {
    state = switch (key) {
      'maintenanceMode' =>
        state.copyWith(maintenanceMode: !state.maintenanceMode),
      'allowNewRegistrations' =>
        state.copyWith(allowNewRegistrations: !state.allowNewRegistrations),
      'allowGuestView' =>
        state.copyWith(allowGuestView: !state.allowGuestView),
      'requireEmailVerification' =>
        state.copyWith(requireEmailVerification: !state.requireEmailVerification),
      'autoModerationEnabled' =>
        state.copyWith(autoModerationEnabled: !state.autoModerationEnabled),
      'pushNotificationsEnabled' =>
        state.copyWith(pushNotificationsEnabled: !state.pushNotificationsEnabled),
      _ => state,
    };
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

// ── Active admin section ──────────────────────────────────────────────────────

enum AdminSection {
  users,
  content,
  moderators,
  categories,
  stats,
  settings,
}

class _AdminSectionNotifier extends Notifier<AdminSection> {
  @override
  AdminSection build() => AdminSection.users;
  void select(AdminSection section) => state = section;
}

final adminSectionProvider =
    NotifierProvider<_AdminSectionNotifier, AdminSection>(
  _AdminSectionNotifier.new,
);
