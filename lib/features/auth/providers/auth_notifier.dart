// lib/features/auth/providers/auth_notifier.dart
//
// Authentification par numéro de téléphone + OTP (Firebase Phone Auth)
// Flux : Téléphone → SMS OTP → Vérification → Profil (1ère fois) → Home
// Sans mot de passe — comme WhatsApp.

import 'package:dio/dio.dart' show DioException;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../../../services/fcm_service.dart';
import '../../../shared/models/models.dart';
import '../services/social_auth_service.dart';

const _kLocalDisplayName = 'local_display_name';

// Keys used to cache the authenticated user locally so session can be restored
// without a network call (e.g. on startup with no internet).
const _kCachedDisplayName = 'cached_user_display_name';
const _kCachedEmail       = 'cached_user_email';
const _kCachedAvatarUrl   = 'cached_user_avatar_url';
const _kCachedCountry     = 'cached_user_country';
const _kCachedRole        = 'cached_user_role';

// Mirror of ProfileExtrasNotifier storage keys — written here so the profile
// screen shows the correct name immediately after login and on next launch.
const _kProfileFirstName  = 'profile_first_name';
const _kProfileLastName   = 'profile_last_name';
const _kProfileEmail      = 'profile_email';
const _kProfileCountry    = 'profile_country';

// Credentials saved for transparent auto-login when the JWT expires.
// Stored in the hardware-backed secure enclave (Keychain / Android Keystore).
// Cleared only on explicit logout — never on token expiry.
const _kAutoLoginEmail    = 'auto_login_email';
const _kAutoLoginPassword = 'auto_login_password';

// ── Auth state ─────────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

/// Vérification en cours au démarrage
final class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

/// Utilisateur connecté et son profil chargé
final class AuthStateAuthenticated extends AuthState {
  const AuthStateAuthenticated(this.user);
  final UserModel user;
}

/// Non connecté — affiche l'écran téléphone
final class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

