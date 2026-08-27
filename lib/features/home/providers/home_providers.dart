import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/app_constants.dart';
import '../../../core/local_db/daos/testimony_dao.dart';
import '../../../core/local_db/database_service.dart';
import '../../../services/api_service.dart';
import '../models/testimony_model.dart';

// ============================================================================
// ReactionType enum + extension
// ============================================================================

enum ReactionType { like, pray, love, glory, strong, fire, touched }

extension ReactionTypeInfo on ReactionType {
  String get emoji {
    switch (this) {
      case ReactionType.like:
        return '❤️';
      case ReactionType.pray:
        return '🙏';
      case ReactionType.love:
        return '😍';
      case ReactionType.glory:
        return '🙌';
      case ReactionType.strong:
        return '💪';
      case ReactionType.fire:
        return '🔥';
      case ReactionType.touched:
        return '😢';
    }
  }

  String get label {
    switch (this) {
      case ReactionType.like:
        return "J'aime";
      case ReactionType.pray:
        return 'Je prie';
      case ReactionType.love:
        return "J'adore";
      case ReactionType.glory:
        return 'Gloire !';
      case ReactionType.strong:
        return 'Inspirant';
      case ReactionType.fire:
        return 'Puissant';
      case ReactionType.touched:
        return 'Touché';
    }
  }

  /// Valeur envoyée au backend (POST /testimonies/{id}/reactions).
  String get apiValue => switch (this) {
        ReactionType.like    => 'like',
        ReactionType.pray    => 'pray',
        ReactionType.love    => 'love',
        ReactionType.glory   => 'amen',
        ReactionType.strong  => 'fire',
        ReactionType.fire    => 'fire',
        ReactionType.touched => 'love',
      };
}

// ============================================================================
// Helpers : catégorie API slug ↔ enum Flutter
// ============================================================================

TestimonyCategory _categoryFromApiSlug(String slug) => switch (slug) {
      'guerison'          => TestimonyCategory.guerison,
      'delivrance'        => TestimonyCategory.delivrance,
      'conversion'        => TestimonyCategory.conversion,
      'mariage'           => TestimonyCategory.mariage,
      'famille'           => TestimonyCategory.famille,
      'finances'          => TestimonyCategory.finances,
      'miracles'          => TestimonyCategory.miracles,
      'protection_divine' => TestimonyCategory.protection,
      'protection'        => TestimonyCategory.protection,
      'ministere'         => TestimonyCategory.ministere,
      'salut'             => TestimonyCategory.salut,
      _                   => TestimonyCategory.guerison,
    };

/// Slug envoyé au backend (protection → protection_divine).
String toCategoryApiSlug(TestimonyCategory cat) =>
    cat == TestimonyCategory.protection ? 'protection_divine' : cat.name;

// ============================================================================
// Helper : reconstruit un Testimony avec des stats modifiées (optimistic UI)
// ============================================================================

Testimony _applyStatsDelta(
    Testimony t, int likeDelta, int prayDelta, int commentDelta) {
  final s = t.stats;
  final ns = TestimonyStats(
    views:    s.views,
    comments: (s.comments + commentDelta).clamp(0, 999999),
    likes:    (s.likes    + likeDelta).clamp(0, 999999),
    prayers:  (s.prayers  + prayDelta).clamp(0, 999999),
  );
  if (t is TextTestimony) {
    return TextTestimony(
      id: t.id, author: t.author, title: t.title,
      category: t.category, createdAt: t.createdAt, stats: ns,
      preview: t.preview, coverImageUrl: t.coverImageUrl,
      bibleVerse: t.bibleVerse, bibleVerseRef: t.bibleVerseRef,
      isFeatured: t.isFeatured, isLiked: t.isLiked,
      isPrayed: t.isPrayed, isSaved: t.isSaved,
    );
  }
  if (t is AudioTestimony) {
    return AudioTestimony(
      id: t.id, author: t.author, title: t.title,
      category: t.category, createdAt: t.createdAt, stats: ns,
      durationSeconds: t.durationSeconds, transcriptPreview: t.transcriptPreview,
      mediaPath: t.mediaPath, coverImageUrl: t.coverImageUrl,
      bibleVerse: t.bibleVerse, bibleVerseRef: t.bibleVerseRef,
      isFeatured: t.isFeatured, isLiked: t.isLiked,
      isPrayed: t.isPrayed, isSaved: t.isSaved,
    );
  }
  if (t is VideoTestimony) {
    return VideoTestimony(
      id: t.id, author: t.author, title: t.title,
      category: t.category, createdAt: t.createdAt, stats: ns,
      durationSeconds: t.durationSeconds, thumbnailUrl: t.thumbnailUrl,
      mediaPath: t.mediaPath,
      bibleVerse: t.bibleVerse, bibleVerseRef: t.bibleVerseRef,
      isFeatured: t.isFeatured, isLiked: t.isLiked,
      isPrayed: t.isPrayed, isSaved: t.isSaved,
    );
  }
  return t;
}

