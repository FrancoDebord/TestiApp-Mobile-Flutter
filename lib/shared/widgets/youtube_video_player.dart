// lib/shared/widgets/youtube_video_player.dart
//
// Lecteur des témoignages publiés par lien YouTube (youtubeId dans l'API).
// Remplace video_player/chewie : pas de sélection de qualité (gérée par YouTube).

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class YouTubeVideoPlayer extends StatefulWidget {
  const YouTubeVideoPlayer({
    super.key,
    required this.videoId,
    this.autoPlay = true,
    this.aspectRatio = 16 / 9,
  });

  final String videoId;
  final bool autoPlay;
  final double aspectRatio;

  @override
  State<YouTubeVideoPlayer> createState() => _YouTubeVideoPlayerState();
}

class _YouTubeVideoPlayerState extends State<YouTubeVideoPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _create(widget.videoId);
  }

  YoutubePlayerController _create(String id) =>
      YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: widget.autoPlay,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          strictRelatedVideos: true,
          interfaceLanguage: 'fr',
          captionLanguage: 'fr',
          // youtube-nocookie.com
          privacyEnhancedMode: true,
        ),
      );

  @override
  void didUpdateWidget(covariant YouTubeVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      final old = _controller;
      _controller = _create(widget.videoId);
      old.close();
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      key: ValueKey(widget.videoId),
      controller: _controller,
      aspectRatio: widget.aspectRatio,
      backgroundColor: Colors.black,
    );
  }
}

/// Petit badge « YouTube » posé sur les miniatures (cartes du fil, listes).
class YouTubeBadge extends StatelessWidget {
  const YouTubeBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(170),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_display_rounded,
            size: compact ? 11 : 13,
            color: AppColors.surface,
          ),
          const SizedBox(width: 3),
          Text(
            'YouTube',
            style: TextStyle(
              color: AppColors.surface,
              fontFamily: AppFonts.family,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
