import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/utils/rich_text_utils.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';
import 'testimony_action_bar.dart';
import 'testimony_card_header.dart';
import 'testimony_stats_row.dart';

class TextTestimonyCard extends ConsumerStatefulWidget {
  const TextTestimonyCard({required this.testimony, super.key});

  final TextTestimony testimony;

  @override
  ConsumerState<TextTestimonyCard> createState() => _TextTestimonyCardState();
}

class _TextTestimonyCardState extends ConsumerState<TextTestimonyCard> {
  /// Extrait court et sans balises pour le message de partage (le lien mène
  /// au texte complet).
  static String _excerpt(String body) {
    final plain = stripFormatting(body).trim();
    if (plain.length <= 200) return plain;
    final cut = plain.lastIndexOf(' ', 200);
    return '${plain.substring(0, cut > 120 ? cut : 200).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    final testimony = widget.testimony;
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
                    onShare: () {
                      SharePlus.instance.share(ShareParams(
                        text: '${testimony.title}\n\n${_excerpt(testimony.preview)}\n\n'
                            '${testimony.shareLink}\n\n'
                            'Partagé depuis l\'application Témoignages ✝️',
                      ));
                      ref.read(interactionProvider.notifier)
                          .recordShare(testimony.id);
                    },
                    onReport: () =>
                        context.push('/testimony/${testimony.id}/report'),
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
              const SizedBox(height: 8),

              // ── Texte mis en forme, dévoilé morceau par morceau ───────────
              ProgressiveRichText(
                text: testimony.preview,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                initialChars: 220,
                stepChars: 500,
                // Non sélectionnable : le tap sur la carte ouvre le détail.
                selectable: false,
                linkStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
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
                    ? ref
                        .read(interactionProvider.notifier)
                        .removeReaction(testimony.id)
                    : ref
                        .read(interactionProvider.notifier)
                        .setReaction(testimony.id, type),
                onPray: () => ref
                    .read(interactionProvider.notifier)
                    .togglePray(testimony.id),
                onComment: () =>
                    context.push('/testimony/${testimony.id}/comments'),
                onShare: () {
                  SharePlus.instance.share(ShareParams(
                    text: '${testimony.title}\n\n'
                        '${testimony.shareLink}',
                  ));
                  ref
                      .read(interactionProvider.notifier)
                      .recordShare(testimony.id);
                },
              ),
            ],
          ),
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
    required this.onShare,
    required this.onReport,
  });

  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onShare;
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
            onShare();
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