// ============================================================================
// JSON API → Testimony
// ============================================================================

// Convertit int, double ou String en int (robuste face aux types variables de l'API).
int _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

// Convertit une URL relative serveur ("/storage/…") en URL absolue.
String? _absUrl(String? raw) {
  if (raw == null || raw.isEmpty) return raw;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final root = AppConstants.baseUrl.replaceFirst(RegExp(r'/api/v1.*$'), '');
  return raw.startsWith('/') ? '$root$raw' : '$root/$raw';
}

Testimony? testimonyFromApiJson(dynamic raw) {
  try {
    final m        = raw as Map<String, dynamic>;
    final userMap  = m['user']  as Map<String, dynamic>? ?? {};
    final statsMap = m['stats'] as Map<String, dynamic>? ?? {};

    // Laravel peut renvoyer camelCase ou snake_case selon la version — on essaie les deux.
    final author = TestimonyAuthor(
      uid:         (userMap['id'] ?? m['userId'] ?? m['user_id'])?.toString() ?? '',
      displayName: (userMap['displayName'] ?? userMap['display_name'])  as String? ?? 'Anonyme',
      avatarUrl:   (userMap['avatarUrl']   ?? userMap['avatar_url'])    as String?,
    );
    final id        = m['id']?.toString() ?? '';
    final title     = m['title']    as String? ?? '';
    final category  = _categoryFromApiSlug(
        (m['category'] ?? m['category_slug']) as String? ?? '');
    final createdAt = DateTime.tryParse(
        (m['createdAt'] ?? m['created_at']) as String? ?? '') ?? DateTime.now();
    final stats = TestimonyStats(
      views:    ((statsMap['viewsCount']    ?? statsMap['views_count'])    as int?) ?? 0,
      likes:    ((statsMap['likesCount']    ?? statsMap['likes_count'])    as int?) ?? 0,
      prayers:  ((statsMap['prayersCount']  ?? statsMap['prayers_count'])  as int?) ?? 0,
      comments: ((statsMap['commentsCount'] ?? statsMap['comments_count']) as int?) ?? 0,
    );
    final isFeatured = (m['isFeatured']       ?? m['is_featured'])                              as bool? ?? false;
    final isLiked    = (m['isLikedByMe']      ?? m['is_liked_by_me']  ?? m['is_liked'])        as bool? ?? false;
    final isPrayed   = (m['isPrayedByMe']     ?? m['is_prayed_by_me'] ?? m['is_prayed'])       as bool? ?? false;
    final isSaved    = (m['isBookmarkedByMe'] ?? m['is_bookmarked_by_me'])                     as bool? ?? false;
    final type          = m['type']                                                            as String? ?? 'text';
    final bibleVerse    = (m['bibleVerse']      ?? m['bible_verse'])                          as String?;
    final bibleVerseRef = (m['verseReference']  ?? m['verse_reference'])                      as String?;

    switch (type) {
      case 'audio':
        final body = (m['bodyText'] ?? m['body_text']) as String? ?? '';
        return AudioTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: createdAt, stats: stats,
          durationSeconds:   _parseInt(m['duration'] ?? m['duration_seconds']),
          transcriptPreview: body.length > 180 ? '${body.substring(0, 180)}…' : body,
          mediaPath:     _absUrl((m['mediaUrl'] ?? m['media_url']) as String?),
          coverImageUrl: (m['coverUrl'] ?? m['cover_url']) as String?,
          bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          isFeatured: isFeatured, isLiked: isLiked, isPrayed: isPrayed, isSaved: isSaved,
        );
      case 'video':
        return VideoTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: createdAt, stats: stats,
          durationSeconds: _parseInt(m['duration'] ?? m['duration_seconds']),
          thumbnailUrl:    (m['coverUrl'] ?? m['cover_url']) as String? ?? '',
          mediaPath:       _absUrl((m['mediaUrl'] ?? m['media_url']) as String?),
          bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          isFeatured: isFeatured, isLiked: isLiked, isPrayed: isPrayed, isSaved: isSaved,
        );
      default:
        final body = (m['bodyText'] ?? m['body_text']) as String? ?? '';
        return TextTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: createdAt, stats: stats,
          preview: body.length > 220 ? '${body.substring(0, 220)}…' : body,
          coverImageUrl: (m['coverUrl'] ?? m['cover_url']) as String?,
          bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          isFeatured: isFeatured, isLiked: isLiked, isPrayed: isPrayed, isSaved: isSaved,
        );
    }
  } catch (_) {
    return null;
  }
}

