import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/playback_preferences.dart' show FeedLayout;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/events_repository.dart';
import '../models/event_models.dart';
import '../providers/events_providers.dart';
import '../widgets/event_widgets.dart';

/// Événements chrétiens : à venir, auxquels je participe, passés, les miens.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  EventType? _type;

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(currentUserProvider) != null;
    final canCreate = ref.watch(canCreateEventsProvider);
    final tabs = <(String, EventScope)>[
      ('À venir', EventScope.upcoming),
      if (loggedIn) ("J'y participe", EventScope.going),
      ('Passés', EventScope.past),
      if (canCreate) ('Mes événements', EventScope.mine),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Événements'),
          actions: const [_LayoutToggle()],
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: AppColors.surface,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Column(
              children: [
                _TypeFilter(
                  selected: _type,
                  onChanged: (t) => setState(() => _type = t),
                ),
                TabBar(
                  isScrollable: tabs.length > 3,
                  tabAlignment: tabs.length > 3 ? TabAlignment.start : null,
                  tabs: [for (final (label, _) in tabs) Tab(text: label)],
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: canCreate
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/events/new'),
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer un événement'),
              )
            : null,
        body: TabBarView(
          children: [
            for (final (_, scope) in tabs)
              _EventList(listKey: (scope: scope, type: _type)),
          ],
        ),
      ),
    );
  }
}

/// Bascule « Cartes » / « Liste compacte » (choix mémorisé : eventLayoutProvider).
class _LayoutToggle extends ConsumerWidget {
  const _LayoutToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = ref.watch(eventLayoutProvider) == FeedLayout.compact;
    return IconButton(
      tooltip: compact ? 'Affichage : cartes' : 'Affichage : liste compacte',
      icon: Icon(compact ? Icons.view_agenda_outlined : Icons.view_list_rounded),
      onPressed: () => ref
          .read(eventLayoutProvider.notifier)
          .set(compact ? FeedLayout.cards : FeedLayout.compact),
    );
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.selected, required this.onChanged});

  final EventType? selected;
  final ValueChanged<EventType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Tous'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final t in EventType.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(eventTypeIcon(t), size: 16),
                label: Text(t.label),
                selected: selected == t,
                onSelected: (_) => onChanged(selected == t ? null : t),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventList extends ConsumerWidget {
  const _EventList({required this.listKey});

  final EventListKey listKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventListProvider(listKey));
    final compact = ref.watch(eventLayoutProvider) == FeedLayout.compact;
    final empty = switch (listKey.scope) {
      EventScope.upcoming => 'Aucun événement à venir pour le moment.',
      EventScope.going => "Vous n'avez encore répondu « Je participe » à aucun événement.",
      EventScope.past => 'Aucun événement passé.',
      EventScope.mine => 'Vous n\'avez pas encore créé d\'événement.\nCroisade, conférence, camp… lancez-vous !',
      EventScope.following => 'Aucun événement à venir des comptes que vous suivez.',
    };

    return RefreshIndicator(
      onRefresh: () => ref.refresh(eventListProvider(listKey).future),
      child: switch (async) {
        AsyncValue(:final value?) when value.items.isEmpty =>
          _Message(icon: Icons.event_busy_rounded, text: empty),
        AsyncValue(:final value?) => NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 400) {
                ref.read(eventListProvider(listKey).notifier).loadMore();
              }
              return false;
            },
            child: ListView.separated(
              padding: compact
                  ? const EdgeInsets.fromLTRB(0, 4, 0, 96)
                  : const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 96),
              itemCount: value.items.length + (value.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => compact
                  ? const Divider(height: 1, thickness: 1, color: AppColors.border)
                  : const SizedBox(height: 14),
              itemBuilder: (context, i) {
                if (i >= value.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final e = value.items[i];
                void open() => context.push('/events/${e.id}');
                return compact
                    ? EventCompactTile(event: e, onTap: open)
                    : EventCard(event: e, onTap: open);
              },
            ),
          ),
        AsyncValue(:final error?) => _Message(
            icon: Icons.wifi_off_rounded,
            text: error is EventFailure ? error.message : 'Impossible de charger les événements.',
            action: TextButton(
              onPressed: () => ref.invalidate(eventListProvider(listKey)),
              child: const Text('Réessayer'),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
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
    // ListView : « tirer pour rafraîchir » reste possible.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
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
