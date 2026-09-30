import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';
import 'pill_tabs.dart';

/// Horizontally scrollable row of category filter chips.
///
/// Variante « douce » des pilules (sélection = fond bleu clair + texte bleu)
/// pour la distinguer des onglets de type (Tous / Vidéos / Audios / Textes).
///
/// Widget tree:
/// SingleChildScrollView (horizontal)
///   └─ Row
///       ├─ PillChip (label: "Toutes", isActive: selected == null)
///       └─ PillChip × 10 (one per TestimonyCategory)
class CategoryChipsRow extends ConsumerWidget {
  const CategoryChipsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);
    final notifier = ref.read(selectedCategoryProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          PillChip(
            label: 'Toutes',
            icon: Icons.grid_view_rounded,
            soft: true,
            selected: selected == null,
            onTap: () => notifier.select(null),
          ),
          for (final category in TestimonyCategory.values) ...[
            const SizedBox(width: AppSpacing.sm),
            PillChip(
              label: category.label,
              soft: true,
              selected: selected == category,
              onTap: () => notifier.select(category),
            ),
          ],
        ],
      ),
    );
  }
}
