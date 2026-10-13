import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../features/downloads/providers/downloads_provider.dart' show isOnlineProvider;
import '../../services/api_service.dart';

/// Autocomplétion des barres de recherche : modèles, appel à
/// GET /search/suggest, recherches récentes (stockage local).
/// Voir docs/fonctionnalites/recherche.md (dépôt du serveur).

/// Portée des suggestions demandées au serveur ; [local] = récentes seulement.
enum SearchScope { all, testimonies, users, events, prayer, bible, local }

/// Type d'un résultat direct.
enum SearchResultType { testimony, user, event, category, bible, prayerSession, unknown }

SearchResultType _typeFrom(String? raw) => switch (raw) {
      'testimony' => SearchResultType.testimony,
      'user' => SearchResultType.user,
      'event' => SearchResultType.event,
      'category' => SearchResultType.category,
      'bible' => SearchResultType.bible,
      'prayer_session' => SearchResultType.prayerSession,
      _ => SearchResultType.unknown,
    };

/// Partie surlignée : [start, length] en caractères du texte.
typedef SearchHighlight = (int start, int length);

SearchHighlight? _highlightFrom(Object? raw) {
  if (raw is List && raw.length == 2 && raw[0] is num && raw[1] is num) {
    return ((raw[0] as num).toInt(), (raw[1] as num).toInt());
  }
  return null;
}

/// Suggestion de texte : complète la saisie.
@immutable
class SearchTextSuggestion {
  const SearchTextSuggestion({required this.text, this.source, this.highlight});

  factory SearchTextSuggestion.fromJson(Map<String, dynamic> j) => SearchTextSuggestion(
        text: (j['text'] ?? '').toString(),
        source: j['source']?.toString(),
        highlight: _highlightFrom(j['highlight']),
      );

  final String text;
  final String? source;
  final SearchHighlight? highlight;
}

/// Résultat direct (ouvre la page correspondante).
@immutable
class SearchDirectResult {
  const SearchDirectResult({
    required this.type,
    required this.id,
    required this.label,
    this.sublabel,
    this.route,
    this.avatar,
    this.verified = false,
    this.highlight,
    this.book,
    this.translation,
  });

