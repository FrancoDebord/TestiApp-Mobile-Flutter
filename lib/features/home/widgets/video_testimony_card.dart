import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart' show VideoPlayerController;

import '../../../core/theme/app_colors.dart';
import '../../../core/media/playback_preferences.dart'
    show isMeteredConnectionProvider;
import '../../../shared/widgets/video_poster.dart' show VideoThumbnailImage;
import '../../../shared/widgets/video_status_views.dart';
import '../../publish/upload/video_resend.dart' show resendVideoAction;
import '../../testimony/providers/testimony_refresh.dart' show LatestTestimony;
import '../../../shared/widgets/youtube_video_player.dart' show YouTubeBadge;
import '../models/testimony_model.dart';
import 'compact_testimony_tile.dart' show openVideoTestimony;
import 'feed_card_frame.dart';
import '../../../core/media/video_source.dart' show networkVideoController;

class VideoTestimonyCard extends ConsumerWidget {
  const VideoTestimonyCard({required this.testimony, super.key});

  final VideoTestimony testimony;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Version rechargée après video_ready / video_failed, si elle existe.
    final testimony = ref.latest(this.testimony);
    // Shorts dans l'ordre des vidéos du fil (lecteur YouTube pour un lien YouTube).
    void onPlayTap() => openVideoTestimony(context, ref, testimony);

    final verse = testimony.bibleVerse?.trim() ?? '';

    return FeedCardFrame(
      testimony: testimony,
      media: testimony.isReady
          ? _VideoThumbnail(testimony: testimony, onPlayTap: onPlayTap)
          // En traitement : badge, pas de lecture. En échec : message et,
          // pour l'auteur, « Renvoyer la vidéo ».
          : AspectRatio(
              aspectRatio: 16 / 9,
              child: VideoNotReadySurface(
                state: testimony.processingState,
                thumbnailUrl: testimony.thumbnailUrl,
                onResend: testimony.isFailed
                    ? resendVideoAction(context, ref,
                        testimonyId: testimony.id,
                        authorId: testimony.author.uid)
                    : null,
              ),
            ),
      preview: verse.isEmpty
          ? null
          : Text(
              '« $verse »',
              style: feedPreviewStyle(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

// ── Thumbnail ─────────────────────────────────────────────────────────────────

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.testimony, required this.onPlayTap});
  final VideoTestimony testimony;
  final VoidCallback onPlayTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Miniature Bunny (thumbnail_url), YouTube ou couverture, en cache.
            VideoThumbnailImage(
              url: testimony.thumbnailUrl,
              fallback: Container(
                color: AppColors.primarySoft,
                child: const Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withAlpha(70)],
                ),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: onPlayTap,
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primaryDark.withAlpha(60),
                          blurRadius: 12),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8, right: 8,
              // YouTube : badge au lieu de la durée (aucun fichier à sonder).
              child: testimony.isYouTube
                  ? const YouTubeBadge()
                  : _SmartDurationBadge(testimony: testimony),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartDurationBadge extends ConsumerStatefulWidget {
  const _SmartDurationBadge({required this.testimony});
  final VideoTestimony testimony;

  @override
  ConsumerState<_SmartDurationBadge> createState() => _SmartDurationBadgeState();
}

class _SmartDurationBadgeState extends ConsumerState<_SmartDurationBadge> {
  late int _secs;

  @override
  void initState() {
    super.initState();
    _secs = widget.testimony.durationSeconds;
    // Durée inconnue d'une ancienne vidéo : sondée en Wi-Fi seulement.
    final metered = ref.read(isMeteredConnectionProvider).value ?? true;
    if (_secs == 0 && !metered && widget.testimony.hlsUrl == null) {
      _loadDuration();
    }
  }

  Future<void> _loadDuration() async {
    // Économie de données : la version la plus légère suffit pour connaître la durée.
    final renditions = widget.testimony.renditions;
    final path = renditions.isNotEmpty
        ? renditions.first.url
        : widget.testimony.mp4Url ?? widget.testimony.mediaPath;
    if (path == null || path.isEmpty) return;
    try {
      final ctrl = path.startsWith('http')
          ? networkVideoController(path)
          : VideoPlayerController.file(File(path));
      await ctrl.initialize();
      final secs = ctrl.value.duration.inSeconds;
      ctrl.dispose();
      if (mounted && secs > 0) setState(() => _secs = secs);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(_SmartDurationBadge old) {
    super.didUpdateWidget(old);
    // Durée connue après rechargement (vidéo devenue prête).
    if (widget.testimony.durationSeconds > 0) {
      _secs = widget.testimony.durationSeconds;
    }
  }

  @override
  Widget build(BuildContext context) => VideoDurationBadge(seconds: _secs);
}
