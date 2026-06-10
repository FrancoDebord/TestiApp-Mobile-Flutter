import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/app_constants.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider, authStateProvider;
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../services/api_service.dart';
import '../models/profile_models.dart';

// ── Clés de stockage ──────────────────────────────────────────────────────

const _kFirstName   = 'profile_first_name';
const _kLastName    = 'profile_last_name';
const _kGender      = 'profile_gender';
const _kPhone       = 'profile_phone';
const _kEmail       = 'profile_email';
const _kCountry     = 'profile_country';
const _kBio         = 'profile_bio';
const _kTitle       = 'profile_title';
const _kAvatarPath  = 'profile_avatar_path';

// ═══════════════════════════════════════════════════════════════════════════
// ProfileExtrasNotifier — champs complémentaires persistants
// ═══════════════════════════════════════════════════════════════════════════

class ProfileExtrasNotifier extends AsyncNotifier<ProfileExtras> {
  late final FlutterSecureStorage _storage;

  @override
  Future<ProfileExtras> build() async {
    _storage = ref.read(secureStorageProvider);
    return _load();
  }

  Future<ProfileExtras> _load() async {
    final fn     = await _storage.read(key: _kFirstName)  ?? '';
    final ln     = await _storage.read(key: _kLastName)   ?? '';
    final gen    = await _storage.read(key: _kGender)     ?? '';
    final ph     = await _storage.read(key: _kPhone)      ?? '';
    final em     = await _storage.read(key: _kEmail)      ?? '';
    final co     = await _storage.read(key: _kCountry)    ?? '';
    final bio    = await _storage.read(key: _kBio)        ?? '';
    final title  = await _storage.read(key: _kTitle)      ?? '';
    final avatar = await _storage.read(key: _kAvatarPath);

    // 1er lancement : initialiser prénom/nom depuis le displayName auth
    if (fn.isEmpty && ln.isEmpty) {
      final displayName = ref.read(currentUserProvider)?.displayName ?? '';
      final parts = displayName.trim().split(' ');
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName  = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      // Persister pour que le prochain lancement n'ait pas la race condition
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        await Future.wait([
          _storage.write(key: _kFirstName, value: firstName),
          _storage.write(key: _kLastName,  value: lastName),
        ]);
      }
      return ProfileExtras(
        firstName: firstName, lastName: lastName,
        gender: gen, phone: ph, email: em, country: co, bio: bio,
        title: title, avatarPath: avatar,
      );
    }

    return ProfileExtras(
      firstName: fn, lastName: ln, gender: gen,
      phone: ph, email: em, country: co, bio: bio,
      title: title, avatarPath: avatar,
    );
  }

  Future<void> updateAvatar(String filePath) async {
    final current = state.value ?? const ProfileExtras();
    final updated = current.copyWith(avatarPath: filePath);
    state = AsyncValue.data(updated);
    await _storage.write(key: _kAvatarPath, value: filePath);
    _uploadAvatarToServer(filePath);
  }

  void _uploadAvatarToServer(String filePath) {
    () async {
      try {
        final api = ref.read(apiServiceProvider);
        await api.upload<void>(
          AppConstants.uploadAvatar,
          filePath:  filePath,
          fieldName: 'avatar',
        );
      } catch (_) {}
    }();
  }

  Future<void> save(ProfileExtras extras) async {
    // Persistance locale immédiate
    await Future.wait([
      _storage.write(key: _kFirstName,  value: extras.firstName),
      _storage.write(key: _kLastName,   value: extras.lastName),
      _storage.write(key: _kGender,     value: extras.gender),
      _storage.write(key: _kPhone,      value: extras.phone),
      _storage.write(key: _kEmail,      value: extras.email),
      _storage.write(key: _kCountry,    value: extras.country),
      _storage.write(key: _kBio,        value: extras.bio),
      _storage.write(key: _kTitle,      value: extras.title),
      if (extras.avatarPath != null)
        _storage.write(key: _kAvatarPath, value: extras.avatarPath!),
      _storage.write(key: 'local_display_name', value: extras.displayName),
    ]);

    // Synchronisation API (PUT /users/me) — fire-and-forget
    _syncProfileToApi(extras);

    // Mettre à jour le displayName en mémoire dans l'état d'auth
    await ref
        .read(authStateProvider.notifier)
        .updateDisplayName(extras.displayName);

    state = AsyncValue.data(extras);
  }

  /// Envoie les données de profil au serveur ; erreurs ignorées silencieusement.
  void _syncProfileToApi(ProfileExtras extras) {
    () async {
      try {
        final api = ref.read(apiServiceProvider);
        await api.put<void>(
          AppConstants.updateProfile,
          data: {
            'display_name': extras.displayName,
            'country'     : extras.country.isNotEmpty ? extras.country : null,
            'bio'         : extras.bio.isNotEmpty     ? extras.bio     : null,
            'phone'       : extras.phone.isNotEmpty   ? extras.phone   : null,
          },
        );
      } catch (_) {}
    }();
  }
}

