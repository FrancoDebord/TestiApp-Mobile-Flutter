// Événements passés : revivre les témoignages de ceux qui y étaient.
// Bande de l'accueil (« Revivre les événements ») et carte des listes.
// Backend : docs/fonctionnalites/evenements.md (GET events?scope=past).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../models/event_models.dart';
import '../providers/events_providers.dart';
import 'event_widgets.dart';

/// Ouvre l'événement (onglet « Témoignages », ouvert par défaut).
void openPastEvent(BuildContext context, ChristianEvent e) => context.push('/events/${e.id}');

/// Bande « Revivre les événements passés » de l'accueil (masquée s'il n'y en a aucun).
class PastEventsStrip extends ConsumerWidget {
  const PastEventsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(pastEventsHomeProvider).value ?? const <ChristianEvent>[];
    if (events.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 8),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 20, color: AppColors.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.pastEventsTitle,
                          style: AppTextStyles.h4.copyWith(
                              fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      Text(l10n.pastEventsSubtitle,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/events/past'),
                  child: Text(l10n.eventsSeeAll),
                ),
              ],
            ),
          ),
          SizedBox(
            // Image (104) + texte et bouton, qui grandissent avec la taille du texte.
            height: 104 + 132 * (MediaQuery.textScalerOf(context).scale(14) / 14),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: events.length.clamp(0, 10),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => SizedBox(
                width: 250,
                child: PastEventCard(event: events[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'un événement passé : image, dates, lieu, nombre de témoignages et
/// « Revivre les témoignages ».
class PastEventCard extends StatelessWidget {
  const PastEventCard({required this.event, this.imageHeight = 104, super.key});

  final ChristianEvent event;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final l10n = context.l10n;
    final place = [e.city, e.country].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openPastEvent(context, e),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: imageHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventCoverImage(event: e),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _TestimonyCountPill(count: e.testimonyCount),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontFamily: AppFonts.family,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (e.startsAt != null) formatEventDay(e.startsAt!),
                        if (place.isNotEmpty) place,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: AppFonts.family,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => openPastEvent(context, e),
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                    label: Text(
                      e.testimonyCount > 0 ? l10n.pastEventsRelive : l10n.pastEventsOpen,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

class _TestimonyCountPill extends StatelessWidget {
  const _TestimonyCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: count > 0 ? AppColors.sun : Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 13, color: count > 0 ? AppColors.primaryDark : Colors.white),
          const SizedBox(width: 4),
          Text(
            context.l10n.pastEventsTestimonyCount(count),
            style: TextStyle(
              fontFamily: AppFonts.family,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: count > 0 ? AppColors.primaryDark : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
