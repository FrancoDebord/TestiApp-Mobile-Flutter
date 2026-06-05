import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/explore_models.dart';
import '../providers/explore_providers.dart';

/// Filter row: Type dropdown + Sort dropdown.
///
/// Widget tree:
/// Padding
///   └─ Row
///       ├─ `_FilterDropdown<ExploreTypeFilter>` (Type)
///       ├─ SizedBox
///       └─ `_FilterDropdown<ExploreSortOrder>` (Tri)
class FilterRow extends ConsumerWidget {
  const FilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeFilter = ref.watch(typeFilterProvider);
    final sortOrder = ref.watch(sortOrderProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Type filter
          _FilterDropdown<ExploreTypeFilter>(
            label: 'Type',
            value: typeFilter,
            items: ExploreTypeFilter.values,
            labelOf: (v) => v.label,
            onChanged: (v) =>
                ref.read(typeFilterProvider.notifier).update(v),
          ),
          const SizedBox(width: 10),
          // Sort order
          _FilterDropdown<ExploreSortOrder>(
            label: 'Tri',
            value: sortOrder,
            items: ExploreSortOrder.values,
            labelOf: (v) => v.label,
            onChanged: (v) =>
                ref.read(sortOrderProvider.notifier).update(v),
          ),
        ],
      ),
    );
  }
}

// ── Generic dropdown chip ─────────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labelOf(value),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PickerSheet<T>(
        title: label,
        items: items,
        selected: value,
        labelOf: labelOf,
        onSelected: onChanged,
      ),
    );
  }
}

// ── Bottom sheet picker ───────────────────────────────────────────────────────

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    super.key,
  });

  final String title;
  final List<T> items;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.h4),
            const SizedBox(height: 12),
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(labelOf(item), style: AppTextStyles.bodyMedium),
                trailing: item == selected
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 20)
                    : null,
                onTap: () {
                  onSelected(item);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
