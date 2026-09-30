import '../../home/widgets/compact_testimony_tile.dart';
import '../../home/widgets/testimony_card_header.dart' show openAuthorProfile;
import '../../community/widgets/follow_button.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../../../core/app_constants.dart';
import '../../../core/local_db/daos/comment_dao.dart';
import '../../../core/local_db/database_service.dart';
import '../../../core/media/media_quality.dart' show OfflineMedia;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/api_service.dart' show apiServiceProvider;
import '../../../shared/models/comment_model.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/rich_text_utils.dart';
import '../../../shared/widgets/guest_gate.dart';
import '../../../shared/widgets/testimony_proofs_card.dart';
import '../../../shared/widgets/youtube_video_player.dart';
import '../../../services/audio_player_service.dart' show audioPlayerProvider;
import '../providers/recommendations_provider.dart';
import '../providers/tts_provider.dart';
import '../widgets/testimony_info.dart';
import '../widgets/tts_listen_card.dart';
import 'audio_player_screen.dart';
import 'video_player_screen.dart';

// ── Modèle commentaire local (in-memory + SQLite) ─────────────────────────────

class _LocalComment {
  const _LocalComment({
    required this.id,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final int likes = 0;

  String get initials {
    final parts = authorName.trim().split(' ');
    if (parts.length >= 2 && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }

  factory _LocalComment.fromModel(CommentModel m) => _LocalComment(
    id: m.id,
    authorName: m.user?.displayName ?? 'Anonyme',
    body: m.text,
    createdAt: DateTime.tryParse(m.createdAt ?? '') ?? DateTime.now(),
  );
}

// ============================================================================
// Testimony Detail Screen
// ============================================================================

/// Full detail view for a single testimony.
/// Supports text-only, audio, and video testimony types.
///
/// Widget tree:
///   TestimonyDetailScreen
///   └─ Scaffold
///      ├─ body: CustomScrollView
///      │  ├─ _HeroSliverAppBar         (cover + back + share/bookmark)
///      │  └─ SliverToBoxAdapter
///      │     └─ Column
///      │        ├─ _AuthorCard
///      │        ├─ _MetaRow             (category chip + date)
///      │        ├─ _TitleText
///      │        ├─ TestimonyStatsRow    (❤ · partage · commentaires · télécharger)
///      │        ├─ _ContentBody
///      │        ├─ _AudioPlayerEmbed?   (if audio type)
///      │        ├─ _VideoPlayerEmbed?   (if video type)
///      │        ├─ _BibleVerseSection
///      │        ├─ _CommentsSection
///      │        └─ _SimilarTestimonies
///      └─ bottomNavigationBar: _StickyReactionBar
class TestimonyDetailScreen extends ConsumerStatefulWidget {
  const TestimonyDetailScreen({required this.testimonyId, super.key});
  final String testimonyId;

  @override
  ConsumerState<TestimonyDetailScreen> createState() =>
      _TestimonyDetailScreenState();
}

class _TestimonyDetailScreenState extends ConsumerState<TestimonyDetailScreen> {
  // ── Interactions ──────────────────────────────────────────────────────────
  bool _isBookmarked = false;
  bool _isLiked = false;
  bool _isPraying = false;
  int _likeCount = 0;
  int _prayCount = 0;

  // ── Testimony (fallback when not in feed) ─────────────────────────────────
  Testimony? _singleTestimony;

  /// Preuves privées relues sur le serveur (auteur, modération) : la version
  /// du fil peut être ancienne ou ne pas les contenir.
  List<TestimonyProof>? _proofs;

  // ── Commentaires locaux ───────────────────────────────────────────────────
  List<_LocalComment> _comments = [];
  bool _loadingComments = true;

  // ── Lecture vocale (témoignages texte) ────────────────────────────────────
  late final TtsController _tts;
  bool _autoReadHandled = false;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFromTestimony();
      _loadComments();
    });
  }

  @override
  void dispose() {
    // Quitter l'écran arrête la lecture vocale de ce témoignage.
    final id = widget.testimonyId;
    Future.microtask(() => _tts.stopFor(id));
    super.dispose();
  }

