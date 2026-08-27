import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../shared/models/user_model.dart' show UserRole;
import '../../../services/api_service.dart';
import '../../moderation/models/moderation_models.dart';
import '../models/admin_models.dart';

// =============================================================================
// JSON helpers
// =============================================================================

AdminUser? _adminUserFromJson(dynamic raw) {
  try {
    final m = raw as Map<String, dynamic>;
    return AdminUser(
      uid:         m['id']           as String,
      displayName: m['display_name'] as String? ?? '',
      email:       m['email']        as String? ?? '',
      role:        UserRole.fromJson(m['role'] as String?),
      status:      _parseAccountStatus(m['status'] as String? ?? 'active'),
      avatarUrl:   m['avatar_url']   as String?,
      country:     m['country']      as String?,
      joinedAt:    DateTime.tryParse(m['created_at'] as String? ?? ''),
    );
  } catch (_) {
    return null;
  }
}

UserAccountStatus _parseAccountStatus(String v) => switch (v) {
      'suspended' => UserAccountStatus.suspended,
      'banned'    => UserAccountStatus.banned,
      _           => UserAccountStatus.active,
    };

AppCategory? _categoryFromJson(dynamic raw) {
  try {
    final m = raw as Map<String, dynamic>;
    return AppCategory(
      id:             m['id']              as String,
      name:           m['name']            as String? ?? '',
      slug:           m['slug']            as String? ?? '',
      order:          m['display_order']   as int? ?? 0,
      testimonyCount: m['testimony_count'] as int? ?? 0,
      isActive:       m['is_active']       as bool? ?? true,
    );
  } catch (_) {
    return null;
  }
}

