import 'dart:async';
import 'dart:io' show File;

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';

// ============================================================================
// Video Player Screen — YouTube-inspired
// ============================================================================
//
// Widget tree (Portrait):
//   VideoPlayerScreen (StatefulWidget)
//   └─ Scaffold
//      ├─ body: Column
//      │  ├─ _VideoSurface          (16:9 AspectRatio, black bg)
//      │  │  └─ Stack
//      │  │     ├─ _VideoPlaceholder (gradient thumbnail)
//      │  │     └─ _VideoOverlay    (shown when _controlsVisible)
//      │  │        ├─ _TopGradientBar  (back arrow + title + fullscreen)
//      │  │        ├─ _CenterPlayPause
//      │  │        └─ _BottomControlBar (scrubber + time + HD + cc + settings)
//      │  └─ Expanded: SingleChildScrollView
//      │     └─ Column
//      │        ├─ _VideoMeta        (title + category chip)
//      │        ├─ _VideoStats       (views + date)
//      │        ├─ _VideoAuthorRow   (avatar + name + follow)
//      │        ├─ _VideoReactionBar (❤️ 🙏 💬 🔖 📤)
//      │        ├─ _VideoDescription (collapsible)
//      │        ├─ _CommentsPreview  (tap → full sheet)
//      │        └─ _RelatedVideosList
//      └─ (fullscreen: _FullscreenVideoOverlay pushed as route)
//
// Fullscreen mode:
//   _FullscreenVideoRoute (StatefulWidget)
//   └─ Scaffold (black, landscape-locked)
//      └─ Stack
//         ├─ _VideoPlaceholder
//         └─ _FullscreenOverlay  (top gradient + bottom gradient, tap to toggle)
//            ├─ _FullscreenTopBar    (back + title)
//            └─ _FullscreenBottomBar (scrubber + controls + speed + cc + rotate)
//
// Mini Video Player (PiP):
//   MiniVideoPlayer (StatefulWidget)
//   └─ Positioned (bottom-right, draggable)
//      └─ GestureDetector (drag)
//         └─ Container (160×90, black, rounded)
//            ├─ _VideoPlaceholder
//            ├─ _MiniPlayPauseOverlay
//            └─ _MiniCloseButton

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({required this.testimonyId, super.key});

  final String testimonyId;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _videoCtrl;
  ChewieController?      _chewieCtrl;
  bool _isLiked        = false;
  bool _isPraying      = false;
  bool _isBookmarked   = false;
  bool _descriptionExpanded = false;
  VideoTestimony? _testimony;

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPlayer());
  }

  Future<void> _initPlayer() async {
    final feed = ref.read(feedNotifierProvider);
    _testimony = feed.whereType<VideoTestimony>()
        .where((t) => t.id == widget.testimonyId)
        .firstOrNull;

    final source = _testimony?.mediaPath;
    if (source == null || source.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    final bool isNetwork = source.startsWith('http://') ||
                           source.startsWith('https://');
    VideoPlayerController ctrl;

    if (kIsWeb || isNetwork) {
      ctrl = VideoPlayerController.networkUrl(Uri.parse(source));
    } else {
      ctrl = VideoPlayerController.file(File(source));
    }

    await ctrl.initialize();

    final chewie = ChewieController(
      videoPlayerController: ctrl,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      aspectRatio: ctrl.value.aspectRatio,
      placeholder: const _VideoPlaceholder(),
    );

    if (mounted) {
      setState(() {
        _videoCtrl  = ctrl;
        _chewieCtrl = chewie;
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // ── Surface vidéo (16:9) ───────────────────────────────────────
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _chewieCtrl != null
                  ? Chewie(controller: _chewieCtrl!)
                  : _VideoSurface(
                      // Placeholder pendant l'initialisation
                      isPlaying: false,
                      controlsVisible: true,
                      progress: 0,
                      elapsed: '00:00',
                      total: '00:00',
                      onTap: () {},
                      onPlayPause: () {},
                      onSeek: (_) {},
                      onFullscreen: () {},
                      onBack: () => Navigator.of(context).pop(),
                    ),
            ),
            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const _VideoMeta(),
                    const _VideoStats(),
                    _VideoAuthorRow(),
                    const Divider(height: 1, color: AppColors.border),
                    _VideoReactionBar(
                      isLiked: _isLiked,
                      isPraying: _isPraying,
                      isBookmarked: _isBookmarked,
                      onLike: () => setState(() => _isLiked = !_isLiked),
                      onPray: () => setState(() => _isPraying = !_isPraying),
                      onComment: () => _showCommentsSheet(context),
                      onBookmark: () =>
                          setState(() => _isBookmarked = !_isBookmarked),
                      onShare: () {},
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _VideoDescription(
                      expanded: _descriptionExpanded,
                      onToggle: () => setState(
                          () => _descriptionExpanded = !_descriptionExpanded),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _CommentsPreview(
                      onTap: () => _showCommentsSheet(context),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    const _RelatedVideosList(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _VideoCommentsBottomSheet(testimonyId: widget.testimonyId),
    );
  }
}

// ============================================================================
// Video Surface  (16:9 + tap-to-reveal overlay)
// ============================================================================

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({
    required this.isPlaying,
    required this.controlsVisible,
    required this.progress,
    required this.elapsed,
    required this.total,
    required this.onTap,
    required this.onPlayPause,
    required this.onSeek,
    required this.onFullscreen,
    required this.onBack,
  });

  final bool isPlaying;
  final bool controlsVisible;
  final double progress;
  final String elapsed;
  final String total;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final VoidCallback onFullscreen;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _VideoPlaceholder(),
            AnimatedOpacity(
              opacity: controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: _VideoOverlay(
                isPlaying: isPlaying,
                progress: progress,
                elapsed: elapsed,
                total: total,
                onPlayPause: onPlayPause,
                onSeek: onSeek,
                onFullscreen: onFullscreen,
                onBack: onBack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Video Placeholder (gradient thumbnail)
// ============================================================================

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.videocam_rounded,
                      color: Colors.white38, size: 28),
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
// Video Overlay (controls layer)
// ============================================================================

class _VideoOverlay extends StatelessWidget {
  const _VideoOverlay({
    required this.isPlaying,
    required this.progress,
    required this.elapsed,
    required this.total,
    required this.onPlayPause,
    required this.onSeek,
    required this.onFullscreen,
    required this.onBack,
  });

  final bool isPlaying;
  final double progress;
  final String elapsed;
  final String total;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final VoidCallback onFullscreen;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Top gradient
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),
        // Bottom gradient
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),
        // Top bar: back + title + fullscreen
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
                iconSize: 22,
              ),
              const Expanded(
                child: Text(
                  'Comment Dieu a guéri ma fille',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: onFullscreen,
                icon: const Icon(Icons.fullscreen_rounded),
                color: Colors.white,
                iconSize: 24,
              ),
            ],
          ),
        ),
        // Center play/pause
        Center(
          child: GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7), width: 2),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
        // Bottom control bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _BottomControlBar(
            progress: progress,
            elapsed: elapsed,
            total: total,
            onSeek: onSeek,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Bottom Control Bar (scrubber + time + badges)
// ============================================================================

class _BottomControlBar extends StatelessWidget {
  const _BottomControlBar({
    required this.progress,
    required this.elapsed,
    required this.total,
    required this.onSeek,
  });

  final double progress;
  final String elapsed;
  final String total;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white30,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
            ),
            child: Slider(value: progress, onChanged: onSeek),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(elapsed,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontFamily: 'Inter')),
                const SizedBox(width: 4),
                Text('/ $total',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'Inter')),
                const Spacer(),
                // HD badge
                _VideoBadge(label: 'HD'),
                const SizedBox(width: 8),
                // Captions
                const Icon(Icons.closed_caption_outlined,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                // Settings
                const Icon(Icons.settings_outlined,
                    color: Colors.white70, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white54),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ============================================================================
// Video Meta (title + category)
// ============================================================================

class _VideoMeta extends StatelessWidget {
  const _VideoMeta();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comment Dieu a miraculeusement guéri ma fille d\'une maladie incurable',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 8),
          _CategoryChipSmall(label: 'Guérison'),
        ],
      ),
    );
  }
}

