import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../testimony/screens/shorts_screen.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';
import 'testimony_action_bar.dart';
import 'testimony_card_header.dart';
import 'testimony_stats_row.dart';

class VideoTestimonyCard extends ConsumerWidget {
  const VideoTestimonyCard({required this.testimony, super.key});

  final VideoTestimony testimony;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked  = ref.watch(likedIdsProvider).contains(testimony.id);
    final prayed = ref.watch(prayedIdsProvider).contains(testimony.id);
    final saved  = ref.watch(savedIdsProvider).contains(testimony.id);

    // Build the ordered list of VideoTestimonies from the full feed.
    void onPlayTap() {
      final allVideos = ref
          .read(feedNotifierProvider)
          .whereType<VideoTestimony>()
          .toList();
      final startIndex =
          allVideos.indexWhere((v) => v.id == testimony.id);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ShortsScreen(
            testimonies: allVideos,
            startIndex: startIndex < 0 ? 0 : startIndex,
          ),
        ),
      );
    }

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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top: catégorie + menu ─────────────────────────────────────
              Row(
                children: [
                  CategoryBadge(category: testimony.category),
                  const Spacer(),
                  _CardMenu(
                    isSaved: saved,
                    onSave: () => ref
                        .read(interactionProvider.notifier)
                        .toggleSave(testimony.id),
                    shareText:
                        '${testimony.title}\n\n'
                        'Partagé depuis l\'application Témoignages ✝️',
                    onReport: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signalement envoyé')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Titre ─────────────────────────────────────────────────────
              Text(
                testimony.title,
                style: AppTextStyles.h4.copyWith(fontSize: 17),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // ── Vignette vidéo ────────────────────────────────────────────
              _VideoThumbnail(testimony: testimony, onPlayTap: onPlayTap),
              const SizedBox(height: 12),

              // ── Auteur compact ────────────────────────────────────────────
              TestimonyAuthorRow(testimony: testimony),
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
                    text: '${testimony.title}\n\n'
                        'testi://app/testimony/${testimony.id}',
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

// ── Thumbnail ─────────────────────────────────────────────────────────────────

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.testimony, required this.onPlayTap});
  final VideoTestimony testimony;
  final VoidCallback onPlayTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              testimony.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.primary.withAlpha(20),
                child: const Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withAlpha(100)],
                ),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: onPlayTap,
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(220),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(50), blurRadius: 8),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8, right: 8,
              child: _DurationBadge(duration: testimony.formattedDuration),
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.duration});
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(170),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        duration,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
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
