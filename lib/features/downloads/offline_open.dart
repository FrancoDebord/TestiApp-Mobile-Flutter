// Ouverture d'un témoignage téléchargé, sans connexion :
//   • texte → lecteur hors ligne (texte stocké dans l'index)
//   • audio → lecteur audio sur le fichier local
//   • vidéo → lecteur vidéo sur le fichier local

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/audio_player_service.dart';
import '../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../home/models/testimony_model.dart';
import '../home/providers/home_providers.dart' show testimonyFromApiJson;
import '../profile/models/user_testimony_model.dart';
import '../profile/providers/profile_provider.dart' show offlineTestimoniesStoreProvider;
import '../../l10n/app_localizations.dart';
import 'providers/downloads_provider.dart';
import '../testimony/screens/audio_player_screen.dart';
import '../testimony/screens/video_player_screen.dart';
import 'screens/offline_text_screen.dart';

/// Un de mes témoignages, sans connexion : téléchargé → lecteur sur le fichier ;
/// sinon la copie gardée dans la base du téléphone (texte, description ou
/// transcription ; le média demande un téléchargement). Renvoie faux si le
/// témoignage n'est pas sur le téléphone.
Future<bool> openMyTestimonyOffline(BuildContext context, WidgetRef ref, String id) async {
  final downloaded = ref.read(downloadsProvider).entries[id];
  if (downloaded != null) {
    await openDownloadedTestimony(context, ref, downloaded);
    return true;
  }
  final uid = ref.read(currentUserProvider)?.id;
  if (uid == null) return false;
  final stored = await ref.read(offlineTestimoniesStoreProvider).mineById(uid, id);
  final t = stored == null ? null : testimonyFromApiJson(stored.json);
  if (stored == null || t == null || !context.mounted) return false;
  final base = DownloadEntry.fromTestimony(t);
  final full = UserTestimony.fromJson(stored.json).bodyText;
  final entry = DownloadEntry(
    id: base.id,
    type: TestimonyType.text, // lecture du texte seulement : pas de fichier média
    title: base.title,
    authorUid: base.authorUid,
    authorName: base.authorName,
    authorAvatarUrl: base.authorAvatarUrl,
    category: base.category,
    createdAt: base.createdAt,
    bibleVerse: base.bibleVerse,
    bibleVerseRef: base.bibleVerseRef,
    textBody: full.trim().isNotEmpty ? full : base.textBody,
    downloadedAt: stored.savedAt,
  );
  if (t.type != TestimonyType.text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(context.l10n.offlineMineMediaHint),
    ));
  }
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    builder: (_) => OfflineTextScreen(entry: entry),
  ));
  return true;
}

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
