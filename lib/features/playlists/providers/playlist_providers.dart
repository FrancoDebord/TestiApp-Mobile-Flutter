// Listes de témoignages : état partagé par les écrans.
// Docs serveur : fonctionnalites/listes-de-temoignages.md

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/playlist_api.dart';
import '../models/playlist_models.dart';

/// Mes listes (vide pour un visiteur). Rechargé après chaque modification.
final myPlaylistsProvider = FutureProvider.autoDispose<List<Playlist>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const [];
  return ref.watch(playlistApiProvider).mine();
});

/// Listes d'un compte (profil).
final userPlaylistsProvider = FutureProvider.autoDispose.family<List<Playlist>, String>(
  (ref, userId) => ref.watch(playlistApiProvider).ofUser(userId),
);

/// Une liste et ses témoignages.
final playlistProvider = FutureProvider.autoDispose.family<Playlist, String>(
  (ref, id) => ref.watch(playlistApiProvider).show(id),
);

/// Témoignage lu et liste d'où l'on vient (`?list=`).
typedef PlaylistContextKey = ({String testimonyId, String? listId});

/// Liste en cours pendant la lecture d'un témoignage ; null hors liste ou si
/// elle n'a pas pu être lue (le panneau n'est alors pas affiché).
final playlistContextProvider = FutureProvider.autoDispose.family<PlaylistContext?, PlaylistContextKey>(
  (ref, key) async {
    try {
      return await ref.watch(playlistApiProvider).contextOf(key.testimonyId, listId: key.listId);
    } catch (e) {
      debugPrint('PlaylistContext ✗ $e');
      return null;
    }
  },
);

/// Recharge les listes après une modification (mes listes, profil, liste
/// ouverte, panneaux des lecteurs). [invalidate] : `ref.invalidate`.
void refreshPlaylists(
  void Function(ProviderOrFamily provider) invalidate, {
  String? playlistId,
  String? ownerId,
}) {
  invalidate(myPlaylistsProvider);
  if (playlistId != null) invalidate(playlistProvider(playlistId));
  if (ownerId != null) invalidate(userPlaylistsProvider(ownerId));
  invalidate(playlistContextProvider);
}

// ── Lecture automatique de la liste ───────────────────────────────────────────

/// « Lecture auto de la liste » : activée par défaut, mémorisée sur le
/// téléphone à part de la lecture auto ordinaire (couper l'une ne coupe pas
/// l'autre, comme `playlistAutoplay` sur le site).
class PlaylistAutoplayNotifier extends Notifier<bool> {
  static const storageKey = 'playlist_autoplay';

  @override
  bool build() {
    Future.microtask(_load);
    return true;
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getBool(storageKey);
      if (v != null && ref.mounted) state = v;
    } catch (_) {}
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(storageKey, value);
    } catch (_) {}
  }

  Future<void> toggle() => set(!state);
}

final playlistAutoplayProvider = NotifierProvider<PlaylistAutoplayNotifier, bool>(PlaylistAutoplayNotifier.new);
