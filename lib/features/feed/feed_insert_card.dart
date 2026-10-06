import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../events/models/event_models.dart';
import '../events/widgets/event_widgets.dart';
import '../prayer/models/prayer_models.dart';
import '../prayer/widgets/prayer_widgets.dart';
import '../prophecies/models/public_prophecy.dart';
import '../prophecies/widgets/public_prophecy_feed_card.dart';

/// Élément inséré dans un fil de témoignages ([mixFeed]) : événement, session ou requête de
/// prière, parole prophétique publique, précédé d'une étiquette qui dit pourquoi il est là.
class FeedInsertCard extends StatelessWidget {
  const FeedInsertCard({required this.item, super.key});

  /// [ChristianEvent], [PrayerSession], [PrayerRequest] ou [PublicProphecy].
  final Object item;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      final ChristianEvent e => _Labeled(
          icon: Icons.event_rounded,
          label: e.organizer.displayName.isEmpty
              ? 'Événement à venir'
              : 'Événement · ${e.organizer.displayName}',
          child: EventCard(event: e, onTap: () => context.push('/events/${e.id}')),
        ),
      final PrayerRequest r => _Labeled(
          icon: Icons.volunteer_activism_rounded,
          label: r.event == null ? 'Requête de prière' : 'Requête de prière · ${r.event!.title}',
          child: PrayerRequestFeedCard(key: ValueKey('pr-${r.id}'), request: r, maxLines: 5),
        ),
      final PrayerSession s => _Labeled(
          icon: Icons.groups_2_rounded,
          label: s.host.displayName.isEmpty
              ? 'Session de prière'
              : 'Session de prière · ${s.host.displayName}',
          child: PrayerSessionCard(key: ValueKey('ps-${s.id}'), session: s),
        ),
      final PublicProphecy p => _Labeled(
          icon: Icons.record_voice_over_rounded,
          label: 'Parole prophétique accomplie · ${p.authorName}',
          child: PublicProphecyFeedCard(key: ValueKey('pp-${p.id}'), prophecy: p),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.icon, required this.label, required this.child});

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
}
