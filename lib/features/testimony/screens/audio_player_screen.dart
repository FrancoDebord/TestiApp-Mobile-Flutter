import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../services/audio_player_service.dart';

// ============================================================================
// Audio Player Screen — Spotify-inspired full-screen audio player
// ============================================================================
//
// Widget tree:
//   AudioPlayerScreen (StatefulWidget)
//   └─ Scaffold (black-to-background gradient bg)
//      ├─ body: SafeArea
//      │  └─ Column
//      │     ├─ _AudioAppBar          (back + title + more options)
//      │     ├─ Expanded
//      │     │  └─ SingleChildScrollView
//      │     │     └─ Column
//      │     │        ├─ _CoverArt             (280×280 rounded square)
//      │     │        ├─ _TrackInfo            (title + author + flag + date)
//      │     │        ├─ _CategoryChip
//      │     │        ├─ _ProgressSection      (slider + times)
//      │     │        ├─ _PlayerControls       (rewind15 + play/pause + fwd15)
//      │     │        ├─ _SpeedSelector        (0.75x…2x)
//      │     │        ├─ _CastRow              (airplay/bluetooth icon)
//      │     │        └─ _TranscriptToggle     (expandable text)
//      │     └─ _AudioReactionBar     (❤️ 🙏 💬 🔖 📤)
//
// Mini Audio Player (persistent, sits above nav bar):
//   MiniAudioPlayer (StatefulWidget)
//   └─ Material > InkWell
//      └─ Container (56 px height)
//         ├─ _MiniCover     (40×40 thumbnail)
//         ├─ Expanded: Column (title + author)
//         ├─ _MiniPlayPause
//         └─ _MiniClose