/// OTP envoyé — attend la saisie du code
final class AuthStateOtpSent extends AuthState {
  const AuthStateOtpSent({
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;
}

/// Nouvel utilisateur — doit compléter son profil (prénom, nom, pays)
final class AuthStateNeedsProfile extends AuthState {
  const AuthStateNeedsProfile({
    required this.firebaseUid,
    required this.phoneNumber,
    required this.firebaseToken,
  });
  final String firebaseUid;
  final String phoneNumber;
  final String firebaseToken;
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<AuthState> {
  late final FirebaseAuth _firebaseAuth;
  late final ApiService _api;
  late final FlutterSecureStorage _storage;
  late final SocialAuthService _social;

  @override
  Future<AuthState> build() async {
    _firebaseAuth = FirebaseAuth.instance;
    _api          = ref.read(apiServiceProvider);
    _storage      = ref.read(secureStorageProvider);
    _social       = ref.read(socialAuthServiceProvider);
    return _restoreSession();
  }

  // ── Session restoration ─────────────────────────────────────────────────────
  //
  // Stratégie stale-while-revalidate :
  //   1. Cache disponible → retourner immédiatement (pas d'attente réseau)
  //      puis rafraîchir silencieusement en arrière-plan.
  //   2. Pas de cache     → requête réseau bloquante (premier lancement).
  //
  // Avantage : même avec un timeout de 8 s ou un réseau lent, l'utilisateur
  // connecté ne voit jamais l'écran de chargement au démarrage.

  Future<AuthState> _restoreSession() async {
    final token = await _storage.read(key: AppConstants.keyAccessToken);

    // Jetons hérités des modes locaux/hors-ligne → on nettoie et on essaie
    // de se reconnecter avec les credentials sauvegardés si disponibles.
    if (token == 'local_auth' || token == 'offline_mode') {
      await _clearTokens();
      return await _tryAutoLoginWithCredentials() ?? const AuthStateUnauthenticated();
    }

    // Pas de jeton → tentative de reconnexion automatique avec les credentials
    if (token == null || token.isEmpty) {
      return await _tryAutoLoginWithCredentials() ?? const AuthStateUnauthenticated();
    }

    // ── Cas 1 : cache disponible → affichage immédiat ─────────────────────
    final cached = await _userFromCache();
    if (cached != null) {
      Future.microtask(_refreshSessionInBackground);
      return cached;
    }

    // ── Cas 2 : pas de cache → requête bloquante ──────────────────────────
    return _fetchSessionFromNetwork();
  }

  /// Rafraîchit le profil utilisateur depuis le serveur en arrière-plan.
  /// Met à jour `state` si les données ont changé ou invalide la session sur 401.
  Future<void> _refreshSessionInBackground() async {
    try {
      final response =
          await _api.get<Map<String, dynamic>>(AppConstants.authMe);
      final user = UserModel.fromJson(
          Map<String, dynamic>.from(response.data));
      await _cacheUser(user);
      if (state.value is! AuthStateAuthenticated ||
          (state.value as AuthStateAuthenticated).user != user) {
        state = AsyncValue.data(AuthStateAuthenticated(user));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // JWT expiré → reconnexion silencieuse avec les credentials sauvegardés
        final autoLogin = await _tryAutoLoginWithCredentials();
        if (autoLogin != null) {
          state = AsyncValue.data(autoLogin);
        } else {
          await _clearTokens();
          state = const AsyncValue.data(AuthStateUnauthenticated());
        }
      }
      // Timeout / réseau → garder l'état en cache, pas de déconnexion
    } catch (_) {}
  }

  /// Appel réseau bloquant utilisé uniquement quand il n'y a pas de cache.
  Future<AuthState> _fetchSessionFromNetwork() async {
    try {
      final response =
          await _api.get<Map<String, dynamic>>(AppConstants.authMe);
      debugPrint('[Auth] /auth/me keys: ${response.data.keys.toList()}');
      final user = UserModel.fromJson(
          Map<String, dynamic>.from(response.data));
      await _cacheUser(user);
      return AuthStateAuthenticated(user);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // JWT expiré → reconnexion silencieuse
        final autoLogin = await _tryAutoLoginWithCredentials();
        if (autoLogin != null) return autoLogin;
        await _clearTokens();
      }
      return const AuthStateUnauthenticated();
    } catch (_) {
      return const AuthStateUnauthenticated();
    }
  }

  /// Reconnexion silencieuse avec les credentials email/password mis en cache.
  /// Retourne null si les credentials sont absents ou invalides.
  Future<AuthState?> _tryAutoLoginWithCredentials() async {
    final email    = await _storage.read(key: _kAutoLoginEmail);
    final password = await _storage.read(key: _kAutoLoginPassword);
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    try {
      final response = await _api.post<Map<String, dynamic>>(
        AppConstants.authLogin,
        data: {'email': email, 'password': password},
      );
      return await _handleTokenResponse(response.data);
    } catch (_) {
      return null;
    }
  }

  // ── Phone OTP — Étape 1 : Envoyer le code ──────────────────────────────────

  Future<void> sendOtp({
    required String phoneNumber,
    int? resendToken,
  }) async {
    state = const AsyncValue.loading();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),

      // Android auto-detection
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _signInWithCredential(credential, phoneNumber);
      },

      verificationFailed: (FirebaseAuthException e) {
        final message = switch (e.code) {
          'invalid-phone-number'   => 'Numéro de téléphone invalide.',
          'too-many-requests'      => 'Trop de tentatives. Réessayez dans quelques minutes.',
          'quota-exceeded'         => 'Quota SMS dépassé. Réessayez plus tard.',
          _                        => 'Erreur : ${e.message ?? e.code}',
        };
        state = AsyncValue.error(message, StackTrace.current);
      },

      codeSent: (String verificationId, int? token) {
        state = AsyncValue.data(AuthStateOtpSent(
          phoneNumber: phoneNumber,
          verificationId: verificationId,
          resendToken: token,
        ));
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        // Timeout du déchiffrement automatique — l'utilisateur doit saisir manuellement
        if (state.value is AuthStateOtpSent) return;
        state = AsyncValue.data(AuthStateOtpSent(
          phoneNumber: phoneNumber,
          verificationId: verificationId,
        ));
      },
    );
  }

  // ── Phone OTP — Étape 2 : Vérifier le code ─────────────────────────────────

  Future<void> verifyOtp({
    required String verificationId,
    required String otp,
    required String phoneNumber,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      return _signInWithCredential(credential, phoneNumber);
    });
  }

  Future<AuthState> _signInWithCredential(
    PhoneAuthCredential credential,
    String phoneNumber,
  ) async {
    final userCredential =
        await _firebaseAuth.signInWithCredential(credential);
    final firebaseUser = userCredential.user!;
    final firebaseToken = await firebaseUser.getIdToken();

    // Appel Laravel : crée ou retrouve l'utilisateur
    try {
      final response = await _api.post<Map<String, dynamic>>(
        AppConstants.authPhone,
        data: {
          'firebase_token': firebaseToken,
          'phone': phoneNumber,
        },
      );

      final data = response.data;
      final isNewUser = data['is_new_user'] as bool? ?? false;

      if (isNewUser) {
        // Nouveau compte — doit compléter son profil
        return AuthStateNeedsProfile(
          firebaseUid: firebaseUser.uid,
          phoneNumber: phoneNumber,
          firebaseToken: firebaseToken!,
        );
      }

      return await _handleTokenResponse(data);
    } on LaravelApiException catch (e) {
      // Laravel n'est pas encore prêt ? Mode hors-ligne
      if (e.statusCode >= 500 || e.statusCode == 0) {
        return _offlineFallback(firebaseUser, phoneNumber, firebaseToken!);
      }
      rethrow;
    } catch (_) {
      return _offlineFallback(firebaseUser, phoneNumber, firebaseToken!);
    }
  }

  // ── Phone OTP — Étape 3 : Compléter le profil ──────────────────────────────

  Future<void> completeProfile({
    required String firebaseToken,
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String country,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _api.post<Map<String, dynamic>>(
        AppConstants.authPhone,
        data: {
          'firebase_token': firebaseToken,
          'phone': phoneNumber,
          'first_name': firstName,
          'last_name': lastName,
          'country': country,
        },
      );
      return _handleTokenResponse(response.data);
    });
  }

  // ── Mise à jour du nom d'affichage (après édition du profil) ──────────────

  Future<void> updateDisplayName(String displayName) async {
    final current = state.value;
    if (current is! AuthStateAuthenticated) return;
    final updated = current.user.copyWith(displayName: displayName);
    state = AsyncValue.data(AuthStateAuthenticated(updated));
  }

  // ── Inscription locale (prénom + nom, sans mot de passe) ───────────────────

  Future<void> registerLocally({
    required String firstName,
    required String lastName,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final displayName = '$firstName $lastName'.trim();
      await _storage.write(
          key: AppConstants.keyAccessToken, value: 'local_auth');
      await _storage.write(key: AppConstants.keyUserId, value: id);
      await _storage.write(
          key: _kLocalDisplayName, value: displayName);
      return AuthStateAuthenticated(UserModel(
        id: id,
        displayName: displayName,
        email: '',
        phone: '',
        role: UserRole.utilisateur,
        isEmailVerified: true,
        country: '',
      ));
    });
  }

  // ── Renvoyer l'OTP ──────────────────────────────────────────────────────────

  Future<void> resendOtp({
    required String phoneNumber,
    required int? resendToken,
  }) async {
    await sendOtp(phoneNumber: phoneNumber, resendToken: resendToken);
  }

  // ── Inscription email / mot de passe ──────────────────────────────────────
  //
  // Ne pas émettre AsyncValue.loading() ici : cela déclencherait une
  // redirection du router vers le splash et l'écran d'inscription disparaîtrait.
  // L'écran gère son propre indicateur de chargement (_isLoading).
  // Les exceptions sont relancées pour que le try/catch de l'écran les affiche.

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? country,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      AppConstants.authRegister,
      data: {
        'first_name':             firstName,
        'last_name':              lastName,
        'name':                   '$firstName $lastName'.trim(),
        'display_name':           '$firstName $lastName'.trim(),
        'email':                  email,
        'password':               password,
        'password_confirmation':  password,
        'country': ?country,
      },
    );
    await _saveCredentials(email, password);
    state = AsyncValue.data(await _handleTokenResponse(response.data));
  }

  // ── Email / Password login ─────────────────────────────────────────────────

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      AppConstants.authLogin,
      data: {'email': email, 'password': password},
    );
    await _saveCredentials(email, password);
    state = AsyncValue.data(await _handleTokenResponse(response.data));
  }

  // ── Social login (Google / Facebook) ───────────────────────────────────────

  Future<void> signInWithGoogle() async {
    final result = await _social.signInWithGoogle();
    final next = switch (result) {
      SocialAuthSuccess()              => await _exchangeSocialToken(result),
      SocialAuthCancelled()            => const AuthStateUnauthenticated(),
      SocialAuthError(:final message)  => throw Exception(message),
    };
    state = AsyncValue.data(next);
  }

  Future<void> signInWithFacebook() async {
    final result = await _social.signInWithFacebook();
    final next = switch (result) {
      SocialAuthSuccess()              => await _exchangeSocialToken(result),
      SocialAuthCancelled()            => const AuthStateUnauthenticated(),
      SocialAuthError(:final message)  => throw Exception(message),
    };
    state = AsyncValue.data(next);
  }

  Future<AuthState> _exchangeSocialToken(SocialAuthSuccess social) async {
    final response = await _api.post<Map<String, dynamic>>(
      AppConstants.authSocial,
      data: {
        'provider': social.provider,
        'token': social.token,
        if (social.email != null)       'email': social.email,
        if (social.displayName != null) 'name': social.displayName,
        if (social.avatarUrl != null)   'avatar_url': social.avatarUrl,
      },
    );
    return _handleTokenResponse(response.data);
  }

  // ── Logout ──────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    // Dissocier le token FCM de ce compte avant de révoquer la session.
    await ref.read(fcmServiceProvider).unregister();
    try {
      await _api.post<void>(AppConstants.authLogout);
    } catch (_) {}
    await _firebaseAuth.signOut();
    await _clearTokens();
    await _social.signOutAll();
    // Effacer les credentials sauvegardés — déconnexion volontaire.
    await Future.wait([
      _storage.delete(key: _kAutoLoginEmail),
      _storage.delete(key: _kAutoLoginPassword),
    ]);
    state = const AsyncValue.data(AuthStateUnauthenticated());
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<AuthState> _handleTokenResponse(Map<String, dynamic> data) async {
    final accessToken  = data['access_token']  as String?;
    final refreshToken = data['refresh_token'] as String?;
    final userData     = data['user']          as Map<String, dynamic>?;

    if (accessToken == null || userData == null) {
      throw Exception('Réponse serveur invalide.');
    }

    await _storage.write(key: AppConstants.keyAccessToken,  value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken);
    }

    final user = UserModel.fromJson(userData);
    await _storage.write(key: AppConstants.keyUserId, value: user.id);
    await _cacheUser(user);
    return AuthStateAuthenticated(user);
  }

  Future<void> _saveCredentials(String email, String password) async {
    await Future.wait([
      _storage.write(key: _kAutoLoginEmail,    value: email),
      _storage.write(key: _kAutoLoginPassword, value: password),
    ]);
  }

  // ── User caching (for offline session restoration) ─────────────────────────

  Future<void> _cacheUser(UserModel user) async {
    final writes = [
      _storage.write(key: _kCachedDisplayName, value: user.displayName),
      _storage.write(key: _kCachedEmail,       value: user.email),
      _storage.write(key: _kCachedCountry,     value: user.country),
      _storage.write(key: _kCachedRole,        value: user.role.toJson()),
      // Mirror into ProfileExtrasNotifier keys so the profile screen shows
      // the name immediately and on the next launch without a network call.
      _storage.write(key: _kProfileFirstName,  value: _firstPart(user.displayName)),
      _storage.write(key: _kProfileLastName,   value: _lastPart(user.displayName)),
      _storage.write(key: _kProfileEmail,      value: user.email),
      _storage.write(key: _kProfileCountry,    value: user.country),
    ];
    if (user.avatarUrl != null) {
      writes.add(_storage.write(key: _kCachedAvatarUrl, value: user.avatarUrl!));
    }
    await Future.wait(writes);
  }

  Future<AuthState?> _userFromCache() async {
    final userId      = await _storage.read(key: AppConstants.keyUserId);
    final displayName = await _storage.read(key: _kCachedDisplayName);
    if (userId == null || displayName == null || displayName.isEmpty) return null;

    return AuthStateAuthenticated(UserModel(
      id:              userId,
      displayName:     displayName,
      email:           await _storage.read(key: _kCachedEmail)   ?? '',
      country:         await _storage.read(key: _kCachedCountry) ?? '',
      avatarUrl:       await _storage.read(key: _kCachedAvatarUrl),
      role:            UserRole.fromJson(await _storage.read(key: _kCachedRole)),
      isEmailVerified: true,
    ));
  }

  static String _firstPart(String name) {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }

  static String _lastPart(String name) {
    final parts = name.trim().split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  /// Mode hors-ligne : crée un utilisateur local temporaire
  Future<AuthState> _offlineFallback(
    User firebaseUser,
    String phoneNumber,
    String firebaseToken,
  ) async {
    // Crée un utilisateur local avec les infos Firebase disponibles
    const fakeJwt = 'offline_mode';
    await _storage.write(key: AppConstants.keyAccessToken, value: fakeJwt);

    final user = UserModel(
      id: firebaseUser.uid,
      displayName: firebaseUser.displayName ?? 'Utilisateur',
      email: firebaseUser.email ?? '',
      phone: phoneNumber,
      role: UserRole.utilisateur,
      isEmailVerified: true,
      country: '',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _storage.write(key: AppConstants.keyUserId, value: user.id);
    return AuthStateAuthenticated(user);
  }

  Future<void> _clearTokens() async {
    await Future.wait([
      _storage.delete(key: AppConstants.keyAccessToken),
      _storage.delete(key: AppConstants.keyRefreshToken),
      _storage.delete(key: AppConstants.keyUserId),
      _storage.delete(key: _kCachedDisplayName),
      _storage.delete(key: _kCachedEmail),
      _storage.delete(key: _kCachedAvatarUrl),
      _storage.delete(key: _kCachedCountry),
      _storage.delete(key: _kCachedRole),
      _storage.delete(key: _kProfileFirstName),
      _storage.delete(key: _kProfileLastName),
      _storage.delete(key: _kProfileEmail),
      _storage.delete(key: _kProfileCountry),
    ]);
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final currentUserProvider = Provider<UserModel?>((ref) {
  final value = ref.watch(authStateProvider).value;
  if (value is AuthStateAuthenticated) return value.user;
  return null;
});

final isAuthenticatedProvider =
    Provider<bool>((ref) => ref.watch(currentUserProvider) != null);

final canPublishProvider = Provider<bool>(
    (ref) => ref.watch(currentUserProvider)?.canPublish ?? false);

final canModerateProvider = Provider<bool>(
    (ref) => ref.watch(currentUserProvider)?.canModerate ?? false);
