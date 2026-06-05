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
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart';
import '../../home/widgets/audio_testimony_card.dart';
import '../../home/widgets/text_testimony_card.dart';
import '../../home/widgets/video_testimony_card.dart';
import '../models/explore_models.dart';
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
                        Text('Explorer', style: AppTextStyles.h3),
                        if (!isSearching)
                          Text(
                            'Trouvez ce qui vous inspire',
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
                      child: const Text(
                        'Annuler',
                        style: TextStyle(
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
                  ? 'Aucun résultat'
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
    final trending   = ref.watch(trendingProvider);
    final mostPrayed = ref.watch(mostPrayedProvider);
    final recent     = ref.watch(recentProvider);

    return SliverMainAxisGroup(
      slivers: [
        // ── Rubriques ─────────────────────────────────────────────────────
        const SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Rubriques',
            subtitle: 'Parcourez par thème',
            icon: Icons.grid_view_rounded,
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: _CategoriesGrid(),
        ),

        // ── Tendances ─────────────────────────────────────────────────────
        if (trending.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Tendances 🔥',
              subtitle: 'Les plus consultés en ce moment',
              icon: null,
            ),
          ),
          SliverToBoxAdapter(
            child: _HorizontalScroll(
              testimonies: trending,
              statLabel: 'vues',
              statValue: (t) => t.stats.views,
            ),
          ),
        ],

        // ── Les plus priés ────────────────────────────────────────────────
        if (mostPrayed.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Les plus priés 🙏',
              subtitle: 'Témoignages qui touchent le cœur',
              icon: null,
            ),
          ),
          SliverToBoxAdapter(
            child: _HorizontalScroll(
              testimonies: mostPrayed,
              statLabel: 'prières',
              statValue: (t) => t.stats.prayers,
            ),
          ),
        ],

        // ── Récents ───────────────────────────────────────────────────────
        if (recent.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Récents',
              subtitle: 'Derniers témoignages publiés',
              icon: Icons.access_time_rounded,
            ),
          ),
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

// ── Grille catégories ─────────────────────────────────────────────────────────

class _CategoriesGrid extends ConsumerWidget {
  const _CategoriesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(feedNotifierProvider);

    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Hauteur fixe plutôt que ratio — évite l'overflow sur petits écrans
        mainAxisExtent: 76,
      ),
      itemCount: CategoryCardData.all.length,
      itemBuilder: (_, i) {
        final data  = CategoryCardData.all[i];
        final count =
            all.where((t) => t.category == data.category).length;
        return _CategoryCard(data: data, liveCount: count);
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.data, required this.liveCount});

  final CategoryCardData data;
  final int liveCount;

  @override
  Widget build(BuildContext context) {
    final colors = data.gradientColors
        .map((c) => Color(c))
        .toList();

    return GestureDetector(
      onTap: () => context.go('/explore/category/${data.category.slug}'),
      child: Container(
        // height = mainAxisExtent = 76px
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        // Centre verticalement dans les 76px fixes
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
                IconData(data.iconCodePoint, fontFamily: 'MaterialIcons'),
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
                    data.category.label,
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
                        : '${data.count} téms.',
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
