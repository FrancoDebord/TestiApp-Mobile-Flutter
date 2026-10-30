// Ouvrir un témoignage d'une liste, avec la liste en cours (`?list=`) et sa
// lecture lancée : vidéo → lecteur vidéo, audio → lecteur audio, écrit → page
// du témoignage. Docs serveur : fonctionnalites/listes-de-temoignages.md

import 'package:flutter/material.dart';

import '../testimony/screens/audio_player_screen.dart' show AudioPlayerScreen;
import '../testimony/screens/testimony_detail_screen.dart' show TestimonyDetailScreen;
import '../testimony/screens/video_player_screen.dart' show VideoPlayerScreen;
import 'models/playlist_models.dart';
import 'screens/playlist_screen.dart' show PlaylistScreen;

/// Page qui lit [item] dans la liste [playlistId].
Widget playlistItemPage(PlaylistItem item, String playlistId) => switch (item.type) {
      PlaylistItemType.video => VideoPlayerScreen(testimonyId: item.id, listId: playlistId),
      PlaylistItemType.audio => AudioPlayerScreen(testimonyId: item.id, listId: playlistId),
      PlaylistItemType.text => TestimonyDetailScreen(testimonyId: item.id, listId: playlistId),
    };

/// Ouvre [item] ; [replace] : remplace la page en cours (suivant, précédent,
/// choix dans le panneau du lecteur) pour ne pas empiler les épisodes.
Future<void> openPlaylistItem(
  BuildContext context,
  PlaylistItem item,
  String playlistId, {
  bool replace = false,
}) {
  final route = MaterialPageRoute<void>(builder: (_) => playlistItemPage(item, playlistId));
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement(route) : nav.push(route);
}

/// Ouvre la page d'une liste.
Future<void> openPlaylist(BuildContext context, String playlistId) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => PlaylistScreen(playlistId: playlistId)));
