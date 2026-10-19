import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/app_constants.dart';
import '../../../features/accounts/providers/acting_account_provider.dart'
    show actingAccountProvider;
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider, authStateProvider;
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../services/api_service.dart';
import '../../../shared/models/user_model.dart';
import '../models/profile_models.dart';
import '../models/user_testimony_model.dart';
import '../../../l10n/app_localizations.dart';

// ── Clés de stockage ──────────────────────────────────────────────────────

const _kFirstName   = 'profile_first_name';
const _kLastName    = 'profile_last_name';
const _kGender      = 'profile_gender';
const _kPhone       = 'profile_phone';
const _kPhoneCountry = 'profile_phone_country';
const _kEmail       = 'profile_email';
const _kCountry     = 'profile_country';
const _kBio         = 'profile_bio';
const _kTitle       = 'profile_title';
const _kAvatarPath  = 'profile_avatar_path';

/// Champs propres aux comptes organisation, envoyés dans le même
/// PUT /users/me que le reste du profil.
class OrganizationProfileUpdate {
  const OrganizationProfileUpdate({
    required this.name,
    this.type,
    this.city,
    this.website,
  });

  final String name;
  final OrganizationType? type;
  final String? city;
  final String? website;

  Map<String, dynamic> toJson() => {
        'display_name':         name,
        'organization_name':    name,
        'organization_type':    type?.toJson(),
        'organization_city':    city,
        'organization_website': website,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// ProfileExtrasNotifier — champs complémentaires persistants
// ═══════════════════════════════════════════════════════════════════════════

class ProfileExtrasNotifier extends AsyncNotifier<ProfileExtras> {
  late FlutterSecureStorage _storage;

  /// Agit pour un compte administré : ses champs viennent du serveur et ne
  /// sont pas mémorisés sur l'appareil (réservé au profil de la personne).
  bool get _actingForOther => ref.read(actingAccountProvider) != null;

  @override
  Future<ProfileExtras> build() async {
    _storage = ref.read(secureStorageProvider);
    final acting = ref.watch(actingAccountProvider);
    if (acting != null) return _fromUser(acting.asUser);
    return _load();
  }

  static ProfileExtras _fromUser(UserModel u) {
    final parts = u.displayName.trim().split(RegExp(r'\s+'));
    return ProfileExtras(
      firstName: parts.isNotEmpty ? parts.first : '',
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      country: u.country,
      bio: u.bio,
    );
  }

  Future<ProfileExtras> _load() async {
    final fn     = await _storage.read(key: _kFirstName)  ?? '';
    final ln     = await _storage.read(key: _kLastName)   ?? '';
    final gen    = await _storage.read(key: _kGender)     ?? '';
    final ph     = await _storage.read(key: _kPhone)      ?? '';
    final pc     = await _storage.read(key: _kPhoneCountry) ?? '';
    final em     = await _storage.read(key: _kEmail)      ?? '';
    // Pays et présentation : valeurs du serveur si l'appareil n'en a pas (nouvelle
    // installation, second appareil, profil modifié sur le site). Sinon l'enregistrement
    // du profil enverrait null et effacerait les valeurs du serveur.
    final me     = ref.read(currentUserProvider);
    final coLoc  = await _storage.read(key: _kCountry)    ?? '';
    final bioLoc = await _storage.read(key: _kBio)        ?? '';
    final co     = coLoc.isNotEmpty  ? coLoc  : (me?.country ?? '');
    final bio    = bioLoc.isNotEmpty ? bioLoc : (me?.bio ?? '');
    final title  = await _storage.read(key: _kTitle)      ?? '';
    final avatar = await _storage.read(key: _kAvatarPath);

    // 1er lancement, ou nom changé ailleurs (site, autre appareil) : prénom/nom
    // repris du nom du serveur, qui fait foi.
    final serverName = (me?.displayName ?? '').trim();
    final localName = '${fn.trim()} ${ln.trim()}'.trim();
    if ((fn.isEmpty && ln.isEmpty) || (serverName.isNotEmpty && serverName != localName)) {
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
        gender: gen, phone: ph, phoneCountry: pc, email: em, country: co, bio: bio,
        title: title, avatarPath: avatar,
      );
    }

    return ProfileExtras(
      firstName: fn, lastName: ln, gender: gen,
      phone: ph, phoneCountry: pc, email: em, country: co, bio: bio,
      title: title, avatarPath: avatar,
    );
  }

  Future<void> updateAvatar(String filePath) async {
    final current = state.value ?? const ProfileExtras();
    final updated = current.copyWith(avatarPath: filePath);
    state = AsyncValue.data(updated);
    if (!_actingForOther) await _storage.write(key: _kAvatarPath, value: filePath);
    _uploadAvatarToServer(filePath);
  }

  void _uploadAvatarToServer(String filePath) {
    () async {
      try {
        await uploadAvatar(filePath);
      } catch (_) {}
    }();
  }

  /// Envoie la photo / le logo (POST /users/me/avatar, champ `avatar`),
  /// mémorise le fichier local et met à jour `avatar_url` de l'utilisateur
  /// connecté. Lève une exception en cas d'échec (à gérer par l'appelant).
  Future<String?> uploadAvatar(String filePath) async {
    final api = ref.read(apiServiceProvider);
    final res = await api.upload<dynamic>(
      AppConstants.uploadAvatar,
      filePath:  filePath,
      fieldName: 'avatar',
    );
    final data = res.data;
    final url = data is Map ? data['avatar_url'] as String? : null;

    try {
      if (!_actingForOther) await _storage.write(key: _kAvatarPath, value: filePath);
    } catch (_) {}
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(avatarPath: filePath));
    }

