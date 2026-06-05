import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';
import '../widgets/audio_testimony_card.dart';
import '../widgets/text_testimony_card.dart';
import '../widgets/video_testimony_card.dart';

// ============================================================================
// TrendingScreen
// ============================================================================

/// "Voir tout" screen — shown when the user taps "Voir tout" in the featured
/// carousel or trending sections on the home screen.
///
/// Widget tree:
/// DefaultTabController (length: 4)
///   └─ Scaffold
///       └─ NestedScrollView
///           ├─ headerSliverBuilder → SliverAppBar (pinned, TabBar.bottom)
///           └─ body → TabBarView
///               ├─ _TestimonyTab (featured)
///               ├─ _TestimonyTab (sorted by views)
///               ├─ _TestimonyTab (sorted by createdAt)
///               └─ _TestimonyTab (sorted by prayers)
class TrendingScreen extends ConsumerWidget {
  const TrendingScreen({super.key});

  static const _tabs = <Tab>[
    Tab(text: 'À la une'),
    Tab(text: 'Tendances'),
    Tab(text: 'Récents'),
    Tab(text: 'Plus priés'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredProvider);
    final all = ref.watch(feedNotifierProvider);

    // Sorted copies — avoid mutating the original lists
    final byViews = [...all]
      ..sort((a, b) => b.stats.views.compareTo(a.stats.views));

    final byDate = [...all]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final byPrayers = [...all]
      ..sort((a, b) => b.stats.prayers.compareTo(a.stats.prayers));

    return DefaultTabController(
      length: _tabs.length,
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
                'Tendances',
                style: AppTextStyles.h3.copyWith(fontSize: 18),
              ),
              centerTitle: false,
              bottom: TabBar(
                tabs: _tabs,
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
              _TestimonyTab(testimonies: featured, emptyLabel: 'Aucun témoignage à la une'),
              _TestimonyTab(testimonies: byViews,  emptyLabel: 'Aucune tendance disponible'),
              _TestimonyTab(testimonies: byDate,   emptyLabel: 'Aucun témoignage récent'),
              _TestimonyTab(testimonies: byPrayers, emptyLabel: 'Aucun témoignage prié'),
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
