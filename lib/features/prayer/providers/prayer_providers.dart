import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prayer_repository.dart';
import '../models/prayer_models.dart';

// ── Requêtes : une page (fils, page d'un événement) ──────────────────────────

/// Première page d'un scope de requêtes, ex. `prayerRequestsPageProvider((PrayerRequestScope.feed, null))`
/// ou `((PrayerRequestScope.event, eventId))`. Pensé pour les fils « Pour vous » / « Mon fil » et
/// la page d'un événement (cartes [PrayerRequestFeedCard]).
final prayerRequestsPageProvider = FutureProvider.autoDispose
    .family<PrayerPage<PrayerRequest>, (PrayerRequestScope, String?)>(
  (ref, key) => ref.watch(prayerRepositoryProvider).requests(scope: key.$1, eventId: key.$2),
);

// ── Requêtes : liste paginée (écran « Requêtes de prière ») ──────────────────

typedef PrayerRequestListKey = ({PrayerRequestScope scope, bool answeredOnly});

class PrayerListState<T> {
  const PrayerListState({
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<T> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  PrayerListState<T> copyWith({List<T>? items, int? page, bool? hasMore, bool? loadingMore}) =>
      PrayerListState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class PrayerRequestListNotifier extends AsyncNotifier<PrayerListState<PrayerRequest>> {
  PrayerRequestListNotifier(this.key);
  final PrayerRequestListKey key;

  PrayerRepository get _repo => ref.read(prayerRepositoryProvider);

  @override
  Future<PrayerListState<PrayerRequest>> build() async {
    final p = await _repo.requests(scope: key.scope, answeredOnly: key.answeredOnly);
    return PrayerListState(items: p.items, hasMore: p.hasMore);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final p = await _repo.requests(scope: key.scope, answeredOnly: key.answeredOnly, page: s.page + 1);
      state = AsyncData(s.copyWith(items: [...s.items, ...p.items], page: p.page, hasMore: p.hasMore, loadingMore: false));
    } catch (_) {
      state = AsyncData(s.copyWith(loadingMore: false));
    }
  }

  /// Remplace une requête (après « Je prie », exaucée…).
  void replace(PrayerRequest r) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(items: [for (final i in s.items) i.id == r.id ? r : i]));
  }

  void remove(String id) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(items: s.items.where((i) => i.id != id).toList()));
  }
}

final prayerRequestListProvider = AsyncNotifierProvider.autoDispose
    .family<PrayerRequestListNotifier, PrayerListState<PrayerRequest>, PrayerRequestListKey>(
        PrayerRequestListNotifier.new);

// ── Requête : détail et messages ─────────────────────────────────────────────

class PrayerRequestNotifier extends AsyncNotifier<PrayerRequest> {
  PrayerRequestNotifier(this.id);
  final String id;

  @override
  Future<PrayerRequest> build() => ref.read(prayerRepositoryProvider).request(id);

  void replace(PrayerRequest r) => state = AsyncData(r);
}

final prayerRequestProvider =
    AsyncNotifierProvider.autoDispose.family<PrayerRequestNotifier, PrayerRequest, String>(PrayerRequestNotifier.new);

/// Messages d'encouragement d'une requête (du plus ancien au plus récent).
final prayerMessagesProvider = FutureProvider.autoDispose.family<List<PrayerMessage>, String>(
  (ref, id) => ref.watch(prayerRepositoryProvider).messages(id),
);

// ── Sessions ─────────────────────────────────────────────────────────────────

typedef PrayerSessionListKey = ({PrayerSessionScope scope, String? eventId});

class PrayerSessionListNotifier extends AsyncNotifier<PrayerListState<PrayerSession>> {
  PrayerSessionListNotifier(this.key);
  final PrayerSessionListKey key;

  PrayerRepository get _repo => ref.read(prayerRepositoryProvider);

  @override
  Future<PrayerListState<PrayerSession>> build() async {
    final p = await _repo.sessions(scope: key.scope, eventId: key.eventId);
    return PrayerListState(items: p.items, hasMore: p.hasMore);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final p = await _repo.sessions(scope: key.scope, eventId: key.eventId, page: s.page + 1);
      state = AsyncData(s.copyWith(items: [...s.items, ...p.items], page: p.page, hasMore: p.hasMore, loadingMore: false));
    } catch (_) {
      state = AsyncData(s.copyWith(loadingMore: false));
    }
  }
}

final prayerSessionListProvider = AsyncNotifierProvider.autoDispose
    .family<PrayerSessionListNotifier, PrayerListState<PrayerSession>, PrayerSessionListKey>(
        PrayerSessionListNotifier.new);

class PrayerSessionNotifier extends AsyncNotifier<PrayerSession> {
  PrayerSessionNotifier(this.id);
  final String id;

  @override
  Future<PrayerSession> build() => ref.read(prayerRepositoryProvider).session(id);

  void replace(PrayerSession s) => state = AsyncData(s);

  Future<void> reload() async {
    state = await AsyncValue.guard(() => ref.read(prayerRepositoryProvider).session(id));
  }
}

final prayerSessionProvider =
    AsyncNotifierProvider.autoDispose.family<PrayerSessionNotifier, PrayerSession, String>(PrayerSessionNotifier.new);