    final user = ref.read(currentUserProvider);
    if (user != null && url != null && url.isNotEmpty) {
      await ref
          .read(authStateProvider.notifier)
          .updateCurrentUser(user.copyWith(avatarUrl: url));
    }
    return url;
  }

  /// Photo de couverture : POST /users/me/cover (champ `cover`), puis mise à
  /// jour de `cover_url` de l'utilisateur connecté. Lève [LaravelApiException]
  /// en cas d'échec (image trop petite, réseau…). Backend :
  /// docs/fonctionnalites/photo-de-couverture.md
  Future<String?> uploadCover(String filePath) async {
    final res = await ref.read(apiServiceProvider).upload<dynamic>(
          AppConstants.profileCover,
          filePath:  filePath,
          fieldName: 'cover',
        );
    final data = res.data;
    final url = data is Map ? data['cover_url'] as String? : null;
    final user = ref.read(currentUserProvider);
    if (user != null && url != null && url.isNotEmpty) {
      await ref
          .read(authStateProvider.notifier)
          .updateCurrentUser(user.copyWith(coverUrl: url));
    }
    return url;
  }

  /// Retire la photo de couverture (DELETE /users/me/cover).
  Future<void> removeCover() async {
    await ref.read(apiServiceProvider).delete<dynamic>(AppConstants.profileCover);
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref
          .read(authStateProvider.notifier)
          .updateCurrentUser(user.copyWith(clearCoverUrl: true));
    }
  }

  /// Enregistre le profil : photo choisie ([newAvatarPath], POST /users/me/avatar),
  /// puis PUT /users/me (champs organisation compris, dans la **même** requête),
  /// puis mémorisation locale. L'utilisateur connecté est mis à jour avec la
  /// réponse du serveur. Retourne `null` si tout est enregistré, sinon le
  /// message d'erreur du serveur (validation, réseau…) : rien n'est alors
  /// mémorisé, l'écran reste ouvert pour corriger et réessayer.
  Future<String?> save(
    ProfileExtras extras, {
    OrganizationProfileUpdate? organization,
    String? newAvatarPath,
  }) async {
    try {
      if (newAvatarPath != null && newAvatarPath.isNotEmpty) {
        await uploadAvatar(newAvatarPath);
      }
      final res = await _syncProfileToApi(extras, organization: organization);
      final current = ref.read(currentUserProvider);
      if (current != null) {
        final server = res.data;
        // Base : l'utilisateur renvoyé par le serveur (s'il est exploitable),
        // puis les champs organisation saisis (un serveur plus ancien peut
        // les ignorer).
        final base = server is Map<String, dynamic> && server['id'] is String
            ? server
            : {
                ...current.toJson(),
                'display_name': extras.displayName,
                'country': extras.country.isNotEmpty ? extras.country : null,
                'bio': extras.bio.isNotEmpty ? extras.bio : null,
              };
        await ref.read(authStateProvider.notifier).updateCurrentUser(
              UserModel.fromJson({
                ...base,
                if (organization != null) ...{
                  ...organization.toJson(),
                  'account_type': AccountType.organization.toJson(),
                },
              }),
            );
      }
    } on LaravelApiException catch (e) {
      debugPrint('profile save ✗ $e');
      return e.displayMessage;
    } catch (e) {
      debugPrint('profile save ✗ $e');
      return L10n.current.profileSaveFailed;
    }

    // Persistance locale (profil de la personne seulement) : champs que le
    // serveur ne garde pas (prénom/nom séparés, genre, titre, e-mail saisi).
    if (!_actingForOther) {
      await Future.wait([
        _storage.write(key: _kFirstName,  value: extras.firstName),
        _storage.write(key: _kLastName,   value: extras.lastName),
        _storage.write(key: _kGender,     value: extras.gender),
        _storage.write(key: _kPhone,      value: extras.phone),
        _storage.write(key: _kPhoneCountry, value: extras.phoneCountry),
        _storage.write(key: _kEmail,      value: extras.email),
        _storage.write(key: _kCountry,    value: extras.country),
        _storage.write(key: _kBio,        value: extras.bio),
        _storage.write(key: _kTitle,      value: extras.title),
        if (extras.avatarPath != null)
          _storage.write(key: _kAvatarPath, value: extras.avatarPath!),
        _storage.write(key: 'local_display_name', value: extras.displayName),
      ]);
    }
    state = AsyncValue.data(extras);
    return null;
  }

  /// PUT /users/me avec le profil (+ champs organisation éventuels).
  Future<LaravelResponse<dynamic>> _syncProfileToApi(
    ProfileExtras extras, {
    OrganizationProfileUpdate? organization,
  }) {
    final api = ref.read(apiServiceProvider);
    return api.put<dynamic>(
      AppConstants.updateProfile,
      data: {
        'display_name': extras.displayName,
        'country'     : extras.country.isNotEmpty ? extras.country : null,
        'bio'         : extras.bio.isNotEmpty     ? extras.bio     : null,
        // Téléphone : indicatif (code ISO) + numéro national, mis au format international
        // par le serveur. Un numéro vérifié par SMS ne se change pas ici (docs/fonctionnalites/telephone.md).
        if (ref.read(currentUserProvider)?.isPhoneVerified != true) ...{
          'phone'        : extras.phone.isNotEmpty ? extras.phone : null,
          if (extras.phoneCountry.isNotEmpty) 'phone_country': extras.phoneCountry,
        },
        ...?organization?.toJson(),
      },
    );
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
    followersCount: user.followerCount,
    followingCount: user.followingCount,
    bio:            extras?.bio.isNotEmpty == true ? extras!.bio : null,
    avatarUrl:      user.avatarUrl,
    coverUrl:       user.coverUrl,
    extras:         extras ?? const ProfileExtras(),
  );
});

