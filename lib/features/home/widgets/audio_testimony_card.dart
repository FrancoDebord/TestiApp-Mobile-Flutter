import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';
import 'testimony_action_bar.dart';
import 'testimony_card_header.dart';
import 'testimony_stats_row.dart';

class AudioTestimonyCard extends ConsumerWidget {
  const AudioTestimonyCard({required this.testimony, super.key});

  final AudioTestimony testimony;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked  = ref.watch(likedIdsProvider).contains(testimony.id);
    final prayed = ref.watch(prayedIdsProvider).contains(testimony.id);
    final saved  = ref.watch(savedIdsProvider).contains(testimony.id);

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/testimony/${testimony.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TestimonyCardHeader(
                testimony: testimony,
                trailing: _CardMenu(
                  isSaved: saved,
                  onSave: () => ref
                      .read(interactionProvider.notifier)
                      .toggleSave(testimony.id),
                  shareText:
                      '${testimony.title}\n\n${testimony.transcriptPreview}\n\n'
                      'Partagé depuis l\'application Témoignages ✝️',
                  onReport: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signalement envoyé')),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                testimony.title,
                style: AppTextStyles.h4,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              _WaveformPlayer(testimony: testimony),
              const SizedBox(height: 10),

              Text(
                testimony.transcriptPreview,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              TestimonyStatsRow(stats: testimony.stats),
              const Divider(height: 20, color: AppColors.border),

              TestimonyActionBar(
                testimony: testimony,
                isLiked: liked,
                isPrayed: prayed,
                currentReaction: ref.watch(reactionsMapProvider)[testimony.id],
                onReact: (type) => type == null
                    ? ref.read(interactionProvider.notifier).removeReaction(testimony.id)
                    : ref.read(interactionProvider.notifier).setReaction(testimony.id, type),
                onPray: () => ref
                    .read(interactionProvider.notifier)
                    .togglePray(testimony.id),
                onComment: () =>
                    context.push('/testimony/${testimony.id}/comments'),
                onShare: () => SharePlus.instance.share(
                  ShareParams(
                    text: '${testimony.title}\n\n${testimony.transcriptPreview}\n\n'
                        'Partagé depuis l\'application Témoignages ✝️',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Waveform player ────────────────────────────────────────────────────────────

class _WaveformPlayer extends StatelessWidget {
  const _WaveformPlayer({required this.testimony});
  final AudioTestimony testimony;

  static const List<double> _bars = [
    0.3, 0.6, 0.4, 0.9, 0.7, 0.5, 0.8, 0.4, 0.6, 0.3,
    0.7, 0.5, 0.9, 0.4, 0.6, 0.8, 0.3, 0.7, 0.5, 0.4,
    0.9, 0.6, 0.3, 0.8, 0.5, 0.7, 0.4, 0.6, 0.3, 0.9,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(25)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                _PlayButton(onTap: () => context.push('/testimony/${testimony.id}')),
                const SizedBox(width: 12),
                Expanded(child: _WaveformBars(bars: _bars)),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 10,
            child: _DurationBadge(duration: testimony.formattedDuration),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _WaveformBars extends StatelessWidget {
  const _WaveformBars({required this.bars});
  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: bars.asMap().entries.map((e) {
        final played = e.key / bars.length < 0.40;
        return Container(
          width: 3,
          height: 40 * e.value,
          decoration: BoxDecoration(
            color: played
                ? AppColors.primary
                : AppColors.primary.withAlpha(40),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.duration});
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(180),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        duration,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── 3-dot context menu ────────────────────────────────────────────────────────

class _CardMenu extends StatelessWidget {
  const _CardMenu({
    required this.isSaved,
    required this.onSave,
    required this.shareText,
    required this.onReport,
  });

  final bool isSaved;
  final VoidCallback onSave;
  final String shareText;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      iconColor: AppColors.textSecondary,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'save':
            onSave();
          case 'share':
            SharePlus.instance.share(ShareParams(text: shareText));
          case 'report':
            onReport();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
                size: 18,
                color: isSaved ? AppColors.primary : null,
              ),
              const SizedBox(width: 10),
              Text(isSaved ? 'Enlever des sauvegardes' : 'Sauvegarder'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share_outlined, size: 18),
              SizedBox(width: 10),
              Text('Partager'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Signaler', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }
}
