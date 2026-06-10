import 'package:flutter_riverpod/flutter_riverpod.dart';

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

Testimony _applyStatsDelta(Testimony t, int likeDelta, int prayDelta) {
  final s = t.stats;
  final ns = TestimonyStats(
    views:    s.views,
    comments: s.comments,
    likes:    (s.likes    + likeDelta).clamp(0, 999999),
    prayers:  (s.prayers  + prayDelta).clamp(0, 999999),
  );
  if (t is TextTestimony) {
    return TextTestimony(
      id: t.id, author: t.author, title: t.title,
      category: t.category, createdAt: t.createdAt, stats: ns,
      preview: t.preview, coverImageUrl: t.coverImageUrl,
      isFeatured: t.isFeatured, isLiked: t.isLiked, isPrayed: t.isPrayed,
    );
  }
  if (t is AudioTestimony) {
    return AudioTestimony(
      id: t.id, author: t.author, title: t.title,
      category: t.category, createdAt: t.createdAt, stats: ns,
      durationSeconds: t.durationSeconds, transcriptPreview: t.transcriptPreview,
      mediaPath: t.mediaPath, coverImageUrl: t.coverImageUrl,
      isFeatured: t.isFeatured, isLiked: t.isLiked, isPrayed: t.isPrayed,
    );
  }
  if (t is VideoTestimony) {
    return VideoTestimony(
      id: t.id, author: t.author, title: t.title,
      category: t.category, createdAt: t.createdAt, stats: ns,
      durationSeconds: t.durationSeconds, thumbnailUrl: t.thumbnailUrl,
      mediaPath: t.mediaPath,
      isFeatured: t.isFeatured, isLiked: t.isLiked, isPrayed: t.isPrayed,
    );
  }
  return t;
}

// ============================================================================
// JSON API → Testimony
// ============================================================================

Testimony? testimonyFromApiJson(dynamic raw) {
  try {
    final m        = raw as Map<String, dynamic>;
    final userMap  = m['user']  as Map<String, dynamic>? ?? {};
    final statsMap = m['stats'] as Map<String, dynamic>? ?? {};

    final author = TestimonyAuthor(
      uid:         userMap['id']          as String? ?? m['userId'] as String? ?? '',
      displayName: userMap['displayName'] as String? ?? 'Anonyme',
      avatarUrl:   userMap['avatarUrl']   as String?,
    );
    final id        = m['id']       as String? ?? '';
    final title     = m['title']    as String? ?? '';
    final category  = _categoryFromApiSlug(m['category'] as String? ?? '');
    final createdAt = DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now();
    final stats = TestimonyStats(
      views:    (statsMap['viewsCount']     as int?) ?? 0,
      likes:    (statsMap['likesCount']     as int?) ?? 0,
      prayers:  (statsMap['bookmarksCount'] as int?) ?? 0,
      comments: (statsMap['commentsCount']  as int?) ?? 0,
    );
    final isFeatured = m['isFeatured']  as bool? ?? false;
    final isLiked    = m['isLikedByMe'] as bool? ?? false;
    final isPrayed   = m['isPrayedByMe'] as bool? ?? false;
    final type       = m['type']        as String? ?? 'text';

    switch (type) {
      case 'audio':
        final body = m['bodyText'] as String? ?? '';
        return AudioTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: createdAt, stats: stats,
          durationSeconds:   m['duration'] as int? ?? 0,
          transcriptPreview: body.length > 180 ? '${body.substring(0, 180)}…' : body,
          mediaPath:     m['mediaUrl'] as String?,
          coverImageUrl: m['coverUrl'] as String?,
          isFeatured: isFeatured, isLiked: isLiked, isPrayed: isPrayed,
        );
      case 'video':
        return VideoTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: createdAt, stats: stats,
          durationSeconds: m['duration'] as int? ?? 0,
          thumbnailUrl:    m['coverUrl'] as String? ?? '',
          mediaPath:       m['mediaUrl'] as String?,
          isFeatured: isFeatured, isLiked: isLiked, isPrayed: isPrayed,
        );
      default:
        final body = m['bodyText'] as String? ?? '';
        return TextTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: createdAt, stats: stats,
          preview: body.length > 220 ? '${body.substring(0, 220)}…' : body,
          coverImageUrl: m['coverUrl'] as String?,
          isFeatured: isFeatured, isLiked: isLiked, isPrayed: isPrayed,
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

  Future<void> _loadFromApi() async {
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
      // Hors-ligne ou non authentifié → fallback SQLite
      await _loadFromDb();
    } finally {
      ref.read(feedIsLoadingProvider.notifier).done();
    }
  }

  /// Ajuste les compteurs en mémoire sans attendre le serveur (optimistic UI).
  void applyOptimisticDelta(String id, {int likes = 0, int prayers = 0}) {
    if (likes == 0 && prayers == 0) return;
    state = [
      for (final t in state)
        t.id == id ? _applyStatsDelta(t, likes, prayers) : t,
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
      final id     = row['id']     as String;
      final author = TestimonyAuthor(
        uid:         row['user_id']       as String? ?? '',
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

      switch (type) {
        case 'audio':
          return AudioTestimony(
            id: id, author: author, title: title,
            category: category, createdAt: createdAt, stats: stats,
            durationSeconds:   row['duration_sec'] as int? ?? 0,
            transcriptPreview: row['body_text']    as String? ?? '',
            mediaPath:         row['media_url']    as String?,
          );
        case 'video':
          return VideoTestimony(
            id: id, author: author, title: title,
            category: category, createdAt: createdAt, stats: stats,
            durationSeconds: row['duration_sec'] as int? ?? 0,
            thumbnailUrl:    row['cover_url']    as String? ?? '',
            mediaPath:       row['media_url']    as String?,
          );
        default:
          final body = row['body_text'] as String? ?? '';
          return TextTestimony(
            id: id, author: author, title: title,
            category: category, createdAt: createdAt, stats: stats,
            preview: body.length > 220 ? '${body.substring(0, 220)}…' : body,
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

  /// Recharge le feed depuis l'API.
  Future<void> refresh() => _loadFromApi();
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
    for (final t in testimonies) {
      if (t.isLiked)  serverLiked.add(t.id);
      if (t.isPrayed) serverPrayed.add(t.id);
    }
    state = state.copyWith(
      liked:  {...state.liked,  ...serverLiked},
      prayed: {...state.prayed, ...serverPrayed},
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
    try {
      final api    = ref.read(apiServiceProvider);
      final result = await api.get<Map<String, dynamic>>(AppConstants.verseToday);
      return DailyVerse.fromJson(result.data);
    } catch (_) {
      return _kFallbackVerse;
    }
  }

  Future<void> toggleLike() async {
    final verse = state.value;
    if (verse == null) return;
    final wasLiked = verse.isLiked;
    // Mise à jour optimiste
    state = AsyncValue.data(verse.copyWith(
      isLiked:   !wasLiked,
      likeCount: verse.likeCount + (wasLiked ? -1 : 1),
    ));
    try {
      final api = ref.read(apiServiceProvider);
      if (wasLiked) {
        await api.delete<void>(AppConstants.verseLike(verse.id));
      } else {
        await api.post<void>(AppConstants.verseLike(verse.id));
      }
    } catch (_) {
      // Annuler l'optimiste en cas d'erreur
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
        await api.delete<void>(AppConstants.versePray(verse.id));
      } else {
        await api.post<void>(AppConstants.versePray(verse.id));
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
      await api.post<void>(AppConstants.verseShare(verse.id));
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
