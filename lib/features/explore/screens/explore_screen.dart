// lib/features/explore/screens/explore_screen.dart
//
// Page Explorer — deux modes :
//   • Découverte : rubriques + tendances + plus priés + récents
//   • Recherche  : résultats filtrés en temps réel

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart';
import '../../home/widgets/audio_testimony_card.dart';
import '../../home/widgets/text_testimony_card.dart';
import '../../home/widgets/video_testimony_card.dart';
import '../../../core/providers/categories_provider.dart';
import '../../home/widgets/skeleton_card.dart';
import '../providers/explore_providers.dart';
import '../widgets/filter_row.dart';
import '../widgets/horizontal_testimony_card.dart';
import '../widgets/search_bar_widget.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query  = ref.watch(searchQueryProvider);
    final active = ref.watch(searchBarActiveProvider);
    final isSearching = query.trim().isNotEmpty || active;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 1,
            shadowColor: AppColors.border,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(AppLocalizations.of(context).exploreTitle, style: AppTextStyles.h3),
                        if (!isSearching)
                          Text(
                            AppLocalizations.of(context).exploreSubtitle,
                            style: AppTextStyles.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (isSearching)
                    TextButton(
                      onPressed: () {
                        ref.read(searchQueryProvider.notifier).clear();
                        ref
                            .read(searchBarActiveProvider.notifier)
                            .update(false);
                      },
                      child: Text(
                        AppLocalizations.of(context).exploreCancel,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(64),
              child: Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: SearchBarWidget(),
              ),
            ),
          ),

          // ── Contenu ───────────────────────────────────────────────────────
          if (isSearching)
            _SearchContent()
          else
            _DiscoverContent(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODE RECHERCHE
// ═══════════════════════════════════════════════════════════════════════════════

class _SearchContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(exploreResultsProvider);

    return SliverMainAxisGroup(
      slivers: [
        // Filtres type + tri
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 12, bottom: 8),
            child: FilterRow(),
          ),
        ),

        // Compte de résultats
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              results.isEmpty
                  ? AppLocalizations.of(context).exploreNoResults
                  : '${results.length} témoignage${results.length > 1 ? 's' : ''}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),

        if (results.isEmpty)
          const SliverFillRemaining(child: _EmptySearch())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _buildCard(results[i]),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODE DÉCOUVERTE
// ═══════════════════════════════════════════════════════════════════════════════

class _DiscoverContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading  = ref.watch(feedIsLoadingProvider);
    final trending   = ref.watch(trendingProvider);
    final mostPrayed = ref.watch(mostPrayedProvider);
    final recent     = ref.watch(recentProvider);
    final l10n       = AppLocalizations.of(context);

    return SliverMainAxisGroup(
      slivers: [
        // ── Rubriques ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: l10n.exploreCategories,
            subtitle: 'Parcourez par thème',
            icon: Icons.grid_view_rounded,
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: _CategoriesGrid(),
        ),

        // ── Tendances ─────────────────────────────────────────────────────
        if (isLoading || trending.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: l10n.exploreTrending,
              subtitle: 'Les plus consultés en ce moment',
              icon: null,
            ),
          ),
          SliverToBoxAdapter(
            child: isLoading
                ? const _SkeletonHorizontalScroll()
                : _HorizontalScroll(
                    testimonies: trending,
                    statLabel: 'vues',
                    statValue: (t) => t.stats.views,
                  ),
          ),
        ],

        // ── Les plus priés ────────────────────────────────────────────────
        if (isLoading || mostPrayed.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: l10n.exploreMostPrayed,
              subtitle: 'Témoignages qui touchent le cœur',
              icon: null,
            ),
          ),
          SliverToBoxAdapter(
            child: isLoading
                ? const _SkeletonHorizontalScroll()
                : _HorizontalScroll(
                    testimonies: mostPrayed,
                    statLabel: 'prières',
                    statValue: (t) => t.stats.prayers,
                  ),
          ),
        ],

        // ── Récents ───────────────────────────────────────────────────────
        if (isLoading || recent.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: l10n.exploreRecent,
              subtitle: 'Derniers témoignages publiés',
              icon: Icons.access_time_rounded,
            ),
          ),
          if (isLoading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, _) => const SkeletonCard(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: recent.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildCard(recent[i]),
              ),
            ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ── Carousel squelette ────────────────────────────────────────────────────────

class _SkeletonHorizontalScroll extends StatelessWidget {
  const _SkeletonHorizontalScroll();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => const SkeletonHorizontalCard(),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.icon,
  });

  final String title;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h3),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Visuel par slug ───────────────────────────────────────────────────────────

