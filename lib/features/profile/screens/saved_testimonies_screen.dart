import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../features/downloads/providers/downloads_provider.dart';
import '../../../features/downloads/widgets/download_tile.dart';
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../features/home/widgets/testimony_feed_item.dart';
import '../../../l10n/app_localizations.dart';

class SavedTestimoniesScreen extends ConsumerWidget {
  const SavedTestimoniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedIds = ref.watch(savedIdsProvider);
    final allFeed  = ref.watch(feedNotifierProvider);
    final l10n = context.l10n;

    // Tab 1 — all saved testimonies (in feed order)
    final savedList = allFeed.where((t) => savedIds.contains(t.id)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            l10n.profileSaved,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: AppColors.border,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          bottom: TabBar(
            labelStyle: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: AppTextStyles.labelMedium,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            tabs: [
              Tab(text: l10n.profileSavedTab),
              Tab(text: l10n.profileOfflineTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SavedTab(testimonies: savedList),
            const _OfflineTab(),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Sauvegardés ────────────────────────────────────────────────────────

class _SavedTab extends StatelessWidget {
  const _SavedTab({required this.testimonies});

  final List<Testimony> testimonies;

  @override
  Widget build(BuildContext context) {
    if (testimonies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border_rounded,
                size: 56,
                color: AppColors.textSecondary.withAlpha(80),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.profileNoSaved,
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.profileNoSavedHint,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: testimonies.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _card(testimonies[i]),
    );
  }

  Widget _card(Testimony t) =>
      TestimonyFeedItem(key: ValueKey(t.id), testimony: t);
}

// ── Tab 2: Hors ligne (vrais téléchargements) ────────────────────────────────

class _OfflineTab extends ConsumerWidget {
  const _OfflineTab();

  void _openDownloads(BuildContext context) =>
      GoRouter.maybeOf(context)?.push(AppPaths.downloadsPath);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(downloadsProvider);
    final entries = s.sortedEntries;

    if (!s.supported || entries.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_for_offline_outlined,
                size: 56,
                color: AppColors.textSecondary.withAlpha(80),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.profileNoOffline,
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                s.supported
                    ? context.l10n.profileNoOfflineHint
                    : context.l10n.profileDownloadsMobileOnly,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (s.supported) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _openDownloads(context),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(context.l10n.profileDownloads),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.lg),
      children: [
        for (final e in entries) DownloadTile(key: ValueKey(e.id), entry: e),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => _openDownloads(context),
          icon: const Icon(Icons.download_rounded),
          label: Text(
            context.l10n.profileManageDownloads,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
