import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/guest_gate.dart' show requireAccount;
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/prayer_repository.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';
import '../widgets/prayer_widgets.dart';

/// Requêtes de prière : toutes celles que je peux voir, ou les miennes ; filtre « Exaucées ».
/// Docs serveur : fonctionnalites/requetes-de-priere.md
class PrayerRequestsScreen extends ConsumerStatefulWidget {
  const PrayerRequestsScreen({super.key});

  @override
  ConsumerState<PrayerRequestsScreen> createState() => _PrayerRequestsScreenState();
}

class _PrayerRequestsScreenState extends ConsumerState<PrayerRequestsScreen> {
  bool _answeredOnly = false;

  Future<void> _create() async {
    if (!await requireAccount(context, ref, reason: 'confier une requête de prière')) return;
    if (!mounted) return;
    final created = await context.push<PrayerRequest>('/prayer-requests/new');
    if (created != null) {
      ref.invalidate(prayerRequestListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(currentUserProvider) != null;
    final tabs = <(String, PrayerRequestScope)>[
      ('Toutes', PrayerRequestScope.all),
      if (loggedIn) ('Mes requêtes', PrayerRequestScope.mine),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Requêtes de prière'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: AppColors.surface,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Sessions de prière',
              icon: const Icon(Icons.groups_2_outlined),
              onPressed: () => context.push('/prayer-sessions'),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(tabs.length > 1 ? 96 : 48),
            child: Column(children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: 6),
                  children: [
                    ChoiceChip(
                      label: const Text('Toutes'),
                      selected: !_answeredOnly,
                      onSelected: (_) => setState(() => _answeredOnly = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Exaucées'),
                      selected: _answeredOnly,
                      onSelected: (_) => setState(() => _answeredOnly = !_answeredOnly),
                    ),
                  ],
                ),
              ),
              if (tabs.length > 1) TabBar(tabs: [for (final (label, _) in tabs) Tab(text: label)]),
            ]),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Confier une requête'),
        ),
        body: TabBarView(
          children: [
            for (final (_, scope) in tabs) _RequestList(listKey: (scope: scope, answeredOnly: _answeredOnly)),
          ],
        ),
      ),
    );
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList({required this.listKey});
  final PrayerRequestListKey listKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(prayerRequestListProvider(listKey));
    final empty = listKey.scope == PrayerRequestScope.mine
        ? "Vous n'avez pas encore confié de requête.\nLa communauté priera avec vous — vous pouvez rester anonyme."
        : listKey.answeredOnly
            ? 'Aucune requête exaucée pour le moment.'
            : 'Aucune requête de prière pour le moment.\nSoyez le premier à confier un besoin.';

    return RefreshIndicator(
      onRefresh: () => ref.refresh(prayerRequestListProvider(listKey).future),
      child: switch (async) {
        AsyncValue(:final value?) when value.items.isEmpty =>
          PrayerMessageView(icon: Icons.volunteer_activism_outlined, text: empty, verse: true),
        AsyncValue(:final value?) => NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 400) {
                ref.read(prayerRequestListProvider(listKey).notifier).loadMore();
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 96),
              itemCount: value.items.length + 1 + (value.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                if (i == 0) return const _VerseBanner();
                final index = i - 1;
                if (index >= value.items.length) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                }
                final r = value.items[index];
                return PrayerRequestFeedCard(
                  key: ValueKey(r.id),
                  request: r,
                  onChanged: ref.read(prayerRequestListProvider(listKey).notifier).replace,
                );
              },
            ),
          ),
        AsyncValue(:final error?) => PrayerMessageView(
            icon: Icons.wifi_off_rounded,
            text: error is PrayerFailure ? error.message : 'Impossible de charger les requêtes.',
            action: TextButton(
              onPressed: () => ref.invalidate(prayerRequestListProvider(listKey)),
              child: const Text('Réessayer'),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Jacques 5:16, en tête de liste.
class _VerseBanner extends StatelessWidget {
  const _VerseBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.sunSoft,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.sunBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '« Priez les uns pour les autres, afin que vous soyez guéris. '
              'La prière agissante du juste a une grande efficacité. »',
              style: AppTextStyles.bodyMedium.copyWith(fontStyle: FontStyle.italic, color: AppColors.textPrimary, height: 1.45),
            ),
            const SizedBox(height: 6),
            Text('Jacques 5:16', style: AppTextStyles.labelMedium.copyWith(color: AppColors.sunText)),
          ],
        ),
      );
}

/// Message plein écran (vide, erreur) qui garde « tirer pour rafraîchir ».
class PrayerMessageView extends StatelessWidget {
  const PrayerMessageView({required this.icon, required this.text, this.action, this.verse = false, super.key});

  final IconData icon;
  final String text;
  final Widget? action;
  final bool verse;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        if (verse) ...[const _VerseBanner(), const SizedBox(height: 24)] else SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        Icon(icon, size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 14),
        Text(text, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        if (action != null) Center(child: action),
      ],
    );
  }
}
