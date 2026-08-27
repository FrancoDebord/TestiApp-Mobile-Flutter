import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart';
import '../models/explore_models.dart';

// ── Recherche ─────────────────────────────────────────────────────────────────

class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider =
    NotifierProvider<_SearchQueryNotifier, String>(_SearchQueryNotifier.new);

class _SearchBarActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void update(bool value) => state = value;
}

final searchBarActiveProvider =
    NotifierProvider<_SearchBarActiveNotifier, bool>(
  _SearchBarActiveNotifier.new,
);

// ── Filtres globaux (explore main) ────────────────────────────────────────────

class _TypeFilterNotifier extends Notifier<ExploreTypeFilter> {
  @override
  ExploreTypeFilter build() => ExploreTypeFilter.all;
  void update(ExploreTypeFilter filter) => state = filter;
  void reset() => state = ExploreTypeFilter.all;
}

final typeFilterProvider =
    NotifierProvider<_TypeFilterNotifier, ExploreTypeFilter>(
  _TypeFilterNotifier.new,
);

class _SortOrderNotifier extends Notifier<ExploreSortOrder> {
  @override
  ExploreSortOrder build() => ExploreSortOrder.recent;
  void update(ExploreSortOrder order) => state = order;
  void reset() => state = ExploreSortOrder.recent;
}

final sortOrderProvider =
    NotifierProvider<_SortOrderNotifier, ExploreSortOrder>(
  _SortOrderNotifier.new,
);

// ── Filtres spécifiques à l'écran Catégorie ───────────────────────────────────

class _CatTypeNotifier extends Notifier<ExploreTypeFilter> {
  @override
  ExploreTypeFilter build() => ExploreTypeFilter.all;
  void update(ExploreTypeFilter v) => state = v;
}

final categoryTypeFilterProvider =
    NotifierProvider<_CatTypeNotifier, ExploreTypeFilter>(
  _CatTypeNotifier.new,
);

class _CatSortNotifier extends Notifier<ExploreSortOrder> {
  @override
  ExploreSortOrder build() => ExploreSortOrder.popular;
  void update(ExploreSortOrder v) => state = v;
}

final categorySortOrderProvider =
    NotifierProvider<_CatSortNotifier, ExploreSortOrder>(
  _CatSortNotifier.new,
);

// ── Résultats de recherche (tous les témoignages, filtrés) ─────────────────────

/// Utilise feedNotifierProvider (toutes rubriques) plutôt que feedProvider
/// qui est déjà filtré par catégorie sélectionnée en Home.
final exploreResultsProvider = Provider<List<Testimony>>((ref) {
  final query      = ref.watch(searchQueryProvider).trim().toLowerCase();
  final typeFilter = ref.watch(typeFilterProvider);
  final sortOrder  = ref.watch(sortOrderProvider);

  var results = ref.watch(feedNotifierProvider);

  results = _applyTypeFilter(results, typeFilter);

  if (query.isNotEmpty) {
    results = results.where((t) {
      return t.title.toLowerCase().contains(query) ||
          t.author.displayName.toLowerCase().contains(query) ||
          t.category.label.toLowerCase().contains(query);
    }).toList();
  }

  return _applySortOrder(results, sortOrder);
});

// ── Chargement API par catégorie ──────────────────────────────────────────────

final categoryApiProvider =
    FutureProvider.family<List<Testimony>, TestimonyCategory>((ref, cat) async {
  final api  = ref.read(apiServiceProvider);
  final slug = toCategoryApiSlug(cat);
  try {
    final response = await api.get<dynamic>(
      '${AppConstants.testimonies}?category=$slug&limit=50',
    );
    final raw  = response.data;
    final list = raw is List
        ? raw
        : raw is Map
            ? (raw['data'] as List? ?? [])
            : <dynamic>[];
    final items =
        list.map(testimonyFromApiJson).whereType<Testimony>().toList();
    if (items.isNotEmpty) return items;
  } catch (_) {}
  // Fallback : données déjà en mémoire
  return ref.read(feedNotifierProvider).where((t) => t.category == cat).toList();
});

// ── Résultats par catégorie (API + filtres locaux) ────────────────────────────

final categoryResultsProvider =
    Provider.family<List<Testimony>, TestimonyCategory>((ref, cat) {
  final typeFilter = ref.watch(categoryTypeFilterProvider);
  final sortOrder  = ref.watch(categorySortOrderProvider);

  // Utilise les données API si disponibles, sinon le feed en mémoire.
  final apiState = ref.watch(categoryApiProvider(cat));
  final all = apiState.when(
    data:    (items) => items,
    loading: () => ref.read(feedNotifierProvider).where((t) => t.category == cat).toList(),
    error:   (_, _)  => ref.read(feedNotifierProvider).where((t) => t.category == cat).toList(),
  );

  final filtered = _applyTypeFilter(all, typeFilter);
  return _applySortOrder(filtered, sortOrder);
});

/// `true` pendant le chargement initial de la catégorie depuis l'API.
final categoryLoadingProvider =
    Provider.family<bool, TestimonyCategory>((ref, cat) {
  return ref.watch(categoryApiProvider(cat)).isLoading;
});

// ── Sections de découverte ────────────────────────────────────────────────────

/// Les N témoignages les plus vus (toutes catégories).
final trendingProvider = Provider<List<Testimony>>((ref) {
  final all = List<Testimony>.from(ref.watch(feedNotifierProvider));
  all.sort((a, b) => b.stats.views.compareTo(a.stats.views));
  return all.take(8).toList();
});

/// Les N témoignages les plus priés.
final mostPrayedProvider = Provider<List<Testimony>>((ref) {
  final all = List<Testimony>.from(ref.watch(feedNotifierProvider));
  all.sort((a, b) => b.stats.prayers.compareTo(a.stats.prayers));
  return all.take(8).toList();
});

/// Témoignages récents (5 derniers).
final recentProvider = Provider<List<Testimony>>((ref) {
  final all = List<Testimony>.from(ref.watch(feedNotifierProvider));
  all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return all.take(5).toList();
});

// ── Helpers ───────────────────────────────────────────────────────────────────

List<Testimony> _applyTypeFilter(
    List<Testimony> list, ExploreTypeFilter filter) {
  return switch (filter) {
    ExploreTypeFilter.all   => list,
    ExploreTypeFilter.text  => list.whereType<TextTestimony>().toList(),
    ExploreTypeFilter.audio => list.whereType<AudioTestimony>().toList(),
    ExploreTypeFilter.video => list.whereType<VideoTestimony>().toList(),
  };
}

List<Testimony> _applySortOrder(
    List<Testimony> list, ExploreSortOrder order) {
  final sorted = List<Testimony>.from(list);
  switch (order) {
    case ExploreSortOrder.recent:
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case ExploreSortOrder.popular:
      sorted.sort((a, b) => b.stats.views.compareTo(a.stats.views));
    case ExploreSortOrder.recommended:
      sorted.sort((a, b) => b.stats.prayers.compareTo(a.stats.prayers));
  }
  return sorted;
}