class _CategoryVisual {
  const _CategoryVisual(this.colorA, this.colorB, this.icon);
  final int colorA, colorB, icon;
}

const _kVisualMap = <String, _CategoryVisual>{
  'guerison':         _CategoryVisual(0xFF6B21A8, 0xFFA855F7, 0xe3f3),
  'delivrance':       _CategoryVisual(0xFF1E3A8A, 0xFF3B82F6, 0xe1af),
  'conversion':       _CategoryVisual(0xFF065F46, 0xFF10B981, 0xef6e),
  'mariage':          _CategoryVisual(0xFF9D174D, 0xFFF43F5E, 0xe87d),
  'famille':          _CategoryVisual(0xFF92400E, 0xFFF59E0B, 0xe533),
  'finances':         _CategoryVisual(0xFF14532D, 0xFF22C55E, 0xe263),
  'miracles':         _CategoryVisual(0xFF7C2D12, 0xFFF97316, 0xe518),
  'protection':       _CategoryVisual(0xFF1E3A5F, 0xFF0EA5E9, 0xe32a),
  'protection_divine':_CategoryVisual(0xFF1E3A5F, 0xFF0EA5E9, 0xe32a),
  'ministere':        _CategoryVisual(0xFF4A1D96, 0xFF8B5CF6, 0xe547),
  'salut':            _CategoryVisual(0xFF7F1D1D, 0xFFEF4444, 0xe838),
};

// Couleurs de secours pour les catégories inconnues (cycle)
const _kFallbackVisuals = <_CategoryVisual>[
  _CategoryVisual(0xFF374151, 0xFF6B7280, 0xe88a), // bookmark
  _CategoryVisual(0xFF1F2937, 0xFF4B5563, 0xe7ef), // label
  _CategoryVisual(0xFF312E81, 0xFF6366F1, 0xe54f), // star_border
  _CategoryVisual(0xFF064E3B, 0xFF059669, 0xe1b0), // eco
];

// ── Grille catégories ─────────────────────────────────────────────────────────

class _CategoriesGrid extends ConsumerWidget {
  const _CategoriesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedNotifierProvider);
    final cats = ref.watch(categoriesListProvider);

    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 76,
      ),
      itemCount: cats.length,
      itemBuilder: (_, i) {
        final cat   = cats[i];
        final count = feed.where((t) => t.category.slug == cat.slug).length;
        return _CategoryCard(cat: cat, liveCount: count, index: i);
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.cat,
    required this.liveCount,
    required this.index,
  });

  final CategoryModel cat;
  final int liveCount;
  final int index;

  @override
  Widget build(BuildContext context) {
    final visual = _kVisualMap[cat.slug] ??
        _kFallbackVisuals[index % _kFallbackVisuals.length];

    return GestureDetector(
      onTap: () => context.go('/explore/category/${cat.slug}'),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(visual.colorA), Color(visual.colorB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                IconData(visual.icon, fontFamily: 'MaterialIcons'),
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cat.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    liveCount > 0
                        ? '$liveCount tém.${liveCount > 1 ? 's' : ''}'
                        : 'Aucun tém.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Colors.white.withAlpha(200),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scroll horizontal ─────────────────────────────────────────────────────────

class _HorizontalScroll extends StatelessWidget {
  const _HorizontalScroll({
    required this.testimonies,
    required this.statLabel,
    required this.statValue,
  });

  final List<Testimony> testimonies;
  final String statLabel;
  final int Function(Testimony) statValue;

  @override
  Widget build(BuildContext context) {
    // Doit correspondre à _kCardHeight définie dans horizontal_testimony_card.dart
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: testimonies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => HorizontalTestimonyCard(
          testimony: testimonies[i],
          statLabel: statLabel,
          statValue: statValue(testimonies[i]),
        ),
      ),
    );
  }
}

// ── Empty search ──────────────────────────────────────────────────────────────

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off_rounded,
            size: 60,
            color: AppColors.textSecondary.withAlpha(80)),
        const SizedBox(height: 16),
        Text(
          'Aucun témoignage trouvé',
          style: AppTextStyles.h4
              .copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Text(
          'Essayez un autre mot-clé ou\nparcourez les rubriques.',
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Dispatch card par type ────────────────────────────────────────────────────

Widget _buildCard(Testimony t) => switch (t) {
      TextTestimony()  => TextTestimonyCard(testimony: t),
      AudioTestimony() => AudioTestimonyCard(testimony: t),
      VideoTestimony() => VideoTestimonyCard(testimony: t),
    };