// ============================================================================
// FeedNotifier — liste mutable chargée depuis l'API (+ SQLite en fallback)
// ============================================================================

class FeedNotifier extends Notifier<List<Testimony>> {
  @override
  List<Testimony> build() {
    Future.microtask(_loadFromApi);
    return const [];
  }

  // ── Chargement depuis l'API ───────────────────────────────────────────────

  Future<void> _loadFromApi({bool silent = false}) async {
    try {
      final api      = ref.read(apiServiceProvider);
      final response = await api.get<List<dynamic>>(AppConstants.testimonies);
      final items = response.data
          .map(testimonyFromApiJson)
          .whereType<Testimony>()
          .toList();
      state = items;
      // Synchronise l'état liked/prayed depuis le serveur.
      ref.read(interactionProvider.notifier).seedFromFeed(items);
    } catch (_) {
      // Hors-ligne ou non authentifié → fallback SQLite (seulement au premier chargement)
      if (!silent) await _loadFromDb();
    } finally {
      if (!silent) ref.read(feedIsLoadingProvider.notifier).done();
    }
  }

  /// Ajuste les compteurs en mémoire sans attendre le serveur (optimistic UI).
  void applyOptimisticDelta(String id,
      {int likes = 0, int prayers = 0, int comments = 0}) {
    if (likes == 0 && prayers == 0 && comments == 0) return;
    state = [
      for (final t in state)
        t.id == id ? _applyStatsDelta(t, likes, prayers, comments) : t,
    ];
  }

  // ── Fallback SQLite ───────────────────────────────────────────────────────

  Future<void> _loadFromDb() async {
    try {
      final dao  = TestimonyDao(DatabaseService());
      final rows = await dao.getFeed();
      if (rows.isEmpty) return;

      final fromDb = rows
          .map(_rowToTestimony)
          .whereType<Testimony>()
          .toList();
      if (fromDb.isNotEmpty) state = fromDb;
    } catch (_) {}
  }

  // ── SQLite row → Testimony ────────────────────────────────────────────────

