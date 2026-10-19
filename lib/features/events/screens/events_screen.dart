import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/playback_preferences.dart' show FeedLayout;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/search/search_suggestions.dart' show SearchScope;
import '../../../shared/widgets/search_autocomplete_field.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/events_repository.dart';
import '../models/event_models.dart';
import '../providers/events_providers.dart';
import '../providers/event_types_providers.dart' show eventTypesProvider;
import '../widgets/event_widgets.dart';
import '../../../l10n/app_localizations.dart';

/// Événements chrétiens : à venir, auxquels je participe, passés, les miens.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  EventType? _type;

  /// Recherche validée (titre, ville, lieu) ; null = pas de recherche.
  String? _query;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submitSearch(String q) {
    final v = q.trim();
    setState(() => _query = v.isEmpty ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    // Types d'événements gérés par les administrateurs (recharge à l'arrivée de la liste).
    ref.watch(eventTypesProvider);
    final loggedIn = ref.watch(currentUserProvider) != null;
    final canCreate = ref.watch(canCreateEventsProvider);
    final l10n = context.l10n;
    final tabs = <(String, EventScope)>[
      (l10n.eventsTabUpcoming, EventScope.upcoming),
      (l10n.eventsTabOngoing, EventScope.ongoing),
      if (loggedIn) (l10n.eventsTabGoing, EventScope.going),
      (l10n.eventsTabPast, EventScope.past),
      if (canCreate) (l10n.eventsTabMine, EventScope.mine),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(l10n.navEvents),
          actions: const [_LayoutToggle()],
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: AppColors.surface,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(152),
            child: Column(
              children: [
                // Recherche avec autocomplétion (GET /search/suggest?scope=events) ;
                // un résultat direct ouvre l'événement, la validation filtre la liste.
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 4, AppSpacing.screen, 4),
                  child: SearchAutocompleteField(
                    controller: _search,
                    scope: SearchScope.events,
                    recentKey: 'events',
                    hintText: l10n.eventsSearchHint,
                    onSubmitted: _submitSearch,
                    onChanged: (v) {
                      if (v.trim().isEmpty && _query != null) _submitSearch('');
                    },
                    onResultSelected: (r) {
                      if (r.route != null) context.push(r.route!);
                    },
                  ),
                ),
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
                label: Text(l10n.eventsCreate),
              )
            : null,
        body: TabBarView(
          children: [
            for (final (_, scope) in tabs)
              _EventList(listKey: (scope: scope, type: _type, query: _query)),
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
      tooltip: compact ? context.l10n.eventsLayoutCards : context.l10n.eventsLayoutCompact,
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
              label: Text(context.l10n.eventsAllTypes),
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
    final l10n = context.l10n;
    final empty = switch (listKey.scope) {
      EventScope.upcoming => l10n.eventsEmptyUpcoming,
      EventScope.going => l10n.eventsEmptyGoing,
      EventScope.ongoing => l10n.eventsEmptyOngoing,
      EventScope.past => l10n.eventsEmptyPast,
      EventScope.mine => l10n.eventsEmptyMine,
      EventScope.following => l10n.eventsEmptyFollowing,
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
            text: error is EventFailure ? error.message : l10n.eventsLoadError,
            action: TextButton(
              onPressed: () => ref.invalidate(eventListProvider(listKey)),
              child: Text(l10n.commonRetry),
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