class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({required this.testimonyId, super.key});

  final String testimonyId;

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  double _speed = 1.0;
  bool _transcriptOpen = false;
  bool _isLiked = false;
  bool _isPraying = false;
  bool _isBookmarked = false;

  AudioTestimony? _testimony;

  static const _speedOptions = [0.75, 1.0, 1.25, 1.5, 2.0];

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndPlay());
  }

  Future<void> _loadAndPlay() async {
    final feed = ref.read(feedNotifierProvider);
    _testimony = feed.whereType<AudioTestimony>()
        .where((t) => t.id == widget.testimonyId)
        .firstOrNull;

    final source = _testimony?.mediaPath;
    if (source != null && source.isNotEmpty) {
      await ref.read(audioPlayerProvider.notifier).play(source);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ref.read(audioPlayerProvider.notifier).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player    = ref.watch(audioPlayerProvider);
    final isPlaying = player.isPlaying;
    final progress  = player.progress;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2D0B4E), Color(0xFF0D0D1A)],
              stops: [0.0, 0.55],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _AudioAppBar(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        const _CoverArt(),
                        const SizedBox(height: 28),
                        _TrackInfo(testimony: _testimony),
                        const SizedBox(height: 12),
                        _CategoryChipLight(
                            label: _testimony?.category.label ?? ''),
                        const SizedBox(height: 28),

                        // ── Slider de progression réel ────────────────────
                        _ProgressSection(
                          progress: progress,
                          elapsed: _fmtDuration(player.position),
                          total:   _fmtDuration(player.duration),
                          onChanged: (v) => ref
                              .read(audioPlayerProvider.notifier)
                              .seekToFraction(v),
                        ),
                        const SizedBox(height: 24),

                        // ── Contrôles réels ───────────────────────────────
                        _PlayerControls(
                          isPlaying: isPlaying,
                          onPlayPause: () => isPlaying
                              ? ref.read(audioPlayerProvider.notifier).pause()
                              : ref.read(audioPlayerProvider.notifier).resume(),
                          onRewind: () => ref
                              .read(audioPlayerProvider.notifier)
                              .skipBackward(),
                          onForward: () => ref
                              .read(audioPlayerProvider.notifier)
                              .skipForward(),
                        ),
                        const SizedBox(height: 28),

                        // ── Vitesse réelle ────────────────────────────────
                        _SpeedSelector(
                          current: _speed,
                          options: _speedOptions,
                          onSelect: (s) {
                            setState(() => _speed = s);
                            ref.read(audioPlayerProvider.notifier).setSpeed(s);
                          },
                        ),
                        const SizedBox(height: 20),
                        const _CastRow(),
                        const SizedBox(height: 20),
                        _TranscriptToggle(
                          open: _transcriptOpen,
                          transcript: _testimony?.transcriptPreview,
                          onToggle: () => setState(
                              () => _transcriptOpen = !_transcriptOpen),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _AudioReactionBar(
                  isLiked:      _isLiked,
                  isPraying:    _isPraying,
                  isBookmarked: _isBookmarked,
                  onLike:     () => setState(() => _isLiked      = !_isLiked),
                  onPray:     () => setState(() => _isPraying    = !_isPraying),
                  onComment:  () {},
                  onBookmark: () => setState(
                      () => _isBookmarked = !_isBookmarked),
                  onShare:    () {},
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
// App Bar
// ============================================================================

class _AudioAppBar extends StatelessWidget {
  const _AudioAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: Colors.white,
            iconSize: 28,
          ),
          const Expanded(
            child: Text(
              'Témoignage Audio',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
            color: Colors.white,
            iconSize: 24,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Cover Art (280×280)
// ============================================================================

class _CoverArt extends StatelessWidget {
  const _CoverArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.guerisonGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Decorative cross pattern
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(painter: _CrossPatternPainter()),
            ),
          ),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.healing_rounded, color: Colors.white60, size: 72),
                SizedBox(height: 12),
                Text(
                  'GUÉRISON',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          // Mic badge (bottom right)
          Positioned(
            bottom: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_rounded, color: Colors.white70, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'AUDIO',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
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
// Track Info
// ============================================================================

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({this.testimony});
  final AudioTestimony? testimony;

  @override
  Widget build(BuildContext context) {
    final title  = testimony?.title  ?? 'Chargement…';
    final author = testimony?.author.displayName ?? '';
    final dur    = testimony?.formattedDuration ?? '';

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
            height: 1.35,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          author,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            color: Colors.white60,
          ),
        ),
        if (dur.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            dur,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// Category Chip (light-on-dark variant)
// ============================================================================

class _CategoryChipLight extends StatelessWidget {
  const _CategoryChipLight({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }
}

// ============================================================================
// Progress Section
// ============================================================================

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.progress,
    required this.elapsed,
    required this.total,
    required this.onChanged,
  });

  final double progress;
  final String elapsed;
  final String total;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: progress,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                elapsed,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                total,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Player Controls
// ============================================================================

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onRewind,
    required this.onForward,
  });

  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onRewind;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rewind 15s
        _SkipButton(
          onTap: onRewind,
          icon: Icons.replay_10_rounded,
          label: '15s',
        ),
        const SizedBox(width: 32),
        // Play / Pause (large)
        GestureDetector(
          onTap: onPlayPause,
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppColors.primary,
              size: 42,
            ),
          ),
        ),
        const SizedBox(width: 32),
        // Forward 15s
        _SkipButton(
          onTap: onForward,
          icon: Icons.forward_10_rounded,
          label: '15s',
          isForward: true,
        ),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.onTap,
    required this.icon,
    required this.label,
    this.isForward = false,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final bool isForward;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Speed Selector
// ============================================================================

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({
    required this.current,
    required this.options,
    required this.onSelect,
  });

  final double current;
  final List<double> options;
  final ValueChanged<double> onSelect;

  String _label(double v) {
    if (v == v.truncateToDouble()) {
      return '${v.toInt()}x';
    }
    return '${v}x';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((speed) {
          final selected = speed == current;
          return GestureDetector(
            onTap: () => onSelect(speed),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                _label(speed),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppColors.primary : Colors.white54,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// Cast Row
// ============================================================================

class _CastRow extends StatelessWidget {
  const _CastRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.airplay_rounded),
          color: Colors.white54,
          iconSize: 22,
          tooltip: 'AirPlay',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.bluetooth_audio_rounded),
          color: Colors.white54,
          iconSize: 22,
          tooltip: 'Bluetooth',
        ),
      ],
    );
  }
}

