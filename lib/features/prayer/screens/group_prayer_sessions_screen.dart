import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
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
      (context.l10n.prayerSessionsTabUpcoming, PrayerSessionScope.upcoming),
      if (loggedIn) (context.l10n.prayerSessionsTabJoined, PrayerSessionScope.joined),
      if (loggedIn) (context.l10n.prayerSessionsTabHosting, PrayerSessionScope.mine),
      (context.l10n.prayerSessionsTabPast, PrayerSessionScope.past),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(context.l10n.prayerGroupTitle),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: AppColors.surface,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: context.l10n.prayerTitle,
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
            if (!await requireAccount(context, ref, reason: context.l10n.prayerReasonSchedule)) return;
            if (context.mounted) context.push('/prayer-sessions/new');
          },
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.event_available_rounded),
          label: Text(context.l10n.prayerSchedule),
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
      PrayerSessionScope.joined => context.l10n.prayerSessionsEmptyJoined,
      PrayerSessionScope.mine => context.l10n.prayerSessionsEmptyHosting,
      PrayerSessionScope.past => context.l10n.prayerSessionsEmptyPast,
      _ => context.l10n.prayerSessionsEmpty,
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
            text: error is PrayerFailure ? error.message : context.l10n.prayerLoadSessionsError,
            action: TextButton(
              onPressed: () => ref.invalidate(prayerSessionListProvider(listKey)),
              child: Text(context.l10n.commonRetry),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
