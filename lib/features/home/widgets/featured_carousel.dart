import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';

/// "À la une" section: section header + horizontal scroll of featured cards.
///
/// Widget tree:
/// Column
///   ├─ Padding → Row ("À la une" heading + "Voir tout" TextButton)
///   └─ SizedBox (height: 220)
///       └─ ListView.separated (scrollDirection: horizontal)
///           └─ _FeaturedCard × N
class FeaturedCarousel extends ConsumerWidget {
  const FeaturedCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('À la une', style: AppTextStyles.h3),
              TextButton(
                onPressed: () => context.push('/trending'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Voir tout',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal carousel
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: featured.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _FeaturedCard(testimony: featured[index]),
          ),
        ),
      ],
    );
  }
}

// ── Featured card ─────────────────────────────────────────────────────────────

/// Full-bleed cover image card with gradient overlay and type icon badge.
///
/// Widget tree:
/// GestureDetector
///   └─ ClipRRect (r: 16)
///       └─ SizedBox (w: 260, h: 220)
///           └─ Stack
///               ├─ _CoverImage (full-bleed network image or placeholder)
///               ├─ Container (bottom gradient overlay)
///               ├─ Positioned (top-left) → _TypeBadge
///               └─ Positioned (bottom) → Column
///                   ├─ _CategoryBadge
///                   ├─ SizedBox
///                   └─ Text (title, white, Poppins SemiBold)
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.testimony});

  final Testimony testimony;

  String? get _imageUrl => switch (testimony) {
        TextTestimony t => t.coverImageUrl,
        AudioTestimony a => a.coverImageUrl,
        VideoTestimony v => v.thumbnailUrl,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/testimony/${testimony.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 260,
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover image or gradient placeholder
              _CoverImage(imageUrl: _imageUrl, category: testimony.category),

              // Bottom gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.3, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(200),
                    ],
                  ),
                ),
              ),

              // Type badge (top-left)
              Positioned(
                top: 12,
                left: 12,
                child: _TypeBadge(type: testimony.type),
              ),

              // Title + category (bottom)
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryPill(category: testimony.category),
                    const SizedBox(height: 6),
                    Text(
                      testimony.title,
                      style: AppTextStyles.h4.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          testimony.author.displayName,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cover image ───────────────────────────────────────────────────────────────

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.imageUrl, required this.category});

  final String? imageUrl;
  final TestimonyCategory category;

  List<Color> get _gradient =>
      _kCategoryGradients[category] ??
      [AppColors.primary, AppColors.primaryLight];

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _Placeholder(gradient: _gradient),
      );
    }
    return _Placeholder(gradient: _gradient);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.gradient});
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.church_rounded, size: 48, color: Colors.white30),
      ),
    );
  }
}

// ── Type badge ────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final TestimonyType type;

  IconData get _icon => switch (type) {
        TestimonyType.text => Icons.article_outlined,
        TestimonyType.audio => Icons.headphones_outlined,
        TestimonyType.video => Icons.play_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(130),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_icon, size: 14, color: Colors.white),
    );
  }
}

// ── Category pill ─────────────────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});
  final TestimonyCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(220),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        category.label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Per-category gradient map (file-private top-level constant) ───────────────

const Map<TestimonyCategory, List<Color>> _kCategoryGradients = {
  TestimonyCategory.guerison: [Color(0xFF6B21A8), Color(0xFFA855F7)],
  TestimonyCategory.delivrance: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
  TestimonyCategory.conversion: [Color(0xFF065F46), Color(0xFF10B981)],
  TestimonyCategory.mariage: [Color(0xFF9D174D), Color(0xFFF43F5E)],
  TestimonyCategory.famille: [Color(0xFF92400E), Color(0xFFF59E0B)],
  TestimonyCategory.finances: [Color(0xFF14532D), Color(0xFF22C55E)],
  TestimonyCategory.miracles: [Color(0xFF7C2D12), Color(0xFFF97316)],
  TestimonyCategory.protection: [Color(0xFF1E3A5F), Color(0xFF0EA5E9)],
  TestimonyCategory.ministere: [Color(0xFF4A1D96), Color(0xFF8B5CF6)],
  TestimonyCategory.salut: [Color(0xFF7F1D1D), Color(0xFFEF4444)],
};
