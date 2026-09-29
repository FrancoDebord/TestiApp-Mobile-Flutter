import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/media/playback_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../services/api_service.dart' show apiServiceProvider;
import '../../../services/audio_player_service.dart';
import '../../../shared/widgets/quality_picker_sheet.dart';
import 'video_player_screen.dart' show singleQualityReason;

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
//      │     │        ├─ _PlayerControls       (préc. · -15s · play/pause · +15s · suiv.)
//      │     │        ├─ _SecondaryControls    (répétition · lecture auto · qualité · vitesse)
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
  const AudioPlayerScreen({required this.testimonyId, this.mediaPath, super.key});

  final String  testimonyId;
  final String? mediaPath;

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  bool _transcriptOpen = false;
  bool _isLiked = false;
  bool _isPraying = false;
  bool _isBookmarked = false;

  /// Témoignage demandé (affiché tant que le lecteur n'a pas démarré).
  AudioTestimony? _testimony;

  /// Notifier mémorisé pour pouvoir arrêter la lecture dans dispose().
  late final AudioPlayerNotifier _audio;

  static const _speedOptions = [0.75, 1.0, 1.25, 1.5, 2.0];

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioPlayerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndPlay());
  }

  static bool _hasMedia(AudioTestimony t) =>
      (t.mediaPath?.isNotEmpty ?? false) || t.renditions.isNotEmpty;

  /// Construit la file de lecture : les témoignages audio du fil (dans
  /// l'ordre affiché), en démarrant sur le témoignage demandé. Si celui-ci
  /// n'est pas dans le fil, on le charge depuis l'API et on le lit seul.
  Future<void> _loadAndPlay() async {
    // Déjà en cours de lecture : on ne relance pas.
    if (ref.read(audioPlayerProvider).currentTestimony?.id ==
        widget.testimonyId) {
      return;
    }

    // Fil filtré (ce que l'utilisateur voit), sinon fil complet.
    for (final feed in [
      ref.read(feedProvider),
      ref.read(feedNotifierProvider),
    ]) {
      final audios =
          feed.whereType<AudioTestimony>().where(_hasMedia).toList();
      final idx = audios.indexWhere((t) => t.id == widget.testimonyId);
      if (idx >= 0) {
        if (mounted) setState(() => _testimony = audios[idx]);
        await _audio.setTestimonyQueue(audios, startIndex: idx);
        return;
      }
    }

    await _fetchFromApi();
  }

  Future<void> _fetchFromApi() async {
    try {
      final api  = ref.read(apiServiceProvider);
      final resp = await api.get<Map<String, dynamic>>(
        AppConstants.testimonyById(widget.testimonyId),
      );
      final t = testimonyFromApiJson(resp.data);
      if (t is AudioTestimony && mounted) {
        setState(() => _testimony = t);
        if (_hasMedia(t)) {
          await _audio.setTestimonyQueue([t]);
          return;
        }
      }
    } catch (_) {
      // Repli ci-dessous.
    }
    // Dernier recours : lecture directe du fichier transmis.
    final src = widget.mediaPath;
    if (src != null && src.isNotEmpty && mounted) {
      await _audio.play(_absUrl(src));
    }
    if (mounted) setState(() {});
  }

  static String _absUrl(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) return src;
    final root = AppConstants.baseUrl.replaceAll(RegExp(r'/api/v\d+$'), '');
    return src.startsWith('/') ? '$root$src' : '$root/$src';
  }

  @override
  void dispose() {
    _audio.stop();
    super.dispose();
  }

  // ── Qualité ────────────────────────────────────────────────────────────────

  Future<void> _openQualitySheet(AudioPlayerState player) async {
    final t = player.currentTestimony ?? _testimony;
    final hasRenditions = t != null && t.renditions.isNotEmpty;
    final options = [
      for (final q in hasRenditions ? AudioQuality.values : [AudioQuality.auto])
        QualityOption(value: q, label: q.label, hint: q.hint),
    ];
    final footer = [
      if (!hasRenditions) singleQualityReason(t is AudioTestimony ? t.renditionsStatus : null, video: false),
      'Qualité par défaut modifiable dans Paramètres › Lecture et données.',
    ].join('\n');

    final choice = await showQualityPickerSheet<AudioQuality>(
      context,
      title: 'Qualité audio',
      options: options,
      selected: player.qualityOverride ?? AudioQuality.auto,
      currentLabel: player.qualityOverride == null ? player.qualityLabel : null,
      footer: footer,
    );
    if (choice == null || !mounted) return;
    await _audio.setQuality(choice == AudioQuality.auto ? null : choice);
  }

  /// « Auto · 64 kbps », « Faible · 64 kbps »…
  String _qualityButtonLabel(AudioPlayerState player, PlaybackPreferences prefs) {
    final mode = (player.qualityOverride ?? prefs.audioQuality).label;
    final version = player.qualityLabel;
    return version == null || version.isEmpty ? mode : '$mode · $version';
  }

  void _cycleSpeed(double current) {
    final i = _speedOptions.indexOf(current);
    final next = _speedOptions[(i + 1) % _speedOptions.length];
    _audio.setSpeed(next);
  }

  @override
  Widget build(BuildContext context) {
    final player    = ref.watch(audioPlayerProvider);
    final prefs     = ref.watch(playbackPreferencesProvider);
    final prefsCtl  = ref.read(playbackPreferencesProvider.notifier);
    final isPlaying = player.isPlaying;
    final progress  = player.progress;

    // Témoignage réellement en cours (change lors de l'enchaînement auto).
    final current = player.currentTestimony ?? _testimony;

    final canNext = player.hasNext ||
        (player.queueLength > 1 && prefs.repeatMode == RepeatMode.all);

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
                        _TrackInfo(testimony: current),
                        const SizedBox(height: 12),
                        _CategoryChipLight(
                            label: current?.category.label ?? ''),
                        const SizedBox(height: 28),

                        // ── Slider de progression réel ────────────────────
                        _ProgressSection(
                          progress: progress,
                          elapsed: _fmtDuration(player.position),
                          total:   _fmtDuration(player.duration),
                          onChanged: (v) => _audio.seekToFraction(v),
                        ),
                        const SizedBox(height: 24),

                        // ── Contrôles principaux ──────────────────────────
                        _PlayerControls(
                          isPlaying: isPlaying,
                          isLoading: player.isLoading,
                          onPlayPause: () =>
                              isPlaying ? _audio.pause() : _audio.resume(),
                          onRewind: () => _audio.skipBackward(),
                          onForward: () => _audio.skipForward(),
                          onPrevious:
                              player.hasPrevious ? _audio.playPrevious : null,
                          onNext: canNext ? _audio.playNext : null,
                        ),
                        const SizedBox(height: 28),

                        // ── Répétition · lecture auto · qualité · vitesse ─
                        _SecondaryControls(
                          repeatMode: prefs.repeatMode,
                          autoplayNext: prefs.autoplayNext,
                          qualityLabel: _qualityButtonLabel(player, prefs),
                          speed: player.speed,
                          onRepeat: prefsCtl.cycleRepeatMode,
                          onAutoplay: () =>
                              prefsCtl.setAutoplayNext(!prefs.autoplayNext),
                          onQuality: () => _openQualitySheet(player),
                          onSpeed: () => _cycleSpeed(player.speed),
                        ),
                        const SizedBox(height: 24),
                        _TranscriptToggle(
                          open: _transcriptOpen,
                          transcript: current?.transcriptPreview,
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
                fontFamily: 'Plus Jakarta Sans',
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
                    fontFamily: 'Plus Jakarta Sans',
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
                      fontFamily: 'Plus Jakarta Sans',
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
            fontFamily: 'Plus Jakarta Sans',
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
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 16,
            color: Colors.white60,
          ),
        ),
        if (dur.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            dur,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
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
          fontFamily: 'Plus Jakarta Sans',
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
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                total,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
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
// Player Controls — préc. · -15s · play/pause · +15s · suiv.
// ============================================================================

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
    required this.onRewind,
    required this.onForward,
    this.onPrevious,
    this.onNext,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlayPause;
  final VoidCallback onRewind;
  final VoidCallback onForward;

  /// `null` = bouton désactivé (pas de témoignage précédent / suivant).
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 34,
          color: Colors.white,
          disabledColor: Colors.white24,
          tooltip: 'Précédent',
        ),
        // Reculer de 15 s
        _SkipButton(
          onTap: onRewind,
          icon: Icons.replay_10_rounded,
          label: '15s',
        ),
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
            child: isLoading && !isPlaying
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.primary,
                    size: 42,
                  ),
          ),
        ),
        // Avancer de 15 s
        _SkipButton(
          onTap: onForward,
          icon: Icons.forward_10_rounded,
          label: '15s',
          isForward: true,
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 34,
          color: Colors.white,
          disabledColor: Colors.white24,
          tooltip: 'Suivant',
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
              fontFamily: 'Plus Jakarta Sans',
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
// Secondary Controls — répétition · lecture auto · qualité · vitesse
// ============================================================================

class _SecondaryControls extends StatelessWidget {
  const _SecondaryControls({
    required this.repeatMode,
    required this.autoplayNext,
    required this.qualityLabel,
    required this.speed,
    required this.onRepeat,
    required this.onAutoplay,
    required this.onQuality,
    required this.onSpeed,
  });

  final RepeatMode repeatMode;
  final bool autoplayNext;
  final String qualityLabel;
  final double speed;
  final VoidCallback onRepeat;
  final VoidCallback onAutoplay;
  final VoidCallback onQuality;
  final VoidCallback onSpeed;

  static String _speedLabel(double v) =>
      v == v.truncateToDouble() ? '${v.toInt()}x' : '${v}x';

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SecondaryButton(
            icon: repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : repeatMode == RepeatMode.all
                    ? Icons.repeat_rounded
                    : Icons.repeat,
            label: switch (repeatMode) {
              RepeatMode.off => 'Répéter',
              RepeatMode.one => 'Répéter 1',
              RepeatMode.all => 'Tout répéter',
            },
            tooltip: repeatMode.label,
            active: repeatMode != RepeatMode.off,
            onTap: onRepeat,
          ),
        ),
        Expanded(
          child: _SecondaryButton(
            icon: Icons.playlist_play_rounded,
            label: 'Lecture auto',
            tooltip: autoplayNext
                ? 'Lecture automatique activée'
                : 'Lecture automatique désactivée',
            active: autoplayNext,
            onTap: onAutoplay,
          ),
        ),
        Expanded(
          child: _SecondaryButton(
            icon: Icons.high_quality_outlined,
            label: qualityLabel,
            tooltip: 'Qualité',
            onTap: onQuality,
          ),
        ),
        Expanded(
          child: _SecondaryButton(
            icon: Icons.speed_rounded,
            label: _speedLabel(speed),
            tooltip: 'Vitesse de lecture',
            active: speed != 1.0,
            onTap: onSpeed,
          ),
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryLight : Colors.white70;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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
                      fontFamily: 'Plus Jakarta Sans',
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
                fontFamily: 'Plus Jakarta Sans',
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
                        fontFamily: 'Plus Jakarta Sans',
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
                        fontFamily: 'Plus Jakarta Sans',
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