// ============================================================================
// Transcript Toggle
// ============================================================================

class _TranscriptToggle extends StatelessWidget {
  const _TranscriptToggle({
    required this.open,
    required this.onToggle,
    this.transcript,
  });

  final bool open;
  final VoidCallback onToggle;
  final String? transcript;

  static const _transcript =
      'Tout a commencé en novembre 2022, quand ma fille Esther, âgée de 7 ans, '
      'a commencé à souffrir de douleurs intenses aux membres. Les médecins ont '
      'posé un diagnostic alarmant : une leucémie lymphoblastique aiguë de type B.\n\n'
      'Nous avons entamé un traitement de chimiothérapie lourd. Pendant six mois, '
      'nous avons vu notre petite fille perdre ses cheveux, son appétit, sa joie...';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.subtitles_outlined,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Transcription',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState:
              open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              transcript ?? _transcript,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Colors.white70,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Audio Reaction Bar (dark variant)
// ============================================================================

class _AudioReactionBar extends StatelessWidget {
  const _AudioReactionBar({
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
        color: Colors.white.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DarkReactionButton(
                emoji: '❤️',
                active: isLiked,
                onTap: onLike,
              ),
              _DarkReactionButton(
                emoji: '🙏',
                active: isPraying,
                onTap: onPray,
              ),
              _DarkReactionButton(
                emoji: '💬',
                onTap: onComment,
              ),
              _DarkReactionButton(
                emoji: '🔖',
                active: isBookmarked,
                onTap: onBookmark,
              ),
              _DarkReactionButton(
                emoji: '📤',
                onTap: onShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkReactionButton extends StatelessWidget {
  const _DarkReactionButton({
    required this.emoji,
    required this.onTap,
    this.active = false,
  });

  final String emoji;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: 24,
            color: active ? null : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Mini Audio Player — persistent strip above nav bar
// ============================================================================
//
// Widget tree:
//   MiniAudioPlayer
//   └─ Material
//      ├─ InkWell (opens full AudioPlayerScreen on tap)
//      └─ Container (56 px, white surface, shadow top)
//         └─ Row
//            ├─ _MiniCover   (40×40 gradient square)
//            ├─ Expanded
//            │  └─ Column
//            │     ├─ Text (title, truncated, 13px SemiBold)
//            │     └─ Text (author, 11px secondary)
//            ├─ _MiniPlayPauseBtn
//            └─ _MiniCloseBtn

class MiniAudioPlayer extends StatefulWidget {
  const MiniAudioPlayer({
    required this.testimonyId,
    required this.onClose,
    super.key,
  });

  final String testimonyId;
  final VoidCallback onClose;

  @override
  State<MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

class _MiniAudioPlayerState extends State<MiniAudioPlayer> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                AudioPlayerScreen(testimonyId: widget.testimonyId),
          ),
        ),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: AppColors.guerisonGradient,
                  ),
                ),
                child: const Icon(Icons.healing_rounded,
                    color: Colors.white54, size: 20),
              ),
              const SizedBox(width: 10),
              // Title + author
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comment Dieu a guéri ma fille...',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Marie Nkosi',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Play/pause
              GestureDetector(
                onTap: () => setState(() => _isPlaying = !_isPlaying),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
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
              const SizedBox(width: 8),
              // Close
              GestureDetector(
                onTap: widget.onClose,
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
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
// Shared cross pattern painter
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
        canvas.drawLine(Offset(x - crossSize, y), Offset(x + crossSize, y), paint);
        canvas.drawLine(Offset(x, y - crossSize), Offset(x, y + crossSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
