import 'dart:io';

import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  final String message;
}

// ── Service ───────────────────────────────────────────────────────────────────

class SocialAuthService {
  SocialAuthService._();
  static final SocialAuthService instance = SocialAuthService._();

  static const _iosClientId =
      '78564751626-tfc6p4rvivn2pt2hfanpvar336a8nud6.apps.googleusercontent.com';

  // Web Client ID (auto-créé par Firebase quand Google Sign-In est activé).
  // Retrouvez-le dans google-services.json → oauth_client → client_type: 3
  // ou dans Google Cloud Console → APIs & Services → Credentials.
  static const _webClientId =
      ''; // ← collez ici votre Web Client ID

  final _googleSignIn = GoogleSignIn(
    clientId: Platform.isIOS ? _iosClientId : null,
    serverClientId: _webClientId.isEmpty ? null : _webClientId,
    scopes: ['email', 'profile'],
  );

  // ── Google ─────────────────────────────────────────────────────────────────

  Future<SocialAuthResult> signInWithGoogle() async {
    try {
      // Sign out first to force account picker on every call.
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) return const SocialAuthCancelled();

      final auth    = await account.authentication;
      final token   = auth.idToken ?? auth.accessToken;
      if (token == null) {
        return const SocialAuthError(
            'Impossible de récupérer le token Google. '
            'Vérifiez que Google Sign-In est activé dans Firebase Console '
            'et que le Web Client ID est configuré.');
      }

      return SocialAuthSuccess(
        provider: 'google',
        token: token,
        email: account.email,
        displayName: account.displayName,
        avatarUrl: account.photoUrl,
      );
    } catch (e) {
      return SocialAuthError(e.toString());
    }
  }

  Future<void> signOutGoogle() async {
    await _googleSignIn.signOut();
  }

  // ── Facebook ───────────────────────────────────────────────────────────────

  Future<SocialAuthResult> signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.cancelled) {
        return const SocialAuthCancelled();
      }

      if (result.status != LoginStatus.success || result.accessToken == null) {
        return SocialAuthError(
            result.message ?? 'Connexion Facebook échouée.');
      }

      final token = result.accessToken!.tokenString;

      // Fetch user data from Facebook Graph API.
      final userData = await FacebookAuth.instance.getUserData(
        fields: 'email,name,picture.width(200)',
      );

      return SocialAuthSuccess(
        provider: 'facebook',
        token: token,
        email: userData['email'] as String?,
        displayName: userData['name'] as String?,
        avatarUrl: (userData['picture']?['data']?['url']) as String?,
      );
    } catch (e) {
      return SocialAuthError(e.toString());
    }
  }

  Future<void> signOutFacebook() async {
    await FacebookAuth.instance.logOut();
  }

  // ── Sign out all ───────────────────────────────────────────────────────────

  Future<void> signOutAll() async {
    await signOutGoogle();
    await signOutFacebook();
  }
}

final socialAuthServiceProvider = Provider<SocialAuthService>(
  (_) => SocialAuthService.instance,
);
