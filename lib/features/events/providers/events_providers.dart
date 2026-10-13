import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/playback_preferences.dart' show FeedLayout;
import '../../../services/api_service.dart' show secureStorageProvider;
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;

import '../../home/models/testimony_model.dart';
import '../data/events_repository.dart';
import '../models/event_models.dart';

// ── Droits de création ───────────────────────────────────────────────────────

/// Organisations dont la personne connectée est gestionnaire (et si elles sont vérifiées).
final managedOrganizationsProvider =
    FutureProvider.autoDispose<List<(EventPerson, bool)>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const [];
  return ref.watch(eventsRepositoryProvider).managedOrganizations();
});

/// Peut créer des événements : administrateur, organisation vérifiée, ou
/// gestionnaire d'une organisation vérifiée (le serveur vérifie de toute façon).
final canCreateEventsProvider = Provider.autoDispose<bool>((ref) {
  final u = ref.watch(currentUserProvider);
  if (u == null) return false;
  if (u.isAdmin || (u.isOrganization && u.isVerified)) return true;
  final managed = ref.watch(managedOrganizationsProvider).value ?? const [];
  return managed.any((m) => m.$2);
});

/// Au nom de qui créer un événement (meta.organizations de GET /events?scope=mine).
final eventCreatorsProvider = FutureProvider.autoDispose<List<EventPerson>>(
  (ref) async => (await ref.watch(eventsRepositoryProvider).list(scope: EventScope.mine)).organizations,
);

// ── Affichage de la liste : cartes / liste compacte (mémorisé) ───────────────

/// Choix « Cartes » / « Liste compacte » de l'écran Événements, mémorisé
/// localement (stockage sécurisé, clé `event_layout`), comme l'affichage du fil.
class EventLayoutNotifier extends Notifier<FeedLayout> {
  static const _key = 'event_layout';

  @override
  FeedLayout build() {
    Future.microtask(_load);
    return FeedLayout.cards;
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(secureStorageProvider).read(key: _key);
      if (raw == FeedLayout.compact.name) state = FeedLayout.compact;
    } catch (_) {}
  }

  void set(FeedLayout layout) {
    if (layout == state) return;
    state = layout;
    unawaited(() async {
      try {
        await ref.read(secureStorageProvider).write(key: _key, value: layout.name);
      } catch (_) {}
    }());
  }
}

final eventLayoutProvider =
    NotifierProvider<EventLayoutNotifier, FeedLayout>(EventLayoutNotifier.new);

// ── Liste (paginée) ──────────────────────────────────────────────────────────

/// Filtre d'une liste d'événements ([query] : recherche titre / ville / lieu, `null` sinon).
typedef EventListKey = ({EventScope scope, EventType? type, String? query});

class EventListState {
  const EventListState({
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
    this.canCreate = false,
    this.loadingMore = false,
  });

  final List<ChristianEvent> items;
  final int page;
  final bool hasMore;
  final bool canCreate;
  final bool loadingMore;