  factory SearchDirectResult.fromJson(Map<String, dynamic> j) => SearchDirectResult(
        type: _typeFrom(j['type']?.toString()),
        id: (j['id'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        sublabel: j['sublabel']?.toString(),
        route: j['route']?.toString(),
        avatar: (j['avatar'] as String?)?.trim().isEmpty ?? true ? null : j['avatar'] as String,
        verified: j['verified'] == true,
        highlight: _highlightFrom(j['highlight']),
        book: (j['book'] as num?)?.toInt(),
        translation: j['translation']?.toString(),
      );

  final SearchResultType type;
  final String id;
  final String label;
  final String? sublabel;

  /// Chemin de l'application (`/testimony/…`, `/users/…`, `/events/…`…).
  final String? route;
  final String? avatar;
  final bool verified;
  final SearchHighlight? highlight;

  /// Livre de la Bible (numéro) et traduction, pour [SearchResultType.bible].
  final int? book;
  final String? translation;
}

@immutable
class SearchSuggestResponse {
  const SearchSuggestResponse({this.suggestions = const [], this.results = const []});

  factory SearchSuggestResponse.fromJson(Map<String, dynamic> j) => SearchSuggestResponse(
        suggestions: [
          for (final s in (j['suggestions'] as List? ?? const []))
            if (s is Map<String, dynamic>) SearchTextSuggestion.fromJson(s),
        ].where((s) => s.text.isNotEmpty).toList(),
        results: [
          for (final r in (j['results'] as List? ?? const []))
            if (r is Map<String, dynamic>) SearchDirectResult.fromJson(r),
        ].where((r) => r.label.isNotEmpty && r.type != SearchResultType.unknown).toList(),
      );

  static const empty = SearchSuggestResponse();

  final List<SearchTextSuggestion> suggestions;
  final List<SearchDirectResult> results;

  bool get isEmpty => suggestions.isEmpty && results.isEmpty;
}

// ── Appels au serveur ─────────────────────────────────────────────────────────

/// Interroge le serveur ; [cancelToken] annule une requête devenue obsolète.
typedef SearchSuggestFetcher = Future<SearchSuggestResponse> Function(
  String query,
  SearchScope scope, {
  int limit,
  CancelToken? cancelToken,
});

final searchSuggestFetcherProvider = Provider<SearchSuggestFetcher>((ref) {
  final api = ref.watch(apiServiceProvider);
  return (query, scope, {limit = 6, cancelToken}) async {
    final res = await api.rawDio.get<dynamic>(
      AppConstants.searchSuggest,
      queryParameters: {'q': query, 'scope': scope.name, 'limit': limit},
      cancelToken: cancelToken,
    );
    final body = res.data;
    final data = body is Map<String, dynamic> ? body['data'] : null;
    return data is Map<String, dynamic> ? SearchSuggestResponse.fromJson(data) : SearchSuggestResponse.empty;
  };
});

/// Signale une recherche validée (anonyme) pour les « recherches populaires ». Sans effet en cas d'échec.
final searchLoggerProvider = Provider<void Function(String query)>((ref) {
  final api = ref.watch(apiServiceProvider);
  return (query) {
    final q = query.trim();
    if (q.length < 3) return;
    api.rawDio.post<dynamic>(AppConstants.searchLog, data: {'q': q}).then((_) {}, onError: (_) {});
  };
});

/// Connexion disponible (hors ligne : recherches récentes seulement).
final searchOnlineProvider = Provider<bool>((ref) => ref.watch(isOnlineProvider).value ?? true);

// ── Recherches récentes (sur l'appareil) ─────────────────────────────────────

/// Stockage des recherches récentes, une liste par barre de recherche.
abstract class RecentSearchStore {
  Future<List<String>> read(String key);
  Future<void> write(String key, List<String> values);
}

class SecureRecentSearchStore implements RecentSearchStore {
  SecureRecentSearchStore(this._ref);
  final Ref _ref;

  String _k(String key) => 'search_recent_$key';

  @override
  Future<List<String>> read(String key) async {
    try {
      final raw = await _ref.read(secureStorageProvider).read(key: _k(key));
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw);
      return list is List ? list.whereType<String>().toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> write(String key, List<String> values) async {
    try {
      await _ref.read(secureStorageProvider).write(key: _k(key), value: jsonEncode(values));
    } catch (_) {}
  }
}

/// Stockage en mémoire (tests).
class MemoryRecentSearchStore implements RecentSearchStore {
  final Map<String, List<String>> data = {};
  @override
  Future<List<String>> read(String key) async => List.of(data[key] ?? const []);
  @override
  Future<void> write(String key, List<String> values) async => data[key] = List.of(values);
}

final recentSearchStoreProvider = Provider<RecentSearchStore>((ref) => SecureRecentSearchStore(ref));

const int maxRecentSearches = 8;

/// Ajoute [query] en tête (sans doublon, accents et casse ignorés) et garde les [maxRecentSearches] dernières.
List<String> addRecentSearch(List<String> current, String query) {
  final q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (q.length < 2) return current;
  final f = foldForSearch(q);
  return [q, ...current.where((s) => foldForSearch(s) != f)].take(maxRecentSearches).toList();
}

// ── Pliage (accents, casse) ───────────────────────────────────────────────────

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ù': 'u',
  'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae', '’': "'",
};

String _foldChar(String c) {
  final l = c.toLowerCase();
  return _accents[l] ?? l;
}

/// Minuscules sans accents.
String foldForSearch(String text) => text.split('').map(_foldChar).join();

/// Partie de [text] qui correspond à [query] (début de texte, puis début de mot, puis contient).
SearchHighlight? findSearchMatch(String text, String query) {
  final chars = text.split('');
  final norm = StringBuffer();
  final map = <int>[];
  for (var i = 0; i < chars.length; i++) {
    final f = _foldChar(chars[i]);
    norm.write(f);
    for (var k = 0; k < f.length; k++) {
      map.add(i);
    }
  }
  final n = norm.toString();
  final q = foldForSearch(query.trim());
  if (q.isEmpty) return null;
  var p = n.startsWith(q) ? 0 : n.indexOf(' $q');
  if (p > 0) {
    p += 1;
  } else if (p < 0) {
    p = n.indexOf(q);
  }
  if (p < 0) return null;
  final start = map[p];
  final end = map[p + q.length - 1] + 1;
  return (start, end - start);
}
