import '../../../shared/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/playback_preferences.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/guest_gate.dart';
import '../../explore/providers/explore_providers.dart'
    show searchBarActiveProvider, searchFocusRequestProvider;
import '../../notifications/providers/notifications_provider.dart'
    show unreadCountProvider;
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';
import '../widgets/category_chips_row.dart';
import '../widgets/daily_verse_banner.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/pill_tabs.dart';
import '../widgets/skeleton_card.dart';
import '../widgets/testimony_feed_item.dart';

/// Accueil (Home) screen.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// Widget tree (top-level):
///
/// Scaffold (backgroundColor: #F8FAFC)
///   └─ CustomScrollView
///       ├─ SliverAppBar (pinned, floating)
///       │   └─ _HomeAppBarContent
///       │       └─ Row : menu · AppLogo.horizontal · EN DIRECT · 🔍 · 🔔(badge)
///       ├─ SliverToBoxAdapter → _TypeTabs (Tous / Vidéos / Audios / Textes)
///       ├─ SliverToBoxAdapter → CategoryChipsRow
///       ├─ SliverToBoxAdapter → DailyVerseBanner
///       ├─ SliverToBoxAdapter → _BibleBanner
///       ├─ SliverToBoxAdapter → FeaturedCarousel
///       ├─ SliverToBoxAdapter → _FeedHeader
///       └─ SliverList → _FeedBody
///           ├─ [loading] SkeletonCard × 3
///           └─ [loaded]  TestimonyFeedItem (grande carte par type, ou
///                         ligne compacte dépliable selon feedLayoutProvider)
/// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Menu latéral : Communauté, Directs, Carnet… (écrans sans onglet)
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
        // Défilement infini : page suivante du fil « Pour vous » à l'approche du bas.
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.axis == Axis.vertical &&
                n.metrics.extentAfter < 800) {
              ref.read(feedNotifierProvider.notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── App bar ────────────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 1,
              shadowColor: AppColors.border,
              // toolbarHeight s'ajoute SOUS la status bar → pas d'overflow
              toolbarHeight: 64,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: const _HomeAppBarContent(),
            ),

            // ── Onglets de type (maquette : Tous / Vidéos / Audios / Textes) ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: _TypeTabs(),
              ),
            ),

            // ── Category chips ─────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 10),
                child: CategoryChipsRow(),
              ),
            ),

            // ── Daily verse banner ─────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 6),
                child: DailyVerseBanner(),
              ),
            ),

            // ── Bible shortcut ─────────────────────────────────────────────────
            const SliverToBoxAdapter(child: _BibleBanner()),

            // ── Featured carousel ──────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 20, bottom: 4),
                child: FeaturedCarousel(),
              ),
            ),

            // ── Feed header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: _FeedHeader(),
              ),
            ),

            // ── Main feed ──────────────────────────────────────────────────────
            const _FeedBody(),

            // Page suivante en cours de chargement
            const _FeedLoadMoreIndicator(),

            // Bottom padding so last card clears the nav bar
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
          ),
        ),
      ),
    );
  }
}

// ── App bar content ───────────────────────────────────────────────────────────

/// Row: menu | logo | EN DIRECT | recherche | cloche (badge non lus)
class _HomeAppBarContent extends StatelessWidget {
  const _HomeAppBarContent();

