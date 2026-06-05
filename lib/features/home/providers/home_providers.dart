import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/daos/testimony_dao.dart';
import '../../../core/local_db/database_service.dart';
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
}

// ============================================================================
// Stub data initiale
// ============================================================================

final _stubTestimonies = <Testimony>[
  TextTestimony(
    id: 't1',
    author: const TestimonyAuthor(uid: 'u1', displayName: 'Marie Ndoumbe'),
    title: 'Guérie d\'un cancer en phase terminale',
    category: TestimonyCategory.guerison,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    stats: const TestimonyStats(views: 1243, comments: 34, likes: 89, prayers: 156),
    preview:
        'Après trois ans de combat contre un cancer du sein en phase 4, les médecins m\'avaient donné '
        'six mois à vivre. C\'est alors que lors d\'une réunion de prière, quelque chose d\'extraordinaire s\'est produit…',
    isFeatured: true,
  ),
  AudioTestimony(
    id: 't2',
    author: const TestimonyAuthor(uid: 'u2', displayName: 'Jean-Paul Essomba'),
    title: 'Ma délivrance d\'une addiction de 15 ans',
    category: TestimonyCategory.delivrance,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    stats: const TestimonyStats(views: 876, comments: 21, likes: 63, prayers: 98),
    durationSeconds: 734,
    transcriptPreview:
        'Pendant quinze ans, j\'étais esclave de l\'alcool. Ma famille m\'avait abandonné, '
        'j\'avais perdu mon emploi…',
    isFeatured: true,
  ),
  VideoTestimony(
    id: 't3',
    author: const TestimonyAuthor(uid: 'u3', displayName: 'Esther Fokou'),
    title: 'Comment Dieu a restauré mon mariage brisé',
    category: TestimonyCategory.mariage,
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    stats: const TestimonyStats(views: 2100, comments: 47, likes: 134, prayers: 210),
    durationSeconds: 1245,
    thumbnailUrl: 'https://picsum.photos/seed/testi3/600/340',
    isFeatured: true,
  ),
  TextTestimony(
    id: 't4',
    author: const TestimonyAuthor(uid: 'u4', displayName: 'Samuel Biya'),
    title: 'Miracle financier : dette effacée en une nuit',
    category: TestimonyCategory.finances,
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    stats: const TestimonyStats(views: 654, comments: 18, likes: 45, prayers: 77),
    preview:
        'Notre entreprise était au bord de la faillite avec une dette de 50 millions. '
        'Après une nuit de jeûne et de prière, le lendemain matin…',
  ),
  AudioTestimony(
    id: 't5',
    author: const TestimonyAuthor(uid: 'u5', displayName: 'Grace Mballa'),
    title: 'Protection miraculeuse lors d\'un accident',
    category: TestimonyCategory.protection,
    createdAt: DateTime.now().subtract(const Duration(hours: 18)),
    stats: const TestimonyStats(views: 432, comments: 9, likes: 38, prayers: 55),
    durationSeconds: 412,
    transcriptPreview:
        'Le car a fait plusieurs tonneaux. Tous les passagers ont été blessés gravement sauf moi…',
  ),
  TextTestimony(
    id: 't6',
    author: const TestimonyAuthor(uid: 'u6', displayName: 'Paul Nkeng'),
    title: 'Conversion radicale : d\'imam à pasteur',
    category: TestimonyCategory.conversion,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    stats: const TestimonyStats(views: 3400, comments: 89, likes: 287, prayers: 401),
    preview:
        'J\'ai grandi dans une famille musulmane dévouée. Pendant 30 ans, j\'ai combattu le christianisme '
        'avec toute mon énergie. Puis, une nuit, Jésus m\'est apparu en rêve…',
  ),
];

// ============================================================================
// FeedNotifier — liste mutable (ajout depuis publish, filtrage par catégorie)
// ============================================================================

class FeedNotifier extends Notifier<List<Testimony>> {
  @override
  List<Testimony> build() {
    // Démarrer avec les stubs puis enrichir depuis SQLite de façon asynchrone
    Future.microtask(_loadFromDb);
    return List<Testimony>.from(_stubTestimonies);
  }

  // ── Charger les témoignages publiés depuis SQLite ─────────────────────────

