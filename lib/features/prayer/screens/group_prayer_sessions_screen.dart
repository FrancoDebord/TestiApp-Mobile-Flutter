import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/guest_gate.dart' show requireAccount;
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/prayer_repository.dart';
import '../providers/prayer_providers.dart';
import '../widgets/prayer_widgets.dart';
import 'prayer_requests_screen.dart' show PrayerMessageView;

/// Sessions de prière : à venir, mes inscriptions, celles que j'anime, passées.
/// Docs serveur : fonctionnalites/sessions-de-priere.md
class GroupPrayerSessionsScreen extends ConsumerWidget {
  const GroupPrayerSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(currentUserProvider) != null;
    final tabs = <(String, PrayerSessionScope)>[
      ('À venir', PrayerSessionScope.upcoming),
      if (loggedIn) ('Mes inscriptions', PrayerSessionScope.joined),
      if (loggedIn) ("Que j'anime", PrayerSessionScope.mine),
      ('Passées', PrayerSessionScope.past),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Sessions de prière'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: AppColors.surface,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Requêtes de prière',
              icon: const Icon(Icons.volunteer_activism_outlined),
              onPressed: () => context.push('/prayer-requests'),
            ),
          ],
          bottom: TabBar(
            isScrollable: tabs.length > 2,
            tabAlignment: tabs.length > 2 ? TabAlignment.start : null,
            tabs: [for (final (label, _) in tabs) Tab(text: label)],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            if (!await requireAccount(context, ref, reason: 'programmer une session de prière')) return;
            if (context.mounted) context.push('/prayer-sessions/new');
          },
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.event_available_rounded),
          label: const Text('Programmer'),
        ),
        body: TabBarView(
          children: [for (final (_, scope) in tabs) _SessionList(listKey: (scope: scope, eventId: null))],
        ),
      ),
    );
  }
}

class _SessionList extends ConsumerWidget {
  const _SessionList({required this.listKey});
  final PrayerSessionListKey listKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(prayerSessionListProvider(listKey));
    final empty = switch (listKey.scope) {
      PrayerSessionScope.joined => "Vous n'êtes inscrit à aucune session.\nTouchez « Je serai là » sur une session à venir.",
      PrayerSessionScope.mine => "Vous n'animez aucune session.\nProgrammez un temps de prière : les inscrits seront prévenus.",
      PrayerSessionScope.past => 'Aucune session passée.',
      _ => 'Aucune session de prière programmée pour le moment.',
    };

    return RefreshIndicator(
      onRefresh: () => ref.refresh(prayerSessionListProvider(listKey).future),
      child: switch (async) {
        AsyncValue(:final value?) when value.items.isEmpty =>
          PrayerMessageView(icon: Icons.groups_2_outlined, text: empty),
        AsyncValue(:final value?) => NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 400) ref.read(prayerSessionListProvider(listKey).notifier).loadMore();
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 96),
              itemCount: value.items.length + (value.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) => i >= value.items.length
                  ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                  : PrayerSessionCard(session: value.items[i]),
            ),
          ),
        AsyncValue(:final error?) => PrayerMessageView(
            icon: Icons.wifi_off_rounded,
            text: error is PrayerFailure ? error.message : 'Impossible de charger les sessions.',
            action: TextButton(
              onPressed: () => ref.invalidate(prayerSessionListProvider(listKey)),
              child: const Text('Réessayer'),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
