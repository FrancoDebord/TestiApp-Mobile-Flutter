// lib/features/explore/screens/search_results_screen.dart
//
// Résultats d'une recherche ouverte par lien (/explore/search?q=…) :
// onglets de type + liste des témoignages correspondants (filtrage local).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/providers/home_providers.dart';
import '../../home/widgets/pill_tabs.dart';
import '../../home/widgets/testimony_feed_item.dart';
import '../models/explore_models.dart';
import '../providers/explore_providers.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({required this.query, super.key});
  final String query;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  ExploreTypeFilter _type = ExploreTypeFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = filterTestimonies(
      ref.watch(feedNotifierProvider),
      query: widget.query,
      type: _type,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        title: Text(
          '${l10n.searchResults} : ${widget.query}',
          style: AppTextStyles.h4,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: PillTabs<ExploreTypeFilter>(
                tabs: [for (final f in kExploreTypeTabs) PillTab(f, f.tabLabel)],
                selected: _type,
                onSelected: (f) => setState(() => _type = f),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                '${results.length} témoignage${results.length > 1 ? 's' : ''}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 56,
                        color: AppColors.textSecondary.withAlpha(90)),
                    const SizedBox(height: 12),
                    Text(
                      l10n.searchResultsBody,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => TestimonyFeedItem(
                  key: ValueKey(results[i].id),
                  testimony: results[i],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