  Future<void> _loadFromDb() async {
    try {
      final dao  = TestimonyDao(DatabaseService());
      final rows = await dao.getFeed();
      if (rows.isEmpty) return;

      final fromDb = rows
          .map(_rowToTestimony)
          .whereType<Testimony>()
          .toList();

      if (fromDb.isEmpty) return;

      // Fusionner : DB en tête, stubs à la fin (sans doublons)
      final dbIds = fromDb.map((t) => t.id).toSet();
      final stubs = state.where((t) => !dbIds.contains(t.id)).toList();
      state = [...fromDb, ...stubs];
    } catch (_) {
      // SQLite non disponible (web, premier lancement) — continuer avec stubs
    }
  }

  // ── Convertir une ligne SQLite en objet Testimony ─────────────────────────

  static Testimony? _rowToTestimony(Map<String, dynamic> row) {
    try {
      final type   = row['type'] as String? ?? 'text';
      final id     = row['id']   as String;
      final author = TestimonyAuthor(
        uid:         row['user_id']     as String? ?? '',
        displayName: row['author_name'] as String? ?? 'Anonyme',
        avatarUrl:   row['author_avatar'] as String?,
      );
      final title    = row['title']    as String? ?? '';
      final catName  = row['category'] as String? ?? '';
      final category = TestimonyCategory.values
          .firstWhere((c) => c.name == catName,
              orElse: () => TestimonyCategory.guerison);
      final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now();
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
            durationSeconds: row['duration_sec'] as int? ?? 0,
            transcriptPreview: row['body_text'] as String? ?? '',
            mediaPath: row['media_url'] as String?,
          );
        case 'video':
          return VideoTestimony(
            id: id, author: author, title: title,
            category: category, createdAt: createdAt, stats: stats,
            durationSeconds: row['duration_sec'] as int? ?? 0,
            thumbnailUrl:   row['cover_url']  as String? ?? '',
            mediaPath:      row['media_url']  as String?,
          );
        default: // text
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

  // ── Ajouter (feed en mémoire ; SQLite géré par publish_provider) ──────────

  void addTestimony(Testimony testimony) {
    state = [testimony, ...state];
  }

  void removeTestimony(String id) {
    state = state.where((t) => t.id != id).toList();
  }
}

final feedNotifierProvider =
    NotifierProvider<FeedNotifier, List<Testimony>>(FeedNotifier.new);

// ============================================================================
// Feed filtré par catégorie (utilisé par HomeScreen)
// ============================================================================

final feedProvider = Provider<List<Testimony>>((ref) {
  final all = ref.watch(feedNotifierProvider);
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
// Interactions : likes, prières, réactions emoji (par ID de témoignage)
// ============================================================================

class TestimonyInteractions {
  const TestimonyInteractions({
    this.liked = const {},
    this.prayed = const {},
    this.saved = const {},
    this.reactions = const {},
  });

  /// IDs des témoignages aimés (rétrocompatibilité — miroir de reactions[id]==like).
  final Set<String> liked;

  /// IDs des témoignages pour lesquels l'utilisateur a prié.
  final Set<String> prayed;

  /// IDs des témoignages sauvegardés.
  final Set<String> saved;

  /// Réaction emoji choisie par l'utilisateur, indexée par ID de témoignage.
  final Map<String, ReactionType> reactions;

  // ── Mutation : réaction ───────────────────────────────────────────────────

  /// Pose ou remplace la réaction de l'utilisateur sur [id].
  /// Si [type] == [ReactionType.like], synchronise aussi [liked].
  TestimonyInteractions setReaction(String id, ReactionType type) {
    final newReactions = Map<String, ReactionType>.from(reactions)..[id] = type;
    final newLiked = Set<String>.from(liked);
    if (type == ReactionType.like) {
      newLiked.add(id);
    } else {
      // Une autre réaction ne compte pas comme "like"
      newLiked.remove(id);
    }
    return copyWith(reactions: newReactions, liked: newLiked);
  }

  /// Retire la réaction de l'utilisateur sur [id].
  TestimonyInteractions removeReaction(String id) {
    final newReactions = Map<String, ReactionType>.from(reactions)..remove(id);
    final newLiked = Set<String>.from(liked)..remove(id);
    return copyWith(reactions: newReactions, liked: newLiked);
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

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
  @override
  TestimonyInteractions build() => const TestimonyInteractions();

  // ── Réactions emoji ───────────────────────────────────────────────────────

  /// Pose ou remplace la réaction de l'utilisateur sur [id].
  void setReaction(String id, ReactionType type) {
    state = state.setReaction(id, type);
  }

  /// Retire la réaction de l'utilisateur sur [id].
  void removeReaction(String id) {
    state = state.removeReaction(id);
  }

  /// Retourne la réaction courante de l'utilisateur pour [id], ou null.
  ReactionType? getReaction(String id) => state.reactions[id];

  // ── Compatibilité ascendante ──────────────────────────────────────────────

  void toggleLike(String id) {
    if (state.reactions.containsKey(id) &&
        state.reactions[id] == ReactionType.like) {
      state = state.removeReaction(id);
    } else {
      state = state.setReaction(id, ReactionType.like);
    }
  }

  void togglePray(String id) {
    final prayed = {...state.prayed};
    if (prayed.contains(id)) {
      prayed.remove(id);
    } else {
      prayed.add(id);
    }
    state = state.copyWith(prayed: prayed);
  }

  void toggleSave(String id) {
    final saved = {...state.saved};
    if (saved.contains(id)) {
      saved.remove(id);
    } else {
      saved.add(id);
    }
    state = state.copyWith(saved: saved);
  }

  bool isLiked(String id)  => state.liked.contains(id);
  bool isPrayed(String id) => state.prayed.contains(id);
  bool isSaved(String id)  => state.saved.contains(id);
}

final interactionProvider =
    NotifierProvider<InteractionNotifier, TestimonyInteractions>(
        InteractionNotifier.new);

// Sélecteurs pratiques
final likedIdsProvider = Provider<Set<String>>(
    (ref) => ref.watch(interactionProvider).liked);

final prayedIdsProvider = Provider<Set<String>>(
    (ref) => ref.watch(interactionProvider).prayed);

final savedIdsProvider = Provider<Set<String>>(
    (ref) => ref.watch(interactionProvider).saved);

/// Map complète testimony-id → ReactionType pour l'utilisateur courant.
final reactionsMapProvider = Provider<Map<String, ReactionType>>(
    (ref) => ref.watch(interactionProvider).reactions);

// ============================================================================
// Statistiques effectives — intègre les interactions locales de l'utilisateur
// ============================================================================

/// Statistiques effectives d'un témoignage après application des interactions
/// locales de l'utilisateur (like, prière, sauvegarde).
///
/// - [likes]   = stats.likes   + (isLiked  ? 1 : 0)
/// - [prayers] = stats.prayers + (isPrayed ? 1 : 0)
/// - [saves]   = 0             + (isSaved  ? 1 : 0)
///
/// Les champs [views] et [comments] sont repris tels quels depuis [TestimonyStats].
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

  /// Nombre de sauvegardes (uniquement l'interaction locale pour l'instant).
  final int saves;
  final int views;
  final int comments;
}

/// Provider de famille qui calcule les [_EffectiveStats] pour un témoignage
/// identifié par son [id].
///
/// Usage dans un widget :
/// ```dart
/// final stats = ref.watch(computedStatsProvider('t1'));
/// Text('${stats.likes} likes');
/// ```
final computedStatsProvider =
    Provider.family<_EffectiveStats, String>((ref, id) {
  // Localiser le témoignage dans le feed
  final feed = ref.watch(feedNotifierProvider);
  final testimony = feed.cast<Testimony?>().firstWhere(
        (t) => t?.id == id,
        orElse: () => null,
      );

  // Interactions locales de l'utilisateur courant
  final interactions = ref.watch(interactionProvider);
  final isLiked  = interactions.liked.contains(id);
  final isPrayed = interactions.prayed.contains(id);
  final isSaved  = interactions.saved.contains(id);

  // Stats de base (zéro si le témoignage est introuvable)
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

final dailyVerseProvider = Provider<DailyVerse>((ref) {
  return const DailyVerse(
    text:
        '« Car je connais les projets que j\'ai formés sur vous, dit l\'Éternel, '
        'projets de paix et non de malheur, afin de vous donner un avenir et de l\'espérance. »',
    reference: 'Jérémie 29 : 11',
  );
});

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
