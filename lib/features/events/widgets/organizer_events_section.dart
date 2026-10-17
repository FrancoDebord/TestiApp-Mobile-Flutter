// Événements organisés par un compte, sur son profil : à venir et en cours, puis passés
// (on y retrouve les témoignages et commentaires de l'événement, pour le revivre).
// API : GET /events?scope=upcoming|past&organizer_id=… — docs serveur fonctionnalites/evenements.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/events_repository.dart';
import '../models/event_models.dart';
import 'event_widgets.dart';
import '../../../l10n/app_localizations.dart';

/// Nombre d'événements montrés par liste sur le profil.
const _perList = 5;

final organizerEventsProvider = FutureProvider.autoDispose
    .family<({List<ChristianEvent> upcoming, List<ChristianEvent> past}), String>((ref, organizerId) async {
  final repo = ref.watch(eventsRepositoryProvider);
  final results = await Future.wait([
    repo.list(scope: EventScope.upcoming, organizerId: organizerId, limit: _perList),
    repo.list(scope: EventScope.past, organizerId: organizerId, limit: _perList),
  ]);
  return (upcoming: results[0].items, past: results[1].items);
});

/// Masquée tant que le compte n'a organisé aucun événement (ou en cas d'erreur).
class OrganizerEventsSection extends ConsumerWidget {
  const OrganizerEventsSection({required this.organizerId, this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 0), super.key});

  final String organizerId;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(organizerEventsProvider(organizerId)).value;
    if (data == null || (data.upcoming.isEmpty && data.past.isEmpty)) return const SizedBox.shrink();

    Widget list(String title, IconData icon, List<ChristianEvent> events) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: AppTextStyles.h4)),
            ]),
            const SizedBox(height: 10),
            for (final e in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EventCard(event: e, onTap: () => context.push('/events/${e.id}')),
              ),
          ],
        );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.upcoming.isNotEmpty) list(context.l10n.eventsUpcomingAndOngoing, Icons.event_rounded, data.upcoming),
          if (data.past.isNotEmpty) ...[
            if (data.upcoming.isNotEmpty) const SizedBox(height: 8),
            list(context.l10n.eventsPastEvents, Icons.history_rounded, data.past),
          ],
        ],
      ),
    );
  }
}
