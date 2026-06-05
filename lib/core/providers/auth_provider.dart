import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Domain model
// ---------------------------------------------------------------------------

enum UserRole { visiteur, utilisateur, moderateur, administrateur }

class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.isEmailVerified = false,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? avatarUrl;
  final bool isEmailVerified;

  bool get canPublish =>
      role == UserRole.utilisateur ||
      role == UserRole.moderateur ||
      role == UserRole.administrateur;

  bool get canModerate =>
      role == UserRole.moderateur || role == UserRole.administrateur;
}

// ---------------------------------------------------------------------------
// Auth state  (sealed class hierarchy)
// ---------------------------------------------------------------------------

sealed class AuthState {
  const AuthState();
}

final class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

final class AuthStateAuthenticated extends AuthState {
  const AuthStateAuthenticated(this.user);
  final AuthUser user;
}

final class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

// ---------------------------------------------------------------------------
// Notifier  (swap build() body with your real Hive/Dio implementation)
// ---------------------------------------------------------------------------

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // TODO: restore persisted session from Hive secure box
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return const AuthStateUnauthenticated();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      // TODO: call Dio auth repository
      await Future<void>.delayed(const Duration(seconds: 1)); // stub
      state = AsyncValue.data(
        AuthStateAuthenticated(
          AuthUser(
            uid: 'uid-stub',
            email: email,
            displayName: 'Utilisateur',
            role: UserRole.utilisateur,
            isEmailVerified: true,
          ),
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    // TODO: clear Hive box and revoke Dio token
    state = const AsyncValue.data(AuthStateUnauthenticated());
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Convenience selector — returns the signed-in user or null.
final currentUserProvider = Provider<AuthUser?>((ref) {
  final value = ref.watch(authProvider).value;
  if (value is AuthStateAuthenticated) return value.user;
  return null;
});

final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider) != null,
);
