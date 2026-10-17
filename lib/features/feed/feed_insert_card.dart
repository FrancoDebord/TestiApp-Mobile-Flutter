import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../events/models/event_models.dart';
import '../events/widgets/event_widgets.dart';
import '../prayer/models/prayer_models.dart';
import '../prayer/widgets/prayer_widgets.dart';
import '../prophecies/models/public_prophecy.dart';
import '../prophecies/widgets/public_prophecy_feed_card.dart';
import '../repost/content_interactions.dart';
import '../repost/repost.dart' show RepostInfo;
import '../repost/repost_widgets.dart' show RepostHeader;

/// Élément inséré dans un fil de témoignages ([mixFeed]) : événement, session ou requête de
/// prière, parole prophétique publique, précédé d'une étiquette qui dit pourquoi il est là
/// (« X a partagé » le cas échéant) et suivi des réactions (j'aime, je prie, partager).
class FeedInsertCard extends StatelessWidget {
  const FeedInsertCard({required this.item, super.key});

  /// [ChristianEvent], [PrayerSession], [PrayerRequest] ou [PublicProphecy].
  final Object item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (item) {
      final ChristianEvent e => _Labeled(
          icon: e.phase == EventPhase.past ? Icons.history_rounded : Icons.event_rounded,
          // À venir, en cours, ou passé (à revivre : témoignages et commentaires).
          label: [
            switch (e.phase) {
              EventPhase.past => l10n.feedEventPast,
              EventPhase.ongoing => l10n.feedEventOngoing,
              EventPhase.upcoming => l10n.feedEventUpcoming,
            },
            if (e.organizer.displayName.isNotEmpty) e.organizer.displayName,
          ].join(' · '),
          repost: e.repost,
          reactions: ContentReactionBar(
            key: ValueKey('rx-e-${e.id}'),
            kind: ContentKind.event,
            id: e.id,
            initial: e.reactions,
            title: e.title,
            webUrl: e.webUrl,
            dense: true,
          ),
          child: EventCard(event: e, onTap: () => context.push('/events/${e.id}')),
        ),
      final PrayerRequest r => _Labeled(
          icon: Icons.volunteer_activism_rounded,
          label: r.event == null ? l10n.feedPrayerRequest : l10n.feedPrayerRequestEvent(r.event!.title),
          repost: r.repost,
          reactions: ContentReactionBar(
            key: ValueKey('rx-r-${r.id}'),
            kind: ContentKind.prayerRequest,
            id: r.id,
            initial: r.reactions,
            title: l10n.feedPrayerRequestBy(r.authorName),
            webUrl: r.webUrl,
            showPray: false, // « Je prie » : bouton de la carte
            dense: true,
          ),
          child: PrayerRequestFeedCard(key: ValueKey('pr-${r.id}'), request: r, maxLines: 5),
        ),
      final PrayerSession s => _Labeled(
          icon: Icons.groups_2_rounded,
          label: s.host.displayName.isEmpty
              ? l10n.feedPrayerSession
              : l10n.feedPrayerSessionHost(s.host.displayName),
          repost: s.repost,
          reactions: ContentReactionBar(
            key: ValueKey('rx-s-${s.id}'),
            kind: ContentKind.prayerSession,
            id: s.id,
            initial: s.reactions,
            title: s.title,
            webUrl: s.webUrl,
            dense: true,
          ),
          child: PrayerSessionCard(key: ValueKey('ps-${s.id}'), session: s),
        ),
      final PublicProphecy p => _Labeled(
          icon: Icons.record_voice_over_rounded,
          label: l10n.feedProphecyFulfilled(p.authorName),
          child: PublicProphecyFeedCard(key: ValueKey('pp-${p.id}'), prophecy: p),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.icon, required this.label, required this.child, this.repost, this.reactions});

  final IconData icon;
  final String label;
  final Widget child;

  /// « X a partagé » au-dessus de l'étiquette.
  final RepostInfo? repost;

  /// Réactions sous la carte.
  final Widget? reactions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (repost != null) ...[
          RepostHeader(repost: repost!),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.secondary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.secondaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
        ?reactions,
      ],
    );
  }
}
