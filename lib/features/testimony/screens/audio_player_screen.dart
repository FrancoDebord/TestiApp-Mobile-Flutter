import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../../../core/app_constants.dart';
import '../../../core/media/media_quality.dart' show OfflineMedia;
import '../../../core/media/playback_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart' show apiServiceProvider;
import '../../../services/audio_player_service.dart';
import '../../../shared/widgets/guest_gate.dart';
import '../../../shared/widgets/quality_picker_sheet.dart';
import '../../home/widgets/testimony_card_header.dart' show openAuthorProfile;
import '../providers/tts_provider.dart';
import '../widgets/testimony_info.dart';
import 'testimony_comments_screen.dart';
import 'video_player_screen.dart' show singleQualityReason;

// ============================================================================
// Audio Player Screen — lecteur plein écran (charte : fond blanc, bleu, orange)
// ============================================================================
//
// Widget tree:
//   AudioPlayerScreen (StatefulWidget)
//   └─ Scaffold (fond blanc)
//      └─ body: SafeArea
//         └─ Column
//            ├─ _AudioAppBar          (fermer · titre · favori · partager)
//            └─ Expanded: SingleChildScrollView
//               └─ Column
//                  ├─ _CoverArt             (carré arrondi bleu + onde)
//                  ├─ _ProgressSection      (barre orange + temps)
//                  ├─ _PlayerControls       (préc. · -15s · play/pause · +15s · suiv.)
//                  ├─ _SecondaryControls    (répétition · lecture auto · qualité · vitesse)
//                  ├─ titre · TestimonyAuthorRow · CategoryBadge
//                  ├─ TestimonyStatsRow     (❤ · prière · partage · commentaires · télécharger)
//                  ├─ InsightVerseCard      (verset, si présent)
//                  └─ _TranscriptToggle     (expandable text)
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Un seul son à la fois : l'audio arrête la lecture vocale en cours.
      ref.read(ttsControllerProvider.notifier).stop();
      _loadAndPlay();
    });
  }

  /// Témoignage affiché + état initial des réactions de l'utilisateur.
  void _setTestimony(AudioTestimony t) {
    _testimony = t;
    _isLiked = t.isLiked;
    _isPraying = t.isPrayed;
    _isBookmarked = t.isSaved;
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
        if (mounted) setState(() => _setTestimony(audios[idx]));
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
        setState(() => _setTestimony(t));
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

  // ── Actions réservées aux membres (mode invité : feuille « compte requis »)

  Future<bool> _member(String reason) =>
      requireAccount(context, ref, reason: reason);

  Future<void> _toggleLike(AudioTestimony? t) async {
    if (!await _member('réagir aux témoignages') || !mounted) return;
    final wasLiked = _isLiked;
    setState(() => _isLiked = !_isLiked);
    if (t == null) return;
    final interactions = ref.read(interactionProvider.notifier);
    if (!wasLiked) {
      interactions.setReaction(t.id, ReactionType.like);
    } else {
      interactions.removeReaction(t.id);
    }
  }

  Future<void> _togglePray(AudioTestimony? t) async {
    if (!await _member('réagir aux témoignages') || !mounted) return;
    setState(() => _isPraying = !_isPraying);
    if (t != null) ref.read(interactionProvider.notifier).togglePray(t.id);
  }

  Future<void> _toggleBookmark(AudioTestimony? t) async {
    if (!await _member('enregistrer vos favoris') || !mounted) return;
    setState(() => _isBookmarked = !_isBookmarked);
    if (t != null) ref.read(interactionProvider.notifier).toggleSave(t.id);
  }

  void _share(AudioTestimony? t) {
    if (t == null) return;
    SharePlus.instance.share(ShareParams(text: '${t.title}\n\n${t.shareLink}'));
    ref.read(interactionProvider.notifier).recordShare(t.id);
  }

  Future<void> _openComments(AudioTestimony? t) async {
    if (!await _member('commenter les témoignages') || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TestimonyCommentsScreen(testimonyId: t?.id ?? widget.testimonyId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player    = ref.watch(audioPlayerProvider);
    final prefs     = ref.watch(playbackPreferencesProvider);
    final prefsCtl  = ref.read(playbackPreferencesProvider.notifier);
    final isPlaying = player.isPlaying;
    final progress  = player.progress;
    final fr        = AppLocalizations.of(context).isFr;

    // Témoignage réellement en cours (change lors de l'enchaînement auto).
    final current = player.currentTestimony ?? _testimony;
    final isOffline = player.qualityLabel == OfflineMedia.label;

    final canNext = player.hasNext ||
        (player.queueLength > 1 && prefs.repeatMode == RepeatMode.all);

    // Compteurs : ceux du serveur, ajustés par les réactions de la session.
    int adjust(int base, bool now, bool before) =>
        (base + (now == before ? 0 : (now ? 1 : -1))).clamp(0, 1 << 31);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _AudioAppBar(
                onBack: () => Navigator.of(context).pop(),
                isBookmarked: _isBookmarked,
                onBookmark: () => _toggleBookmark(current),
                onShare: () => _share(current),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: _CoverArt(
                          category: current?.category,
                          isPlaying: isPlaying,
                          isOffline: isOffline,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Slider de progression réel ────────────────────
                      _ProgressSection(
                        progress: progress,
                        elapsed: _fmtDuration(player.position),
                        total:   _fmtDuration(player.duration),
                        onChanged: (v) => _audio.seekToFraction(v),
                      ),
                      const SizedBox(height: 8),

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
                      const SizedBox(height: 12),

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
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 16),

                      // ── Infos (même hiérarchie que le lecteur vidéo) ──
                      Text(
                        current?.title ?? (fr ? 'Chargement…' : 'Loading…'),
                        style: AppTextStyles.h3,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      if (current != null) ...[
                        TestimonyAuthorRow(
                          author: current.author,
                          meta: viewsAndAge(current, fr: fr),
                          onTap: () =>
                              openAuthorProfile(context, current.author.uid),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            CategoryBadge(category: current.category),
                            if (isOffline) const OfflineBadge(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TestimonyStatsRow(
                          testimony: current,
                          likes: adjust(
                              current.stats.likes, _isLiked, current.isLiked),
                          isLiked: _isLiked,
                          prayers: adjust(current.stats.prayers, _isPraying,
                              current.isPrayed),
                          isPraying: _isPraying,
                          comments: current.stats.comments,
                          onLike: () => _toggleLike(current),
                          onPray: () => _togglePray(current),
                          onShare: () => _share(current),
                          onComment: () => _openComments(current),
                          fr: fr,
                        ),
                        if (current.bibleVerse?.trim().isNotEmpty ?? false) ...[
                          const SizedBox(height: 12),
                          InsightVerseCard(
                            verse: current.bibleVerse!.trim(),
                            reference: current.bibleVerseRef,
                            title: fr ? 'Parole de Dieu' : 'Word of God',
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
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
            ],
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
  const _AudioAppBar({
    required this.onBack,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onShare,
  });

  final VoidCallback onBack;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final fr = AppLocalizations.of(context).isFr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: fr ? 'Fermer' : 'Close',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: AppColors.primary,
            iconSize: 28,
          ),
          Expanded(
            child: Text(
              fr ? 'Témoignage audio' : 'Audio testimony',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h4.copyWith(color: AppColors.primary),
            ),
          ),
          IconButton(
            onPressed: onBookmark,
            tooltip: fr ? 'Sauvegarder' : 'Save',
            icon: Icon(isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded),
            color: isBookmarked ? AppColors.secondary : AppColors.textSecondary,
          ),
          IconButton(
            onPressed: onShare,
            tooltip: fr ? 'Partager' : 'Share',
            icon: const Icon(Icons.share_rounded),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Cover Art (carré arrondi, dégradé bleu, onde)
// ============================================================================

class _CoverArt extends StatelessWidget {
  const _CoverArt({this.category, this.isPlaying = false, this.isOffline = false});

  final TestimonyCategory? category;
  final bool isPlaying;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.maxWidth.clamp(120.0, 240.0);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.blueGradient,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Motif discret de croix
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Opacity(
                  opacity: 0.08,
                  child: CustomPaint(painter: _CrossPatternPainter()),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Wave(active: isPlaying, height: size * 0.28),
                      if (category != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          category!.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.surface.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Badge micro (bas droite)
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic_rounded,
                          color: AppColors.sun, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'AUDIO',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.surface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isOffline)
                const Positioned(top: 12, left: 12, child: OfflineBadge()),
            ],
          ),
        );
      },
    );
  }
}

/// Onde stylisée (barres arrondies) : jaune pendant la lecture.
class _Wave extends StatelessWidget {
  const _Wave({required this.active, required this.height});

  final bool active;
  final double height;

  static const _bars = [0.35, 0.6, 0.9, 0.55, 1.0, 0.7, 0.4, 0.8, 0.5, 0.3];

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.sun
        : AppColors.surface.withValues(alpha: 0.7);
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final b in _bars)
            Container(
              width: 5,
              height: height * b,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Progress Section (barre orange)
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
            activeTrackColor: AppColors.secondary,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.secondary,
            overlayColor: AppColors.secondarySoft,
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(elapsed, style: AppTextStyles.bodySmall),
              Text(total, style: AppTextStyles.bodySmall),
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
          iconSize: 32,
          color: AppColors.primary,
          disabledColor: AppColors.border,
          tooltip: 'Précédent',
        ),
        // Reculer de 15 s
        _SkipButton(
          onTap: onRewind,
          icon: Icons.replay_10_rounded,
          label: '15s',
        ),
        // Play / Pause (grand, bleu)
        Semantics(
          button: true,
          label: isPlaying ? 'Pause' : 'Lecture',
          child: GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: AppShadows.card,
              ),
              child: isLoading && !isPlaying
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.surface,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppColors.surface,
                      size: 40,
                    ),
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
          iconSize: 32,
          color: AppColors.primary,
          disabledColor: AppColors.border,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 32),
          Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
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
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active ? AppColors.primarySoft : AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
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

  @override
  Widget build(BuildContext context) {
    final text = transcript?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: AppShadows.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: AppRadius.cardRadius,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.subtitles_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Transcription',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(text, style: AppTextStyles.bodyMedium),
            ),
          ),
        ],
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
                        fontFamily: AppFonts.family,
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
                        fontFamily: AppFonts.family,
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
