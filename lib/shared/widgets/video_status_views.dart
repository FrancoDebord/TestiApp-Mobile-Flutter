// lib/shared/widgets/video_status_views.dart
//
// États d'une vidéo Bunny Stream dans le fil, le détail, « Mes témoignages »
// et la modération :
//   • processing : miniature (ou fond) + badge « Vidéo en cours de
//     traitement », sans bouton lecture ;
//   • failed     : « La vidéo n'a pas pu être traitée » et, pour l'auteur
//     seulement, « Renvoyer la vidéo » ;
//   • ready      : affiche habituelle, durée en bas à droite.

import 'package:flutter/material.dart';

import '../../core/media/video_source.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import 'video_poster.dart';
import '../../l10n/app_localizations.dart';

/// Pastille « Vidéo en cours de traitement ».
class VideoProcessingBadge extends StatelessWidget {
  const VideoProcessingBadge({this.compact = false, super.key});

  /// Version courte (« En traitement ») pour les petites vignettes.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: VideoStatusText.processing,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                compact ? context.l10n.mediaProcessingShort : VideoStatusText.processing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Durée sur la vignette (« 02:07 ») ; rien si elle est inconnue.
class VideoDurationBadge extends StatelessWidget {
  const VideoDurationBadge({required this.seconds, super.key});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final label = formatVideoDuration(seconds);
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppFonts.family,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Surface d'une vidéo pas encore lisible (en traitement ou en échec), à
/// placer dans un cadre 16:9. [onResend] (auteur seulement) affiche
/// « Renvoyer la vidéo » sous le message d'échec.
class VideoNotReadySurface extends StatelessWidget {
  const VideoNotReadySurface({
    required this.state,
    this.thumbnailUrl,
    this.onResend,
    this.compact = false,
    super.key,
  });

  final VideoProcessingState state;
  final String? thumbnailUrl;
  final VoidCallback? onResend;

  /// Petite vignette : textes courts, pas de bouton.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final failed = state == VideoProcessingState.failed;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Pas de miniature avant la fin de l'encodage : fond de la charte.
        VideoThumbnailImage(url: failed ? null : thumbnailUrl),
        if (failed)
          ColoredBox(
            color: AppColors.primaryDark.withValues(alpha: 0.88),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 24),
                child: compact
                    ? const Icon(Icons.error_outline_rounded,
                        color: AppColors.surface, size: 22)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.surface, size: 30),
                          const SizedBox(height: 8),
                          Text(
                            VideoStatusText.failed,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.surface),
                          ),
                          if (onResend != null) ...[
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              key: const ValueKey('resend-video-button'),
                              onPressed: onResend,
                              icon: const Icon(Icons.upload_rounded, size: 18),
                              label: Text(VideoStatusText.resend),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          )
        else ...[
          ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: VideoProcessingBadge(compact: compact),
            ),
          ),
        ],
      ],
    );
  }
}