  EventListState copyWith({
    List<ChristianEvent>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      EventListState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        canCreate: canCreate,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class EventListNotifier extends AsyncNotifier<EventListState> {
  EventListNotifier(this.key);
  final EventListKey key;

  EventsRepository get _repo => ref.read(eventsRepositoryProvider);

  @override
  Future<EventListState> build() async {
    final p = await _repo.list(scope: key.scope, type: key.type, query: key.query);
    return EventListState(items: p.items, hasMore: p.hasMore, canCreate: p.canCreate);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final p = await _repo.list(scope: key.scope, type: key.type, query: key.query, page: s.page + 1);
      state = AsyncData(s.copyWith(
        items: [...s.items, ...p.items],
        page: p.page,
        hasMore: p.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(s.copyWith(loadingMore: false));
    }
  }
}

final eventListProvider = AsyncNotifierProvider.autoDispose
    .family<EventListNotifier, EventListState, EventListKey>(EventListNotifier.new);

/// Prochains événements (bandeau de l'accueil).
final upcomingEventsProvider = FutureProvider.autoDispose<List<ChristianEvent>>(
  (ref) async => (await ref.watch(eventsRepositoryProvider).list()).items,
);

/// Événements à venir des comptes suivis (« Mon fil ») ; vide pour un invité.
final followingEventsProvider = FutureProvider.autoDispose<List<ChristianEvent>>(
  (ref) async {
    if (ref.watch(currentUserProvider) == null) return const [];
    return (await ref.watch(eventsRepositoryProvider).list(scope: EventScope.following)).items;
  },
);

// ── Détail ───────────────────────────────────────────────────────────────────

class EventDetailNotifier extends AsyncNotifier<ChristianEvent> {
  EventDetailNotifier(this.id);
  final String id;

  EventsRepository get _repo => ref.read(eventsRepositoryProvider);

  @override
  Future<ChristianEvent> build() => _repo.show(id);

  /// Remplace l'événement (après une action qui renvoie la version à jour).
  void replace(ChristianEvent e) => state = AsyncData(e);

  Future<void> reload() async {
    state = await AsyncValue.guard(() => _repo.show(id));
  }

  /// Répond à « Participer » ; même réponse = retirer sa réponse.
  /// Renvoie un message d'erreur, ou null.
  Future<String?> answer(EventParticipation answer) async {
    final current = state.value;
    try {
      final updated = current?.myParticipation == answer
          ? await _repo.cancelParticipation(id)
          : await _repo.participate(id, answer);
      state = AsyncData(updated);
      _refreshLists();
      return null;
    } on EventFailure catch (e) {
      return e.message;
    }
  }

  /// Exécute une action qui renvoie l'événement à jour (report, annulation,
  /// avis, modération). Renvoie un message d'erreur, ou null.
  Future<String?> apply(Future<ChristianEvent> Function(EventsRepository repo) action) async {
    try {
      state = AsyncData(await action(_repo));
      _refreshLists();
      ref.invalidate(eventReviewsProvider(id));
      return null;
    } on EventFailure catch (e) {
      return e.message;
    }
  }

  void _refreshLists() {
    ref.invalidate(eventListProvider);
    ref.invalidate(upcomingEventsProvider);
  }
}

/// Avis publics du sondage d'après l'événement (première page).
final eventReviewsProvider =
    FutureProvider.autoDispose.family<List<EventReviewItem>, String>(
  (ref, id) async => (await ref.watch(eventsRepositoryProvider).reviews(id)).items,
);

final eventDetailProvider = AsyncNotifierProvider.autoDispose
    .family<EventDetailNotifier, ChristianEvent, String>(EventDetailNotifier.new);

// ── Commentaires (témoignages des participants) ──────────────────────────────

class EventCommentsState {
  const EventCommentsState({
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<EventComment> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  EventCommentsState copyWith({
    List<EventComment>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      EventCommentsState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class EventCommentsNotifier extends AsyncNotifier<EventCommentsState> {
  EventCommentsNotifier(this.eventId);
  final String eventId;

  EventsRepository get _repo => ref.read(eventsRepositoryProvider);

  @override
  Future<EventCommentsState> build() async {
    final p = await _repo.comments(eventId);
    return EventCommentsState(items: p.items, hasMore: p.hasMore);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final p = await _repo.comments(eventId, page: s.page + 1);
      state = AsyncData(s.copyWith(
          items: [...s.items, ...p.items], page: p.page, hasMore: p.hasMore, loadingMore: false));
    } catch (_) {
      state = AsyncData(s.copyWith(loadingMore: false));
    }
  }

  /// Renvoie un message d'erreur, ou null.
  Future<String?> add(String body) async {
    try {
      final c = await _repo.addComment(eventId, body);
      final s = state.value ?? const EventCommentsState();
      state = AsyncData(s.copyWith(items: [c, ...s.items]));
      ref.invalidate(eventDetailProvider(eventId)); // compteur
      return null;
    } on EventFailure catch (e) {
      return e.message;
    }
  }

  Future<String?> delete(EventComment c) async {
    try {
      await _repo.deleteComment(eventId, c.id);
      final s = state.value ?? const EventCommentsState();
      state = AsyncData(s.copyWith(items: s.items.where((x) => x.id != c.id).toList()));
      return null;
    } on EventFailure catch (e) {
      return e.message;
    }
  }

  /// Enregistre le commentaire comme témoignage officiel.
  /// Renvoie (erreur, message de réussite).
  Future<(String?, String?)> promote(EventComment c, {String? title, String? category}) async {
    try {
      final (testimonyId, message) =
          await _repo.promote(eventId, c.id, title: title, category: category);
      final s = state.value ?? const EventCommentsState();
      state = AsyncData(s.copyWith(
        items: [for (final x in s.items) x.id == c.id ? x.copyWith(testimonyId: testimonyId) : x],
      ));
      ref.invalidate(eventTestimoniesProvider(eventId));
      ref.invalidate(eventDetailProvider(eventId));
      return (null, message);
    } on EventFailure catch (e) {
      return (e.message, null);
    }
  }
}

final eventCommentsProvider = AsyncNotifierProvider.autoDispose
    .family<EventCommentsNotifier, EventCommentsState, String>(EventCommentsNotifier.new);

// ── Témoignages officiels ────────────────────────────────────────────────────

final eventTestimoniesProvider =
    FutureProvider.autoDispose.family<List<Testimony>, String>(
  (ref, id) async => (await ref.watch(eventsRepositoryProvider).testimonies(id)).items,
);