PublishedTestimony? _publishedTestimonyFromJson(dynamic raw) {
  try {
    final m    = raw as Map<String, dynamic>;
    final user = m['user'] as Map<String, dynamic>? ?? {};
    return PublishedTestimony(
      id:          m['id']    as String,
      title:       m['title'] as String? ?? '',
      authorName:  user['display_name'] as String? ?? '',
      category:    m['category'] is String
                   ? m['category'] as String
                   : (m['category'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      type:        _parseTestimonyType(m['type'] as String? ?? 'text'),
      publishedAt: DateTime.tryParse(
              m['approved_at'] as String? ?? m['created_at'] as String? ?? '') ??
          DateTime.now(),
      views: m['views_count'] as int? ?? 0,
      likes: m['likes_count'] as int? ?? 0,
    );
  } catch (_) {
    return null;
  }
}

TestimonyType _parseTestimonyType(String v) => switch (v) {
      'audio' => TestimonyType.audio,
      'video' => TestimonyType.video,
      _       => TestimonyType.text,
    };

List<dynamic> _asList(dynamic raw) {
  if (raw is List) return raw;
  if (raw is Map) {
    return raw['data']  as List<dynamic>? ??
           raw['items'] as List<dynamic>? ??
           [];
  }
  return [];
}

// =============================================================================
// Admin metrics — FutureProvider (read-only, fetched from API)
// =============================================================================

final adminMetricsProvider = FutureProvider<AdminMetrics>((ref) async {
  final api      = ref.read(apiServiceProvider);
  final response = await api.get<Map<String, dynamic>>(AppConstants.adminStats);
  final m        = response.data;
  return AdminMetrics(
    totalUsers:          m['totalUsers']          as int?    ?? 0,
    newUsersToday:       m['newUsersToday']        as int?    ?? 0,
    totalTestimonies:    m['totalTestimonies']     as int?    ?? 0,
    viewsThisMonth:      m['viewsThisMonth']       as int?    ?? 0,
    approvalRate:        (m['approvalRate']        as num?)?.toDouble() ?? 0.0,
    pendingTestimonies:  m['pendingTestimonies']   as int?    ?? 0,
    avgEngagement:       (m['avgEngagement']       as num?)?.toDouble() ?? 0.0,
    commentsThisMonth:   m['commentsThisMonth']    as int?    ?? 0,
  );
});

// =============================================================================
// Admin users — AsyncNotifier with full CRUD via API
// =============================================================================

class AdminUsersNotifier extends AsyncNotifier<List<AdminUser>> {
  @override
  Future<List<AdminUser>> build() => _fetch();

  Future<List<AdminUser>> _fetch() async {
    final api      = ref.read(apiServiceProvider);
    final response = await api.get<dynamic>(AppConstants.adminUsers);
    return _asList(response.data)
        .map(_adminUserFromJson)
        .whereType<AdminUser>()
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> updateRole(String uid, UserRole newRole) async {
    _optimistic(uid, (u) => u.copyWith(role: newRole));
    await ref.read(apiServiceProvider).put<void>(
      AppConstants.adminUserRole(uid),
      data: {'role': newRole.toJson()},
    );
  }

  Future<void> suspend(String uid) async {
    _optimistic(uid, (u) => u.copyWith(status: UserAccountStatus.suspended));
    await ref
        .read(apiServiceProvider)
        .post<void>(AppConstants.adminSuspendUser(uid));
  }

  Future<void> ban(String uid) async {
    _optimistic(uid, (u) => u.copyWith(status: UserAccountStatus.banned));
    await ref
        .read(apiServiceProvider)
        .post<void>(AppConstants.adminBanUser(uid));
  }

  Future<void> activate(String uid) async {
    _optimistic(uid, (u) => u.copyWith(status: UserAccountStatus.active));
    await ref
        .read(apiServiceProvider)
        .post<void>(AppConstants.adminActivateUser(uid));
  }

  void _optimistic(String uid, AdminUser Function(AdminUser) update) {
    final current = state.value ?? [];
    state = AsyncValue.data([
      for (final u in current) if (u.uid == uid) update(u) else u,
    ]);
  }
}

final adminUsersNotifierProvider =
    AsyncNotifierProvider<AdminUsersNotifier, List<AdminUser>>(
  AdminUsersNotifier.new,
);

// ── User search state ─────────────────────────────────────────────────────────

class _AdminUserSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String query) => state = query;
}

final adminUserSearchProvider =
    NotifierProvider<_AdminUserSearchNotifier, String>(
  _AdminUserSearchNotifier.new,
);

/// Filtered & searched list for display (used by AdminUsersScreen)
final adminUsersProvider = Provider<List<AdminUser>>((ref) {
  final all   = ref.watch(adminUsersNotifierProvider).value ?? const [];
  final query = ref.watch(adminUserSearchProvider).toLowerCase();
  if (query.isEmpty) return all;
  return all.where((u) {
    return u.displayName.toLowerCase().contains(query) ||
        u.email.toLowerCase().contains(query);
  }).toList();
});

/// Alias used by AdminUsersScreen (which references adminUsersListProvider)
final adminUsersListProvider =
    Provider<List<AdminUser>>((ref) => ref.watch(adminUsersProvider));

// =============================================================================
// Admin categories — AsyncNotifier with CRUD via API
// =============================================================================

class AdminCategoriesNotifier extends AsyncNotifier<List<AppCategory>> {
  @override
  Future<List<AppCategory>> build() => _fetch();

  Future<List<AppCategory>> _fetch() async {
    final api      = ref.read(apiServiceProvider);
    final response = await api.get<dynamic>(AppConstants.adminCategories);
    return _asList(response.data)
        .map(_categoryFromJson)
        .whereType<AppCategory>()
        .toList();
  }

  Future<void> create(String name) async {
    final api      = ref.read(apiServiceProvider);
    final response = await api.post<Map<String, dynamic>>(
      AppConstants.adminCategories,
      data: {'name': name},
    );
    final newCat = _categoryFromJson(response.data);
    if (newCat != null) {
      state = AsyncValue.data([...state.value ?? [], newCat]);
    }
  }

  Future<void> updateName(String id, String newName) async {
    // Optimistic
    final current = state.value ?? [];
    state = AsyncValue.data([
      for (final c in current)
        if (c.id == id)
          AppCategory(
            id: c.id,
            name: newName,
            slug: newName.toLowerCase().replaceAll(' ', '-'),
            order: c.order,
            testimonyCount: c.testimonyCount,
            isActive: c.isActive,
          )
        else
          c,
    ]);
    await ref.read(apiServiceProvider).put<void>(
      AppConstants.adminCategoryById(id),
      data: {'name': newName},
    );
  }

  Future<void> toggleActive(String id, {required bool isActive}) async {
    // Optimistic
    final current = state.value ?? [];
    state = AsyncValue.data([
      for (final c in current)
        if (c.id == id)
          AppCategory(
            id: c.id,
            name: c.name,
            slug: c.slug,
            order: c.order,
            testimonyCount: c.testimonyCount,
            isActive: isActive,
          )
        else
          c,
    ]);
    await ref.read(apiServiceProvider).put<void>(
      AppConstants.adminCategoryById(id),
      data: {'is_active': isActive},
    );
  }

  /// Drag-and-drop reorder — local only (no bulk-reorder endpoint)
  void reorder(List<AppCategory> newOrder) {
    state = AsyncValue.data(newOrder);
  }
}

final adminCategoriesNotifierProvider =
    AsyncNotifierProvider<AdminCategoriesNotifier, List<AppCategory>>(
  AdminCategoriesNotifier.new,
);

/// Sync view of categories list (for screens that expect `List<AppCategory>`)
final adminCategoriesProvider = Provider<List<AppCategory>>(
  (ref) => ref.watch(adminCategoriesNotifierProvider).value ?? const [],
);

// =============================================================================
// Admin testimonies (content management) — read-only
// =============================================================================

final adminTestimoniesProvider =
    FutureProvider<List<PublishedTestimony>>((ref) async {
  final api      = ref.read(apiServiceProvider);
  final response = await api.get<dynamic>(AppConstants.adminTestimonies);
  return _asList(response.data)
      .map(_publishedTestimonyFromJson)
      .whereType<PublishedTestimony>()
      .toList();
});

// =============================================================================
// App settings — fetched from API, toggled locally and saved on demand
// =============================================================================

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final api      = ref.read(apiServiceProvider);
    final response =
        await api.get<Map<String, dynamic>>(AppConstants.adminSettings);
    final m = response.data;
    return AppSettings(
      maintenanceMode:          m['maintenance_mode']          as bool? ?? false,
      allowNewRegistrations:    m['allow_new_registrations']   as bool? ?? true,
      allowGuestView:           m['allow_guest_view']          as bool? ?? true,
      requireEmailVerification: m['require_email_verification'] as bool? ?? true,
      autoModerationEnabled:    m['auto_moderation_enabled']   as bool? ?? false,
      pushNotificationsEnabled: m['push_notifications_enabled'] as bool? ?? true,
    );
  }

  void toggle(String key) {
    final s = state.value;
    if (s == null) return;
    state = AsyncValue.data(switch (key) {
      'maintenanceMode'          => s.copyWith(maintenanceMode: !s.maintenanceMode),
      'allowNewRegistrations'    => s.copyWith(allowNewRegistrations: !s.allowNewRegistrations),
      'allowGuestView'           => s.copyWith(allowGuestView: !s.allowGuestView),
      'requireEmailVerification' => s.copyWith(requireEmailVerification: !s.requireEmailVerification),
      'autoModerationEnabled'    => s.copyWith(autoModerationEnabled: !s.autoModerationEnabled),
      'pushNotificationsEnabled' => s.copyWith(pushNotificationsEnabled: !s.pushNotificationsEnabled),
      _ => s,
    });
  }

  Future<void> save() async {
    final s = state.value;
    if (s == null) return;
    await ref.read(apiServiceProvider).put<void>(
      AppConstants.adminSettings,
      data: {
        'maintenance_mode':           s.maintenanceMode,
        'allow_new_registrations':    s.allowNewRegistrations,
        'allow_guest_view':           s.allowGuestView,
        'require_email_verification': s.requireEmailVerification,
        'auto_moderation_enabled':    s.autoModerationEnabled,
        'push_notifications_enabled': s.pushNotificationsEnabled,
      },
    );
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

// =============================================================================
// Active admin section
// =============================================================================

enum AdminSection { users, content, moderators, categories, stats, settings }

class _AdminSectionNotifier extends Notifier<AdminSection> {
  @override
  AdminSection build() => AdminSection.users;
  void select(AdminSection section) => state = section;
}

final adminSectionProvider =
    NotifierProvider<_AdminSectionNotifier, AdminSection>(
  _AdminSectionNotifier.new,
);
