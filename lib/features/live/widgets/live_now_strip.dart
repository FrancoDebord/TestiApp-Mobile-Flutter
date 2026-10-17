import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../data/live_repository.dart' show livesIndexProvider;
import '../models/live_models.dart';
import 'live_widgets.dart';

/// Bandeau « En direct maintenant » des fils (Accueil, Mon fil) : directs à l'antenne,
/// en cartes défilant horizontalement. Masqué s'il n'y en a aucun (ou en cas d'erreur).
class LiveNowStrip extends ConsumerWidget {
  const LiveNowStrip({this.padding = const EdgeInsets.only(top: 16), super.key});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lives = (ref.watch(livesIndexProvider).value?.active ?? const <LiveSession>[])
        .where((l) => l.isOnAir)
        .toList();
    if (lives.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 8),
            child: Row(
              children: [
                // Pas de pastille ici : chaque carte a la sienne (et la place manque à 320 px).
                const Icon(Icons.sensors_rounded, size: 20, color: kLiveRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.l10n.liveNowCount(lives.length),
                    style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/lives'),
                  child: Text(context.l10n.liveSeeAll),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: lives.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => LiveNowCard(
                live: lives[i],
                width: lives.length == 1 ? MediaQuery.sizeOf(context).width - 32 : 264,
                onTap: () => context.push('/lives/${lives[i].id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'un direct en cours (bandeau des fils).
class LiveNowCard extends StatelessWidget {
  const LiveNowCard({required this.live, required this.onTap, this.width = 264, super.key});

  final LiveSession live;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final viewers = live.liveStats?.viewers;
    return SizedBox(
      width: width.clamp(220, 560),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const LiveBadge(),
                    const Spacer(),
                    if (viewers != null) LiveChip(icon: Icons.visibility_rounded, label: '$viewers'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  live.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    LiveAvatar(person: live.host, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        live.host.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