  static Testimony? _rowToTestimony(Map<String, dynamic> row) {
    try {
      final type   = row['type']   as String? ?? 'text';
      final id     = row['id']?.toString() ?? '';
      final author = TestimonyAuthor(
        uid:         row['user_id']?.toString() ?? '',
        displayName: row['author_name']   as String? ?? 'Anonyme',
        avatarUrl:   row['author_avatar'] as String?,
      );
      final title    = row['title']    as String? ?? '';
      final catName  = row['category'] as String? ?? '';
      final category = TestimonyCategory.values
          .firstWhere((c) => c.name == catName,
              orElse: () => TestimonyCategory.guerison);
      final createdAt =
          DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();
      final stats = TestimonyStats(
        views:    row['views']         as int? ?? 0,
        likes:    row['like_count']    as int? ?? 0,
        prayers:  row['prayer_count']  as int? ?? 0,
        comments: row['comment_count'] as int? ?? 0,
      );

      final bibleVerse    = row['bible_verse'] as String?;
      final bibleVerseRef = row['bible_ref']   as String?;

      switch (type) {
        case 'audio':
          return AudioTestimony(
            id: id, author: author, title: title,
            category: category, createdAt: createdAt, stats: stats,
            durationSeconds:   row['duration_sec'] as int? ?? 0,
            transcriptPreview: row['body_text']    as String? ?? '',
            mediaPath:         _absUrl(row['media_url'] as String?),
            bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          );
        case 'video':
          return VideoTestimony(
            id: id, author: author, title: title,
            category: category, createdAt: createdAt, stats: stats,
            durationSeconds: row['duration_sec'] as int? ?? 0,
            thumbnailUrl:    row['cover_url']    as String? ?? '',
            mediaPath:       _absUrl(row['media_url'] as String?),
            bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          );
        default:
          final body = row['body_text'] as String? ?? '';
          return TextTestimony(
            id: id, author: author, title: title,
            category: category, createdAt: createdAt, stats: stats,
            preview: body.length > 220 ? '${body.substring(0, 220)}…' : body,
            bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          );
      }
    } catch (_) {
      return null;
    }
  }

  // ── Mutations mémoire ─────────────────────────────────────────────────────

  void addTestimony(Testimony testimony) {
    state = [testimony, ...state];
  }

  void removeTestimony(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  /// Rafraîchit le feed depuis l'API sans afficher l'état de chargement (appelé en arrière-plan).
  Future<void> refresh() => _loadFromApi(silent: state.isNotEmpty);
}

final feedNotifierProvider =
    NotifierProvider<FeedNotifier, List<Testimony>>(FeedNotifier.new);

/// `true` tant que le premier chargement (API ou SQLite) n'est pas terminé.
/// Utilisé par HomeScreen pour afficher les skeleton cards plutôt que l'état vide.
class _FeedLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void done() => state = false;
}

final feedIsLoadingProvider =
    NotifierProvider<_FeedLoadingNotifier, bool>(_FeedLoadingNotifier.new);

// ============================================================================
// Feed filtré par catégorie (utilisé par HomeScreen)
// ============================================================================

final feedProvider = Provider<List<Testimony>>((ref) {
  final all      = ref.watch(feedNotifierProvider);
  final selected = ref.watch(selectedCategoryProvider);
  if (selected == null) return all;
  return all.where((t) => t.category == selected).toList();
});

// ============================================================================
// Featured
// ============================================================================

final featuredProvider = Provider<List<Testimony>>((ref) {
  return ref.watch(feedNotifierProvider).where((t) => t.isFeatured).toList();
});

// ============================================================================
// Interactions : likes, prières, réactions emoji — avec appels API
// ============================================================================

class TestimonyInteractions {
  const TestimonyInteractions({
    this.liked     = const {},
    this.prayed    = const {},
    this.saved     = const {},
    this.reactions = const {},
  });

  final Set<String> liked;
  final Set<String> prayed;
  final Set<String> saved;
  final Map<String, ReactionType> reactions;

  TestimonyInteractions setReaction(String id, ReactionType type) {
    final newReactions = Map<String, ReactionType>.from(reactions)..[id] = type;
    final newLiked     = Set<String>.from(liked);
    if (type == ReactionType.like) {
      newLiked.add(id);
    } else {
      newLiked.remove(id);
    }
    return copyWith(reactions: newReactions, liked: newLiked);
  }

