import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/content/encouragements.dart';
import '../../../shared/widgets/encouragement_card.dart';
import '../data/prophecies_repository.dart';
import '../models/prophecy.dart';
import '../providers/prophecies_providers.dart';
import '../widgets/prophecy_widgets.dart';

/// Paroles prophétiques du carnet privé : en attente / accomplies.
/// Elles sont visibles de vous seul ; quand l'une s'accomplit, vous en témoignez.
class PropheciesScreen extends ConsumerWidget {
  const PropheciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(propheciesListProvider);
    final list = async.value ?? const <Prophecy>[];
    final waiting = list.where((p) => !p.fulfilled).toList();
    final fulfilled = list.where((p) => p.fulfilled).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Paroles prophétiques'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: AppColors.surface,
          elevation: 0,
          bottom: TabBar(
            tabs: [
              Tab(text: 'En attente (${waiting.length})'),
              Tab(text: 'Accomplies (${fulfilled.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/prophecies/new'),
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nouvelle parole'),
        ),
        body: switch (async) {
          AsyncValue(:final error?) when async.value == null => _Error(
              message: error is ProphecyFailure ? error.message : 'Impossible de charger vos paroles.',
              onRetry: () => ref.invalidate(propheciesListProvider),
            ),
          AsyncValue(value: null) => const Center(child: CircularProgressIndicator()),
          _ => TabBarView(
              children: [
                _List(items: waiting, fulfilledTab: false),
                _List(items: fulfilled, fulfilledTab: true),
              ],
            ),
        },
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.items, required this.fulfilledTab});

  final List<Prophecy> items;
  final bool fulfilledTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(propheciesListProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 14, AppSpacing.screen, 96),
        children: [
          if (!fulfilledTab) ...[
            // Habakuk 2:3 en tête : la parole s'accomplira.
            EncouragementCard(message: prophecyVerses.first, compact: true, showAction: false),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Visibles de vous seul. Gardez-les, priez, puis témoignez de leur accomplissement.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: Column(
                children: [
                  Icon(fulfilledTab ? Icons.verified_outlined : Icons.record_voice_over_outlined,
                      size: 52, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    fulfilledTab
                        ? 'Aucune parole accomplie pour le moment. Quand une parole s\'accomplit, '
                            'ouvrez-la et touchez « Elle s\'est accomplie ».'
                        : 'Une parole reçue lors d\'un culte, d\'une prière, d\'un rêve ? '
                            'Notez-la ici (texte ou audio) pour la garder et prier dessus.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            for (final p in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ProphecyCard(prophecy: p, onTap: () => context.push('/prophecies/${p.id}')),
              ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
