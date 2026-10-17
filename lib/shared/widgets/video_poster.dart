// lib/shared/widgets/video_poster.dart
//
// Affiche d'une vidéo : miniature (mise en cache), bouton lecture et durée.
// Utilisée à la place du lecteur sur données mobiles (pas de lecture
// automatique : rien n'est téléchargé avant le toucher), et dans les listes.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/media/video_source.dart' show mediaHttpHeaders;
import '../../l10n/app_localizations.dart';

/// « 04:05 », « 1:02:30 » (format des autres durées de l'app) ; vide si inconnue.
String formatVideoDuration(int seconds) {
  if (seconds <= 0) return '';
  final h = seconds ~/ 3600;
  final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Miniature réseau mise en cache (cached_network_image), avec repli.
class VideoThumbnailImage extends StatelessWidget {
  const VideoThumbnailImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.fallback,
    super.key,
  });

  final String? url;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final u = url;
    final placeholder = fallback ??
        const ColoredBox(
          color: AppColors.primaryDark,
          child: Center(
            child: Icon(Icons.videocam_rounded,
                color: AppColors.primaryLight, size: 36),
          ),
        );
    if (u == null || !(u.startsWith('http://') || u.startsWith('https://'))) {
      return placeholder;
    }
    return CachedNetworkImage(
      imageUrl: u,
      // Bunny Stream refuse les requêtes sans Referer.
      httpHeaders: mediaHttpHeaders(u),
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => const ColoredBox(color: AppColors.primaryDark),
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

/// Miniature + bouton lecture + durée. [onPlay] démarre la lecture.
class VideoPoster extends StatelessWidget {
  const VideoPoster({
    required this.thumbnailUrl,
    required this.onPlay,
    this.durationSeconds = 0,
    this.hint,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String? thumbnailUrl;
  final VoidCallback onPlay;
  final int durationSeconds;

  /// Petit texte sous le bouton (ex. « Données mobiles · Standard (360p) »).
  final String? hint;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final duration = formatVideoDuration(durationSeconds);
    return GestureDetector(
      onTap: onPlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          VideoThumbnailImage(url: thumbnailUrl, fit: fit),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: context.l10n.mediaPlayVideo,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Color(0x55000000), blurRadius: 12),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: AppColors.primary, size: 38),
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hint!,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (duration.isNotEmpty)
            Positioned(
              right: 10,
              bottom: 10,
              child: VideoDurationBadge(label: duration),
            ),
        ],
      ),
    );
  }
}

/// Pastille de durée sur une miniature.
class VideoDurationBadge extends StatelessWidget {
  const VideoDurationBadge({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
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
