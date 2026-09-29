import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/live_repository.dart';
import '../models/live_models.dart';
import '../widgets/live_widgets.dart';

/// Directs en cours et récents ; « Lancer un direct » pour les modérateurs.
class LivesScreen extends ConsumerStatefulWidget {
  const LivesScreen({super.key});

  @override
  ConsumerState<LivesScreen> createState() => _LivesScreenState();
}

class _LivesScreenState extends ConsumerState<LivesScreen> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    // La liste suit l'arrivée et la fin des directs.
    _refresh = Timer.periodic(
        const Duration(seconds: 20), (_) => ref.invalidate(livesIndexProvider));
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  void _openLive(LiveSession live) {
    // Son propre direct pas encore terminé → retour au studio (reprise).
    if (live.isHost && live.status != LiveStatus.ended) {
      context.push('/lives/${live.id}/studio');
    } else {
      context.push('/lives/${live.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(livesIndexProvider);
    final index = async.value;
    final canGoLive = (index?.canGoLive ?? false) && (index?.configured ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Directs'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: canGoLive
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/lives/new'),
              backgroundColor: kLiveRed,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.sensors_rounded),
              label: const Text('Lancer un direct'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(livesIndexProvider.future),
        child: switch (async) {
          AsyncValue(:final value?) => _List(index: value, onOpen: _openLive),
          AsyncValue(:final error?) => _Message(
              icon: Icons.wifi_off_rounded,
              text: error is LiveFailure
                  ? error.message
                  : 'Impossible de charger les directs.',
              action: TextButton(
                onPressed: () => ref.invalidate(livesIndexProvider),
                child: const Text('Réessayer'),
              ),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.index, required this.onOpen});

  final LivesIndex index;
  final void Function(LiveSession) onOpen;

  @override
  Widget build(BuildContext context) {
    if (!index.configured) {
      return const _Message(
        icon: Icons.videocam_off_outlined,
        text: 'Les directs ne sont pas encore disponibles.\n'
            'Le service vidéo doit être configuré sur le serveur.',
      );
    }
    if (index.active.isEmpty && index.recent.isEmpty) {
      return _Message(
        icon: Icons.live_tv_rounded,
        text: index.canGoLive
            ? 'Aucun direct pour le moment.\nLancez le premier !'
            : 'Aucun direct pour le moment.\nRevenez bientôt.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (index.active.isNotEmpty) ...[
          _SectionTitle('En direct', count: index.active.length),
          for (final live in index.active)
            _ActiveCard(live: live, onTap: () => onOpen(live)),
          const SizedBox(height: 12),
        ],
        if (index.recent.isNotEmpty) ...[
          const _SectionTitle('Récents'),
          for (final live in index.recent)
            _RecentTile(live: live, onTap: () => onOpen(live)),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.count});
  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(text, style: AppTextStyles.h4),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: kLiveRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.live, required this.onTap});

  final LiveSession live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final viewers = live.liveStats?.viewers;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF103675), Color(0xFF184797), Color(0xFFF18717)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  live.isOnAir
                      ? const LiveBadge()
                      : const LiveBadge(
                          label: 'EN PRÉPARATION', color: Color(0xFF475467)),
                  const Spacer(),
                  if (viewers != null)
                    LiveChip(icon: Icons.visibility_rounded, label: '$viewers'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                live.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              if ((live.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  live.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  LiveAvatar(person: live.host, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      live.host.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(live.isHost ? 'Reprendre' : 'Regarder'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.live, required this.onTap});

  final LiveSession live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (live.duration != null) formatLiveDuration(live.duration!),
      '${live.peakViewers} spectateur${live.peakViewers > 1 ? 's' : ''}',
      '${live.commentCount} commentaire${live.commentCount > 1 ? 's' : ''}',
    ].join(' · ');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: LiveAvatar(person: live.host, size: 40),
        title: Text(live.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${live.host.displayName}\n$details',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // ListView : le « tirer pour rafraîchir » reste possible.
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
        Icon(icon, size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        if (action != null) Center(child: action),
      ],
    );
  }
}
