// lib/features/publish/upload/video_resend.dart
//
// « Renvoyer la vidéo » (auteur d'un témoignage dont l'encodage a échoué).
//
// Le serveur ne permet pas de rattacher une nouvelle vidéo à un témoignage
// existant : POST /videos/upload-init crée toujours le témoignage. On relance
// donc le flux d'envoi habituel (upload-init → TUS → upload-complete) avec les
// mêmes champs, puis le témoignage en échec est supprimé une fois le nouvel
// envoi terminé (VideoUploadController, replacesTestimonyId). Les preuves
// privées restent sur le serveur avec l'ancien témoignage : elles ne sont pas
// recopiées.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_constants.dart';
import '../../../core/media/video_source.dart' show VideoStatusText;
import '../../../core/router/app_routes.dart' show AppPaths;
import '../../../services/api_service.dart' show apiServiceProvider;
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../screens/video_camera_screen.dart';
import 'video_upload_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Corps de POST /videos/upload-init reconstruit depuis la ressource d'un
/// témoignage (GET /testimonies/{id}). Champs absents ou null ignorés.
Map<String, dynamic> resendBodyFromTestimonyJson(Map<String, dynamic> m) {
  String? str(List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  final cat = m['category'];
  final category = cat is Map
      ? (cat['slug'] ?? cat['name'])?.toString()
      : cat?.toString();
  final mentions = m['mentions'];
  final mentionIds = mentions is List
      ? [
          for (final x in mentions)
            if (x is Map && x['id'] != null) x['id'].toString(),
        ]
      : const <String>[];
  final proofsPublic = m['proofsPublic'] ?? m['proofs_public'];
  final eventId = m['eventId'] ?? m['event_id'];

  return {
    'title': str(['title']) ?? '',
    'type': 'video',
    if (category != null && category.isNotEmpty) 'category': category,
    'body_text': ?str(['bodyText', 'body_text']),
    'bible_verse': ?str(['bibleVerse', 'bible_verse']),
    'verse_ref': ?str(['verseReference', 'verse_reference']),
    if (mentionIds.isNotEmpty) 'mention_ids': mentionIds,
    if (eventId != null && '$eventId'.isNotEmpty) 'event_id': '$eventId',
    if (proofsPublic is bool) 'proofs_public': proofsPublic,
    'visibility': str(['visibility']) ?? 'public',
    // Référencement (docs serveur referencement.md) : accord, anonymat, textes.
    if (m['publicationWeb'] is bool) 'publicationWeb': m['publicationWeb'],
    if (m['isAnonymous'] is bool) 'isAnonymous': m['isAnonymous'],
    'resume': ?str(['resume']),
    'transcription': ?str(['transcription']),
  };
}

/// « Renvoyer la vidéo » proposé seulement à l'auteur du témoignage.
VoidCallback? resendVideoAction(
  BuildContext context,
  WidgetRef ref, {
  required String testimonyId,
  required String authorId,
}) {
  final me = ref.watch(currentUserProvider)?.id;
  if (me == null || me.isEmpty || me != authorId) return null;
  return () => resendFailedVideo(context, ref, testimonyId);
}

/// Choix d'une vidéo (galerie ou caméra), puis nouvel envoi avec les champs
/// du témoignage en échec. Ouvre l'écran de suivi de l'envoi.
Future<void> resendFailedVideo(
  BuildContext context,
  WidgetRef ref,
  String testimonyId,
) async {
  void snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  final upload = ref.read(videoUploadProvider.notifier);
  if (upload.hasPendingJob) {
    snack(context.l10n.uploadResendBusy);
    return;
  }

  final source = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(VideoStatusText.resend,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(ctx.l10n.uploadResendHint),
          ),
          ListTile(
            leading: const Icon(Icons.video_library_outlined),
            title: Text(ctx.l10n.uploadResendGallery),
            onTap: () => Navigator.of(ctx).pop('gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text(ctx.l10n.journalNewFilm),
            onTap: () => Navigator.of(ctx).pop('camera'),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  String? path;
  if (source == 'camera') {
    path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const VideoCameraScreen(),
      ),
    );
  } else {
    path = (await ImagePicker().pickVideo(source: ImageSource.gallery))?.path;
  }
  if (path == null || !context.mounted) return;

  final Map<String, dynamic> body;
  try {
    final res = await ref
        .read(apiServiceProvider)
        .get<Map<String, dynamic>>(AppConstants.testimonyById(testimonyId));
    body = resendBodyFromTestimonyJson(res.data);
  } catch (_) {
    if (context.mounted) {
      snack(context.l10n.uploadResendFetchFailed);
    }
    return;
  }
  try {
    await upload.start(
      sourcePath: path,
      title: body['title'] as String,
      body: body,
      replacesTestimonyId: testimonyId,
    );
  } on StateError {
    if (context.mounted) snack(context.l10n.uploadResendAlreadyUploading);
    return;
  }
  if (context.mounted) context.push(AppPaths.videoUploadPath);
}
