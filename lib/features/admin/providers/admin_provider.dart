import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../moderation/models/moderation_models.dart';
import '../models/admin_models.dart';

// ============================================================================
// Helpers : JSON API → modèles admin
// ============================================================================

AdminMetrics _metricsFromJson(Map<String, dynamic> m) => AdminMetrics(
      totalUsers:         (m['totalUsers']         as int?)    ?? 0,
      newUsersToday:      (m['newUsersToday']       as int?)    ?? 0,
      totalTestimonies:   (m['totalTestimonies']    as int?)    ?? 0,
      viewsThisMonth:     (m['viewsThisMonth']      as int?)    ?? 0,
      approvalRate:       (m['approvalRate']        as num?)?.toDouble() ?? 0.0,
      pendingTestimonies: (m['pendingTestimonies']  as int?)    ?? 0,
      avgEngagement:      (m['avgEngagement']       as num?)?.toDouble() ?? 0.0,
      commentsThisMonth:  (m['commentsThisMonth']   as int?)    ?? 0,
    );

AdminUser? _userFromJson(dynamic raw) {
  try {
    final m = raw as Map<String, dynamic>;
    return AdminUser(
      uid:         m['id']          as String,
      displayName: m['displayName'] as String? ?? '',
      email:       m['email']       as String? ?? '',
      role:        _parseRole(m['role'] as String? ?? 'utilisateur'),
      status:      _parseStatus(m['status'] as String? ?? 'active'),
      avatarUrl:   m['avatarUrl']   as String?,
      country:     m['country']     as String?,
      joinedAt:    DateTime.tryParse(m['createdAt'] as String? ?? ''),
    );
  } catch (_) {
    return null;
  }
}

PublishedTestimony? _testimonyFromJson(dynamic raw) {
  try {
    final m       = raw as Map<String, dynamic>;
    final userMap = m['user'] as Map<String, dynamic>? ?? {};
    final statsMap= m['stats'] as Map<String, dynamic>? ?? {};
    return PublishedTestimony(
      id:          m['id']    as String,
      title:       m['title'] as String? ?? '',
      authorName:  userMap['displayName'] as String? ?? '',
      category:    m['category'] as String? ?? '',
      type:        _parseType(m['type'] as String? ?? 'text'),
      publishedAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      views:       (statsMap['viewsCount'] as int?) ?? 0,
      likes:       (statsMap['likesCount'] as int?) ?? 0,
    );
  } catch (_) {
    return null;
  }
}

UserRole _parseRole(String v) => switch (v) {
      'administrateur' => UserRole.administrateur,
      'moderateur'     => UserRole.moderateur,
      'visiteur'       => UserRole.visiteur,
      _                => UserRole.utilisateur,
    };

UserAccountStatus _parseStatus(String v) => switch (v) {
      'suspended' => UserAccountStatus.suspended,
      'banned'    => UserAccountStatus.banned,
      _           => UserAccountStatus.active,
    };

TestimonyType _parseType(String v) => switch (v) {
      'audio' => TestimonyType.audio,
      'video' => TestimonyType.video,
      _       => TestimonyType.text,
    };

// ============================================================================
// Métriques — AsyncNotifier
// ============================================================================

class AdminMetricsNotifier extends AsyncNotifier<AdminMetrics> {
  @override
  Future<AdminMetrics> build() async {
    final api      = ref.read(apiServiceProvider);
    final response = await api.get<Map<String, dynamic>>(AppConstants.adminStats);
    return _metricsFromJson(response.data);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final adminMetricsProvider =
    AsyncNotifierProvider<AdminMetricsNotifier, AdminMetrics>(
  AdminMetricsNotifier.new,
);

// ============================================================================
// Users — AsyncNotifier avec filtre de recherche
// ============================================================================

class _AdminUserSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String query) => state = query;
}

final adminUserSearchProvider =
    NotifierProvider<_AdminUserSearchNotifier, String>(
  _AdminUserSearchNotifier.new,
);

class AdminUsersNotifier extends AsyncNotifier<List<AdminUser>> {
  @override
  Future<List<AdminUser>> build() => _fetch('');

  Future<List<AdminUser>> _fetch(String query) async {
    final api = ref.read(apiServiceProvider);
    final url = query.isEmpty
        ? AppConstants.adminUsers
        : '${AppConstants.adminUsers}?q=${Uri.encodeComponent(query)}';
    final response = await api.get<List<dynamic>>(url);
    return response.data
        .map(_userFromJson)
        .whereType<AdminUser>()
        .toList();
  }

