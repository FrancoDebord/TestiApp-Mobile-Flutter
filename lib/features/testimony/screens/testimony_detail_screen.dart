import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../../../core/app_constants.dart';
import '../../../core/local_db/daos/comment_dao.dart';
import '../../../core/local_db/database_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/api_service.dart' show apiServiceProvider;
import '../../../shared/models/comment_model.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../l10n/app_localizations.dart';
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
    id:         m.id,
    authorName: m.user?.displayName ?? 'Anonyme',
    body:       m.text,
    createdAt:  DateTime.tryParse(m.createdAt ?? '') ?? DateTime.now(),
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
///      │        ├─ _ReactionSummaryRow  (❤️ 🙏 💬 counts)
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

class _TestimonyDetailScreenState
    extends ConsumerState<TestimonyDetailScreen> {
  // ── Interactions ──────────────────────────────────────────────────────────
  bool _isBookmarked = false;
  bool _isFollowing  = false;
  bool _isLiked      = false;
  bool _isPraying    = false;
  int  _likeCount    = 0;
  int  _prayCount    = 0;

  // ── Commentaires locaux ───────────────────────────────────────────────────
  List<_LocalComment> _comments = [];
  bool _loadingComments = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFromTestimony();
      _loadComments();
    });
  }

  void _initFromTestimony() {
    final feed = ref.read(feedNotifierProvider);
    final t = feed.firstWhere(
      (t) => t.id == widget.testimonyId,
      orElse: () => feed.first,
    );
    if (mounted) {
      setState(() {
        _likeCount  = t.stats.likes;
        _prayCount  = t.stats.prayers;
        _isLiked    = t.isLiked;
        _isPraying  = t.isPrayed;
      });
    }
  }

  Future<void> _loadComments() async {
    final dao = CommentDao(DatabaseService());

    // 1. Affichage immédiat depuis SQLite
    try {
      final rows = await dao.getByTestimony(widget.testimonyId);
      if (rows.isNotEmpty && mounted) {
        setState(() {
          _comments = rows.map((r) => _LocalComment(
            id:         r['id'] as String,
            authorName: r['author_name'] as String? ?? 'Anonyme',
            body:       r['body'] as String? ?? '',
            createdAt:  DateTime.tryParse(r['created_at'] as String? ?? '') ??
                        DateTime.now(),
          )).toList();
          _loadingComments = false;
        });
      }
    } catch (_) {}

    // 2. Synchronisation depuis le serveur
    try {
      final api      = ref.read(apiServiceProvider);
      final response = await api.get<dynamic>(
        AppConstants.testimonyComments(widget.testimonyId),
      );
      final raw   = response.data;
      final items = raw is List
          ? raw
          : raw is Map ? (raw['data'] as List? ?? []) : <dynamic>[];

      final apiList = items
          .whereType<Map>()
          .map((e) => CommentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (mounted) {
        setState(() {
          _comments        = apiList.map(_LocalComment.fromModel).toList();
          _loadingComments = false;
        });
      }

      // Cache dans SQLite
      for (final c in apiList) {
        await dao.insert({
          'id':           c.id,
          'testimony_id': widget.testimonyId,
          'user_id':      c.userId,
          'author_name':  c.user?.displayName ?? '',
          'parent_id':    c.parentId,
          'body':         c.text,
          'likes':        c.likesCount,
          'reply_count':  c.repliesCount,
          'created_at':   c.createdAt ?? DateTime.now().toIso8601String(),
          'updated_at':   c.updatedAt ?? DateTime.now().toIso8601String(),
          'synced_at':    DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _addComment(String text) async {
    final user       = ref.read(currentUserProvider);
    final authorName = user?.displayName ?? 'Vous';
    final now        = DateTime.now();
    final tempId     = 'tmp_${now.millisecondsSinceEpoch}';
    final dao        = CommentDao(DatabaseService());

    // Optimistic UI
    setState(() => _comments = [
      ..._comments,
      _LocalComment(id: tempId, authorName: authorName, body: text, createdAt: now),
    ]);

    // Envoi au serveur
    try {
      final api      = ref.read(apiServiceProvider);
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
      }

      await dao.insert({
        'id':           saved.id,
        'testimony_id': widget.testimonyId,
        'user_id':      saved.userId,
        'author_name':  saved.user?.displayName ?? authorName,
        'parent_id':    saved.parentId,
        'body':         saved.text,
        'likes':        0,
        'reply_count':  0,
        'created_at':   saved.createdAt ?? now.toIso8601String(),
        'updated_at':   saved.updatedAt ?? now.toIso8601String(),
        'synced_at':    now.toIso8601String(),
      });
    } catch (_) {
      // Conserver l'optimistic, sauver avec l'ID temporaire
      try {
        await dao.insert({
          'id':           tempId,
          'testimony_id': widget.testimonyId,
          'user_id':      user?.id ?? 'anon',
          'author_name':  authorName,
          'body':         text,
          'likes':        0,
          'reply_count':  0,
          'created_at':   now.toIso8601String(),
          'updated_at':   now.toIso8601String(),
        });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    // Récupérer le témoignage depuis le feed
    final feed      = ref.watch(feedNotifierProvider);
    final testimony = feed.firstWhere(
      (t) => t.id == widget.testimonyId,
      orElse: () => feed.first,
    );

    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = testimony.author.uid == (currentUser?.id ?? '');

    final isAudio = testimony is AudioTestimony;
    final isVideo = testimony is VideoTestimony;
    final isText  = testimony is TextTestimony;

    final bodyText = isText
        ? testimony.preview
        : isAudio
            ? testimony.transcriptPreview
            : testimony.title;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBodyBehindAppBar: true,
        body: CustomScrollView(
          slivers: [
            _HeroSliverAppBar(
              category:     testimony.category,
              isBookmarked: _isBookmarked,
              onBookmark:   () => setState(() => _isBookmarked = !_isBookmarked),
              onShare:      () => _shareTestimony(testimony.title),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Auteur
                  _AuthorCard(
                    author:       testimony.author,
                    isFollowing:  _isFollowing,
                    isOwnProfile: isOwnProfile,
                    onFollow:     () => setState(() => _isFollowing = !_isFollowing),
                  ),

                  // Catégorie + date
                  _MetaRow(
                    category: testimony.category.label,
                    timeAgo:  _fmtTime(testimony.createdAt),
                  ),

                  // Titre réel
                  _TitleText(title: testimony.title),

                  // Compteurs de réactions
                  _ReactionSummaryRow(
                    likeCount:    _likeCount,
                    prayCount:    _prayCount,
                    commentCount: _comments.length,
                  ),

                  // Corps du témoignage
                  if (isText || isAudio)
                    _ContentBody(text: bodyText),

                  // Lecteur audio inline
                  if (isAudio)
                    _AudioPlayerEmbed(testimonyId: testimony.id),

                  // Lecteur vidéo inline
                  if (isVideo)
                    _VideoPlayerEmbed(testimonyId: testimony.id),

                  // Verset biblique
                  const _BibleVerseSection(),

                  // Commentaires (preview + saisie)
                  _CommentsSection(
                    comments:     _comments,
                    isLoading:    _loadingComments,
                    onOpenAll:    () => _showCommentsSheet(context),
                    currentUser:  ref.read(currentUserProvider)?.displayName ?? 'Vous',
                  ),

                  const _SimilarTestimonies(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _StickyReactionBar(
          isLiked:      _isLiked,
          isPraying:    _isPraying,
          isBookmarked: _isBookmarked,
          onLike: () => setState(() {
            _isLiked   = !_isLiked;
            _likeCount += _isLiked ? 1 : -1;
          }),
          onPray: () => setState(() {
            _isPraying  = !_isPraying;
            _prayCount += _isPraying ? 1 : -1;
          }),
          onComment:  () => _showCommentsSheet(context),
          onBookmark: () => setState(() => _isBookmarked = !_isBookmarked),
          onShare: () => _shareTestimony(testimony.title),
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsBottomSheet(
        testimonyId:  widget.testimonyId,
        comments:     _comments,
        currentUser:  ref.read(currentUserProvider)?.displayName ?? 'Vous',
        onAdd:        _addComment,
      ),
    );
  }

  void _shareTestimony(String title) {
    final link = 'testi://app/testimony/${widget.testimonyId}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(title: title, link: link),
    );
  }

  String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
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
    TestimonyCategory.guerison   => Icons.healing_rounded,
    TestimonyCategory.delivrance => Icons.lock_open_rounded,
    TestimonyCategory.conversion => Icons.rotate_right_rounded,
    TestimonyCategory.mariage    => Icons.favorite_rounded,
    TestimonyCategory.famille    => Icons.people_rounded,
    TestimonyCategory.finances   => Icons.attach_money_rounded,
    TestimonyCategory.miracles   => Icons.auto_awesome_rounded,
    TestimonyCategory.protection => Icons.shield_rounded,
    TestimonyCategory.ministere  => Icons.record_voice_over_rounded,
    TestimonyCategory.salut      => Icons.star_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _CircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      actions: [
        _CircleIconButton(
          icon: isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          onTap: onBookmark,
          color: isBookmarked ? AppColors.secondary : Colors.white,
        ),
        const SizedBox(width: 4),
        _CircleIconButton(
          icon: Icons.share_rounded,
          onTap: onShare,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Category gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.guerisonGradient,
                ),
              ),
            ),
            // Decorative pattern overlay
            Opacity(
              opacity: 0.12,
              child: CustomPaint(painter: _CrossPatternPainter()),
            ),
            // Category icon + label (dynamiques)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_categoryIcon(category), size: 64, color: Colors.white54),
                  const SizedBox(height: 8),
                  Text(
                    category.label.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            // Bottom gradient fade to background
            const Align(
              alignment: Alignment.bottomCenter,
              child: _GradientFade(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientFade extends StatelessWidget {
  const _GradientFade();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppColors.background.withValues(alpha: 0.9)],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
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
          color: Colors.black26,
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
    required this.isFollowing,
    required this.isOwnProfile,
    required this.onFollow,
  });

  final TestimonyAuthor author;
  final bool isFollowing;
  final bool isOwnProfile;
  final VoidCallback onFollow;

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundImage: author.avatarUrl != null
                ? NetworkImage(author.avatarUrl!)
                : null,
            backgroundColor: AppColors.primary.withAlpha(40),
            child: author.avatarUrl == null
                ? Text(
                    _initials(author.displayName),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Nom
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(author.displayName, style: AppTextStyles.labelMedium),
              ],
            ),
          ),
          // Follow button — masqué si c'est le propre profil de l'utilisateur
          if (!isOwnProfile)
            GestureDetector(
              onTap: onFollow,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: isFollowing ? Colors.transparent : AppColors.primary,
                  border: Border.all(
                    color: isFollowing ? AppColors.border : AppColors.primary,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFollowing ? AppLocalizations.of(context).detailFollowing : AppLocalizations.of(context).detailFollow,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color:
                        isFollowing ? AppColors.textSecondary : Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Meta Row (category chip + date)
// ============================================================================

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.category, required this.timeAgo});
  final String category;
  final String timeAgo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _CategoryChip(label: category),
          const SizedBox(width: 8),
          Text(timeAgo, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: AppColors.primary,
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Text(title, style: AppTextStyles.h2),
    );
  }
}

// ============================================================================
// Reaction Summary Row
// ============================================================================

class _ReactionSummaryRow extends StatelessWidget {
  const _ReactionSummaryRow({
    required this.likeCount,
    required this.prayCount,
    required this.commentCount,
  });

  final int likeCount;
  final int prayCount;
  final int commentCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          _ReactionCount(emoji: '❤️', count: likeCount),
          const SizedBox(width: 16),
          _ReactionCount(emoji: '🙏', count: prayCount),
          const SizedBox(width: 16),
          _ReactionCount(emoji: '💬', count: commentCount),
        ],
      ),
    );
  }
}

class _ReactionCount extends StatelessWidget {
  const _ReactionCount({required this.emoji, required this.count});

  final String emoji;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: AppTextStyles.labelSmall,
        ),
      ],
    );
  }
}

