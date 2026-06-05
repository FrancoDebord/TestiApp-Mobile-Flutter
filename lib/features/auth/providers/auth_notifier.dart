// lib/features/auth/providers/auth_notifier.dart
//
// Authentification par numéro de téléphone + OTP (Firebase Phone Auth)
// Flux : Téléphone → SMS OTP → Vérification → Profil (1ère fois) → Home
// Sans mot de passe — comme WhatsApp.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../../../shared/models/models.dart';
import '../services/social_auth_service.dart';

const _kLocalDisplayName = 'local_display_name';

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

  Future<AuthState> _restoreSession() async {
    final token = await _storage.read(key: AppConstants.keyAccessToken);
    if (token == null || token.isEmpty) return const AuthStateUnauthenticated();

    // Restaurer une session locale (inscription sans mot de passe)
    if (token == 'local_auth') {
      final userId = await _storage.read(key: AppConstants.keyUserId);
      final displayName =
          await _storage.read(key: _kLocalDisplayName) ?? 'Utilisateur';
      if (userId != null) {
        return AuthStateAuthenticated(UserModel(
          id: userId,
          displayName: displayName,
          email: '',
          phone: '',
          role: UserRole.utilisateur,
          isEmailVerified: true,
          country: '',
        ));
      }
      return const AuthStateUnauthenticated();
    }

    // Restaurer une session API (Firebase / Laravel)
    try {
      final response =
          await _api.get<Map<String, dynamic>>(AppConstants.authMe);
      final user = UserModel.fromJson(
          Map<String, dynamic>.from(response.data));
      return AuthStateAuthenticated(user);
    } catch (_) {
      await _clearTokens();
      return const AuthStateUnauthenticated();
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

  // ── Social login (Google / Facebook) ───────────────────────────────────────

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _social.signInWithGoogle();
      return switch (result) {
        SocialAuthSuccess() => await _exchangeSocialToken(result),
        SocialAuthCancelled() => const AuthStateUnauthenticated(),
        SocialAuthError(:final message) => throw Exception(message),
      };
    });
  }

  Future<void> signInWithFacebook() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _social.signInWithFacebook();
      return switch (result) {
        SocialAuthSuccess() => await _exchangeSocialToken(result),
        SocialAuthCancelled() => const AuthStateUnauthenticated(),
        SocialAuthError(:final message) => throw Exception(message),
      };
    });
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
    try {
      await _api.post<void>(AppConstants.authLogout);
    } catch (_) {}
    await _firebaseAuth.signOut();
    await _clearTokens();
    await _social.signOutAll();
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
    return AuthStateAuthenticated(user);
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
    await _storage.delete(key: AppConstants.keyAccessToken);
    await _storage.delete(key: AppConstants.keyRefreshToken);
    await _storage.delete(key: AppConstants.keyUserId);
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
