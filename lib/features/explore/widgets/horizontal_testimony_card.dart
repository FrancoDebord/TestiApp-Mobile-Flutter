// lib/features/explore/widgets/horizontal_testimony_card.dart
//
// Carte compacte (largeur fixe 172, hauteur fixe 220) pour les carousels.
// Hauteur fixe = header 84px + corps 136px = 220px total.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../home/models/testimony_model.dart';

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
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
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
                        _CategoryBadge(category: testimony.category),
                        const SizedBox(height: 5),

                        // Titre : 2 lignes max, ellipsis si déborde
                        Expanded(
                          child: Text(
                            testimony.title,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
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
                            CircleAvatar(
                              radius: 9,
                              backgroundColor: AppColors.primary.withAlpha(30),
                              child: Text(
                                testimony.author.displayName.isNotEmpty
                                    ? testimony.author.displayName[0]
                                        .toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                testimony.author.displayName,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
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
                                color: AppColors.primary.withAlpha(190),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${_fmt(statValue!)} ${statLabel ?? ''}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
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
              child: const Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 28),
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

  List<Color> _gradientForCategory(TestimonyCategory cat) => switch (cat) {
        TestimonyCategory.guerison    => [const Color(0xFF6B21A8), const Color(0xFFA855F7)],
        TestimonyCategory.delivrance  => [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
        TestimonyCategory.conversion  => [const Color(0xFF065F46), const Color(0xFF10B981)],
        TestimonyCategory.mariage     => [const Color(0xFF9D174D), const Color(0xFFF43F5E)],
        TestimonyCategory.famille     => [const Color(0xFF92400E), const Color(0xFFF59E0B)],
        TestimonyCategory.finances    => [const Color(0xFF14532D), const Color(0xFF22C55E)],
        TestimonyCategory.miracles    => [const Color(0xFF7C2D12), const Color(0xFFF97316)],
        TestimonyCategory.protection  => [const Color(0xFF1E3A5F), const Color(0xFF0EA5E9)],
        TestimonyCategory.ministere   => [const Color(0xFF4A1D96), const Color(0xFF8B5CF6)],
        TestimonyCategory.salut       => [const Color(0xFF7F1D1D), const Color(0xFFEF4444)],
      };

  IconData _iconForType(TestimonyType type) => switch (type) {
        TestimonyType.audio => Icons.mic_rounded,
        TestimonyType.video => Icons.videocam_rounded,
        _                   => Icons.edit_note_rounded,
      };
}

// ── Badge catégorie ────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final TestimonyCategory category;

  static const _colors = <TestimonyCategory, Color>{
    TestimonyCategory.guerison:   Color(0xFF6B21A8),
    TestimonyCategory.delivrance: Color(0xFF1E3A8A),
    TestimonyCategory.conversion: Color(0xFF065F46),
    TestimonyCategory.mariage:    Color(0xFF9D174D),
    TestimonyCategory.famille:    Color(0xFF92400E),
    TestimonyCategory.finances:   Color(0xFF14532D),
    TestimonyCategory.miracles:   Color(0xFF7C2D12),
    TestimonyCategory.protection: Color(0xFF1E3A5F),
    TestimonyCategory.ministere:  Color(0xFF4A1D96),
    TestimonyCategory.salut:      Color(0xFF7F1D1D),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[category] ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
