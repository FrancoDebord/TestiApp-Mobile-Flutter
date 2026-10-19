// Historique des versets du jour : un jour par carte, du plus récent au plus
// ancien, avec ses « J'aime », prières, commentaires et témoignages (et ses
// propres réactions en couleur). Toucher un jour ouvre son verset, avec les
// mêmes onglets que le verset du jour.
// Backend : docs/fonctionnalites/verset-du-jour.md (GET /daily-verse/history).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/verse_history_providers.dart';
import 'daily_verse_screen.dart';

const _kSerif = 'Lora'; // i18n-ignore : nom de police

class VerseHistoryScreen extends ConsumerWidget {
  const VerseHistoryScreen({super.key});

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  void _open(BuildContext context, VerseHistoryEntry e) {
    if (_isToday(e.date)) {
      openDailyVerse(context);
      return;
    }
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => DailyVerseScreen(verseId: e.id, date: e.date),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(verseHistoryProvider);
    return Scaffold(
      key: const ValueKey('verse-history'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(l10n.verseHistoryTitle,
            style: AppTextStyles.h4.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(verseHistoryProvider),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 600) ref.read(verseHistoryProvider.notifier).loadMore();
            return false;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 40),
            children: [
              Text(l10n.verseHistoryIntro,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              ...switch (async) {
                AsyncValue(:final value?) when value.items.isEmpty => [
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l10n.verseHistoryEmpty,
                          textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                    ),
                  ],
                AsyncValue(:final value?) => [
                    for (final e in value.items) ...[
                      _VerseDayCard(entry: e, isToday: _isToday(e.date), onTap: () => _open(context, e)),
                      const SizedBox(height: 12),
                    ],
                    if (value.loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                  ],
                AsyncValue(hasError: true) => [
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(l10n.verseHistoryLoadError,
                              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                          TextButton(
                            onPressed: () => ref.invalidate(verseHistoryProvider),
                            child: Text(l10n.commonRetry),
                          ),
                        ],
                      ),
                    ),
                  ],
                _ => const [
                    Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                  ],
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _VerseDayCard extends StatelessWidget {
  const _VerseDayCard({required this.entry, required this.isToday, required this.onTap});

  final VerseHistoryEntry entry;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = entry;
    Widget stat(IconData icon, int n, String label, {bool mine = false, Color? color}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: mine ? color : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('$n $label',
                style: AppTextStyles.bodySmall.copyWith(
                  color: mine ? color : AppColors.textSecondary,
                  fontWeight: mine ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        );
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: isToday ? AppColors.sunBorder : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (isToday) l10n.verseHistoryToday else formatWeekdayDate(e.date),
                        ?e.themeLabel,
                      ].join(' · ').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.secondaryDark,
                        fontSize: 11.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '« ${e.text.trim()} »',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: _kSerif, fontSize: 16.5, height: 1.5, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(e.reference,
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  stat(e.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, e.likes,
                      l10n.verseHistoryLikes, mine: e.isLiked, color: AppColors.danger),
                  stat(Icons.volunteer_activism_rounded, e.prayers, l10n.verseHistoryPrayers,
                      mine: e.isPrayed, color: AppColors.secondaryDark),
                  stat(Icons.chat_bubble_outline_rounded, e.comments, l10n.verseHistoryComments),
                  stat(Icons.auto_awesome_outlined, e.testimonies, l10n.verseHistoryTestimonies),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
