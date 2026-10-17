import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';
import '../widgets/audio_testimony_card.dart';
import '../widgets/text_testimony_card.dart';
import '../widgets/video_testimony_card.dart';

// ============================================================================
// TrendingScreen
// ============================================================================

/// "Voir tout" screen — 8 tabs :
/// À la une · Tendances · Récents · Plus priés · Vidéos · Audios · Textes · Shorts
class TrendingScreen extends ConsumerWidget {
  const TrendingScreen({super.key});

  static List<Tab> _tabs(AppLocalizations l10n) => <Tab>[
        Tab(text: l10n.homeFeaturedTab),
        Tab(text: l10n.homeTrending),
        Tab(text: l10n.homeSortRecent),
        Tab(text: l10n.homeMostPrayed),
        Tab(text: l10n.homeTabVideos),
        Tab(text: l10n.homeTabAudios),
        Tab(text: l10n.homeTabTexts),
        Tab(text: l10n.navShorts),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tabs = _tabs(l10n);
    final featured  = ref.watch(featuredProvider);
    final all       = ref.watch(feedNotifierProvider);

    final byViews   = [...all]..sort((a, b) => b.stats.views.compareTo(a.stats.views));
    final byDate    = [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final byPrayers = [...all]..sort((a, b) => b.stats.prayers.compareTo(a.stats.prayers));
    final videos    = byDate.whereType<VideoTestimony>().toList();
    final audios    = byDate.whereType<AudioTestimony>().toList();
    final texts     = byDate.whereType<TextTestimony>().toList();
    // Shorts = vidéos courtes (≤ 60 s)
    final shorts    = videos.where((v) => v.durationSeconds <= 60).toList();

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 1,
              shadowColor: AppColors.border,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: AppColors.textPrimary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                l10n.homeViewAll,
                style: AppTextStyles.h3.copyWith(fontSize: 18),
              ),
              centerTitle: false,
              bottom: TabBar(
                tabs: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: AppColors.border,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _TestimonyTab(testimonies: featured, emptyLabel: l10n.homeEmptyFeatured),
              _TestimonyTab(testimonies: byViews,  emptyLabel: l10n.homeEmptyTrending),
              _TestimonyTab(testimonies: byDate,   emptyLabel: l10n.homeEmptyRecent),
              _TestimonyTab(testimonies: byPrayers, emptyLabel: l10n.homeEmptyPrayed),
              _TestimonyTab(testimonies: videos,   emptyLabel: l10n.homeEmptyVideos),
              _TestimonyTab(testimonies: audios,   emptyLabel: l10n.homeEmptyAudios),
              _TestimonyTab(testimonies: texts,    emptyLabel: l10n.homeEmptyTexts),
              _TestimonyTab(testimonies: shorts,   emptyLabel: l10n.homeEmptyShorts),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _TestimonyTab — vertical scrolling list for one tab
// ============================================================================

/// A scrollable vertical list of testimony cards for a single tab.
///
/// Dispatches to [TextTestimonyCard], [AudioTestimonyCard], or
/// [VideoTestimonyCard] based on the runtime type of each [Testimony].
class _TestimonyTab extends StatelessWidget {
  const _TestimonyTab({
    required this.testimonies,
    required this.emptyLabel,
  });

  final List<Testimony> testimonies;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (testimonies.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const BouncingScrollPhysics(),
      itemCount: testimonies.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _TestimonyCardDispatcher(testimony: testimonies[index]),
    );
  }
}

// ============================================================================
// _TestimonyCardDispatcher — type-based card switcher
// ============================================================================

class _TestimonyCardDispatcher extends StatelessWidget {
  const _TestimonyCardDispatcher({required this.testimony});

  final Testimony testimony;

  @override
  Widget build(BuildContext context) {
    return switch (testimony) {
      final TextTestimony t  => TextTestimonyCard(testimony: t),
      final AudioTestimony a => AudioTestimonyCard(testimony: a),
      final VideoTestimony v => VideoTestimonyCard(testimony: v),
    };
  }
}
