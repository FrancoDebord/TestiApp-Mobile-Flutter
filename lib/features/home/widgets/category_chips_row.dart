import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';

/// Horizontally scrollable row of category filter chips.
///
/// Widget tree:
/// SizedBox (height: 42)
///   └─ ListView.separated (scrollDirection: horizontal, no scrollbar)
///       ├─ _CategoryChip (label: "Tout", isActive: selected == null)
///       └─ _CategoryChip × 10 (one per TestimonyCategory)
class CategoryChipsRow extends ConsumerWidget {
  const CategoryChipsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);

    final allCategories = TestimonyCategory.values;

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // Remove default overscroll glow
        physics: const BouncingScrollPhysics(),
        itemCount: allCategories.length + 1, // +1 for "Tout"
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryChip(
              label: 'Tout',
              isActive: selected == null,
              onTap: () =>
                  ref.read(selectedCategoryProvider.notifier).select(null),
            );
          }
          final category = allCategories[index - 1];
          return _CategoryChip(
            label: category.label,
            isActive: selected == category,
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).select(category),
          );
        },
      ),
    );
  }
}

// ── Single chip ───────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isActive ? Colors.white : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
