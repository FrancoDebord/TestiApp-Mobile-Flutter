import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/prayer_repository.dart';
import '../models/prayer_models.dart';
import 'prayer_widgets.dart';

/// Sessions de prière programmées (à venir et en cours) : GET /prayer/sessions?scope=upcoming.
/// Vide en cas d'erreur réseau (le bandeau est alors masqué).
final upcomingPrayerSessionsProvider = FutureProvider.autoDispose<List<PrayerSession>>((ref) async {
  try {
    return (await ref.watch(prayerRepositoryProvider).sessions()).items;
  } catch (_) {
    return const [];
  }
});

/// Bandeau « Sessions de prière à venir » de l'accueil, à côté des événements
/// (masqué s'il n'y en a aucune). Même bloc sur l'accueil du site (prayer/partials/upcoming-strip).
class UpcomingPrayerSessionsStrip extends ConsumerWidget {
  const UpcomingPrayerSessionsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(upcomingPrayerSessionsProvider).value ?? const [];
    if (sessions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 8),
            child: Row(
              children: [
                const Icon(Icons.groups_2_rounded, size: 20, color: AppColors.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sessions de prière à venir',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/prayer-sessions'),
                  child: const Text('Tout voir'),
                ),
              ],
            ),
          ),
          // Hauteur suivant la taille du texte (police agrandie : pas de débordement).
          SizedBox(
            height: 196 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sessions.length.clamp(0, 10),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => SizedBox(
                width: 260,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: PrayerSessionCard(session: sessions[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
