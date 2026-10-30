// Historique des versets du jour et verset d'un jour passé.
// Backend : docs/fonctionnalites/verset-du-jour.md
//   GET /daily-verse/history?page=&limit= → [{ date, id, reference, verseText, themeLabel,
//       counts: { likes, prayers, comments, testimonies, prayerRequests }, myReactions, webUrl, shareUrl? }]
//   GET /daily-verse/{id}                 → verset complet (comme le verset du jour)
//   POST /daily-verse/{id}/react { type, active } → verset à jour

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../l10n/app_localizations.dart' show watchAppLanguage;
import '../../../services/api_service.dart';
import '../../home/models/testimony_model.dart' show DailyVerse, verseWithPrayer, versePrayBody;
import '../../home/providers/home_providers.dart' show parsePageMeta;

/// Un jour de l'historique.
class VerseHistoryEntry {
  const VerseHistoryEntry({
    required this.date,
    required this.id,
    required this.reference,
    required this.text,
    this.themeLabel,
    this.likes = 0,
    this.prayers = 0,
    this.comments = 0,
    this.testimonies = 0,
    this.prayerRequests = 0,
    this.isLiked = false,
    this.isPrayed = false,
    this.shareUrl,
  });

  factory VerseHistoryEntry.fromJson(Map<String, dynamic> m) {
    final c = m['counts'] is Map ? Map<String, dynamic>.from(m['counts'] as Map) : const <String, dynamic>{};
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    final mine = m['myReactions'] is List ? {for (final r in m['myReactions'] as List) '$r'} : const <String>{};
    return VerseHistoryEntry(
      date: DateTime.tryParse('${m['date']}') ?? DateTime.now(),
      id: n(m['id']),
      reference: '${m['reference'] ?? ''}',
      text: '${m['verseText'] ?? ''}',
      themeLabel: (m['themeLabel'] as String?)?.trim().isEmpty ?? true ? null : m['themeLabel'] as String,
      likes: n(c['likes']),
      prayers: n(c['prayers']),
      comments: n(c['comments']),
      testimonies: n(c['testimonies']),
      prayerRequests: n(c['prayerRequests']),
      isLiked: mine.contains('like'),
      isPrayed: mine.contains('pray'),
      shareUrl: [m['shareUrl'], m['webUrl']].whereType<String>().where((u) => u.isNotEmpty).firstOrNull,
    );
  }

  final DateTime date;
  final int id;
  final String reference;
  final String text;
  final String? themeLabel;
  final int likes;
  final int prayers;
  final int comments;
  final int testimonies;
  final int prayerRequests;
  final bool isLiked;
  final bool isPrayed;

  /// Lien daté du jour (`shareUrl`, sinon `webUrl`) ; null : construit par l'app.
  final String? shareUrl;
}

class VerseHistoryState {
  const VerseHistoryState({this.items = const [], this.page = 0, this.hasMore = true, this.loadingMore = false});

  final List<VerseHistoryEntry> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
}

class VerseHistoryNotifier extends AsyncNotifier<VerseHistoryState> {
  @override
  Future<VerseHistoryState> build() {
    // Versets dans la langue de l'application (Accept-Language) : relus au changement de langue.
    watchAppLanguage(ref);
    return _fetch(1, const VerseHistoryState());
  }

  Future<VerseHistoryState> _fetch(int page, VerseHistoryState current) async {
    final res = await ref
        .read(apiServiceProvider)
        .get<dynamic>(AppConstants.verseHistory, query: {'page': page, 'limit': 15});
    final data = res.data;
    final items = [
      for (final m in (data is List ? data : const []))
        if (m is Map) VerseHistoryEntry.fromJson(Map<String, dynamic>.from(m)),
    ];
    final meta = parsePageMeta(res.meta);
    return VerseHistoryState(
      items: [...current.items, ...items],
      page: meta.currentPage,
      hasMore: meta.currentPage < meta.lastPage,
    );
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(VerseHistoryState(items: s.items, page: s.page, hasMore: s.hasMore, loadingMore: true));
    try {
      state = AsyncData(await _fetch(s.page + 1, s));
    } catch (_) {
      state = AsyncData(VerseHistoryState(items: s.items, page: s.page, hasMore: s.hasMore));
    }
  }
}

final verseHistoryProvider =
    AsyncNotifierProvider.autoDispose<VerseHistoryNotifier, VerseHistoryState>(VerseHistoryNotifier.new);

/// Verset d'un jour passé (par identifiant), avec « J'aime » et « Je prie ».
class VerseByIdNotifier extends AsyncNotifier<DailyVerse> {
  VerseByIdNotifier(this.id);
  final int id;

  @override
  Future<DailyVerse> build() async {
    watchAppLanguage(ref);
    final res = await ref.read(apiServiceProvider).get<Map<String, dynamic>>(AppConstants.verseById(id));
    return DailyVerse.fromJson(res.data);
  }

  Future<void> refresh() async {
    try {
      final res = await ref.read(apiServiceProvider).get<Map<String, dynamic>>(AppConstants.verseById(id));
      final v = DailyVerse.fromJson(res.data);
      if (v.text.isNotEmpty && ref.mounted) state = AsyncData(v);
    } catch (_) {}
  }

  Future<void> toggleLike() => _react('like');

  /// Une prière de plus ou, [again] faux, retirer la dernière (docs serveur prier-plusieurs-fois.md).
  Future<void> pray({bool again = true}) async {
    final v = state.value;
    if (v == null) return;
    state = AsyncData(verseWithPrayer(v, again: again));
    try {
      final res = await ref
          .read(apiServiceProvider)
          .post<Map<String, dynamic>>(AppConstants.verseReactTo(id), data: versePrayBody(again: again));
      final fresh = DailyVerse.fromJson(res.data);
      if (fresh.text.isNotEmpty && ref.mounted) state = AsyncData(fresh);
    } catch (_) {
      if (ref.mounted) state = AsyncData(v);
    }
  }

  Future<void> _react(String type) async {
    final v = state.value;
    if (v == null) return;
    final like = type == 'like';
    final was = like ? v.isLiked : v.isPrayed;
    state = AsyncData(like
        ? v.copyWith(isLiked: !was, likeCount: (v.likeCount + (was ? -1 : 1)).clamp(0, 1 << 30))
        : v.copyWith(isPrayed: !was, prayerCount: (v.prayerCount + (was ? -1 : 1)).clamp(0, 1 << 30)));
    try {
      final res = await ref
          .read(apiServiceProvider)
          .post<Map<String, dynamic>>(AppConstants.verseReactTo(id), data: {'type': type, 'active': !was});
      final fresh = DailyVerse.fromJson(res.data);
      if (fresh.text.isNotEmpty && ref.mounted) state = AsyncData(fresh);
    } catch (_) {
      if (ref.mounted) state = AsyncData(v);
    }
  }
}

final verseByIdProvider =
    AsyncNotifierProvider.autoDispose.family<VerseByIdNotifier, DailyVerse, int>(VerseByIdNotifier.new);
