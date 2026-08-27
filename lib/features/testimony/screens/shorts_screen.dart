import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;
import 'package:video_player/video_player.dart';

import '../../../core/local_db/daos/comment_dao.dart';
import '../../../core/local_db/database_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../l10n/app_localizations.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart';

// ============================================================================
// ShortsScreen
// ============================================================================

class ShortsScreen extends ConsumerStatefulWidget {
  const ShortsScreen({
    required this.testimonies,
    this.startIndex = 0,
    super.key,
  });

  final List<VideoTestimony> testimonies;
  final int startIndex;

  @override
  ConsumerState<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends ConsumerState<ShortsScreen> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.startIndex;
    _pageController = PageController(initialPage: widget.startIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocalizations.of(context).navShorts,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: widget.testimonies.isEmpty
          ? const Center(
              child: Text(
                'Aucune vidéo disponible',
                style: TextStyle(color: Colors.white),
              ),
            )
          : PageView.builder(
              scrollDirection: Axis.vertical,
              controller: _pageController,
              // BouncingScrollPhysics → rebond aux extrémités
              // PageScrollPhysics (parent) → snap page par page
              physics: const BouncingScrollPhysics(
                parent: PageScrollPhysics(),
              ),
              // Pré-construit la page adjacente → vidéo prête avant le swipe
              allowImplicitScrolling: true,
              itemCount: widget.testimonies.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final testimony = widget.testimonies[index];
                final isActive = index == _currentPage;
                return _ShortPage(
                  key: ValueKey(testimony.id),
                  testimony: testimony,
                  isActive: isActive,
                );
              },
            ),
    );
  }
}

// ============================================================================
// _ShortPage — one video page
// ============================================================================

class _ShortPage extends StatefulWidget {
  const _ShortPage({
    required this.testimony,
    required this.isActive,
    super.key,
  });

  final VideoTestimony testimony;
  final bool isActive;