class _CategoryChipSmall extends StatelessWidget {
  const _CategoryChipSmall({required this.label});

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
// Video Stats (views + date)
// ============================================================================

class _VideoStats extends StatelessWidget {
  const _VideoStats();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined,
              size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text('12.4k vues', style: AppTextStyles.bodySmall),
          const SizedBox(width: 14),
          const Icon(Icons.calendar_today_outlined,
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text('il y a 3 jours', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

// ============================================================================
// Video Author Row
// ============================================================================

class _VideoAuthorRow extends StatefulWidget {
  @override
  State<_VideoAuthorRow> createState() => _VideoAuthorRowState();
}

class _VideoAuthorRowState extends State<_VideoAuthorRow> {
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: AppColors.guerisonGradient),
            ),
            child: const Center(
              child: Text('MN',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Marie Nkosi', style: AppTextStyles.labelMedium),
                Row(children: [
                  const Text('🇨🇲', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Text('Cameroun', style: AppTextStyles.bodySmall),
                ]),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _following = !_following),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: _following ? Colors.transparent : AppColors.primary,
                border: Border.all(
                    color:
                        _following ? AppColors.border : AppColors.primary),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _following ? 'Suivi' : 'Suivre',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _following ? AppColors.textSecondary : Colors.white,
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
// Video Reaction Bar
// ============================================================================

class _VideoReactionBar extends StatelessWidget {
  const _VideoReactionBar({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _VideoReactionBtn(
              emoji: '❤️',
              label: "J'aime",
              active: isLiked,
              activeColor: AppColors.danger,
              onTap: onLike),
          _VideoReactionBtn(
              emoji: '🙏',
              label: 'Je prie',
              active: isPraying,
              activeColor: AppColors.primary,
              onTap: onPray),
          _VideoReactionBtn(
              emoji: '💬', label: 'Commentaires', onTap: onComment),
          _VideoReactionBtn(
              emoji: '🔖',
              label: 'Sauvegarder',
              active: isBookmarked,
              activeColor: AppColors.secondary,
              onTap: onBookmark),
          _VideoReactionBtn(emoji: '📤', label: 'Partager', onTap: onShare),
        ],
      ),
    );
  }
}

class _VideoReactionBtn extends StatelessWidget {
  const _VideoReactionBtn({
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.w400,
                color:
                    active ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Video Description (collapsible)
// ============================================================================

class _VideoDescription extends StatelessWidget {
  const _VideoDescription(
      {required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  static const _short =
      'Témoignage de guérison miraculeuse. Ma fille a été diagnostiquée avec une '
      'leucémie de type B et guérie supernaturellement après 6 mois de lutte...';

  static const _full =
      'Témoignage de guérison miraculeuse. Ma fille a été diagnostiquée avec une '
      'leucémie lymphoblastique aiguë de type B et guérie supernaturellement '
      'après 6 mois de lutte. Nous partageons cette expérience pour fortifier '
      'la foi de chacun. Dieu est le même hier, aujourd\'hui et éternellement.\n\n'
      'Référence biblique : Psaumes 147:3\n'
      '#Guérison #Miracle #FoiEnDieu #Témoignage';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(expanded ? _full : _short,
              style: AppTextStyles.bodyMedium),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onToggle,
            child: Text(
              expanded ? 'Voir moins' : 'Voir plus',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Comments Preview
// ============================================================================

class _CommentsPreview extends StatelessWidget {
  const _CommentsPreview({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            const Text('💬',
                style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('34 commentaires',
                  style: AppTextStyles.labelMedium),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Related Videos List
// ============================================================================

class _RelatedVideosList extends StatelessWidget {
  const _RelatedVideosList();

  static const _titles = [
    'Délivrance d\'une addiction de 15 ans',
    'Conversion d\'un chef de secte',
    'Miracle financier au dernier moment',
    'Protection divine dans un accident',
    'Guérison d\'une paralysie totale',
  ];

  static const _authors = [
    'Samuel Obi', 'Grace Nwosu', 'David Kamau', 'Esther Mensah', 'Paul Mbeki'
  ];

  static const _durations = ['12:34', '7:21', '9:48', '5:16', '15:02'];

  static const _views = ['8.2k', '5.7k', '11.3k', '3.9k', '18.6k'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('Vidéos similaires', style: AppTextStyles.h4),
        ),
        ...List.generate(
          _titles.length,
          (i) => _RelatedVideoCard(
            title: _titles[i],
            author: _authors[i],
            duration: _durations[i],
            views: _views[i],
            index: i,
          ),
        ),
      ],
    );
  }
}

class _RelatedVideoCard extends StatelessWidget {
  const _RelatedVideoCard({
    required this.title,
    required this.author,
    required this.duration,
    required this.views,
    required this.index,
  });

  final String title;
  final String author;
  final String duration;
  final String views;
  final int index;

  static const _gradients = [
    AppColors.delivranceGradient,
    AppColors.conversionGradient,
    AppColors.financesGradient,
    AppColors.protectionGradient,
    AppColors.guerisonGradient,
  ];

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[index % _gradients.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Stack(
            children: [
              Container(
                width: 128,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(colors: gradient),
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white54, size: 30),
                ),
              ),
              Positioned(
                bottom: 5,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  author,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text('$views vues',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.more_vert_rounded,
              color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }
}

// ============================================================================
// Comments Bottom Sheet (video variant)
// ============================================================================

class _VideoCommentsBottomSheet extends StatefulWidget {
  const _VideoCommentsBottomSheet({required this.testimonyId});

  final String testimonyId;

  @override
  State<_VideoCommentsBottomSheet> createState() =>
      _VideoCommentsBottomSheetState();
}

class _VideoCommentsBottomSheetState
    extends State<_VideoCommentsBottomSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const _DragHandle(),
              _SheetHeader(
                title: 'Commentaires (34)',
                onClose: () => Navigator.of(context).pop(),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  children: const [
                    _VideoCommentItem(
                      name: 'Jean Dupont',
                      initials: 'JD',
                      text:
                          'Gloire à Dieu ! Ce témoignage m\'a touché au plus profond.',
                      time: 'il y a 2h',
                      likeCount: 12,
                    ),
                    _VideoCommentItem(
                      name: 'Amina Kone',
                      initials: 'AK',
                      text: 'Merci de partager. Dieu est bon tout le temps !',
                      time: 'il y a 5h',
                      likeCount: 8,
                    ),
                    _VideoCommentItem(
                      name: 'Samuel Obi',
                      initials: 'SO',
                      text:
                          'Mon épouse a vécu quelque chose de similaire. Dieu guérit encore aujourd\'hui.',
                      time: 'il y a 1j',
                      likeCount: 21,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              _VideoCommentInputBar(
                controller: _controller,
                focusNode: _focusNode,
                onSend: () {
                  if (_controller.text.trim().isNotEmpty) _controller.clear();
                },
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

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

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

class _VideoCommentItem extends StatelessWidget {
  const _VideoCommentItem({
    required this.name,
    required this.initials,
    required this.text,
    required this.time,
    required this.likeCount,
  });

  final String name;
  final String initials;
  final String text;
  final String time;
  final int likeCount;

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
                      Text(text, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(time, style: AppTextStyles.bodySmall),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Icon(Icons.favorite_border_rounded,
                            size: 13,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text('$likeCount',
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Répondre',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
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

class _VideoCommentInputBar extends StatelessWidget {
  const _VideoCommentInputBar({
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
              gradient:
                  LinearGradient(colors: AppColors.guerisonGradient),
            ),
            child: const Center(
              child: Text('V',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Ajouter un commentaire...',
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
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
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
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Fullscreen Video Route
// ============================================================================
//
// Widget tree:
//   _FullscreenVideoRoute (StatefulWidget)
//   └─ Scaffold (black bg)
//      └─ Stack (full viewport)
//         ├─ _VideoPlaceholder (fill)
//         └─ AnimatedOpacity(_FullscreenOverlay)
//            ├─ _FullscreenTopGradient + Row(back + title)
//            └─ _FullscreenBottomGradient
//               ├─ Slider (scrubber)
//               ├─ Row: time · rewind · play/pause · forward · captions · speed · lock
//               └─ _SpeedRow (compact inline)

class _FullscreenVideoRoute extends StatefulWidget {
  const _FullscreenVideoRoute({
    required this.testimonyId,
    required this.initialProgress,
    required this.isPlaying,
  });

  final String testimonyId;
  final double initialProgress;
  final bool isPlaying;

  @override
  State<_FullscreenVideoRoute> createState() =>
      _FullscreenVideoRouteState();
}

class _FullscreenVideoRouteState extends State<_FullscreenVideoRoute> {
  late bool _isPlaying;
  late double _progress;
  bool _overlayVisible = true;
  bool _rotateLocked = false;
  Timer? _hideTimer;

  static const _totalSeconds = 522;

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.isPlaying;
    _progress = widget.initialProgress;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _overlayVisible = false);
      }
    });
  }

  void _toggleOverlay() {
    setState(() => _overlayVisible = !_overlayVisible);
    if (_overlayVisible && _isPlaying) _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _fmt((_totalSeconds * _progress).round());
    final total = _fmt(_totalSeconds);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleOverlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _VideoPlaceholder(),
            AnimatedOpacity(
              opacity: _overlayVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: _FullscreenOverlay(
                isPlaying: _isPlaying,
                progress: _progress,
                elapsed: elapsed,
                total: total,
                rotateLocked: _rotateLocked,
                onBack: () => Navigator.of(context).pop(),
                onPlayPause: () {
                  setState(() => _isPlaying = !_isPlaying);
                  if (_isPlaying) _startHideTimer();
                },
                onSeek: (v) => setState(() => _progress = v),
                onRewind: () => setState(() =>
                    _progress = (_progress - 15 / _totalSeconds)
                        .clamp(0.0, 1.0)),
                onForward: () => setState(() =>
                    _progress = (_progress + 15 / _totalSeconds)
                        .clamp(0.0, 1.0)),
                onLockRotate: () =>
                    setState(() => _rotateLocked = !_rotateLocked),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenOverlay extends StatelessWidget {
  const _FullscreenOverlay({
    required this.isPlaying,
    required this.progress,
    required this.elapsed,
    required this.total,
    required this.rotateLocked,
    required this.onBack,
    required this.onPlayPause,
    required this.onSeek,
    required this.onRewind,
    required this.onForward,
    required this.onLockRotate,
  });

  final bool isPlaying;
  final double progress;
  final String elapsed;
  final String total;
  final bool rotateLocked;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final VoidCallback onRewind;
  final VoidCallback onForward;
  final VoidCallback onLockRotate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Top gradient bar
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 72,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                ),
                const Expanded(
                  child: Text(
                    'Comment Dieu a guéri ma fille',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
        // Center play/pause
        Center(
          child: GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7), width: 2),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        // Bottom gradient bar
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scrubber
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(value: progress, onChanged: onSeek),
                ),
                // Controls row
                Row(
                  children: [
                    Text(elapsed,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Inter')),
                    Text(' / $total',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontFamily: 'Inter')),
                    const Spacer(),
                    // Rewind
                    IconButton(
                      onPressed: onRewind,
                      icon: const Icon(Icons.replay_10_rounded),
                      color: Colors.white,
                      iconSize: 26,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                    ),
                    // Play/Pause
                    IconButton(
                      onPressed: onPlayPause,
                      icon: Icon(isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                      color: Colors.white,
                      iconSize: 32,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 40, minHeight: 40),
                    ),
                    // Forward
                    IconButton(
                      onPressed: onForward,
                      icon: const Icon(Icons.forward_10_rounded),
                      color: Colors.white,
                      iconSize: 26,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                    ),
                    const Spacer(),
                    // Captions
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.closed_caption_outlined),
                      color: Colors.white70,
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                    ),
                    // Speed label
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '1x',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Rotate lock
                    IconButton(
                      onPressed: onLockRotate,
                      icon: Icon(rotateLocked
                          ? Icons.screen_lock_rotation_rounded
                          : Icons.screen_rotation_rounded),
                      color:
                          rotateLocked ? AppColors.secondary : Colors.white70,
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Mini Video Player (PiP — picture-in-picture)
// ============================================================================
//
// Widget tree:
//   MiniVideoPlayer (StatefulWidget)
//   └─ Positioned (bottom-right, draggable via GestureDetector)
//      └─ GestureDetector (onPanUpdate → reposition, onTap → open full)
//         └─ Container (160×90, black, rounded-8, shadow)
//            └─ Stack
//               ├─ ClipRRect > _VideoPlaceholder
//               ├─ Center > _MiniPlayPause (semi-transparent overlay)
//               └─ Positioned(top-right) > _MiniCloseBtn

class MiniVideoPlayer extends StatefulWidget {
  const MiniVideoPlayer({
    required this.testimonyId,
    required this.onClose,
    super.key,
  });

  final String testimonyId;
  final VoidCallback onClose;

  @override
  State<MiniVideoPlayer> createState() => _MiniVideoPlayerState();
}

class _MiniVideoPlayerState extends State<MiniVideoPlayer> {
  bool _isPlaying = false;
  Offset _position = const Offset(16, 16); // offset from bottom-right

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      right: _position.dx,
      bottom: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position.dx - details.delta.dx).clamp(8.0, size.width - 168),
              (_position.dy - details.delta.dy).clamp(8.0, size.height - 98),
            );
          });
        },
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                VideoPlayerScreen(testimonyId: widget.testimonyId),
          ),
        ),
        child: Container(
          width: 160,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const _VideoPlaceholder(),
              ),
              // Play/pause overlay
              Center(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _isPlaying = !_isPlaying),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
