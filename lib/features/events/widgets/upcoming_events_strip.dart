import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/events_providers.dart';
import 'event_widgets.dart';

/// Bandeau « Événements à venir » de l'accueil (masqué s'il n'y en a aucun).
class UpcomingEventsStrip extends ConsumerWidget {
  const UpcomingEventsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(upcomingEventsProvider).value ?? const [];
    if (events.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 8),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, size: 20, color: AppColors.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Événements à venir',
                    style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/events'),
                  child: const Text('Tout voir'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: events.length.clamp(0, 10),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => EventMiniCard(
                event: events[i],
                onTap: () => context.push('/events/${events[i].id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
