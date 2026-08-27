// lib/features/explore/screens/category_screen.dart
//
// Écran d'une rubrique : AppBar gradient + filtres type/tri + liste complète.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../home/models/testimony_model.dart';
import '../../home/widgets/audio_testimony_card.dart';
import '../../home/widgets/text_testimony_card.dart';
import '../../home/widgets/video_testimony_card.dart';
import '../models/explore_models.dart';
import '../providers/explore_providers.dart';

// ── Métadonnées visuelles par catégorie ───────────────────────────────────────

class _CatMeta {
  const _CatMeta({required this.colors, required this.icon});
  final List<Color> colors;
  final IconData icon;
}

const _catMeta = <TestimonyCategory, _CatMeta>{
  TestimonyCategory.guerison:   _CatMeta(colors: [Color(0xFF6B21A8), Color(0xFFA855F7)], icon: Icons.healing_outlined),
  TestimonyCategory.delivrance: _CatMeta(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)], icon: Icons.lock_open_outlined),
  TestimonyCategory.conversion: _CatMeta(colors: [Color(0xFF065F46), Color(0xFF10B981)], icon: Icons.rotate_right_rounded),
  TestimonyCategory.mariage:    _CatMeta(colors: [Color(0xFF9D174D), Color(0xFFF43F5E)], icon: Icons.favorite_rounded),
  TestimonyCategory.famille:    _CatMeta(colors: [Color(0xFF92400E), Color(0xFFF59E0B)], icon: Icons.people_alt_outlined),
  TestimonyCategory.finances:   _CatMeta(colors: [Color(0xFF14532D), Color(0xFF22C55E)], icon: Icons.attach_money_rounded),
  TestimonyCategory.miracles:   _CatMeta(colors: [Color(0xFF7C2D12), Color(0xFFF97316)], icon: Icons.auto_awesome_rounded),
  TestimonyCategory.protection: _CatMeta(colors: [Color(0xFF1E3A5F), Color(0xFF0EA5E9)], icon: Icons.shield_outlined),
  TestimonyCategory.ministere:  _CatMeta(colors: [Color(0xFF4A1D96), Color(0xFF8B5CF6)], icon: Icons.record_voice_over_outlined),
  TestimonyCategory.salut:      _CatMeta(colors: [Color(0xFF7F1D1D), Color(0xFFEF4444)], icon: Icons.star_rounded),
};

// ═══════════════════════════════════════════════════════════════════════════════
// CategoryScreen
// ═══════════════════════════════════════════════════════════════════════════════

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({required this.slug, super.key});
  final String slug;

  TestimonyCategory get _category {
    try {
      return TestimonyCategory.values.firstWhere((c) => c.name == slug);
    } catch (_) {
      return TestimonyCategory.guerison;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat      = _category;
    final meta     = _catMeta[cat] ??
        const _CatMeta(
          colors: [Color(0xFF6B21A8), Color(0xFFA855F7)],
          icon: Icons.star_rounded,
        );
    final results    = ref.watch(categoryResultsProvider(cat));
    final isLoading  = ref.watch(categoryLoadingProvider(cat));
    final typeFilter = ref.watch(categoryTypeFilterProvider);
    final sortOrder  = ref.watch(categorySortOrderProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── App bar gradient ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: meta.colors.first,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: meta.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(meta.icon,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        cat.label,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${results.length} témoignage${results.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Barre de filtres ────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(
              typeFilter: typeFilter,
              sortOrder: sortOrder,
              onTypeChanged: (v) =>
                  ref.read(categoryTypeFilterProvider.notifier).update(v),
              onSortChanged: (v) =>
                  ref.read(categorySortOrderProvider.notifier).update(v),
            ),
          ),

          // ── Liste ───────────────────────────────────────────────────────
          if (isLoading && results.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (results.isEmpty)
            const SliverFillRemaining(child: _EmptyCategory())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList.separated(
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildCard(results[i]),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Barre de filtres persistante ──────────────────────────────────────────────

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  const _FilterBarDelegate({
    required this.typeFilter,
    required this.sortOrder,
    required this.onTypeChanged,
    required this.onSortChanged,
  });

  final ExploreTypeFilter typeFilter;
  final ExploreSortOrder  sortOrder;
  final ValueChanged<ExploreTypeFilter> onTypeChanged;
  final ValueChanged<ExploreSortOrder>  onSortChanged;

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 60,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          // Chips type
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ExploreTypeFilter.values.map((f) {
                  final selected = f == typeFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onTypeChanged(f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          f.label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Bouton tri
          const SizedBox(width: 8),
          _SortButton(
            current: sortOrder,
            onChanged: onSortChanged,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterBarDelegate old) =>
      old.typeFilter != typeFilter || old.sortOrder != sortOrder;
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.current, required this.onChanged});

  final ExploreSortOrder current;
  final ValueChanged<ExploreSortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              current.label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Trier par', style: AppTextStyles.h4),
              const SizedBox(height: 8),
              ...ExploreSortOrder.values.map((o) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.label, style: AppTextStyles.bodyMedium),
                    trailing: o == current
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary, size: 20)
                        : null,
                    onTap: () {
                      onChanged(o);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_rounded,
            size: 60, color: AppColors.textSecondary.withAlpha(80)),
        const SizedBox(height: 16),
        Text('Aucun témoignage pour l\'instant',
            style:
                AppTextStyles.h4.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Text(
          'Soyez le premier à partager\ndans cette rubrique.',
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Dispatch card ─────────────────────────────────────────────────────────────

Widget _buildCard(Testimony t) => switch (t) {
      TextTestimony()  => TextTestimonyCard(testimony: t),
      AudioTestimony() => AudioTestimonyCard(testimony: t),
      VideoTestimony() => VideoTestimonyCard(testimony: t),
    };