  /// « Lecture automatique » : démarre la lecture vocale à l'ouverture d'un
  /// témoignage texte. Sur le web, les navigateurs bloquent le son sans geste
  /// de l'utilisateur : la lecture n'y démarre qu'après un appui.
  void _maybeAutoRead(Testimony t) {
    if (_autoReadHandled || t is! TextTestimony) return;
    final tts = ref.read(ttsControllerProvider);
    if (!tts.prefsLoaded) return;
    _autoReadHandled = true;
    if (!tts.autoRead || kIsWeb || tts.isFor(t.id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) startTestimonyReading(context, ref, t);
    });
  }

  void _initFromTestimony() {
    final feed = ref.read(feedNotifierProvider);
    final t = feed.where((t) => t.id == widget.testimonyId).firstOrNull;
    if (t == null) {
      _fetchSingleTestimony();
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user != null && (user.id == t.author.uid || user.canModerate)) {
      _fetchSingleTestimony(proofsOnly: true);
    }
    if (mounted) {
      setState(() {
        _likeCount = t.stats.likes;
        _prayCount = t.stats.prayers;
        _isLiked = t.isLiked;
        _isPraying = t.isPrayed;
      });
    }
  }

  Future<void> _fetchSingleTestimony({bool proofsOnly = false}) async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get<Map<String, dynamic>>(
        AppConstants.testimonyById(widget.testimonyId),
      );
      final t = testimonyFromApiJson(response.data);
      if (t != null && mounted && proofsOnly) {
        setState(() => _proofs = t.proofs);
        return;
      }
      if (t != null && mounted) {
        setState(() {
          _singleTestimony = t;
          _likeCount = t.stats.likes;
          _prayCount = t.stats.prayers;
          _isLiked = t.isLiked;
          _isPraying = t.isPrayed;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    final dao = CommentDao(DatabaseService());

    // 1. Affichage immédiat depuis SQLite
    try {
      final rows = await dao.getByTestimony(widget.testimonyId);
      if (rows.isNotEmpty && mounted) {
        setState(() {
          _comments = rows
              .map(
                (r) => _LocalComment(
                  id: r['id'] as String,
                  authorName: r['author_name'] as String? ?? 'Anonyme',
                  body: r['body'] as String? ?? '',
                  createdAt:
                      DateTime.tryParse(r['created_at'] as String? ?? '') ??
                      DateTime.now(),
                ),
              )
              .toList();
          _loadingComments = false;
        });
      }
    } catch (_) {}

    // 2. Synchronisation depuis le serveur
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get<dynamic>(
        AppConstants.testimonyComments(widget.testimonyId),
      );
      final raw = response.data;
      final items = raw is List
          ? raw
          : raw is Map
          ? (raw['data'] as List? ?? [])
          : <dynamic>[];

      final apiList = items
          .whereType<Map>()
          .map((e) => CommentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (mounted) {
        setState(() {
          _comments = apiList.map(_LocalComment.fromModel).toList();
          _loadingComments = false;
        });
      }

      // Cache dans SQLite
      for (final c in apiList) {
        await dao.insert({
          'id': c.id,
          'testimony_id': widget.testimonyId,
          'user_id': c.userId,
          'author_name': c.user?.displayName ?? '',
          'parent_id': c.parentId,
          'body': c.text,
          'likes': c.likesCount,
          'reply_count': c.repliesCount,
          'created_at': c.createdAt ?? DateTime.now().toIso8601String(),
          'updated_at': c.updatedAt ?? DateTime.now().toIso8601String(),
          'synced_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _addComment(String text) async {
    final user = ref.read(currentUserProvider);
    final authorName = user?.displayName ?? 'Vous';
    final now = DateTime.now();
    final tempId = 'tmp_${now.millisecondsSinceEpoch}';
    final dao = CommentDao(DatabaseService());

    // Optimistic UI
    setState(
      () => _comments = [
        ..._comments,
        _LocalComment(
          id: tempId,
          authorName: authorName,
          body: text,
          createdAt: now,
        ),
      ],
    );

    // Envoi au serveur
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post<Map<String, dynamic>>(
        AppConstants.testimonyComments(widget.testimonyId),
        data: {'text': text},
      );
      final saved = CommentModel.fromJson(response.data);

      // Remplacer le commentaire temporaire par la version serveur
      if (mounted) {
        setState(() {
          _comments = [
            ..._comments.where((c) => c.id != tempId),
            _LocalComment.fromModel(saved),
          ];
        });
        // Répercuter le nouveau commentaire sur les compteurs du feed
        ref
            .read(feedNotifierProvider.notifier)
            .applyOptimisticDelta(widget.testimonyId, comments: 1);
      }

      await dao.insert({
        'id': saved.id,
        'testimony_id': widget.testimonyId,
        'user_id': saved.userId,
        'author_name': saved.user?.displayName ?? authorName,
        'parent_id': saved.parentId,
        'body': saved.text,
        'likes': 0,
        'reply_count': 0,
        'created_at': saved.createdAt ?? now.toIso8601String(),
        'updated_at': saved.updatedAt ?? now.toIso8601String(),
        'synced_at': now.toIso8601String(),
      });
    } catch (_) {
      // Conserver l'optimistic, sauver avec l'ID temporaire
      try {
        await dao.insert({
          'id': tempId,
          'testimony_id': widget.testimonyId,
          'user_id': user?.id ?? 'anon',
          'author_name': authorName,
          'body': text,
          'likes': 0,
          'reply_count': 0,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      } catch (_) {}
    }
  }

  /// Auteur ou équipe de modération : les preuves affichées peuvent être privées.
  bool _canSeePrivateProofs(Testimony t) {
    final user = ref.read(currentUserProvider);
    return user != null && (user.id == t.author.uid || user.canModerate);
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedNotifierProvider);
    final testimony =
        feed.where((t) => t.id == widget.testimonyId).firstOrNull ??
        _singleTestimony;

    if (testimony == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(backgroundColor: Colors.transparent),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = testimony.author.uid == (currentUser?.id ?? '');
    final fr = AppLocalizations.of(context).isFr;

    final isAudio = testimony is AudioTestimony;
    final isText = testimony is TextTestimony;

    final bodyText = isText
        ? testimony.preview
        : isAudio
        ? testimony.transcriptPreview
        : testimony.title;

    // Lecture automatique (préférence locale, lue de façon asynchrone).
    if (isText && ref.watch(ttsControllerProvider.select((s) => s.prefsLoaded))) {
      _maybeAutoRead(testimony);
    }

    final verse = _extractBibleVerse(testimony);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // Ouvert depuis un lien partagé, le détail est seul dans la pile :
      // le bouton retour système mène alors à l'accueil au lieu de fermer l'app.
      child: PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/home');
        },
        child: Scaffold(
          backgroundColor: AppColors.surface,
          extendBodyBehindAppBar: true,
          body: CustomScrollView(
            slivers: [
              _HeroSliverAppBar(
                category: testimony.category,
                isBookmarked: _isBookmarked,
                onBookmark: _toggleSave,
                onShare: () => _shareTestimony(testimony),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Lecteur audio inline (en haut, comme le lecteur vidéo)
                    if (testimony is AudioTestimony)
                      _AudioPlayerEmbed(testimony: testimony),

                    // Lecteur vidéo inline (lecteur YouTube si publiée par lien)
                    if (testimony is VideoTestimony && testimony.isYouTube)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: ClipRRect(
                          borderRadius: AppRadius.cardRadius,
                          child: YouTubeVideoPlayer(
                            videoId: testimony.youtubeId!,
                            autoPlay: false,
                          ),
                        ),
                      )
                    else if (testimony is VideoTestimony)
                      _VideoPlayerEmbed(
                        testimonyId: testimony.id,
                        durationSeconds: testimony.durationSeconds,
                        mediaPath: testimony.mediaPath,
                        thumbnailUrl: testimony.thumbnailUrl,
                      ),

                    // Titre
                    _TitleText(title: testimony.title),

                    // Auteur : avatar, nom + badge, « vues · date », Suivre
                    _AuthorCard(
                      author: testimony.author,
                      isOwnProfile: isOwnProfile,
                      meta: viewsAndAge(testimony, fr: fr),
                    ),

                    // Catégorie (badge jaune)
                    _MetaRow(category: testimony.category),

                    // Lecture vocale d'un témoignage texte
                    if (testimony is TextTestimony)
                      TtsListenCard(testimony: testimony),

                    // Corps du témoignage
                    if (isText || isAudio) _ContentBody(text: bodyText),

                    // ❤ · partage · commentaires · télécharger
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 8, 12),
                      child: TestimonyStatsRow(
                        testimony: testimony,
                        likes: _likeCount,
                        isLiked: _isLiked,
                        comments: _comments.length,
                        prayers: _prayCount,
                        isPraying: _isPraying,
                        onLike: _toggleLike,
                        onPray: _togglePray,
                        onShare: () => _onShare(testimony),
                        onComment: () => _showCommentsSheet(context),
                        fr: fr,
                      ),
                    ),
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.border,
                    ),
                    const SizedBox(height: 16),

                    // Verset biblique (masqué si le témoignage n'en a pas)
                    _BibleVerseSection(
                      verse: verse,
                      verseRef: _extractBibleVerseRef(testimony),
                    ),

                    // Preuves : auteur et modération, ou public si l'auteur les a publiées
                    TestimonyProofsCard(
                      proofs: _proofs ?? testimony.proofs,
                      forStaffOrAuthor: _canSeePrivateProofs(testimony),
                    ),

                    // Commentaires (preview + saisie)
                    _CommentsSection(
                      comments: _comments,
                      isLoading: _loadingComments,
                      onOpenAll: () => _showCommentsSheet(context),
                      currentUser:
                          ref.read(currentUserProvider)?.displayName ?? 'Vous',
                    ),

                    _SimilarTestimonies(
                      category: testimony.category,
                      excludeId: testimony.id,
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _StickyReactionBar(
            isLiked: _isLiked,
            isPraying: _isPraying,
            isBookmarked: _isBookmarked,
            onLike: _toggleLike,
            onPray: _togglePray,
            onComment: () => _showCommentsSheet(context),
            onBookmark: _toggleSave,
            onShare: () => _onShare(testimony),
          ),
        ),
      ),
    );
  }

  // ── Actions réservées aux membres (mode invité : feuille « compte requis »)

  Future<void> _toggleLike() async {
    if (!await requireAccount(context, ref, reason: 'réagir aux témoignages')) {
      return;
    }
    if (!mounted) return;
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    if (!wasLiked) {
      ref
          .read(interactionProvider.notifier)
          .setReaction(widget.testimonyId, ReactionType.like);
    } else {
      ref.read(interactionProvider.notifier).removeReaction(widget.testimonyId);
    }
  }

  Future<void> _togglePray() async {
    if (!await requireAccount(context, ref, reason: 'réagir aux témoignages')) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _isPraying = !_isPraying;
      _prayCount += _isPraying ? 1 : -1;
    });
    ref.read(interactionProvider.notifier).togglePray(widget.testimonyId);
  }

  Future<void> _toggleSave() async {
    if (!await requireAccount(context, ref, reason: 'enregistrer vos favoris')) {
      return;
    }
    if (!mounted) return;
    setState(() => _isBookmarked = !_isBookmarked);
    ref.read(interactionProvider.notifier).toggleSave(widget.testimonyId);
  }

  void _onShare(Testimony testimony) {
    _shareTestimony(testimony);
    ref.read(interactionProvider.notifier).recordShare(widget.testimonyId);
  }

  Future<void> _showCommentsSheet(BuildContext context) async {
    if (!await requireAccount(context, ref,
        reason: 'commenter les témoignages')) {
      return;
    }
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsBottomSheet(
        testimonyId: widget.testimonyId,
        comments: _comments,
        currentUser: ref.read(currentUserProvider)?.displayName ?? 'Vous',
        onAdd: _addComment,
      ),
    );
  }

  void _shareTestimony(Testimony testimony) {
    // share_url du serveur : lien https ouvert directement par l'app.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ShareSheet(title: testimony.title, link: testimony.shareLink),
    );
  }

  static String? _extractBibleVerse(Testimony t) {
    if (t is TextTestimony) return t.bibleVerse;
    if (t is AudioTestimony) return t.bibleVerse;
    if (t is VideoTestimony) return t.bibleVerse;
    return null;
  }

  static String? _extractBibleVerseRef(Testimony t) {
    if (t is TextTestimony) return t.bibleVerseRef;
    if (t is AudioTestimony) return t.bibleVerseRef;
    if (t is VideoTestimony) return t.bibleVerseRef;
    return null;
  }
}

