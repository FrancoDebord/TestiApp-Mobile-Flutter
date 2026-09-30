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

/// Demande de focus du champ de recherche (icône loupe de l'accueil) :
/// chaque appel à [request] incrémente le compteur, écouté par SearchBarWidget.
class _SearchFocusRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void request() => state++;
}

final searchFocusRequestProvider =
    NotifierProvider<_SearchFocusRequestNotifier, int>(
  _SearchFocusRequestNotifier.new,
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

/// Filtre « Catégorie » de la recherche (slug serveur, null = toutes).
class _CategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? slug) => state = slug;
  void reset() => state = null;
}

final exploreCategoryFilterProvider =
    NotifierProvider<_CategoryFilterNotifier, String?>(
  _CategoryFilterNotifier.new,
);

/// `true` si un filtre (type, catégorie, tri) diffère des valeurs par défaut.
final exploreFiltersActiveProvider = Provider<bool>((ref) =>
    ref.watch(typeFilterProvider) != ExploreTypeFilter.all ||
    ref.watch(exploreCategoryFilterProvider) != null ||
    ref.watch(sortOrderProvider) != ExploreSortOrder.recent);

/// Réinitialise tous les filtres de la recherche.
void resetExploreFilters(WidgetRef ref) {
  ref.read(typeFilterProvider.notifier).reset();
  ref.read(exploreCategoryFilterProvider.notifier).reset();
  ref.read(sortOrderProvider.notifier).reset();
}

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
/// Filtrage local (l'API de liste n'accepte pas ces paramètres).
final exploreResultsProvider = Provider<List<Testimony>>((ref) {
  return filterTestimonies(
    ref.watch(feedNotifierProvider),
    query: ref.watch(searchQueryProvider),
    type: ref.watch(typeFilterProvider),
    categorySlug: ref.watch(exploreCategoryFilterProvider),
    sort: ref.watch(sortOrderProvider),
  );
});

/// Filtre + tri d'une liste de témoignages (recherche, écran de résultats).
List<Testimony> filterTestimonies(
  List<Testimony> all, {
  String query = '',
  ExploreTypeFilter type = ExploreTypeFilter.all,
  String? categorySlug,
  ExploreSortOrder sort = ExploreSortOrder.recent,
}) {
  final q = query.trim().toLowerCase();
  var results = _applyTypeFilter(all, type);

  if (categorySlug != null && categorySlug.isNotEmpty) {
    results = results
        .where((t) =>
            t.category.slug == categorySlug ||
            toCategoryApiSlug(t.category) == categorySlug)
        .toList();
  }

  if (q.isNotEmpty) {
    results = results.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.author.displayName.toLowerCase().contains(q) ||
          t.category.label.toLowerCase().contains(q);
    }).toList();
  }

  return _applySortOrder(results, sort);
}

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
    case ExploreSortOrder.liked:
      sorted.sort((a, b) => b.stats.likes.compareTo(a.stats.likes));
    case ExploreSortOrder.recommended:
      sorted.sort((a, b) => b.stats.prayers.compareTo(a.stats.prayers));
  }
  return sorted;
}