// ── Mes témoignages (feed local seulement — utilisé par le profil stats) ─────

final myTestimoniesProvider = Provider<List<Testimony>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref
      .watch(feedNotifierProvider)
      .where((t) => t.author.uid == user.id)
      .toList();
});

// ── Mes témoignages complets (API, tous statuts) ──────────────────────────────

class MyTestimoniesNotifier extends AsyncNotifier<List<UserTestimony>> {
  @override
  Future<List<UserTestimony>> build() => _fetch();

  /// GET /testimonies/my : tous les témoignages de l'auteur, quel que soit leur
  /// statut (le carnet privé a sa propre liste). Pages de 50, 10 au plus.
  Future<List<UserTestimony>> _fetch() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null || userId.isEmpty) return [];
    try {
      final api = ref.read(apiServiceProvider);
      final all = <UserTestimony>[];
      for (var page = 1, last = 1; page <= last && page <= 10; page++) {
        final res = await api.get<dynamic>(AppConstants.myTestimonies, query: {'limit': 50, 'page': page});
        final data = res.data;
        if (data is List) {
          all.addAll(data.whereType<Map<String, dynamic>>().map(UserTestimony.fromJson));
        }
        last = parsePageMeta(res.meta).lastPage;
      }
      return all;
    } catch (e) {
      debugPrint('myTestimonies ✗ $e');
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<bool> deleteTestimony(String id) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.delete<void>(AppConstants.testimonyById(id));
      state = AsyncData(state.value?.where((t) => t.id != id).toList() ?? []);
      ref.read(feedNotifierProvider.notifier).removeTestimony(id);
      return true;
    } catch (e) {
      debugPrint('delete testimony ✗ $e');
      return false;
    }
  }

  /// « Modifier et renvoyer » : PUT /testimonies/{id} avec le contenu modifié. Le
  /// serveur décide du statut (refusé ou publié → en attente si la modération est
  /// active ; label « Témoignage approuvé » retiré). Renvoie le témoignage tel que
  /// le serveur l'a enregistré ; lève [LaravelApiException] en cas de refus.
  Future<UserTestimony> resubmit(String id, {required String title, required String bodyText}) async {
    final res = await ref.read(apiServiceProvider).put<Map<String, dynamic>>(
      AppConstants.testimonyById(id),
      data: {'title': title, 'body_text': bodyText},
    );
    final updated = UserTestimony.fromJson(res.data);
    state = AsyncData([
      for (final t in state.value ?? const <UserTestimony>[]) t.id == id ? updated : t,
    ]);
    // Repassé en attente : plus visible dans les fils tant qu'il n'est pas validé.
    if (updated.status != 'published') {
      ref.read(feedNotifierProvider.notifier).removeTestimony(id);
    }
    return updated;
  }
}