// ============================================================================
// Content Body
// ============================================================================

class _ContentBody extends StatefulWidget {
  const _ContentBody({required this.text});
  final String text;

  @override
  State<_ContentBody> createState() => _ContentBodyState();
}

class _ContentBodyState extends State<_ContentBody> {
  bool _expanded = false;
  static const _shortLength = 500;

  @override
  Widget build(BuildContext context) {
    final displayText = _expanded || widget.text.length <= _shortLength
        ? widget.text
        : '${widget.text.substring(0, _shortLength)}...';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayText, style: AppTextStyles.bodyLarge),
          if (widget.text.length > _shortLength) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? AppLocalizations.of(context).detailSeeLess : AppLocalizations.of(context).detailSeeMore,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Embedded Audio Player (inline preview, opens full player on tap)
// ============================================================================

class _AudioPlayerEmbed extends StatefulWidget {
  const _AudioPlayerEmbed({required this.testimonyId});

  final String testimonyId;

  @override
  State<_AudioPlayerEmbed> createState() => _AudioPlayerEmbedState();
}

class _AudioPlayerEmbedState extends State<_AudioPlayerEmbed> {
  bool _isPlaying = false;
  final double _progress = 0.31;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AudioPlayerScreen(testimonyId: widget.testimonyId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.guerisonGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mic_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).detailAudioLabel,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '14:23 min  ·  ${AppLocalizations.of(context).detailTapToOpen}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isPlaying = !_isPlaying),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Mini progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '4:28',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '14:23',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
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
  const _VideoPlayerEmbed({required this.testimonyId});

