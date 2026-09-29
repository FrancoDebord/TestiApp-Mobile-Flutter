// État « Suivre » partagé par toute l'application : un seul ensemble des comptes suivis,
// chargé une fois (GET /users/me/following-ids), puis mis à jour à chaque action.
// Tous les boutons (cartes, lecteur, profil, Communauté) restent ainsi cohérents.
// Backend : docs/fonctionnalites/abonnements.md

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_service.dart' show LaravelApiException;
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/community_repository.dart';

class FollowState {
  const FollowState({this.following = const {}, this.pending = const {}, this.loaded = false});

  /// Identifiants des comptes suivis.
  final Set<String> following;

  /// Actions en cours (bouton désactivé).
  final Set<String> pending;

  /// Liste reçue du serveur.
  final bool loaded;

  bool isFollowing(String userId) => following.contains(userId);

  FollowState copyWith({Set<String>? following, Set<String>? pending, bool? loaded}) => FollowState(
        following: following ?? this.following,
        pending: pending ?? this.pending,
        loaded: loaded ?? this.loaded,
      );
}

class FollowNotifier extends Notifier<FollowState> {
  @override
  FollowState build() {
    // Nouvelle personne connectée (ou déconnexion) : liste rechargée.
    final me = ref.watch(currentUserProvider)?.id;
    if (me != null) Future.microtask(_load);
    return const FollowState();
  }

  Future<void> _load() async {
    try {
      final ids = await ref.read(communityRepositoryProvider).followingIds();
      state = state.copyWith(following: ids, loaded: true);
    } catch (_) {
      // Hors connexion : les boutons indiquent « Suivre » ; l'action reste possible.
    }
  }

  /// Prend en compte l'état renvoyé par le serveur (profil, Communauté).
  void remember(String userId, bool following) {
    if (state.isFollowing(userId) == following) return;
    final next = {...state.following};
    following ? next.add(userId) : next.remove(userId);
    state = state.copyWith(following: next);
  }

  /// Suivre / ne plus suivre, affiché tout de suite puis confirmé par le serveur
  /// (rétabli en cas d'erreur). Renvoie le nouveau nombre d'abonnés, ou lève [FollowFailure].
  Future<int?> toggle(String userId) async {
    final me = ref.read(currentUserProvider)?.id;
    if (me == null) throw const FollowFailure('Connectez-vous pour suivre ce compte.');
    if (me == userId) throw const FollowFailure('Vous ne pouvez pas vous suivre vous-même.');
    if (state.pending.contains(userId)) return null;

    final wasFollowing = state.isFollowing(userId);
    remember(userId, !wasFollowing);
    state = state.copyWith(pending: {...state.pending, userId});
    try {
      final repo = ref.read(communityRepositoryProvider);
      final result = wasFollowing ? await repo.unfollow(userId) : await repo.follow(userId);
      remember(userId, result.following);
      return result.followerCount;
    } on LaravelApiException catch (e) {
      remember(userId, wasFollowing);
      throw FollowFailure(e.message);
    } catch (_) {
      remember(userId, wasFollowing);
      throw const FollowFailure('Action impossible. Vérifiez votre connexion.');
    } finally {
      state = state.copyWith(pending: {...state.pending}..remove(userId));
    }
  }
}

class FollowFailure implements Exception {
  const FollowFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

final followProvider = NotifierProvider<FollowNotifier, FollowState>(FollowNotifier.new);