  @override
  State<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends State<_ShortPage> {
  VideoPlayerController? _videoController;
  bool _controllerReady = false;
  bool _showPlayIcon = false;
  Timer? _playIconTimer;

  // Tracks whether we showed the play icon overlay recently.
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Décaler l'init après le premier frame pour ne pas bloquer l'animation de swipe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initVideo();
    });
  }

  Future<void> _initVideo() async {
    final path = widget.testimony.mediaPath;
    debugPrint('⚡ _initVideo id=${widget.testimony.id} path=$path');
    if (path == null || path.isEmpty) {
      debugPrint('⚡ _initVideo: path null/empty → placeholder');
      return;
    }

    VideoPlayerController controller;

    if (kIsWeb) {
      controller = VideoPlayerController.networkUrl(Uri.parse(path));
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      controller = VideoPlayerController.networkUrl(Uri.parse(path));
    } else {
      controller = VideoPlayerController.file(File(path));
    }

    _videoController = controller;

    try {
      await controller.initialize();
      controller.setLooping(true);
      if (mounted) {
        setState(() => _controllerReady = true);
        _isPlaying = widget.isActive;
        if (widget.isActive) {
          controller.play();
        }
      }
    } catch (e) {
      debugPrint('⚡ _initVideo FAIL path=$path error=$e');
      if (mounted) setState(() => _controllerReady = false);
    }
  }

  @override
  void didUpdateWidget(covariant _ShortPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _videoController?.play();
        setState(() => _isPlaying = true);
      } else {
        _videoController?.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  void dispose() {
    _playIconTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _videoController;
    if (controller == null || !_controllerReady) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _isPlaying = false;
      } else {
        controller.play();
        _isPlaying = true;
      }
      _showPlayIcon = true;
    });

    _playIconTimer?.cancel();
    _playIconTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showPlayIcon = false);
    });
  }

  // ── Category gradient helper ──────────────────────────────────────────────

  List<Color> _categoryGradient(TestimonyCategory category) {
    return switch (category) {
      TestimonyCategory.guerison    => AppColors.guerisonGradient,
      TestimonyCategory.delivrance  => AppColors.delivranceGradient,
      TestimonyCategory.conversion  => AppColors.conversionGradient,
      TestimonyCategory.mariage     => AppColors.mariageGradient,
      TestimonyCategory.famille     => AppColors.familleGradient,
      TestimonyCategory.finances    => AppColors.financesGradient,
      TestimonyCategory.miracles    => AppColors.miraclesGradient,
      TestimonyCategory.protection  => AppColors.protectionGradient,
      TestimonyCategory.ministere   => AppColors.ministereGradient,
      TestimonyCategory.salut       => AppColors.salutGradient,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Video or placeholder ─────────────────────────────────────
          if (_controllerReady && _videoController != null)
            _VideoFill(controller: _videoController!)
          else
            _PlaceholderGradient(
              colors: _categoryGradient(widget.testimony.category),
              label: widget.testimony.category.label,
            ),

          // ── 2. Dark gradient overlays ───────────────────────────────────
          // Top overlay (for AppBar legibility)
          Positioned(
            top: 0, left: 0, right: 0,
            height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xAA000000), Colors.transparent],
                ),
              ),
            ),
          ),
          // Bottom overlay (for info + actions)
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 200,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xDD000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── 3. Bottom-left info ─────────────────────────────────────────
          Positioned(
            left: 16,
            right: 72, // leave room for the action column
            bottom: 24,
            child: _ShortInfo(testimony: widget.testimony),
          ),

          // ── 4. Bottom-right actions ─────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 24,
            child: _ShortActions(testimony: widget.testimony),
          ),

          // ── 5. Centre play/pause flash ──────────────────────────────────
          if (_showPlayIcon)
            Center(
              child: AnimatedOpacity(
                opacity: _showPlayIcon ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(140),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Video fill widget ─────────────────────────────────────────────────────────

class _VideoFill extends StatelessWidget {
  const _VideoFill({required this.controller});
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}

// ── Placeholder gradient shown when no video is available ─────────────────────

class _PlaceholderGradient extends StatelessWidget {
  const _PlaceholderGradient({
    required this.colors,
    required this.label,
  });

  final List<Color> colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              color: Colors.white54,
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// _ShortInfo — bottom-left overlay
// ============================================================================

class _ShortInfo extends StatelessWidget {
  const _ShortInfo({required this.testimony});
  final VideoTestimony testimony;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(testimony.author.displayName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Author row
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              backgroundImage: testimony.author.avatarUrl != null
                  ? NetworkImage(testimony.author.avatarUrl!)
                  : null,
              child: testimony.author.avatarUrl == null
                  ? Text(
                      initials,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                testimony.author.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          testimony.title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),

        // Category chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(51),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(77)),
          ),
          child: Text(
            testimony.category.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  static String _initials(String displayName) {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ============================================================================
// _ShortActions — bottom-right vertical action column
// ============================================================================

class _ShortActions extends ConsumerWidget {
  const _ShortActions({required this.testimony});
  final VideoTestimony testimony;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked  = ref.watch(likedIdsProvider).contains(testimony.id);
    final prayed = ref.watch(prayedIdsProvider).contains(testimony.id);
    final saved  = ref.watch(savedIdsProvider).contains(testimony.id);

    final effectiveLikes   = testimony.stats.likes   + (liked  ? 1 : 0);
    final effectivePrayers = testimony.stats.prayers + (prayed ? 1 : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Heart / Like ────────────────────────────────────────────────
        _ActionButton(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? Colors.redAccent : Colors.white,
          label: _formatCount(effectiveLikes),
          onTap: () =>
              ref.read(interactionProvider.notifier).toggleLike(testimony.id),
        ),
        const SizedBox(height: 20),

        // ── Praying hands ───────────────────────────────────────────────
        _EmojiActionButton(
          emoji: '🙏',
          label: _formatCount(effectivePrayers),
          onTap: () =>
              ref.read(interactionProvider.notifier).togglePray(testimony.id),
        ),
        const SizedBox(height: 20),

        // ── Comments ────────────────────────────────────────────────────
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          color: Colors.white,
          label: _formatCount(testimony.stats.comments),
          onTap: () => _openComments(context),
        ),
        const SizedBox(height: 20),

        // ── Bookmark / Save ─────────────────────────────────────────────
        _ActionButton(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          color: saved ? AppColors.secondary : Colors.white,
          label: saved ? 'Sauvegardé' : AppLocalizations.of(context).detailSave,
          onTap: () =>
              ref.read(interactionProvider.notifier).toggleSave(testimony.id),
        ),
        const SizedBox(height: 20),

        // ── Share ───────────────────────────────────────────────────────
        _ActionButton(
          icon: Icons.share_outlined,
          color: Colors.white,
          label: AppLocalizations.of(context).detailShare,
          onTap: () => SharePlus.instance.share(
            ShareParams(
              text: '${testimony.title}\n\nPartagé depuis l\'application Témoignages ✝️',
            ),
          ),
        ),
      ],
    );
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _ShortsCommentsSheet(testimonyId: testimony.id),
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

// ── Reusable action button (icon) ─────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable action button (emoji text) ──────────────────────────────────────

class _EmojiActionButton extends StatelessWidget {
  const _EmojiActionButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shorts comments bottom sheet ─────────────────────────────────────────────
//
// Fully self-contained: handles keyboard insets so the input field stays
// visible above the keyboard at all times.

class _ShortsCommentsSheet extends ConsumerStatefulWidget {
  const _ShortsCommentsSheet({required this.testimonyId});
  final String testimonyId;

  @override
  ConsumerState<_ShortsCommentsSheet> createState() =>
      _ShortsCommentsSheetState();
}

class _ShortsCommentsSheetState
    extends ConsumerState<_ShortsCommentsSheet> {
  final _ctrl      = TextEditingController();
  final _focus     = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _sending    = false;

  final List<_ShortsComment> _comments = [];

  @override
  void initState() {
    super.initState();
    // Auto-open keyboard immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    final user = ref.read(currentUserProvider);

    // Persist to SQLite
    try {
      final dao = CommentDao(DatabaseService());
      await dao.insert({
        'id': 'sc_${DateTime.now().millisecondsSinceEpoch}',
        'testimony_id': widget.testimonyId,
        'user_id': user?.id ?? 'anon',
        'author_name': user?.displayName ?? 'Moi',
        'body': text,
        'created_at': DateTime.now().toIso8601String(),
        'like_count': 0,
        'user_liked': 0,
      });
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _comments.add(_ShortsComment(
        author: user?.displayName ?? 'Moi',
        text: text,
        createdAt: DateTime.now(),
      ));
      _sending = false;
    });
    _ctrl.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom = keyboard height; animates with keyboard
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      // Sheet height: 70% of screen + keyboard height so it rises with keyboard
      height: MediaQuery.of(context).size.height * 0.75 + keyboardHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).detailComments,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Comments list
          Expanded(
            child: _comments.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context).detailFirstComment,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) =>
                        _CommentTile(comment: _comments[i]),
                  ),
          ),

          // Input bar — sits directly above keyboard via padding
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              // Push above keyboard; the Container itself is sized to include
              // keyboard space, so we just need safe area bottom when no keyboard
              bottom: keyboardHeight > 0 ? 8 : 8,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    maxLines: 3,
                    minLines: 1,
                    style: AppTextStyles.bodyMedium,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).detailAddComment,
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _sending
                          ? AppColors.primary.withAlpha(120)
                          : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Bottom padding when no keyboard (safe area)
          if (keyboardHeight == 0)
            SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final _ShortsComment comment;

  @override
  Widget build(BuildContext context) {
    final initials = comment.author.isNotEmpty
        ? comment.author[0].toUpperCase()
        : '?';
    final diff = DateTime.now().difference(comment.createdAt);
    final timeAgo = diff.inMinutes < 1
        ? 'à l\'instant'
        : diff.inMinutes < 60
            ? 'il y a ${diff.inMinutes}min'
            : 'il y a ${diff.inHours}h';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF9333EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.author,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(timeAgo,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  style:
                      AppTextStyles.bodyMedium.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortsComment {
  const _ShortsComment({
    required this.author,
    required this.text,
    required this.createdAt,
  });
  final String author;
  final String text;
  final DateTime createdAt;
}
