// lib/features/home/widgets/feed_filter_bar.dart
//
// Filtre et tri du fil de témoignages : puce « Approuvés » (?verified=1, label
// « Témoignage approuvé ») et tri Pour vous / Récents / Populaires / Plus vus
// (?sort=). Docs serveur fonctionnalites/gestion-des-temoignages.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/home_providers.dart';

class FeedFilterBar extends ConsumerWidget {
  const FeedFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(feedQueryProvider);
    final notifier = ref.read(feedQueryProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          key: const ValueKey('feed-filter-verified'),
          selected: query.verifiedOnly,
          onSelected: notifier.setVerifiedOnly,
          showCheckmark: false,
          avatar: Icon(
            Icons.verified_rounded,
            size: 16,
            color: query.verifiedOnly ? AppColors.surface : AppColors.primary,
          ),
          label: const Text('Approuvés'),
          tooltip: 'Seulement les témoignages vérifiés par l\'équipe de modération',
          labelStyle: AppTextStyles.labelMedium.copyWith(
            color: query.verifiedOnly ? AppColors.surface : AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.primarySoft,
          side: BorderSide(color: query.verifiedOnly ? AppColors.primary : AppColors.border),
          shape: const StadiumBorder(),
        ),
        PopupMenuButton<FeedSort>(
          key: const ValueKey('feed-sort'),
          tooltip: 'Trier les témoignages',
          initialValue: query.effectiveSort,
          onSelected: notifier.setSort,
          itemBuilder: (_) => [
            for (final s in FeedSort.values)
              CheckedPopupMenuItem(
                value: s,
                checked: s == query.effectiveSort,
                // « Pour vous » ne se combine pas avec « Approuvés » (non filtré côté serveur).
                enabled: !(query.verifiedOnly && s == FeedSort.forYou),
                child: Text(s == FeedSort.forYou && query.verifiedOnly
                    ? '${s.label} (sans « Approuvés »)'
                    : s.label),
              ),
          ],
          child: Semantics(
            button: true,
            label: 'Tri : ${query.effectiveSort.label}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Tri : ${query.effectiveSort.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