// ============================================================================
// Hero Sliver App Bar
// ============================================================================

class _HeroSliverAppBar extends StatelessWidget {
  const _HeroSliverAppBar({
    required this.category,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onShare,
  });

  final TestimonyCategory category;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onShare;

  static IconData _categoryIcon(TestimonyCategory cat) => switch (cat) {
    TestimonyCategory.guerison => Icons.healing_rounded,
    TestimonyCategory.delivrance => Icons.lock_open_rounded,
    TestimonyCategory.conversion => Icons.rotate_right_rounded,
    TestimonyCategory.mariage => Icons.favorite_rounded,
    TestimonyCategory.famille => Icons.people_rounded,
    TestimonyCategory.finances => Icons.attach_money_rounded,
    TestimonyCategory.miracles => Icons.auto_awesome_rounded,
    TestimonyCategory.protection => Icons.shield_rounded,
    TestimonyCategory.ministere => Icons.record_voice_over_rounded,
    TestimonyCategory.salut => Icons.star_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.surface,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _CircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => _leaveDetail(context),
        ),
      ),
      actions: [
        _CircleIconButton(
          icon: isBookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          onTap: onBookmark,
          color: isBookmarked ? AppColors.secondary : AppColors.primary,
        ),
        const SizedBox(width: 6),
        _CircleIconButton(icon: Icons.share_rounded, onTap: onShare),
        const SizedBox(width: 12),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Dégradé bleu → bleu foncé (seul dégradé autorisé par la charte)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.blueGradient,
                ),
              ),
            ),
            // Motif discret de croix
            Opacity(
              opacity: 0.08,
              child: CustomPaint(painter: _CrossPatternPainter()),
            ),
            // Icône + catégorie (dynamiques)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _categoryIcon(category),
                        size: 32,
                        color: AppColors.sun,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      category.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.surface.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ============================================================================