final myTestimoniesNotifierProvider =
    AsyncNotifierProvider<MyTestimoniesNotifier, List<UserTestimony>>(
  MyTestimoniesNotifier.new,
);

// ── Témoignages sauvegardés (GET /testimonies/saved/list) ────────────────────

class SavedTestimoniesNotifier extends AsyncNotifier<List<Testimony>> {
  @override
  Future<List<Testimony>> build() => _fetch();

  Future<List<Testimony>> _fetch() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.get<dynamic>(AppConstants.testimoniesSaved);
    final data = res.data;
    final raw = data is List
        ? data
        : (data is Map ? (data['data'] as List? ?? []) : []);
    return raw
        .map(testimonyFromApiJson)
        .whereType<Testimony>()
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final savedTestimoniesProvider =
    AsyncNotifierProvider<SavedTestimoniesNotifier, List<Testimony>>(
  SavedTestimoniesNotifier.new,
);

// ═══════════════════════════════════════════════════════════════════════════
// UserSettingsNotifier
// ═══════════════════════════════════════════════════════════════════════════

/// Réglages du compte, lus et enregistrés sur le serveur (GET / PUT
/// /users/me/settings) : le serveur s'en sert pour filtrer les push et
/// appliquer « Qui peut commenter ». Sans compte : valeurs par défaut, locales.
class UserSettingsNotifier extends Notifier<UserSettings> {
  @override
  UserSettings build() {
    final userId = ref.watch(currentUserProvider.select((u) => u?.id));
    if (userId != null) Future.microtask(_fetch);
    return const UserSettings();
  }

  Future<void> _fetch() async {
    try {
      final res =
          await ref.read(apiServiceProvider).get<dynamic>(AppConstants.updateSettings);
      if (res.data is Map) {
        state = UserSettings.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
    } catch (e) {
      debugPrint('settings load ✗ $e');
    }
  }

  /// Mise à jour immédiate de l'écran, puis envoi ; rétablit l'état précédent
  /// si le serveur refuse ou n'est pas joignable.
  Future<void> _save(UserSettings next, Map<String, dynamic> changes) async {
    final previous = state;
    state = next;
    if (ref.read(currentUserProvider) == null) return;
    try {
      await ref.read(apiServiceProvider).put<dynamic>(
            AppConstants.updateSettings, data: changes);
    } catch (e) {
      debugPrint('settings save ✗ $e');
      state = previous;
    }
  }

  Future<void> setCommentPermission(CommentPermission p) => _save(
      state.copyWith(commentPermission: p), {'comment_permission': p.toJson()});
  Future<void> togglePushComments() => _save(
      state.copyWith(pushComments: !state.pushComments),
      {'push_comments': !state.pushComments});
  Future<void> togglePushLikes() => _save(
      state.copyWith(pushLikes: !state.pushLikes),
      {'push_likes': !state.pushLikes});
  Future<void> togglePushPrayers() => _save(
      state.copyWith(pushPrayers: !state.pushPrayers),
      {'push_prayers': !state.pushPrayers});
  Future<void> togglePushApproval() => _save(
      state.copyWith(pushApproval: !state.pushApproval),
      {'push_approval': !state.pushApproval});

  /// Catégories supplémentaires ([kExtraPushCategories]).
  Future<void> togglePush(String key) {
    final next = !state.push(key);
    return _save(state.copyWith(extraPush: {...state.extraPush, key: next}), {key: next});
  }
}

final userSettingsProvider =
    NotifierProvider<UserSettingsNotifier, UserSettings>(
  UserSettingsNotifier.new,
);
