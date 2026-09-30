// lib/features/explore/widgets/filter_row.dart
//
// Filtres de la recherche (maquette « Recherche & filtres ») :
//   • onglets Tous / Vidéos / Audios / Textes (appliqués tout de suite) ;
//   • panneau « Filtres » : Type, Catégorie, Popularité en listes déroulantes,
//     bouton « Appliquer les filtres » + lien « Réinitialiser ».
// Le filtrage est local (exploreResultsProvider) : l'API de liste des
// témoignages n'accepte pas ces paramètres.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/categories_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../home/widgets/pill_tabs.dart';
import '../models/explore_models.dart';
import '../providers/explore_providers.dart';

/// Onglets de type en pilule (appliqués immédiatement).
class ExploreTypeTabs extends ConsumerWidget {
  const ExploreTypeTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PillTabs<ExploreTypeFilter>(
      tabs: [for (final f in kExploreTypeTabs) PillTab(f, f.tabLabel)],
      selected: ref.watch(typeFilterProvider),
      onSelected: (f) => ref.read(typeFilterProvider.notifier).update(f),
    );
  }
}

/// Panneau « Filtres » repliable.
class ExploreFiltersPanel extends ConsumerStatefulWidget {
  const ExploreFiltersPanel({this.initiallyOpen = true, super.key});

  final bool initiallyOpen;

  @override
  ConsumerState<ExploreFiltersPanel> createState() =>
      _ExploreFiltersPanelState();
}

class _ExploreFiltersPanelState extends ConsumerState<ExploreFiltersPanel> {
  late bool _open = widget.initiallyOpen;

  // Brouillon : appliqué seulement avec « Appliquer les filtres ».
  late ExploreTypeFilter _type = ref.read(typeFilterProvider);
  late String? _category = ref.read(exploreCategoryFilterProvider);
  late ExploreSortOrder _sort = ref.read(sortOrderProvider);

  void _apply() {
    ref.read(typeFilterProvider.notifier).update(_type);
    ref.read(exploreCategoryFilterProvider.notifier).update(_category);
    ref.read(sortOrderProvider.notifier).update(_sort);
    FocusScope.of(context).unfocus();
    setState(() => _open = false);
  }

  void _reset() {
    resetExploreFilters(ref);
    setState(() {
      _type = ExploreTypeFilter.all;
      _category = null;
      _sort = ExploreSortOrder.recent;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Onglets de type ou réinitialisation ailleurs → le brouillon suit.
    ref.listen<ExploreTypeFilter>(
        typeFilterProvider, (_, v) => setState(() => _type = v));
    ref.listen<String?>(
        exploreCategoryFilterProvider, (_, v) => setState(() => _category = v));
    ref.listen<ExploreSortOrder>(
        sortOrderProvider, (_, v) => setState(() => _sort = v));

    final categories = ref.watch(categoriesListProvider);
    final active = ref.watch(exploreFiltersActiveProvider);
    // Catégorie choisie absente de la liste (liste rechargée) → « Toutes ».
    final categoryValue =
        categories.any((c) => c.slug == _category) ? _category : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: DecoratedBox(
        decoration: AppShadows.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête repliable ─────────────────────────────────────────
            Semantics(
              button: true,
              expanded: _open,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                borderRadius: AppRadius.cardRadius,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Filtres',
                          style: AppTextStyles.h4,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (active && !_open)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(Icons.expand_more_rounded,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Champs ────────────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: !_open
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FieldLabel('Type'),
                          _Dropdown<ExploreTypeFilter>(
                            value: _type,
                            items: [
                              for (final f in kExploreTypeTabs)
                                (f, f.dropdownLabel),
                            ],
                            onChanged: (v) => setState(() => _type = v),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _FieldLabel('Catégorie'),
                          _Dropdown<String?>(
                            value: categoryValue,
                            items: [
                              (null, 'Toutes les catégories'),
                              for (final c in categories) (c.slug, c.name),
                            ],
                            onChanged: (v) => setState(() => _category = v),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _FieldLabel('Popularité'),
                          _Dropdown<ExploreSortOrder>(
                            value: _sort,
                            items: [
                              for (final o in ExploreSortOrder.values)
                                (o, o.popularityLabel),
                            ],
                            onChanged: (v) => setState(() => _sort = v),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: 'Appliquer les filtres',
                            variant: AppButtonVariant.accent,
                            fullWidth: true,
                            onPressed: _apply,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Center(
                            child: TextButton(
                              onPressed: _reset,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                minimumSize: const Size(44, 44),
                              ),
                              child: Text(
                                'Réinitialiser',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Liste déroulante de la charte : fond blanc, bordure fine, radius 10.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
      borderSide: const BorderSide(color: AppColors.inputBorder),
    );
    return DropdownButtonFormField<T>(
      initialValue: value,
      key: ValueKey(value),
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      items: [
        for (final (v, label) in items)
          DropdownMenuItem<T>(
            value: v,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null || null is T) onChanged(v as T);
      },
    );
  }
}
