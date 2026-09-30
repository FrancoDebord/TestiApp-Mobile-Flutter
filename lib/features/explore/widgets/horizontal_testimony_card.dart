// lib/features/explore/widgets/horizontal_testimony_card.dart
//
// Carte compacte (largeur fixe 172, hauteur fixe 220) pour les carousels.
// Hauteur fixe = header 84px + corps 136px = 220px total.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../home/models/testimony_model.dart';
import '../../home/widgets/testimony_card_header.dart'
    show AuthorAvatar, categoryBadgeTone;

// Hauteurs fixes — garantissent l'absence d'overflow dans le ListView
const double _kCardWidth  = 172;
const double _kCardHeight = 220;
const double _kHeaderHeight = 84;

class HorizontalTestimonyCard extends StatelessWidget {
  const HorizontalTestimonyCard({
    required this.testimony,
    this.statLabel,
    this.statValue,
    super.key,
  });

  final Testimony testimony;
  final String? statLabel;
  final int?    statValue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/testimony/${testimony.id}'),
      child: SizedBox(
        width: _kCardWidth,
        height: _kCardHeight,
        child: DecoratedBox(
          decoration: AppShadows.cardDecoration,
          child: ClipRRect(
            borderRadius: AppRadius.cardRadius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── En-tête (hauteur fixe) ─────────────────────────────────
                SizedBox(
                  height: _kHeaderHeight,
                  width: double.infinity,
                  child: _CardHeader(testimony: testimony),
                ),

                // ── Corps (hauteur restante) ───────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppBadge(
                          label: testimony.category.label,
                          tone: categoryBadgeTone(testimony.category),
                          dense: true,
                        ),
                        const SizedBox(height: 5),

                        // Titre : 2 lignes max, ellipsis si déborde
                        Expanded(
                          child: Text(
                            testimony.title,
                            style: TextStyle(
                              fontFamily: AppFonts.family,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 5),

                        // Auteur
                        Row(
                          children: [
                            AuthorAvatar(author: testimony.author, radius: 9),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                testimony.author.displayName,
                                style: TextStyle(
                                  fontFamily: AppFonts.family,
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // Stat principale
                        if (statValue != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                _statIcon(statLabel),
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  '${_fmt(statValue!)} ${statLabel ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.family,
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _statIcon(String? label) {
    if (label == 'prières') return Icons.volunteer_activism_outlined;
    if (label == 'vues')    return Icons.visibility_outlined;
    return Icons.favorite_border_rounded;
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── En-tête unifié (même hauteur pour tous les types) ────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.testimony});
  final Testimony testimony;

  @override
  Widget build(BuildContext context) {
    if (testimony is VideoTestimony) {
      final url = (testimony as VideoTestimony).thumbnailUrl;
      if (url.isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _GradientHeader(testimony: testimony),
            ),
            Container(
              color: Colors.black.withAlpha(38),
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: AppColors.primary, size: 24),
                ),
              ),
            ),
          ],
        );
      }
    }
    return _GradientHeader(testimony: testimony);
  }
}

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({required this.testimony});
  final Testimony testimony;

  @override
  Widget build(BuildContext context) {
    final colors = _gradientForCategory(testimony.category);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _iconForType(testimony.type),
          color: Colors.white.withAlpha(210),
          size: 28,
        ),
      ),
    );
  }

  // Dégradés de la charte (app_colors.dart).
  List<Color> _gradientForCategory(TestimonyCategory cat) => switch (cat) {
        TestimonyCategory.guerison    => AppColors.guerisonGradient,
        TestimonyCategory.delivrance  => AppColors.delivranceGradient,
        TestimonyCategory.conversion  => AppColors.conversionGradient,
        TestimonyCategory.mariage     => AppColors.mariageGradient,
        TestimonyCategory.famille     => AppColors.familleGradient,
        TestimonyCategory.finances    => AppColors.financesGradient,
        TestimonyCategory.miracles    => AppColors.miraclesGradient,
        TestimonyCategory.protection  => AppColors.protectionGradient,
        TestimonyCategory.ministere   => AppColors.ministereGradient,
        TestimonyCategory.salut       => AppColors.salutGradient,
      };

  IconData _iconForType(TestimonyType type) => switch (type) {
        TestimonyType.audio => Icons.mic_rounded,
        TestimonyType.video => Icons.videocam_rounded,
        _                   => Icons.edit_note_rounded,
      };
}