  TestimonyInteractions removeReaction(String id) {
    final newReactions = Map<String, ReactionType>.from(reactions)..remove(id);
    final newLiked     = Set<String>.from(liked)..remove(id);
    return copyWith(reactions: newReactions, liked: newLiked);
  }

  TestimonyInteractions copyWith({
    Set<String>? liked,
    Set<String>? prayed,
    Set<String>? saved,
    Map<String, ReactionType>? reactions,
  }) =>
      TestimonyInteractions(
        liked:     liked     ?? this.liked,
        prayed:    prayed    ?? this.prayed,
        saved:     saved     ?? this.saved,
        reactions: reactions ?? this.reactions,
      );
}

class InteractionNotifier extends Notifier<TestimonyInteractions> {
  /// Réactions envoyées au serveur — stocke l'ID retourné pour pouvoir supprimer.
  final _reactionIds = <String, String>{}; // testimonyId → reactionId
  final _prayIds     = <String, String>{}; // testimonyId → reactionId (pray)

  @override
  TestimonyInteractions build() => const TestimonyInteractions();

  // ── Seed depuis le serveur (appelé après chaque chargement du feed) ─────────

  void seedFromFeed(List<Testimony> testimonies) {
    final serverLiked  = <String>{};
    final serverPrayed = <String>{};
    final serverSaved  = <String>{};
    for (final t in testimonies) {
      if (t.isLiked)  serverLiked.add(t.id);
      if (t.isPrayed) serverPrayed.add(t.id);
      if (t.isSaved)  serverSaved.add(t.id);
    }
    state = state.copyWith(
      liked:  {...state.liked,  ...serverLiked},
      prayed: {...state.prayed, ...serverPrayed},
      saved:  {...state.saved,  ...serverSaved},
    );
  }

  // ── Réactions emoji ───────────────────────────────────────────────────────

  void setReaction(String id, ReactionType type) {
    final wasLiked = state.reactions[id] == ReactionType.like;
    final isLike   = type == ReactionType.like;
    state = state.setReaction(id, type);
    // Mise à jour optimiste du compteur dans le feed.
    ref.read(feedNotifierProvider.notifier).applyOptimisticDelta(
      id,
      likes: isLike && !wasLiked ? 1 : (!isLike && wasLiked ? -1 : 0),
    );
    _postReaction(id, type.apiValue, ids: _reactionIds);
  }

  void removeReaction(String id) {
    final reactionId = _reactionIds.remove(id);
    final wasLiked   = state.reactions[id] == ReactionType.like;
    state = state.removeReaction(id);
    if (wasLiked) {
      ref.read(feedNotifierProvider.notifier).applyOptimisticDelta(id, likes: -1);
    }
    if (reactionId != null) _deleteReaction(id, reactionId);
  }

  ReactionType? getReaction(String id) => state.reactions[id];

  // ── Like (rétrocompatibilité) ─────────────────────────────────────────────

  void toggleLike(String id) {
    if (state.reactions[id] == ReactionType.like) {
      removeReaction(id);
    } else {
      setReaction(id, ReactionType.like);
    }
  }

  // ── Prière ────────────────────────────────────────────────────────────────

  void togglePray(String id) {
    final prayed = {...state.prayed};
    if (prayed.contains(id)) {
      prayed.remove(id);
      state = state.copyWith(prayed: prayed);
      ref.read(feedNotifierProvider.notifier).applyOptimisticDelta(id, prayers: -1);
      final reactionId = _prayIds.remove(id);
      if (reactionId != null) _deleteReaction(id, reactionId);
    } else {
      prayed.add(id);
      state = state.copyWith(prayed: prayed);
      ref.read(feedNotifierProvider.notifier).applyOptimisticDelta(id, prayers: 1);
      _postReaction(id, 'pray', ids: _prayIds);
    }
  }

  // ── Sauvegarde ────────────────────────────────────────────────────────────

