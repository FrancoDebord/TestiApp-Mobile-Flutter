import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';

// ── Couleurs shimmer ──────────────────────────────────────────────────────────

const _kBaseColor      = Color(0xFFE2E8F0);
const _kHighlightColor = Color(0xFFF8FAFC);

// ── SkeletonCard — carte générique ───────────────────────────────────────────

/// Carte squelette animée (shimmer) affichée pendant le chargement du feed.
/// Reproduit la structure d'une TextTestimonyCard : header, badge catégorie,
/// titre, corps, stats et barre d'actions.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Shimmer.fromColors(
        baseColor: _kBaseColor,
        highlightColor: _kHighlightColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête auteur ─────────────────────────────────────────
              Row(
                children: [
                  const _SkeletonCircle(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(width: 130, height: 11),
                        const SizedBox(height: 5),
                        _SkeletonBox(width: 80, height: 9),
                      ],
                    ),
                  ),
                  _SkeletonBox(width: 24, height: 24, radius: 12),
                ],
              ),
              const SizedBox(height: 14),

              // ── Badge catégorie ────────────────────────────────────────
              _SkeletonBox(width: 90, height: 22, radius: 50),
              const SizedBox(height: 12),

              // ── Titre ──────────────────────────────────────────────────
              _SkeletonBox(width: double.infinity, height: 14),
              const SizedBox(height: 6),
              _SkeletonBox(width: 220, height: 14),
              const SizedBox(height: 12),

              // ── Corps du témoignage ────────────────────────────────────
              _SkeletonBox(width: double.infinity, height: 11),
              const SizedBox(height: 5),
              _SkeletonBox(width: double.infinity, height: 11),
              const SizedBox(height: 5),
              _SkeletonBox(width: 180, height: 11),
              const SizedBox(height: 16),

              // ── Ligne stats ────────────────────────────────────────────
              Row(
                children: [
                  _SkeletonBox(width: 56, height: 10),
                  const SizedBox(width: 14),
                  _SkeletonBox(width: 56, height: 10),
                  const SizedBox(width: 14),
                  _SkeletonBox(width: 56, height: 10),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: _kBaseColor),
              const SizedBox(height: 12),

              // ── Barre d'actions ────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  4,
                  (_) => _SkeletonBox(width: 64, height: 28, radius: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SkeletonVideoCard ─────────────────────────────────────────────────────────

/// Variante pour les témoignages vidéo : remplace le corps texte par
/// un placeholder 16/9 avec un bouton play centré.
class SkeletonVideoCard extends StatelessWidget {
  const SkeletonVideoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Shimmer.fromColors(
        baseColor: _kBaseColor,
        highlightColor: _kHighlightColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _SkeletonCircle(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(width: 130, height: 11),
                        const SizedBox(height: 5),
                        _SkeletonBox(width: 80, height: 9),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SkeletonBox(width: double.infinity, height: 14),
              const SizedBox(height: 10),
              // Placeholder thumbnail 16/9
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(color: Colors.white),
                      const _SkeletonCircle(size: 48),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _SkeletonBox(width: 56, height: 10),
                  const SizedBox(width: 14),
                  _SkeletonBox(width: 56, height: 10),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: _kBaseColor),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  4,
                  (_) => _SkeletonBox(width: 64, height: 28, radius: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SkeletonAudioCard ─────────────────────────────────────────────────────────

/// Variante pour les témoignages audio : remplace le corps texte par
/// un placeholder waveform (barres + bouton play).
class SkeletonAudioCard extends StatelessWidget {
  const SkeletonAudioCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Shimmer.fromColors(
        baseColor: _kBaseColor,
        highlightColor: _kHighlightColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _SkeletonCircle(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(width: 130, height: 11),
                        const SizedBox(height: 5),
                        _SkeletonBox(width: 80, height: 9),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SkeletonBox(width: double.infinity, height: 14),
              const SizedBox(height: 10),
              // Placeholder waveform player
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _SkeletonBox(width: 56, height: 10),
                  const SizedBox(width: 14),
                  _SkeletonBox(width: 56, height: 10),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: _kBaseColor),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  4,
                  (_) => _SkeletonBox(width: 64, height: 28, radius: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SkeletonHorizontalCard ────────────────────────────────────────────────────

/// Carte squelette compacte (172×220) pour les carousels horizontaux Explorer.
/// Reproduit la structure d'un HorizontalTestimonyCard.
class SkeletonHorizontalCard extends StatelessWidget {
  const SkeletonHorizontalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      height: 220,
      child: Shimmer.fromColors(
        baseColor: _kBaseColor,
        highlightColor: _kHighlightColor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête dégradé (84px)
                Container(
                  height: 84,
                  color: Colors.white,
                ),
                // Corps
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(width: 60, height: 16, radius: 5),
                        const SizedBox(height: 5),
                        _SkeletonBox(width: double.infinity, height: 12),
                        const SizedBox(height: 4),
                        _SkeletonBox(width: 100, height: 12),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const _SkeletonCircle(size: 18),
                            const SizedBox(width: 5),
                            _SkeletonBox(width: 80, height: 10),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _SkeletonBox(width: 70, height: 10),
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
}

// ── Primitives ────────────────────────────────────────────────────────────────

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 4,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
}
