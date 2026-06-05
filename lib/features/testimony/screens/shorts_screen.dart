import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart';
import '../screens/testimony_comments_screen.dart';

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
          'Shorts',
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
    _initVideo();
  }

  Future<void> _initVideo() async {
    final path = widget.testimony.mediaPath;
    if (path == null || path.isEmpty) return;

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
    } catch (_) {
      // Video could not be loaded; placeholder gradient will be shown.
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
          label: saved ? 'Sauvegardé' : 'Sauvegarder',
          onTap: () =>
              ref.read(interactionProvider.notifier).toggleSave(testimony.id),
        ),
        const SizedBox(height: 20),

        // ── Share ───────────────────────────────────────────────────────
        _ActionButton(
          icon: Icons.share_outlined,
          color: Colors.white,
          label: 'Partager',
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
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: TestimonyCommentsScreen(testimonyId: testimony.id),
        ),
      ),
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