final profileExtrasProvider =
    AsyncNotifierProvider<ProfileExtrasNotifier, ProfileExtras>(
  ProfileExtrasNotifier.new,
);

// ── Profil complet (auth + extras + stats dynamiques) ────────────────────

final userProfileProvider = Provider<UserProfile?>((ref) {
  final user   = ref.watch(currentUserProvider);
  final extras = ref.watch(profileExtrasProvider).value;
  if (user == null) return null;

  // ── Stats dynamiques calculées à partir du feed ──────────────────────
  final allTestimonies = ref.watch(feedNotifierProvider);
  final myTestimonies  = allTestimonies
      .where((t) => t.author.uid == user.id)
      .toList();

  final testimonyCount = myTestimonies.length;
  final likeCount      = myTestimonies.fold<int>(
      0, (sum, t) => sum + t.stats.likes);
  final prayerCount    = myTestimonies.fold<int>(
      0, (sum, t) => sum + t.stats.prayers);

  // ── Champs d'identité ────────────────────────────────────────────────
  DateTime memberSince = DateTime.now();
  if (user.createdAt != null) {
    try { memberSince = DateTime.parse(user.createdAt!); } catch (_) {}
  }

  final displayName = (extras?.firstName.isNotEmpty == true || extras?.lastName.isNotEmpty == true)
      ? extras!.displayName
      : user.displayName;

  return UserProfile(
    uid:            user.id,
    displayName:    displayName,
    country:        extras?.country.isNotEmpty == true
                        ? extras!.country : user.country,
    memberSince:    memberSince,
    testimonyCount: testimonyCount,
    likeCount:      likeCount,
    prayerCount:    prayerCount,
    followersCount: 128,  // stub — à remplacer par API réelle
    followingCount: 47,   // stub — à remplacer par API réelle
    bio:            extras?.bio.isNotEmpty == true ? extras!.bio : null,
    avatarUrl:      user.avatarUrl,
    extras:         extras ?? const ProfileExtras(),
  );
});

// ── Mes témoignages ───────────────────────────────────────────────────────

final myTestimoniesProvider = Provider<List<Testimony>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref
      .watch(feedNotifierProvider)
      .where((t) => t.author.uid == user.id)
      .toList();
});

// ── Témoignages sauvegardés (stub — les plus priés pour l'instant) ────────

final savedTestimoniesProvider = Provider<List<Testimony>>((ref) {
  final all = List<Testimony>.from(ref.watch(feedNotifierProvider));
  all.sort((a, b) => b.stats.prayers.compareTo(a.stats.prayers));
  return all.take(3).toList();
});

// ═══════════════════════════════════════════════════════════════════════════
// UserSettingsNotifier
// ═══════════════════════════════════════════════════════════════════════════

class UserSettingsNotifier extends Notifier<UserSettings> {
  @override
  UserSettings build() => const UserSettings();

  void setCommentPermission(CommentPermission p) =>
      state = state.copyWith(commentPermission: p);
  void togglePushComments()  =>
      state = state.copyWith(pushComments:  !state.pushComments);
  void togglePushLikes()     =>
      state = state.copyWith(pushLikes:     !state.pushLikes);
  void togglePushPrayers()   =>
      state = state.copyWith(pushPrayers:   !state.pushPrayers);
  void togglePushApproval()  =>
      state = state.copyWith(pushApproval:  !state.pushApproval);
  void setTheme(AppTheme t)  => state = state.copyWith(appTheme: t);
}

final userSettingsProvider =
    NotifierProvider<UserSettingsNotifier, UserSettings>(
  UserSettingsNotifier.new,
);
