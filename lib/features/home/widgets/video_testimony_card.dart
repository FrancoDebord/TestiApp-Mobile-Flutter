import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart' show VideoPlayerController;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/youtube_video_player.dart' show YouTubeBadge;
import '../models/testimony_model.dart';
import 'compact_testimony_tile.dart' show openVideoTestimony;
import 'feed_card_frame.dart';

class VideoTestimonyCard extends ConsumerWidget {
  const VideoTestimonyCard({required this.testimony, super.key});

  final VideoTestimony testimony;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Shorts dans l'ordre des vidéos du fil (lecteur YouTube pour un lien YouTube).
    void onPlayTap() => openVideoTestimony(context, ref, testimony);

    final verse = testimony.bibleVerse?.trim() ?? '';

    return FeedCardFrame(
      testimony: testimony,
      media: _VideoThumbnail(testimony: testimony, onPlayTap: onPlayTap),
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
            Image.network(
              // Miniature YouTube (coverUrl) ou couverture du serveur.
              testimony.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
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

class _SmartDurationBadge extends StatefulWidget {
  const _SmartDurationBadge({required this.testimony});
  final VideoTestimony testimony;

  @override
  State<_SmartDurationBadge> createState() => _SmartDurationBadgeState();
}

class _SmartDurationBadgeState extends State<_SmartDurationBadge> {
  late int _secs;

  @override
  void initState() {
    super.initState();
    _secs = widget.testimony.durationSeconds;
    if (_secs == 0) _loadDuration();
  }

  Future<void> _loadDuration() async {
    // Économie de données : la version la plus légère suffit pour connaître la durée.
    final renditions = widget.testimony.renditions;
    final path = renditions.isNotEmpty ? renditions.first.url : widget.testimony.mediaPath;
    if (path == null || path.isEmpty) return;
    try {
      final ctrl = path.startsWith('http')
          ? VideoPlayerController.networkUrl(Uri.parse(path))
          : VideoPlayerController.file(File(path));
      await ctrl.initialize();
      final secs = ctrl.value.duration.inSeconds;
      ctrl.dispose();
      if (mounted && secs > 0) setState(() => _secs = secs);
    } catch (_) {}
  }

  static String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        _fmt(_secs),
        style: TextStyle(
          fontFamily: AppFonts.family,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