  final String testimonyId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoPlayerScreen(testimonyId: testimonyId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                ),
              ),
            ),
            // Play button overlay
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
            ),
            // HD badge
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
            // Duration badge
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '8:42',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Bible Verse Section
// ============================================================================

class _BibleVerseSection extends StatelessWidget {
  const _BibleVerseSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context).detailBibleTitle,
                style: AppTextStyles.h4,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '"Il guérit ceux qui ont le cœur brisé, et il panse leurs plaies."',
            style: AppTextStyles.verseQuote,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '— Psaumes 147:3',
              style: AppTextStyles.verseReference,
            ),
          ),
        ],
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
  final bool               isLoading;
  final VoidCallback       onOpenAll;
  final String             currentUser;

  @override
  Widget build(BuildContext context) {
    final preview = comments.take(2).toList();
    final count   = comments.length;

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
                  child: Text(AppLocalizations.of(context).detailSeeAll,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
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
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      AppLocalizations.of(context).detailAddComment,
                      style: const TextStyle(
                        fontFamily: 'Inter',
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
                width: 24, height: 24,
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
          ...preview.map((c) => _CommentItem(
                name:      c.authorName,
                initials:  c.initials,
                text:      c.body,
                time:      c.timeAgo,
                likeCount: c.likes,
              )),
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
                  fontFamily: 'Poppins',
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
                                ? Colors.redAccent
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text('$likeCount',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        AppLocalizations.of(context).detailReply,
                        style: const TextStyle(
                          fontFamily: 'Inter',
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
// Similar Testimonies (horizontal scroll)
// ============================================================================

class _SimilarTestimonies extends StatelessWidget {
  const _SimilarTestimonies();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(AppLocalizations.of(context).detailSimilar, style: AppTextStyles.h4),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _SimilarCard(index: index),
          ),
        ),
      ],
    );
  }
}

