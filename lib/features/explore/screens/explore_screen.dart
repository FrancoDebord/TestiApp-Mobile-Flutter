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
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart';
import '../../home/widgets/testimony_feed_item.dart';
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
            automaticallyImplyLeading: false,
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
                        Text(
                          isSearching
                              ? 'Recherche & filtres'
                              : AppLocalizations.of(context).exploreTitle,
                          style: AppTextStyles.h3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isSearching)
                          Text(
                            AppLocalizations.of(context).exploreSubtitle,
                            style: AppTextStyles.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        style: AppTextStyles.labelMedium.copyWith(
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
                padding: EdgeInsets.only(bottom: 12),
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
        // Onglets de type (Tous / Vidéos / Audios / Textes)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 12),
            child: ExploreTypeTabs(),
          ),
        ),

        // Panneau « Filtres » : Type, Catégorie, Popularité
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 12, bottom: 8),
            child: ExploreFiltersPanel(),
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
          const SliverFillRemaining(hasScrollBody: false, child: _EmptySearch())
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

/// Pastille colorée de la charte (fond doux + icône) pour chaque rubrique.
class _CategoryVisual {
  const _CategoryVisual(this.bg, this.fg, this.icon);
  final Color bg, fg;
  final IconData icon;
}

const _kBlue = (AppColors.primarySoft, AppColors.primary);
const _kOrange = (AppColors.secondarySoft, AppColors.secondaryDark);
const _kYellow = (AppColors.sunSoft, AppColors.sunText);
const _kGreen = (AppColors.successSoft, AppColors.success);

_CategoryVisual _visual((Color, Color) tone, IconData icon) =>
    _CategoryVisual(tone.$1, tone.$2, icon);

final _kVisualMap = <String, _CategoryVisual>{
  'guerison':          _visual(_kYellow, Icons.healing_outlined),
  'delivrance':        _visual(_kOrange, Icons.lock_open_outlined),
  'conversion':        _visual(_kBlue, Icons.rotate_right_rounded),
  'mariage':           _visual(_kOrange, Icons.favorite_border_rounded),
  'famille':           _visual(_kGreen, Icons.people_alt_outlined),
  'finances':          _visual(_kGreen, Icons.payments_outlined),
  'provision':         _visual(_kGreen, Icons.payments_outlined),
  'miracles':          _visual(_kYellow, Icons.auto_awesome_outlined),
  'protection':        _visual(_kBlue, Icons.shield_outlined),
  'protection_divine': _visual(_kBlue, Icons.shield_outlined),
  'ministere':         _visual(_kBlue, Icons.record_voice_over_outlined),
  'salut':             _visual(_kOrange, Icons.star_border_rounded),
  'emploi':            _visual(_kBlue, Icons.work_outline_rounded),
  'etudes':            _visual(_kYellow, Icons.school_outlined),
};

// Couleurs de secours pour les catégories inconnues (cycle)
final _kFallbackVisuals = <_CategoryVisual>[
  _visual(_kBlue, Icons.bookmark_border_rounded),
  _visual(_kOrange, Icons.label_outline_rounded),
  _visual(_kYellow, Icons.star_border_rounded),
  _visual(_kGreen, Icons.eco_outlined),
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
        mainAxisExtent: 72,
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

    return DecoratedBox(
      decoration: AppShadows.cardDecoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => context.go('/explore/category/${cat.slug}'),
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: visual.bg,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: Icon(visual.icon, color: visual.fg, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cat.name,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        liveCount > 0
                            ? '$liveCount témoignage${liveCount > 1 ? 's' : ''}'
                            : 'Aucun témoignage',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
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
        const SizedBox(height: 24),
        Icon(Icons.search_off_rounded,
            size: 60,
            color: AppColors.textSecondary.withAlpha(80)),
        const SizedBox(height: 16),
        Text(
          'Aucun témoignage trouvé',
          textAlign: TextAlign.center,
          style: AppTextStyles.h4
              .copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Text(
          'Essayez un autre mot-clé ou\nparcourez les rubriques.',
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Dispatch card par type ────────────────────────────────────────────────────

/// Grande carte ou ligne compacte selon l'affichage choisi (feedLayoutProvider).
Widget _buildCard(Testimony t) =>
    TestimonyFeedItem(key: ValueKey(t.id), testimony: t);