  Future<void> search(String query) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(query));
  }

  Future<void> banUser(String id) async {
    final api = ref.read(apiServiceProvider);
    await api.post<void>(AppConstants.adminBanUser(id));
    state = AsyncValue.data(
      state.value?.where((u) => u.uid != id).toList() ?? [],
    );
  }

  Future<void> suspendUser(String id) async {
    final api = ref.read(apiServiceProvider);
    await api.post<void>(AppConstants.adminSuspendUser(id));
    state = AsyncValue.data([
      for (final u in state.value ?? [])
        if (u.uid == id)
          AdminUser(
            uid: u.uid, displayName: u.displayName, email: u.email,
            role: u.role, status: UserAccountStatus.suspended,
            avatarUrl: u.avatarUrl, country: u.country, joinedAt: u.joinedAt,
          )
        else
          u,
    ]);
  }

  Future<void> activateUser(String id) async {
    final api = ref.read(apiServiceProvider);
    await api.post<void>(AppConstants.adminActivateUser(id));
    state = AsyncValue.data([
      for (final u in state.value ?? [])
        if (u.uid == id)
          AdminUser(
            uid: u.uid, displayName: u.displayName, email: u.email,
            role: u.role, status: UserAccountStatus.active,
            avatarUrl: u.avatarUrl, country: u.country, joinedAt: u.joinedAt,
          )
        else
          u,
    ]);
  }

  Future<void> updateRole(String id, UserRole role) async {
    final api      = ref.read(apiServiceProvider);
    final roleStr  = switch (role) {
      UserRole.administrateur => 'administrateur',
      UserRole.moderateur     => 'moderateur',
      UserRole.visiteur       => 'visiteur',
      _                       => 'utilisateur',
    };
    await api.put<void>(AppConstants.adminUserRole(id), data: {'role': roleStr});
    state = AsyncValue.data([
      for (final u in state.value ?? [])
        if (u.uid == id)
          AdminUser(
            uid: u.uid, displayName: u.displayName, email: u.email,
            role: role, status: u.status,
            avatarUrl: u.avatarUrl, country: u.country, joinedAt: u.joinedAt,
          )
        else
          u,
    ]);
  }
}

final adminUsersProvider =
    AsyncNotifierProvider<AdminUsersNotifier, List<AdminUser>>(
  AdminUsersNotifier.new,
);

// Providers dérivés (synchrones) pour les écrans existants
final adminUsersListProvider = Provider<List<AdminUser>>((ref) {
  final query = ref.watch(adminUserSearchProvider).toLowerCase();
  final all   = ref.watch(adminUsersProvider).value ?? const [];
  if (query.isEmpty) return all;
  return all
      .where((u) =>
          u.displayName.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query))
      .toList();
});

// ============================================================================
// Testimonies admin — FutureProvider
// ============================================================================

final adminTestimoniesProvider = FutureProvider<List<PublishedTestimony>>((ref) async {
  final api      = ref.read(apiServiceProvider);
  final response = await api.get<List<dynamic>>(AppConstants.adminTestimonies);
  return response.data
      .map(_testimonyFromJson)
      .whereType<PublishedTestimony>()
      .toList();
});

// ============================================================================
// Categories — sync Notifier (load from API on init, local update for UI)
// ============================================================================

AppCategory? _categoryFromJson(dynamic raw) {
  try {
    final m = raw as Map<String, dynamic>;
    return AppCategory(
      id:             m['id']             as String,
      name:           m['name']           as String,
      slug:           m['slug']           as String,
      order:          (m['order']         as int?) ?? 0,
      testimonyCount: (m['testimonyCount'] as int?) ?? 0,
      isActive:       (m['isActive']      as bool?) ?? true,
    );
  } catch (_) {
    return null;
  }
}

class AdminCategoriesNotifier extends Notifier<List<AppCategory>> {
  @override
  List<AppCategory> build() {
    Future.microtask(_loadFromApi);
    return const [];
  }

  Future<void> _loadFromApi() async {
    try {
      final api      = ref.read(apiServiceProvider);
      final response = await api.get<List<dynamic>>(AppConstants.adminCategories);
      state = response.data
          .map(_categoryFromJson)
          .whereType<AppCategory>()
          .toList();
    } catch (_) {}
  }

  void update(List<AppCategory> categories) {
    state = categories;
    () async {
      try {
        final api = ref.read(apiServiceProvider);
        final payload = categories.asMap().entries.map((e) => {
          'id': e.value.id, 'order': e.key + 1,
          'name': e.value.name, 'slug': e.value.slug,
          'is_active': e.value.isActive,
        }).toList();
        await api.put<void>(AppConstants.adminCategories, data: {'categories': payload});
      } catch (_) {}
    }();
  }
}

final adminCategoriesProvider =
    NotifierProvider<AdminCategoriesNotifier, List<AppCategory>>(
  AdminCategoriesNotifier.new,
);

// ============================================================================
// App settings
// ============================================================================

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void toggle(String key) {
    state = switch (key) {
      'maintenanceMode'          => state.copyWith(maintenanceMode:          !state.maintenanceMode),
      'allowNewRegistrations'    => state.copyWith(allowNewRegistrations:    !state.allowNewRegistrations),
      'allowGuestView'           => state.copyWith(allowGuestView:           !state.allowGuestView),
      'requireEmailVerification' => state.copyWith(requireEmailVerification: !state.requireEmailVerification),
      'autoModerationEnabled'    => state.copyWith(autoModerationEnabled:    !state.autoModerationEnabled),
      'pushNotificationsEnabled' => state.copyWith(pushNotificationsEnabled: !state.pushNotificationsEnabled),
      _                          => state,
    };
    // Synchroniser avec l'API (fire-and-forget)
    () async {
      try {
        final api = ref.read(apiServiceProvider);
        await api.put<void>(AppConstants.adminSettings, data: {key: _boolFromKey(key)});
      } catch (_) {}
    }();
  }

  bool _boolFromKey(String key) => switch (key) {
        'maintenanceMode'          => state.maintenanceMode,
        'allowNewRegistrations'    => state.allowNewRegistrations,
        'allowGuestView'           => state.allowGuestView,
        'requireEmailVerification' => state.requireEmailVerification,
        'autoModerationEnabled'    => state.autoModerationEnabled,
        'pushNotificationsEnabled' => state.pushNotificationsEnabled,
        _                          => false,
      };
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

// ============================================================================
// Active admin section
// ============================================================================

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