  void toggleSave(String id) {
    final saved = {...state.saved};
    if (saved.contains(id)) {
      saved.remove(id);
      state = state.copyWith(saved: saved);
      _callApi(() async {
        final api = ref.read(apiServiceProvider);
        await api.delete<void>(AppConstants.testimonyUnsave(id));
      });
    } else {
      saved.add(id);
      state = state.copyWith(saved: saved);
      _callApi(() async {
        final api = ref.read(apiServiceProvider);
        await api.put<void>(AppConstants.testimonySave(id));
      });
    }
  }

  // ── Partage (fire-and-forget, incrémente share_count côté serveur) ───────────

  void recordShare(String id) {
    _callApi(() async {
      final api = ref.read(apiServiceProvider);
      await api.post<void>(AppConstants.testimonyShare(id));
    });
  }

  bool isLiked(String id)  => state.liked.contains(id);
  bool isPrayed(String id) => state.prayed.contains(id);
  bool isSaved(String id)  => state.saved.contains(id);

  // ── Helpers API (fire-and-forget, ignorent les erreurs réseau) ────────────

  Future<void> _postReaction(
    String testimonyId,
    String type, {
    required Map<String, String> ids,
  }) async {
    await _callApi(() async {
      final api      = ref.read(apiServiceProvider);
      final response = await api.post<Map<String, dynamic>>(
        AppConstants.testimonyReactions(testimonyId),
        data: {'type': type},
      );
      final reactionId = response.data['id'] as String?;
      if (reactionId != null) ids[testimonyId] = reactionId;
    });
  }

  Future<void> _deleteReaction(String testimonyId, String reactionId) async {
    await _callApi(() async {
      final api = ref.read(apiServiceProvider);
      await api.delete<void>(
          AppConstants.testimonyReactionById(testimonyId, reactionId));
    });
  }

  Future<void> _callApi(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {}
  }
}

final interactionProvider =
    NotifierProvider<InteractionNotifier, TestimonyInteractions>(
        InteractionNotifier.new);

// Sélecteurs pratiques
final likedIdsProvider =
    Provider<Set<String>>((ref) => ref.watch(interactionProvider).liked);

final prayedIdsProvider =
    Provider<Set<String>>((ref) => ref.watch(interactionProvider).prayed);

final savedIdsProvider =
    Provider<Set<String>>((ref) => ref.watch(interactionProvider).saved);

final reactionsMapProvider = Provider<Map<String, ReactionType>>(
    (ref) => ref.watch(interactionProvider).reactions);

// ============================================================================
// Statistiques effectives — intègre les interactions locales de l'utilisateur
// ============================================================================

class _EffectiveStats {
  const _EffectiveStats({
    required this.likes,
    required this.prayers,
    required this.saves,
    required this.views,
    required this.comments,
  });

  final int likes;
  final int prayers;
  final int saves;
  final int views;
  final int comments;
}

final computedStatsProvider =
    Provider.family<_EffectiveStats, String>((ref, id) {
  final feed = ref.watch(feedNotifierProvider);
  final testimony = feed.where((t) => t.id == id).firstOrNull;

  final interactions = ref.watch(interactionProvider);
  final isLiked  = interactions.liked.contains(id);
  final isPrayed = interactions.prayed.contains(id);
  final isSaved  = interactions.saved.contains(id);

  final base = testimony?.stats ?? TestimonyStats.zero;

  return _EffectiveStats(
    likes:    base.likes    + (isLiked  ? 1 : 0),
    prayers:  base.prayers  + (isPrayed ? 1 : 0),
    saves:    isSaved ? 1 : 0,
    views:    base.views,
    comments: base.comments,
  );
});

// ============================================================================
// Filtre de catégorie
// ============================================================================

class _SelectedCategoryNotifier extends Notifier<TestimonyCategory?> {
  @override
  TestimonyCategory? build() => null;
  void select(TestimonyCategory? category) => state = category;
}

final selectedCategoryProvider =
    NotifierProvider<_SelectedCategoryNotifier, TestimonyCategory?>(
  _SelectedCategoryNotifier.new,
);

