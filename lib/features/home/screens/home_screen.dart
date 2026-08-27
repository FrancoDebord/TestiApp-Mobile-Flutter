import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';
import '../widgets/audio_testimony_card.dart';
import '../widgets/category_chips_row.dart';
import '../widgets/daily_verse_banner.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/skeleton_card.dart';
import '../widgets/text_testimony_card.dart';
import '../widgets/video_testimony_card.dart';

/// Accueil (Home) screen.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// Widget tree (top-level):
///
/// Scaffold (backgroundColor: #F8FAFC)
///   └─ CustomScrollView
///       ├─ SliverAppBar (pinned, floating)
///       │   └─ _HomeAppBarContent
///       │       ├─ Row
///       │       │   ├─ _AppLogo
///       │       │   ├─ Expanded → Column (greeting + subtitle)
///       │       │   └─ Row (_NotificationBell + _AvatarButton)
///       │       └─ [space for bottom]
///       ├─ SliverToBoxAdapter → DailyVerseBanner
///       ├─ SliverToBoxAdapter → CategoryChipsRow
///       ├─ SliverToBoxAdapter → SizedBox (gap)
///       ├─ SliverToBoxAdapter → FeaturedCarousel
///       ├─ SliverToBoxAdapter → _FeedHeader
///       └─ SliverList → _FeedBody
///           ├─ [loading] SkeletonCard × 3
///           └─ [loaded]  TextTestimonyCard | AudioTestimonyCard |
///                         VideoTestimonyCard (dispatched per type)
/// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final firstName = user?.displayName.split(' ').first ?? 'vous';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
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
              title: _HomeAppBarContent(firstName: firstName),
            ),

            // ── Daily verse banner ─────────────────────────────────────────────
            const SliverToBoxAdapter(child: DailyVerseBanner()),

            // ── Bible shortcut ─────────────────────────────────────────────────
            const SliverToBoxAdapter(child: _BibleBanner()),

            // ── Category chips ─────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: CategoryChipsRow(),
              ),
            ),

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

            // Bottom padding so last card clears the nav bar
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ── App bar content ───────────────────────────────────────────────────────────

/// Row: logo | greeting column | spacer | notification bell | avatar
class _HomeAppBarContent extends ConsumerWidget {
  const _HomeAppBarContent({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pas de SafeArea : SliverAppBar.title est déjà positionné sous la status bar.
    return Row(
      children: [
        const SizedBox(width: 16),
        _AppLogo(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bonjour, $firstName 👋',
                style: AppTextStyles.h4.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text('Que votre foi grandisse', style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        // Bouton EN DIRECT
        GestureDetector(
          onTap: () => context.push('/live-discovery'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 7, height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context).homeLive.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        const _NotificationBell(badgeCount: 3),
        const SizedBox(width: 4),
        const _AvatarButton(),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.church_rounded, color: Colors.white, size: 22),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.badgeCount});
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: AppColors.textPrimary,
          onPressed: () {},
          tooltip: 'Notifications',
        ),
        if (badgeCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarButton extends ConsumerWidget {
  const _AvatarButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primaryLight.withAlpha(40),
        backgroundImage:
            user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
        child: user?.avatarUrl == null
            ? Text(
                user?.displayName.isNotEmpty == true
                    ? user!.displayName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}

// ── Feed header ───────────────────────────────────────────────────────────────

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('${l10n.homeTitle} récents', style: AppTextStyles.h3),
        const Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 20),
      ],
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
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildCard(feed[index]),
      ),
    );
  }

  Widget _buildCard(Testimony testimony) => switch (testimony) {
        TextTestimony t  => TextTestimonyCard(testimony: t),
        AudioTestimony a => AudioTestimonyCard(testimony: a),
        VideoTestimony v => VideoTestimonyCard(testimony: v),
      };
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
          'Aucun témoignage dans cette catégorie',
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

class _BibleBanner extends StatelessWidget {
  const _BibleBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () => context.push('/bible'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bible',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Télécharger et lire hors connexion',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