  @override
  Widget build(BuildContext context) {
    // Pas de SafeArea : SliverAppBar.title est déjà positionné sous la status bar.
    // Taille de police plafonnée dans l'en-tête (barre de 64 px).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          // Logo complet si la place le permet, sinon le seul dessin.
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.centerLeft,
                child: c.maxWidth >= 120
                    ? const AppLogo.horizontal()
                    : const AppLogoMark(size: 34),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const _LiveButton(),
          const _SearchButton(),
          const _NotificationBell(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Pastille « EN DIRECT » → découverte des directs.
class _LiveButton extends StatelessWidget {
  const _LiveButton();

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).homeLive;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => context.push('/live-discovery'),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 7,
                height: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.danger,
                  fontFamily: AppFonts.family,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loupe → onglet Explorer, en mode recherche (champ focalisé).
class _SearchButton extends ConsumerWidget {
  const _SearchButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Rechercher',
      icon: const Icon(Icons.search_rounded, color: AppColors.primary),
      onPressed: () {
        ref.read(searchBarActiveProvider.notifier).update(true);
        ref.read(searchFocusRequestProvider.notifier).request();
        context.go(AppPaths.explorePath);
      },
    );
  }
}

/// Cloche des notifications avec le nombre de non lues.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: count > 0 ? 'Notifications ($count non lues)' : 'Notifications',
      onPressed: () async {
        if (ref.read(isGuestProvider) &&
            !await requireAccount(context, ref,
                reason: 'recevoir vos notifications')) {
          return;
        }
        if (context.mounted) context.pushNamed(AppRoutes.notifications);
      },
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.secondary,
        textColor: Colors.white,
        label: Text(count > 99 ? '99+' : '$count'),
        child: Icon(
          count > 0
              ? Icons.notifications_rounded
              : Icons.notifications_none_rounded,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── Type tabs ─────────────────────────────────────────────────────────────────

class _TypeTabs extends ConsumerWidget {
  const _TypeTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PillTabs<TestimonyType?>(
      tabs: kTestimonyTypeTabs,
      selected: ref.watch(selectedFeedTypeProvider),
      onSelected: (t) => ref.read(selectedFeedTypeProvider.notifier).select(t),
    );
  }
}

// ── Feed header ───────────────────────────────────────────────────────────────

class _FeedHeader extends ConsumerWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(feedLayoutProvider);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Pour vous',
            style: AppTextStyles.h3,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _LayoutToggle(
          value: layout,
          onChanged: (l) => ref
              .read(playbackPreferencesProvider.notifier)
              .setFeedLayout(l),
        ),
      ],
    );
  }
}

/// Bascule simple entre « Cartes » (grandes cartes) et « Liste » (lignes
/// compactes dépliables).
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.value, required this.onChanged});

  final FeedLayout value;
  final ValueChanged<FeedLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(FeedLayout l, IconData icon, String label) {
      final selected = value == l;
      return Tooltip(
        message: 'Affichage : $label',
        child: Semantics(
          button: true,
          selected: selected,
          label: 'Affichage $label',
          excludeSemantics: true,
          child: InkWell(
            onTap: selected ? null : () => onChanged(l),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: selected
                    ? Border.all(color: AppColors.border)
                    : null,
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(FeedLayout.cards, Icons.view_agenda_rounded, 'Cartes'),
          button(FeedLayout.compact, Icons.view_list_rounded, 'Liste'),
        ],
      ),
    );
  }
}

// ── Feed body ─────────────────────────────────────────────────────────────────

/// Reads the feed provider and renders the appropriate card type per item.
/// Shows 3 skeleton cards while loading, or a "no results" empty state.
class _FeedBody extends ConsumerWidget {
  const _FeedBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed      = ref.watch(feedProvider);
    final isLoading = ref.watch(feedIsLoadingProvider);
    final layout    = ref.watch(feedLayoutProvider);

    // Chargement initial — squelettes animés
    if (isLoading) return const FeedLoadingSkeleton();

    // Feed vide après chargement
    if (feed.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: _EmptyFeed(),
          ),
        ]),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: feed.length,
        separatorBuilder: (_, _) => SizedBox(height: feedItemGap(layout)),
        itemBuilder: (context, index) => TestimonyFeedItem(
          key: ValueKey(feed[index].id),
          testimony: feed[index],
        ),
      ),
    );
  }
}

/// Petit indicateur en bas du fil pendant le chargement d'une page suivante.
class _FeedLoadMoreIndicator extends ConsumerWidget {
  const _FeedLoadMoreIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingMore = ref.watch(feedLoadingMoreProvider);
    if (!loadingMore) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

/// Squelette shimmer du feed affiché pendant le chargement initial.
/// Alterne texte / audio / vidéo pour ressembler à un vrai feed mixte.
class FeedLoadingSkeleton extends StatelessWidget {
  const FeedLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const skeletons = [
      SkeletonCard(),
      SkeletonAudioCard(),
      SkeletonVideoCard(),
      SkeletonCard(),
      SkeletonAudioCard(),
    ];
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: skeletons.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => skeletons[i],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off_rounded,
            size: 56, color: AppColors.textSecondary.withAlpha(80)),
        const SizedBox(height: 12),
        Text(
          'Aucun témoignage pour ce filtre',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Bible shortcut banner ─────────────────────────────────────────────────────

/// Carte bleue unie, accent jaune (charte : pas de gros dégradé).
class _BibleBanner extends StatelessWidget {
  const _BibleBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: AppColors.primary,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          onTap: () => context.push('/bible'),
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.sun,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primaryDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bible',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Télécharger et lire hors connexion',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 11,
                          color: Colors.white.withAlpha(210),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.sun,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