class _SimilarCard extends StatelessWidget {
  const _SimilarCard({required this.index});

  final int index;

  static const _titles = [
    'Guéri d\'un cancer en phase terminale',
    'Délivrance d\'une addiction de 15 ans',
    'Comment j\'ai retrouvé la foi',
    'Miracle financier inattendu',
    'Protection divine sur la route',
  ];

  static const _authors = [
    'Paul Mbeki', 'Sarah Diallo', 'John Osei', 'Grace Nwosu', 'David Kamau'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.guerisonGradient,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Center(
              child: Icon(Icons.healing_rounded,
                  color: Colors.white54, size: 32),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titles[index % _titles.length],
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    _authors[index % _authors.length],
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Builder(builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ReactionButton(
                  emoji: '❤️',
                  label: l10n.detailLike,
                  active: isLiked,
                  activeColor: AppColors.danger,
                  onTap: onLike,
                ),
                _ReactionButton(
                  emoji: '🙏',
                  label: l10n.detailPray,
                  active: isPraying,
                  activeColor: AppColors.primary,
                  onTap: onPray,
                ),
                _ReactionButton(
                  emoji: '💬',
                  label: l10n.detailComment,
                  onTap: onComment,
                ),
                _ReactionButton(
                  emoji: '🔖',
                  label: l10n.detailSave,
                  active: isBookmarked,
                  activeColor: AppColors.secondary,
                  onTap: onBookmark,
                ),
                _ReactionButton(
                  emoji: '📤',
                  label: l10n.detailShare,
                  onTap: onShare,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emoji,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor = AppColors.primary,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
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

  final String               testimonyId;
  final List<_LocalComment>  comments;
  final String               currentUser;
  final Future<void> Function(String text) onAdd;

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final _ctrl      = TextEditingController();
  final _focusNode = FocusNode();
  bool  _sending   = false;

  // Copie locale mise à jour immédiatement (optimistic UI)
  late List<_LocalComment> _local;

  // ── Likes et réponses ─────────────────────────────────────────────────────
  final Set<String> _likedIds = {};
  String? _replyingToName;   // nom de l'auteur auquel on répond

  // ── @mention ──────────────────────────────────────────────────────────────
  String?      _mentionQuery;
  List<String> _filteredUsers = const [];
  static const _mockUsers = [
    'Paul Mbeki', 'Sarah Diallo', 'John Osei', 'Grace Nwosu',
    'David Kamau', 'Marie Dupont', 'Samuel Tchibozo', 'Ruth Mensah',
    'Esther Yao', 'Elie Ndoumbe',
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
    final text   = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    if (cursor <= 0 || cursor > text.length) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final before = text.substring(0, cursor);
    final match  = RegExp(r'@(\w*)$').firstMatch(before);
    if (match != null) {
      final query    = match.group(1) ?? '';
      final filtered = _mockUsers
          .where((u) => query.isEmpty ||
              u.toLowerCase().startsWith(query.toLowerCase()))
          .take(5)
          .toList();
      setState(() { _mentionQuery = query; _filteredUsers = filtered; });
    } else {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
    }
  }

  void _insertMention(String username) {
    final handle = '@${username.replaceAll(' ', '_')}';
    final text   = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, cursor);
    final after  = text.substring(cursor);
    final newBefore = before.replaceFirstMapped(
      RegExp(r'@\w*$'), (_) => '$handle ',
    );
    _ctrl.value = TextEditingValue(
      text: newBefore + after,
      selection: TextSelection.collapsed(offset: newBefore.length),
    );
    setState(() { _mentionQuery = null; _filteredUsers = []; });
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
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: AppColors.textSecondary.withAlpha(80)),
                            const SizedBox(height: 12),
                            Text(
                              AppLocalizations.of(context).detailNoComments,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
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
                            name:      c.authorName,
                            initials:  c.initials,
                            text:      c.body,
                            time:      c.timeAgo,
                            likeCount: c.likes + (isLiked ? 1 : 0),
                            isLiked:   isLiked,
                            onLike:    () => _toggleLike(c.id),
                            onReply:   () => _startReply(c.authorName),
                          );
                        },
                      ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // ── Bandeau "En réponse à" ────────────────────────────────
              if (_replyingToName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: AppColors.primary.withAlpha(12),
                  child: Row(
                    children: [
                      const Icon(Icons.reply_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${AppLocalizations.of(context).detailReplyingTo} @${_replyingToName!.replaceAll(' ', '_')}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.textSecondary),
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
              gradient: LinearGradient(
                colors: AppColors.guerisonGradient,
              ),
            ),
            child: const Center(
              child: Text(
                'V',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFamily: 'Poppins',
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
                  fontFamily: 'Inter',
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
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
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
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
                color: Colors.white,
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
  final spans   = <InlineSpan>[];
  final pattern = RegExp(r'@\w+');
  int   last    = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: base));
    }
    spans.add(TextSpan(
      text: m.group(0),
      style: base.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
    ));
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

  final List<String>        users;
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

  final String       username;
  final VoidCallback onTap;

  String get _initials {
    final parts = username.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '@${username.replaceAll(' ', '_')}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
            Text(
              username,
              style: const TextStyle(
                fontFamily: 'Inter',
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
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            link,
            style: const TextStyle(
              fontFamily: 'Inter',
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
                        content: Text(AppLocalizations.of(context).detailLinkCopied),
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
                    SharePlus.instance.share(ShareParams(
                      text: '$title\n\n$link',
                    ));
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

  final IconData     icon;
  final String       label;
  final Color        color;
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
                fontFamily: 'Inter',
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
      ..color = Colors.white
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
