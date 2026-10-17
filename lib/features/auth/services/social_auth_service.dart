import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb;

// Connexion Facebook désactivée (retirée de l'application) :
// import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart' show LaravelApiException;
import '../../../l10n/app_localizations.dart';

/// Result of a social authentication attempt.
sealed class SocialAuthResult {
  const SocialAuthResult();
}

final class SocialAuthSuccess extends SocialAuthResult {
  const SocialAuthSuccess({
    required this.provider,
    required this.token,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  final String provider;   // 'google' | 'facebook'
  final String token;      // ID token (Google) or access token (Facebook)
  final String? email;
  final String? displayName;
  final String? avatarUrl;
}

final class SocialAuthCancelled extends SocialAuthResult {
  const SocialAuthCancelled();
}

final class SocialAuthError extends SocialAuthResult {
  const SocialAuthError(this.message);

  /// Message clair pour l'utilisateur (le détail technique est journalisé en debug).
  final String message;
}

/// Échec de la connexion Google côté appareil (le message s'affiche tel quel).
class GoogleSignInFailure implements Exception {
  const GoogleSignInFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Message à afficher (SnackBar) après l'échec d'une connexion Google : erreur du SDK
/// ([GoogleSignInFailure]) ou réponse de l'API (401 jeton refusé, 403 compte banni, 5xx…).
/// Le détail technique est journalisé en mode debug.
String googleSignInErrorMessage(Object error, [StackTrace? stack]) {
  if (kDebugMode) debugPrint('Connexion Google ✗ $error${stack != null ? '\n$stack' : ''}');
  return switch (error) {
    GoogleSignInFailure(:final message) => message,
    LaravelApiException(statusCode: 401) => L10n.current.authGoogleIdentityRejected,
    LaravelApiException(statusCode: 403, :final message) =>
      message.isNotEmpty ? message : L10n.current.authAccountCannotSignIn,
    LaravelApiException(:final statusCode) when statusCode >= 500 =>
      L10n.current.authServerUnavailable,
    LaravelApiException(statusCode: 0) => L10n.current.authNoInternet,
    LaravelApiException(:final message) when message.isNotEmpty => message,
    _ => L10n.current.authGoogleFailed,
  };
}

// ── Service ───────────────────────────────────────────────────────────────────

class SocialAuthService {
  SocialAuthService._();
  static final SocialAuthService instance = SocialAuthService._();

  // ── Google (google_sign_in 7.x) ──────────────────────────────────────────

  /// `initialize()` ne doit être appelé qu'une fois : la même opération est réutilisée,
  /// et relancée seulement si elle a échoué.
  Future<void>? _googleInit;

  Future<void> _ensureGoogleInitialized() {
    return _googleInit ??= GoogleSignIn.instance
        .initialize(
          // dart:io Platform lève une exception sur le web → defaultTargetPlatform.
          clientId: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
              ? AppConstants.googleIosClientId
              : null,
          // Identifiant client Web : l'idToken est émis pour lui (vérifié par l'API).
          serverClientId: AppConstants.googleServerClientId,
        )
        .catchError((Object e) {
      _googleInit = null;
      throw e;
    });
  }

  /// Choix du compte Google puis jeton d'identité (idToken) à envoyer à POST /auth/google.
  Future<SocialAuthResult> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return SocialAuthError(L10n.current.authGoogleUnavailable);
      }

      final account = await GoogleSignIn.instance
          .authenticate(scopeHint: const ['email', 'profile']);
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (kDebugMode) {
          debugPrint('Connexion Google ✗ idToken absent : vérifiez serverClientId '
              '(${AppConstants.googleServerClientId}) et l’empreinte SHA-1 dans Firebase.'); // i18n-ignore
        }
        return SocialAuthError(L10n.current.authGoogleFailed);
      }

      return SocialAuthSuccess(
        provider: 'google',
        token: idToken,
        email: account.email,
        displayName: account.displayName,
        avatarUrl: account.photoUrl,
      );
    } on GoogleSignInException catch (e, stack) {
      // Fenêtre fermée par l'utilisateur : rien à afficher.
      if (e.code == GoogleSignInExceptionCode.canceled) return const SocialAuthCancelled();
      if (kDebugMode) {
        debugPrint('Connexion Google ✗ ${e.code.name} : ${e.description} ${e.details ?? ''}\n$stack');
      }
      return SocialAuthError(switch (e.code) {
        GoogleSignInExceptionCode.interrupted => L10n.current.authGoogleInterrupted,
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          L10n.current.authGoogleMisconfigured,
        GoogleSignInExceptionCode.uiUnavailable => L10n.current.authGoogleUiUnavailable,
        _ => L10n.current.authGoogleFailed,
      });
    } catch (e, stack) {
      if (kDebugMode) debugPrint('Connexion Google ✗ $e\n$stack');
      return SocialAuthError(L10n.current.authGoogleFailed);
    }
  }

  /// Déconnexion Google (le prochain « Continuer avec Google » repropose le choix du compte).
  Future<void> signOutGoogle() async {
    try {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('Déconnexion Google ✗ $e');
    }
  }

  // Connexion Facebook désactivée (retirée de l'application) : à réactiver si besoin.
  // // ── Facebook ───────────────────────────────────────────────────────────────

  // Future<SocialAuthResult> signInWithFacebook() async {
  //   try {
  //     final result = await FacebookAuth.instance.login(
  //       permissions: ['email', 'public_profile'],
  //     );

  //     if (result.status == LoginStatus.cancelled) {
  //       return const SocialAuthCancelled();
  //     }

  //     if (result.status != LoginStatus.success || result.accessToken == null) {
  //       return SocialAuthError(
  //           result.message ?? 'Connexion Facebook échouée.');
  //     }

  //     final token = result.accessToken!.tokenString;

  //     // Fetch user data from Facebook Graph API.
  //     final userData = await FacebookAuth.instance.getUserData(
  //       fields: 'email,name,picture.width(200)',
  //     );

  //     return SocialAuthSuccess(
  //       provider: 'facebook',
  //       token: token,
  //       email: userData['email'] as String?,
  //       displayName: userData['name'] as String?,
  //       avatarUrl: (userData['picture']?['data']?['url']) as String?,
  //     );
  //   } catch (e) {
  //     return SocialAuthError(e.toString());
  //   }
  // }

  // Future<void> signOutFacebook() async {
  //   await FacebookAuth.instance.logOut();
  // }

  // ── Sign out all ───────────────────────────────────────────────────────────

  /// Jamais bloquant : un échec côté Google n'empêche pas la déconnexion.
  Future<void> signOutAll() async {
    await signOutGoogle();
    // Connexion Facebook désactivée (retirée de l'application) :
    // try {
    //   await signOutFacebook();
    // } catch (e) {
    //   if (kDebugMode) debugPrint('Déconnexion Facebook ✗ $e');
    // }
  }
}

final socialAuthServiceProvider = Provider<SocialAuthService>(
  (_) => SocialAuthService.instance,
);
