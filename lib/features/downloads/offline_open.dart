// Ouverture d'un témoignage téléchargé, sans connexion :
//   • texte → lecteur hors ligne (texte stocké dans l'index)
//   • audio → lecteur audio sur le fichier local
//   • vidéo → lecteur vidéo sur le fichier local

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/audio_player_service.dart';
import '../home/models/testimony_model.dart';
import '../testimony/screens/audio_player_screen.dart';
import '../testimony/screens/video_player_screen.dart';
import 'models/download_models.dart';
import 'screens/offline_text_screen.dart';

Future<void> openDownloadedTestimony(
  BuildContext context,
  WidgetRef ref,
  DownloadEntry entry,
) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final t = entry.toTestimony();
  switch (t) {
    case TextTestimony():
      await nav.push(MaterialPageRoute<void>(
        builder: (_) => OfflineTextScreen(entry: entry),
      ));
    case AudioTestimony():
      // La file est préparée avant d'ouvrir le lecteur : il reconnaît le
      // témoignage en cours et ne le recherche pas en ligne.
      unawaited(ref.read(audioPlayerProvider.notifier).setTestimonyQueue([t]));
      await nav.push(MaterialPageRoute<void>(
        builder: (_) =>
            AudioPlayerScreen(testimonyId: t.id, mediaPath: entry.filePath),
      ));
    case VideoTestimony():
      await nav.push(MaterialPageRoute<void>(
        builder: (_) => VideoPlayerScreen(
          testimonyId: t.id,
          mediaPath: entry.filePath,
          testimony: t,
          playlist: [t],
        ),
      ));
  }
}