// Author Card
// ============================================================================

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({
    required this.author,
    required this.isOwnProfile,
    required this.meta,
  });

  final TestimonyAuthor author;
  final bool isOwnProfile;

  /// « 12,4k vues · il y a 5 jours ».
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 4),
      child: TestimonyAuthorRow(
        author: author,
        meta: meta,
        // Profil de l'auteur (docs/fonctionnalites/abonnements.md du backend)
        onTap: () => openAuthorProfile(context, author.uid),
        // Suivre (masqué sur son propre témoignage) : état partagé avec toute l'application.
        trailing: isOwnProfile
            ? null
            : FollowButton(
                userId: author.uid,
                displayName: author.displayName,
                compact: true,
              ),
      ),
    );
  }
}

// ============================================================================
// Meta Row (badge de catégorie)
// ============================================================================

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.category});
  final TestimonyCategory category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [CategoryBadge(category: category)],
      ),
    );
  }
}

// ============================================================================
// Title
// ============================================================================

class _TitleText extends StatelessWidget {
  const _TitleText({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(title, style: AppTextStyles.h2),
    );
  }
}

// ============================================================================
// Content Body
// ============================================================================

class _ContentBody extends StatelessWidget {
  const _ContentBody({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      // Texte complet mis en forme, dévoilé morceau par morceau.
      child: ProgressiveRichText(
        text: text,
        style: AppTextStyles.bodyLarge,
        initialChars: 700,
        stepChars: 1200,
        linkStyle: const TextStyle(
          fontFamily: AppFonts.family,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ============================================================================
// Embedded Audio Player (inline preview, opens full player on tap)
// ============================================================================

class _AudioPlayerEmbed extends ConsumerStatefulWidget {
  const _AudioPlayerEmbed({required this.testimony});

  final AudioTestimony testimony;

  @override
  ConsumerState<_AudioPlayerEmbed> createState() => _AudioPlayerEmbedState();
}

class _AudioPlayerEmbedState extends ConsumerState<_AudioPlayerEmbed> {
  static String _absUrl(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) return src;
    // Fichier téléchargé : chemin local, pas d'adresse du serveur.
    if (OfflineMedia.isLocalPath(src)) return src;
    final root = AppConstants.baseUrl.replaceAll(RegExp(r'/api/v\d+$'), '');
    return src.startsWith('/') ? '$root$src' : '$root/$src';
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.testimony;
    final player = ref.watch(audioPlayerProvider);
    final absPath = t.mediaPath != null ? _absUrl(t.mediaPath!) : '';
    // La version lue peut être une autre qualité que le fichier original :
    // on reconnaît aussi la piste via le témoignage en cours.
    final isThisTrack =
        player.currentTestimony?.id == t.id ||
        (absPath.isNotEmpty && player.url == absPath);
    final isPlaying = isThisTrack && player.isPlaying;
    final progress = isThisTrack ? player.progress : 0.0;
    final elapsed = isThisTrack ? _fmt(player.position) : '00:00';
    final isOffline = isThisTrack && player.qualityLabel == OfflineMedia.label;
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AudioPlayerScreen(testimonyId: t.id, mediaPath: t.mediaPath),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(14),
        decoration: AppShadows.cardDecoration,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.detailAudioLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${t.formattedDuration}  ·  ${l10n.detailTapToOpen}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isOffline) ...[
                  const SizedBox(width: 6),
                  const OfflineBadge(),
                ],
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final audio = ref.read(audioPlayerProvider.notifier);
                    // Un seul son à la fois : arrêter la lecture vocale.
                    ref.read(ttsControllerProvider.notifier).stop();
                    if (isPlaying) {
                      audio.pause();
                    } else if (isThisTrack) {
                      audio.resume();
                    } else if (absPath.isNotEmpty || t.renditions.isNotEmpty) {
                      // Qualité choisie selon les préférences et le réseau.
                      audio.setTestimonyQueue([t]);
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.surface,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.secondary,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(elapsed, style: AppTextStyles.bodySmall),
                Text(t.formattedDuration, style: AppTextStyles.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Embedded Video Player (inline preview, opens full player on tap)
// ============================================================================

class _VideoPlayerEmbed extends StatelessWidget {
  const _VideoPlayerEmbed({
    required this.testimonyId,
    required this.durationSeconds,
    this.mediaPath,
    this.thumbnailUrl,
  });

  final String testimonyId;
  final int durationSeconds;
  final String? mediaPath;
  final String? thumbnailUrl;

  static String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final thumb = thumbnailUrl;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              VideoPlayerScreen(testimonyId: testimonyId, mediaPath: mediaPath),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Zone vidéo (reste sombre) ; miniature si disponible.
                const ColoredBox(color: AppColors.primaryDark),
                if (thumb != null && thumb.startsWith('http'))
                  Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                // Bouton lecture
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                ),
                // Durée
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      durationSeconds > 0 ? _fmt(durationSeconds) : '--:--',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Bible Verse Section (carte « Insight »)
// ============================================================================

class _BibleVerseSection extends StatelessWidget {
  const _BibleVerseSection({required this.verse, this.verseRef});

  final String? verse;
  final String? verseRef;

  @override
  Widget build(BuildContext context) {
    if (verse == null || verse!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: InsightVerseCard(
        verse: verse!,
        reference: verseRef,
        title: AppLocalizations.of(context).detailBibleTitle,
      ),
    );
  }
}

// ============================================================================
// Comments Section (preview)
// ============================================================================

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.comments,
    required this.isLoading,
    required this.onOpenAll,
    required this.currentUser,
  });

  final List<_LocalComment> comments;
  final bool isLoading;
  final VoidCallback onOpenAll;
  final String currentUser;

  @override
  Widget build(BuildContext context) {
    final preview = comments.take(2).toList();
    final count = comments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                count == 0
                    ? AppLocalizations.of(context).detailComments
                    : '${AppLocalizations.of(context).detailComments} ($count)',
                style: AppTextStyles.h4,
              ),
              if (count > 2)
                TextButton(
                  onPressed: onOpenAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    AppLocalizations.of(context).detailSeeAll,
                    style: const TextStyle(fontFamily: AppFonts.family, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),

        // ── Saisie rapide (ouvre la bottom sheet) ────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GestureDetector(
            onTap: onOpenAll,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withAlpha(30),
                  child: Text(
                    currentUser.isNotEmpty ? currentUser[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFamily: AppFonts.family,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      AppLocalizations.of(context).detailAddComment,
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Aperçu des commentaires ───────────────────────────────────────
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (preview.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              AppLocalizations.of(context).detailFirstComment,
              style: AppTextStyles.bodySmall,
            ),
          )
        else
          ...preview.map(
            (c) => _CommentItem(
              name: c.authorName,
              initials: c.initials,
              text: c.body,
              time: c.timeAgo,
              likeCount: c.likes,
            ),
          ),
      ],
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.name,
    required this.initials,
    required this.text,
    required this.time,
    required this.likeCount,
    this.isLiked = false,
    this.onLike,
    this.onReply,
  });

  final String name;
  final String initials;
  final String text;
  final String time;
  final int likeCount;
  final bool isLiked;
  final VoidCallback? onLike;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.border,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFamily: AppFonts.family,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.labelMedium),
                      const SizedBox(height: 4),
                      _buildMentionText(text, AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(time, style: AppTextStyles.bodySmall),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        children: [
                          Icon(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 13,
                            color: isLiked
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text('$likeCount', style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        AppLocalizations.of(context).detailReply,
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Similar Testimonies (format compact)
// ============================================================================

class _SimilarTestimonies extends ConsumerWidget {
  const _SimilarTestimonies({required this.category, required this.excludeId});

  final TestimonyCategory category;
  final String excludeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Suggestions du serveur d'abord (intérêts, comptes suivis, déjà vus en fin).
    final recAsync = ref.watch(recommendationsProvider(excludeId));
    // Pas de liste locale affichée puis remplacée : on attend la réponse.
    if (recAsync.isLoading) return const SizedBox.shrink();
    final recommended = recAsync.value ?? const <Testimony>[];
    // Repli local : même catégorie d'abord, puis les autres témoignages récents (8 au plus).
    final all = ref.watch(feedNotifierProvider).where((t) => t.id != excludeId);
    final similar = recommended.isNotEmpty
        ? recommended
        : [
            ...all.where((t) => t.category == category),
            ...all.where((t) => t.category != category),
          ].take(8).toList();

    if (similar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            AppLocalizations.of(context).detailSimilar,
            style: AppTextStyles.h4,
          ),
        ),
        // Format compact (lignes dépliables), comme la « liste compacte » du fil.
        for (final t in similar) CompactTestimonyTile(testimony: t),
      ],
    );
  }
}

// ============================================================================
// Sticky Reaction Bar (bottom)
// ============================================================================

class _StickyReactionBar extends StatelessWidget {
  const _StickyReactionBar({
    required this.isLiked,
    required this.isPraying,
    required this.isBookmarked,
    required this.onLike,
    required this.onPray,
    required this.onComment,
    required this.onBookmark,
    required this.onShare,
  });

  final bool isLiked;
  final bool isPraying;
  final bool isBookmarked;
  final VoidCallback onLike;
  final VoidCallback onPray;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.card,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Row(
                children: [
                  _ReactionButton(
                    icon: isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: l10n.detailLike,
                    active: isLiked,
                    activeColor: AppColors.danger,
                    onTap: onLike,
                  ),
                  _ReactionButton(
                    icon: Icons.volunteer_activism_rounded,
                    label: l10n.detailPray,
                    active: isPraying,
                    activeColor: AppColors.primary,
                    onTap: onPray,
                  ),
                  _ReactionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: l10n.detailComment,
                    onTap: onComment,
                  ),
                  _ReactionButton(
                    icon: isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    label: l10n.detailSave,
                    active: isBookmarked,
                    activeColor: AppColors.secondary,
                    onTap: onBookmark,
                  ),
                  _ReactionButton(
                    icon: Icons.share_rounded,
                    label: l10n.detailShare,
                    onTap: onShare,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Comments Bottom Sheet
// ============================================================================

/// Slide-up bottom sheet with full comment list and reply threading.
///
/// Widget tree:
///   _CommentsBottomSheet
///   └─ DraggableScrollableSheet
///      └─ Container (rounded top corners)
///         ├─ _DragHandle
///         ├─ _BottomSheetHeader ("Commentaires (34)" + close)
///         ├─ Divider
///         ├─ Expanded: ListView (comment list with replies)
///         └─ _CommentInputBar
class _CommentsBottomSheet extends StatefulWidget {
  const _CommentsBottomSheet({
    required this.testimonyId,
    required this.comments,
    required this.currentUser,
    required this.onAdd,
  });

  final String testimonyId;
  final List<_LocalComment> comments;
  final String currentUser;
  final Future<void> Function(String text) onAdd;

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;

  // Copie locale mise à jour immédiatement (optimistic UI)
  late List<_LocalComment> _local;

  // ── Likes et réponses ─────────────────────────────────────────────────────
  final Set<String> _likedIds = {};
  String? _replyingToName; // nom de l'auteur auquel on répond

  // ── @mention ──────────────────────────────────────────────────────────────
  String? _mentionQuery;
  List<String> _filteredUsers = const [];
  static const _mockUsers = [
    'Paul Mbeki',
    'Sarah Diallo',
    'John Osei',
    'Grace Nwosu',
    'David Kamau',
    'Marie Dupont',
    'Samuel Tchibozo',
    'Ruth Mensah',
    'Esther Yao',
    'Elie Ndoumbe',
  ];

  @override
  void initState() {
    super.initState();
    _local = List.from(widget.comments);
    _ctrl.addListener(_onTextChanged);
    // Auto-focus the input so keyboard appears immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    if (cursor <= 0 || cursor > text.length) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final before = text.substring(0, cursor);
    final match = RegExp(r'@(\w*)$').firstMatch(before);
    if (match != null) {
      final query = match.group(1) ?? '';
      final filtered = _mockUsers
          .where(
            (u) =>
                query.isEmpty ||
                u.toLowerCase().startsWith(query.toLowerCase()),
          )
          .take(5)
          .toList();
      setState(() {
        _mentionQuery = query;
        _filteredUsers = filtered;
      });
    } else {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
    }
  }

  void _insertMention(String username) {
    final handle = '@${username.replaceAll(' ', '_')}';
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final newBefore = before.replaceFirstMapped(
      RegExp(r'@\w*$'),
      (_) => '$handle ',
    );
    _ctrl.value = TextEditingValue(
      text: newBefore + after,
      selection: TextSelection.collapsed(offset: newBefore.length),
    );
    setState(() {
      _mentionQuery = null;
      _filteredUsers = [];
    });
    _focusNode.requestFocus();
  }

  void _toggleLike(String commentId) {
    setState(() {
      if (_likedIds.contains(commentId)) {
        _likedIds.remove(commentId);
      } else {
        _likedIds.add(commentId);
      }
    });
  }

  void _startReply(String authorName) {
    final handle = '@${authorName.replaceAll(' ', '_')} ';
    _ctrl.value = TextEditingValue(
      text: handle,
      selection: TextSelection.collapsed(offset: handle.length),
    );
    setState(() => _replyingToName = authorName);
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingToName = null);
    _ctrl.clear();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _ctrl.clear();
    _focusNode.unfocus();

    await widget.onAdd(text);

    // Ajouter en local pour mise à jour instantanée
    if (mounted) {
      setState(() {
        _local = [
          ..._local,
          _LocalComment(
            id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
            authorName: widget.currentUser,
            body: text,
            createdAt: DateTime.now(),
          ),
        ];
        _sending = false;
        _replyingToName = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const _DragHandle(),
              _BottomSheetHeader(
                title: _local.isEmpty
                    ? AppLocalizations.of(context).detailComments
                    : '${AppLocalizations.of(context).detailComments} (${_local.length})',
                onClose: () => Navigator.of(context).pop(),
              ),
              const Divider(height: 1, color: AppColors.border),

              // ── Liste des commentaires ─────────────────────────────────
              Expanded(
                child: _local.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: AppColors.textSecondary.withAlpha(80),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppLocalizations.of(context).detailNoComments,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: AppFonts.family,
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: _local.length,
                        itemBuilder: (_, i) {
                          final c = _local[i];
                          final isLiked = _likedIds.contains(c.id);
                          return _CommentItem(
                            name: c.authorName,
                            initials: c.initials,
                            text: c.body,
                            time: c.timeAgo,
                            likeCount: c.likes + (isLiked ? 1 : 0),
                            isLiked: isLiked,
                            onLike: () => _toggleLike(c.id),
                            onReply: () => _startReply(c.authorName),
                          );
                        },
                      ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // ── Bandeau "En réponse à" ────────────────────────────────
              if (_replyingToName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppColors.primary.withAlpha(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.reply_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${AppLocalizations.of(context).detailReplyingTo} @${_replyingToName!.replaceAll(' ', '_')}',
                          style: const TextStyle(
                            fontFamily: AppFonts.family,
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Suggestions @mention ──────────────────────────────────
              if (_mentionQuery != null && _filteredUsers.isNotEmpty)
                _MentionSuggestions(
                  users: _filteredUsers,
                  onTap: _insertMention,
                ),

              // ── Saisie ─────────────────────────────────────────────────
              _CommentInputBar(
                controller: _ctrl,
                focusNode: _focusNode,
                onSend: _send,
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _BottomSheetHeader extends StatelessWidget {
  const _BottomSheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.h4)),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textSecondary,
            iconSize: 22,
          ),
        ],
      ),
    );
  }
}

class _CommentInputBar extends StatelessWidget {
  const _CommentInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primarySoft,
            ),
            child: const Center(
              child: Text(
                'V',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFamily: AppFonts.family,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).detailCommentHint,
                hintStyle: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: AppColors.surface,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// @mention helpers
// ============================================================================

Widget _buildMentionText(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'@\w+');
  int last = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: base));
    }
    spans.add(
      TextSpan(
        text: m.group(0),
        style: base.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: base));
  }
  if (spans.isEmpty) return Text(text, style: base);
  return RichText(text: TextSpan(children: spans));
}

// ── Mention suggestions panel ────────────────────────────────────────────────

class _MentionSuggestions extends StatelessWidget {
  const _MentionSuggestions({required this.users, required this.onTap});

  final List<String> users;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.border),
          ...users.map((u) => _MentionTile(username: u, onTap: () => onTap(u))),
        ],
      ),
    );
  }
}

