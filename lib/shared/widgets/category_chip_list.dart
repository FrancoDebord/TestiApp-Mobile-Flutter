import 'package:flutter/material.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/core/theme/app_text_styles.dart';
import 'package:testi_app/shared/widgets/testimony_card.dart'
    show TestimonyCategory, TestimonyCategoryX;

// ── Category metadata ──────────────────────────────────────────────────────────

class _CategoryMeta {
  const _CategoryMeta({required this.category, required this.icon});
  final TestimonyCategory category;
  final IconData icon;
}

const _kCategories = <_CategoryMeta>[
  _CategoryMeta(category: TestimonyCategory.guerison, icon: Icons.healing_rounded),
  _CategoryMeta(category: TestimonyCategory.delivrance, icon: Icons.shield_rounded),
  _CategoryMeta(category: TestimonyCategory.conversion, icon: Icons.autorenew_rounded),
  _CategoryMeta(category: TestimonyCategory.mariage, icon: Icons.favorite_rounded),
  _CategoryMeta(category: TestimonyCategory.famille, icon: Icons.family_restroom_rounded),
  _CategoryMeta(category: TestimonyCategory.finances, icon: Icons.attach_money_rounded),
  _CategoryMeta(category: TestimonyCategory.miracles, icon: Icons.auto_awesome_rounded),
  _CategoryMeta(category: TestimonyCategory.protection, icon: Icons.security_rounded),
  _CategoryMeta(category: TestimonyCategory.ministere, icon: Icons.church_rounded),
  _CategoryMeta(category: TestimonyCategory.salut, icon: Icons.brightness_7_rounded),
];

// ── Public widget ──────────────────────────────────────────────────────────────

/// Horizontally scrollable chip list for filtering testimonies by category.
///
/// Pass [selectedCategory] to control active state from outside (null = "Tout").
/// [onCategorySelected] is called with `null` when the user taps "Tout".
class CategoryChipList extends StatelessWidget {
  const CategoryChipList({
    required this.onCategorySelected,
    this.selectedCategory,
    this.showAllChip = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    super.key,
  });

  final TestimonyCategory? selectedCategory;
  final ValueChanged<TestimonyCategory?> onCategorySelected;
  final bool showAllChip;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: [
          if (showAllChip) ...[
            _AllChip(
              isActive: selectedCategory == null,
              onTap: () => onCategorySelected(null),
            ),
            const SizedBox(width: 8),
          ],
          ..._kCategories.map((meta) {
            final isActive = selectedCategory == meta.category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChipItem(
                meta: meta,
                isActive: isActive,
                onTap: () => onCategorySelected(
                  isActive ? null : meta.category,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── "Tout" chip ────────────────────────────────────────────────────────────────

class _AllChip extends StatelessWidget {
  const _AllChip({required this.isActive, required this.onTap});
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(colors: AppColors.guerisonGradient)
                : null,
            color: isActive ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isActive ? Colors.transparent : AppColors.border,
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            'Tout',
            style: AppTextStyles.labelMedium.copyWith(
              color: isActive ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Individual category chip ───────────────────────────────────────────────────

class _CategoryChipItem extends StatelessWidget {
  const _CategoryChipItem({
    required this.meta,
    required this.isActive,
    required this.onTap,
  });

  final _CategoryMeta meta;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = meta.category.gradient;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(colors: gradient)
              : null,
          color: isActive ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : gradient.first.withAlpha(80),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: gradient.first.withAlpha(60),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              meta.icon,
              size: 14,
              color: isActive ? Colors.white : gradient.first,
            ),
            const SizedBox(width: 6),
            Text(
              meta.category.label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isActive ? Colors.white : AppColors.textPrimary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stateful wrapper for standalone use ───────────────────────────────────────

/// Self-contained version that manages its own selection state.
/// Useful in screens that do not need Riverpod-level category state.
class CategoryChipListSelfManaged extends StatefulWidget {
  const CategoryChipListSelfManaged({
    required this.onCategorySelected,
    this.initialCategory,
    this.showAllChip = true,
    super.key,
  });

  final ValueChanged<TestimonyCategory?> onCategorySelected;
  final TestimonyCategory? initialCategory;
  final bool showAllChip;

  @override
  State<CategoryChipListSelfManaged> createState() =>
      _CategoryChipListSelfManagedState();
}

class _CategoryChipListSelfManagedState
    extends State<CategoryChipListSelfManaged> {
  late TestimonyCategory? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    return CategoryChipList(
      selectedCategory: _selected,
      showAllChip: widget.showAllChip,
      onCategorySelected: (cat) {
        setState(() => _selected = cat);
        widget.onCategorySelected(cat);
      },
    );
  }
}
