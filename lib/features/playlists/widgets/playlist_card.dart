// Carte d'une liste de témoignages (Mes listes, profil) : couverture, titre,
// nombre de témoignages.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/network/network_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../models/playlist_models.dart';

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({required this.playlist, required this.onTap, super.key});

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = playlist;
    return Material(
      key: ValueKey('playlist-card-${p.id}'),
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 112,
                  height: 63,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (p.coverUrl != null)
                        CachedNetworkImage(
                          imageUrl: p.coverUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const ColoredBox(color: AppColors.primarySoft),
                        )
                      else
                        const ColoredBox(color: AppColors.primarySoft),
                      // Bandeau du nombre, comme une pile de vidéos.
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 40,
                        child: ColoredBox(
                          color: AppColors.primaryDark.withValues(alpha: 0.78),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${p.count}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                              const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(context.l10n.playlistCount(p.count),
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Erreur d'une liste de listes : hors connexion, sinon message générique.
String playlistsLoadErrorText(Object error) =>
    isNetworkFailure(error) ? L10n.current.commonErrorNetwork : L10n.current.playlistsLoadError;