// ============================================================================
// Verset du jour
// ============================================================================

const _kFallbackVerse = DailyVerse(
  text: '« Car je connais les projets que j\'ai formés sur vous, dit l\'Éternel, '
      'projets de paix et non de malheur, afin de vous donner un avenir et de l\'espérance. »',
  reference: 'Jérémie 29 : 11',
);

class DailyVerseNotifier extends AsyncNotifier<DailyVerse> {
  @override
  Future<DailyVerse> build() async {
    // 1. Try network first
    try {
      final api    = ref.read(apiServiceProvider);
      final result = await api.get<Map<String, dynamic>>(AppConstants.verseToday);
      final verse  = DailyVerse.fromJson(result.data);
      if (verse.text.isNotEmpty) {
        await _saveToCache(verse);
        return verse;
      }
    } catch (_) {}

    // 2. Fallback to today's cached verse
    try {
      final cached = await _loadFromCache();
      if (cached != null) return cached;
    } catch (e) {
      debugPrint('DailyVerse cache read error: $e');
    }

    // 3. Hard-coded fallback
    return _kFallbackVerse;
  }

  // ── Cache helpers (one file per calendar date) ────────────────────────────

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/daily_verse_${_todayKey()}.json');
  }

  Future<DailyVerse?> _loadFromCache() async {
    final file = await _cacheFile();
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final verse = DailyVerse.fromJson(json);
    return verse.text.isNotEmpty ? verse : null;
  }

  Future<void> _saveToCache(DailyVerse verse) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode({
        'id':            verse.id,
        'text':          verse.text,
        'reference':     verse.reference,
        'like_count':    verse.likeCount,
        'prayer_count':  verse.prayerCount,
        'is_liked':      verse.isLiked,
        'is_prayed':     verse.isPrayed,
      }));
    } catch (e) {
      debugPrint('DailyVerse cache write error: $e');
    }
  }

  Future<void> toggleLike() async {
    final verse = state.value;
    if (verse == null) return;
    final wasLiked = verse.isLiked;
    state = AsyncValue.data(verse.copyWith(
      isLiked:   !wasLiked,
      likeCount: verse.likeCount + (wasLiked ? -1 : 1),
    ));
    try {
      final api = ref.read(apiServiceProvider);
      if (wasLiked) {
        await api.delete<void>(AppConstants.verseReact, data: {'type': 'like'});
      } else {
        await api.post<void>(AppConstants.verseReact, data: {'type': 'like'});
      }
    } catch (_) {
      state = AsyncValue.data(verse);
    }
  }

  Future<void> togglePray() async {
    final verse = state.value;
    if (verse == null) return;
    final wasPrayed = verse.isPrayed;
    state = AsyncValue.data(verse.copyWith(
      isPrayed:    !wasPrayed,
      prayerCount: verse.prayerCount + (wasPrayed ? -1 : 1),
    ));
    try {
      final api = ref.read(apiServiceProvider);
      if (wasPrayed) {
        await api.delete<void>(AppConstants.verseReact, data: {'type': 'pray'});
      } else {
        await api.post<void>(AppConstants.verseReact, data: {'type': 'pray'});
      }
    } catch (_) {
      state = AsyncValue.data(verse);
    }
  }

  Future<void> recordShare() async {
    final verse = state.value;
    if (verse == null) return;
    try {
      final api = ref.read(apiServiceProvider);
      await api.post<void>(AppConstants.verseShare);
    } catch (_) {}
  }
}

final dailyVerseProvider =
    AsyncNotifierProvider<DailyVerseNotifier, DailyVerse>(
  DailyVerseNotifier.new,
);

// ============================================================================
// Bannière verset — état étendu/replié
// ============================================================================

class _VerseBannerNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void update(bool value) => state = value;
}

final verseBannerExpandedProvider =
    NotifierProvider<_VerseBannerNotifier, bool>(_VerseBannerNotifier.new);