class _MentionTile extends StatelessWidget {
  const _MentionTile({required this.username, required this.onTap});

  final String username;
  final VoidCallback onTap;

  String get _initials {
    final parts = username.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withAlpha(30),
              child: Text(
                _initials,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  fontFamily: AppFonts.family,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '@${username.replaceAll(' ', '_')}',
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
            Text(
              username,
              style: const TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Share sheet (copier lien + partager)
// ============================================================================

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.title, required this.link});

  final String title;
  final String link;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).detailShareTitle,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            link,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ShareOption(
                  icon: Icons.copy_rounded,
                  label: AppLocalizations.of(context).detailCopyLink,
                  color: AppColors.primary,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: link));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context).detailLinkCopied,
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShareOption(
                  icon: Icons.share_rounded,
                  label: AppLocalizations.of(context).detailShareOn,
                  color: AppColors.secondary,
                  onTap: () {
                    Navigator.of(context).pop();
                    SharePlus.instance.share(
                      ShareParams(text: '$title\n\n$link'),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Custom Painters
// ============================================================================

class _CrossPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surface
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    const crossSize = 10.0;

    for (var x = 0.0; x < size.width + spacing; x += spacing) {
      for (var y = 0.0; y < size.height + spacing; y += spacing) {
        // Horizontal bar
        canvas.drawLine(
          Offset(x - crossSize, y),
          Offset(x + crossSize, y),
          paint,
        );
        // Vertical bar
        canvas.drawLine(
          Offset(x, y - crossSize),
          Offset(x, y + crossSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Retour depuis le détail : écran précédent s'il existe, sinon l'accueil
/// (cas d'un témoignage ouvert directement depuis un lien partagé).
void _leaveDetail(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}
