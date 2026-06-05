import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../home/models/testimony_model.dart';
import '../models/explore_models.dart';

/// 2-column grid of trending category cards.
///
/// Widget tree:
/// Column
///   ├─ Padding → Text ("Catégories tendance")
///   └─ Padding → GridView.count (crossAxisCount: 2, shrinkWrap, no scroll)
///       └─ _CategoryCard × 10
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Catégories tendance', style: AppTextStyles.h3),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: CategoryCardData.all
                .map((data) => _CategoryCard(data: data))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ── Single category card ──────────────────────────────────────────────────────

/// Gradient card with icon, category name, and testimony count.
///
/// Widget tree:
/// GestureDetector
///   └─ ClipRRect (r: 14)
///       └─ Container (gradient)
///           └─ Stack
///               ├─ Positioned (top-right) → Icon (decorative, large, semi-transparent)
///               └─ Padding → Column
///                   ├─ Icon (small, white)
///                   ├─ Spacer
///                   ├─ Text (category name, Poppins SemiBold, white)
///                   └─ Text (count badge, Inter small, white70)
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.data});

  final CategoryCardData data;

  @override
  Widget build(BuildContext context) {
    final c1 = Color(data.gradientColors[0]);
    final c2 = Color(data.gradientColors[1]);

    return GestureDetector(
      onTap: () => context.push('/explore/category/${data.category.slug}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c1, c2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Decorative large icon (top-right, semi-transparent)
              Positioned(
                top: -8,
                right: -8,
                child: Icon(
                  IconData(data.iconCodePoint, fontFamily: 'MaterialIcons'),
                  size: 72,
                  color: Colors.white.withAlpha(30),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Small icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        IconData(data.iconCodePoint,
                            fontFamily: 'MaterialIcons'),
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    // Category name
                    Text(
                      data.category.label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Count
                    Text(
                      '${data.count} témoignages',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
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

// ── Palette helper re-export ──────────────────────────────────────────────────

/// Convenience so callers don't need to import app_colors separately.
// ignore: unused_element
const _kPrimary = AppColors.primary;
