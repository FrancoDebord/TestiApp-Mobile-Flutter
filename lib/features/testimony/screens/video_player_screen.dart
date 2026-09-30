import '../../home/widgets/testimony_card_header.dart' show openAuthorProfile;
import '../../community/widgets/follow_button.dart';
import 'dart:async';
import 'dart:io' show File;

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import 'package:video_player/video_player.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/tts_provider.dart';
import '../widgets/testimony_info.dart';
import '../../../core/media/media_quality.dart';
import '../../../core/media/playback_preferences.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../services/api_service.dart' show apiServiceProvider;
import '../../../shared/widgets/guest_gate.dart';
import '../../../shared/widgets/quality_picker_sheet.dart';
import '../../../shared/widgets/youtube_video_player.dart';
import '../providers/recommendations_provider.dart';

// ============================================================================
// Video Player Screen — YouTube-inspired
// ============================================================================
//
// Widget tree (Portrait):
//   VideoPlayerScreen (StatefulWidget)
//   └─ Scaffold
//      ├─ body: Column
//      │  ├─ Chewie / _VideoSurface (16:9, fond noir, barre orange, plein écran)
//      │  │  └─ retour · badge « Hors ligne » · annonce de la suivante
//      │  ├─ _PlaybackControlsRow   (qualité · favori · répétition · lecture auto)
//      │  └─ Expanded: SingleChildScrollView (zone blanche)
//      │     └─ Column
//      │        ├─ _VideoInfo        (titre, auteur + badge, vues · date,
//      │        │                     catégorie, ❤ · partage · commentaires ·
//      │        │                     télécharger)
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
  const VideoPlayerScreen({
    required this.testimonyId,
    this.mediaPath,
    this.testimony,
    this.playlist,
    this.qualityOverride,
    super.key,
  });

  final String testimonyId;

  /// URL directe passée depuis l'écran appelant (évite une recherche dans le feed).
  final String? mediaPath;

  /// Témoignage complet (titre, versions/qualités…) si l'appelant l'a déjà.
  final VideoTestimony? testimony;

  /// Liste de lecture pour l'enchaînement automatique (par défaut : le fil).
  final List<VideoTestimony>? playlist;

  /// Qualité choisie manuellement pendant la session (transmise à la vidéo
  /// suivante). `null` = préférence par défaut.
  final VideoQuality? qualityOverride;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _isLiked = false;
  bool _isPraying = false;
  bool _isBookmarked = false;
  VideoTestimony? _testimony;

  // ── Qualité ──────────────────────────────────────────────────────────────
  String? _original; // fichier original
  List<MediaRendition> _renditions = const []; // versions disponibles
  VideoQuality? _override; // choix ponctuel (session)
  ResolvedMedia? _resolved; // version en cours de lecture
  bool _switching = false; // changement de qualité en cours

  // ── Fin de lecture / suivant ─────────────────────────────────────────────
  bool _endHandled = false; // évite un double déclenchement
  VideoTestimony? _nextUp; // vidéo suivante annoncée
  int _nextCountdown = 0;
  Timer? _nextTimer;

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _override = widget.qualityOverride;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Un seul son à la fois : la vidéo arrête la lecture vocale en cours.
      ref.read(ttsControllerProvider.notifier).stop();
      _initPlayer();
    });
    ref.listenManual<AsyncValue<bool>>(
      isMeteredConnectionProvider,
      (prev, next) => _onNetworkChanged(prev?.value, next.value),
    );
  }

  /// Wi-Fi ⇄ données mobiles : en mode Auto (pas de choix manuel), on relit
  /// la version adaptée au nouveau réseau, sans perdre la position.
  Future<void> _onNetworkChanged(bool? was, bool? now) async {
    if (now == null || was == null || was == now) return;
    if (_videoCtrl == null || _switching || _override != null) return;
    if (ref.read(playbackPreferencesProvider).videoQuality !=
        VideoQuality.auto) {
      return;
    }
    final next = _resolve();
    if (next == null || next.url == _resolved?.url) return;
    final switched = await _changeQuality(null);
    if (!switched || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Qualité ajustée : ${next.label} '
            '(${now ? 'données mobiles' : 'Wi-Fi'})',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _initPlayer() async {
    // 1. Témoignage transmis par l'appelant, sinon recherche dans le feed local
    _testimony =
        widget.testimony ??
        ref
            .read(feedNotifierProvider)
            .whereType<VideoTestimony>()
            .where((t) => t.id == widget.testimonyId)
            .firstOrNull;
    _isLiked = _testimony?.isLiked ?? false;
    _isPraying = _testimony?.isPrayed ?? false;

    // 2. URL passée directement par l'appelant, sinon celle du témoignage
    final direct = widget.mediaPath;
    _original = (direct != null && direct.isNotEmpty)
        ? direct
        : _testimony?.mediaPath;
    _renditions = _testimony?.renditions ?? const [];

    // Vidéo YouTube : lue par le lecteur YouTube (build), pas de video_player.
    if (_testimony?.isYouTube ?? false) {
      if (mounted) setState(() {});
      return;
    }

    // 3. Fallback : récupérer le témoignage complet depuis l'API
    if ((_original == null || _original!.isEmpty) && _renditions.isEmpty) {
      await _fetchFromApi();
      return;
    }

    await _startPlayback();
  }

  Future<void> _fetchFromApi() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get<dynamic>(
        AppConstants.testimonyById(widget.testimonyId),
      );
      final t = testimonyFromApiJson(response.data);
      if (t is VideoTestimony && mounted) {
        _testimony = t;
        _isLiked = t.isLiked;
        _isPraying = t.isPrayed;
        _original = t.mediaPath;
        _renditions = t.renditions;
        if (t.isYouTube) {
          setState(() {});
          return;
        }
        if (_resolve() != null) {
          await _startPlayback();
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() {}); // afficher l'état vide
  }

  // ── Choix de la version à lire (préférences + réseau + choix manuel) ─────

  ResolvedMedia? _resolve({VideoQuality? override}) => resolveVideo(
    original: _original,
    renditions: _renditions,
    prefs: ref.read(playbackPreferencesProvider),
    metered: ref.read(isMeteredConnectionProvider).value ?? true,
    override: override ?? _override,
    // Retrouver un fichier téléchargé (lecture hors ligne).
    testimonyId: widget.testimonyId,
  );

  VideoPlayerController _createController(String source) {
    final bool isNetwork =
        source.startsWith('http://') || source.startsWith('https://');
    if (kIsWeb || isNetwork) {
      return VideoPlayerController.networkUrl(Uri.parse(source));
    }
    // Fichier local (vidéo téléchargée).
    return VideoPlayerController.file(File(localFilePath(source)));
  }

  ChewieController _buildChewie(
    VideoPlayerController ctrl, {
    required bool autoPlay,
  }) {
    // Barre de progression orange (charte), temps « 2:45 / 5:12 », plein écran.
    final progress = ChewieProgressColors(
      playedColor: AppColors.secondary,
      handleColor: AppColors.secondary,
      bufferedColor: AppColors.surface.withValues(alpha: 0.45),
      backgroundColor: AppColors.surface.withValues(alpha: 0.2),
    );
    return ChewieController(
      videoPlayerController: ctrl,
      autoPlay: autoPlay,
      looping: false, // la répétition est gérée par _onVideoEnded
      allowFullScreen: true,
      aspectRatio: ctrl.value.aspectRatio,
      placeholder: const _VideoPlaceholder(),
      materialProgressColors: progress,
      cupertinoProgressColors: progress,
    );
  }

  Future<void> _startPlayback() async {
    final resolved = _resolve();
    if (resolved == null) {
      if (mounted) setState(() {});
      return;
    }

    final ctrl = _createController(resolved.url);
    try {
      await ctrl.initialize();
    } catch (_) {
      await ctrl.dispose();
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) {
      await ctrl.dispose();
      return;
    }

    ctrl.addListener(_onTick);
    final chewie = _buildChewie(ctrl, autoPlay: true);

    setState(() {
      _videoCtrl = ctrl;
      _chewieCtrl = chewie;
      _resolved = resolved;
    });
  }

  // ── Changement de qualité (conserve la position et lecture/pause) ────────

  Future<void> _openQualitySheet() async {
    final picked = await showVideoQualitySheet(
      context,
      original: _original,
      renditions: _renditions,
      prefs: ref.read(playbackPreferencesProvider),
      metered: ref.read(isMeteredConnectionProvider).value ?? true,
      override: _override,
      renditionsStatus: _testimony?.renditionsStatus,
    );
    if (picked == null || !mounted) return;
    await _changeQuality(picked);
  }

  /// Passe à la version correspondant à [quality] (`null` = préférence /
  /// Auto). Retourne `true` si le lecteur a effectivement changé de fichier.
  Future<bool> _changeQuality(VideoQuality? quality) async {
    final next = quality == null
        ? resolveVideo(
            original: _original,
            renditions: _renditions,
            prefs: ref.read(playbackPreferencesProvider),
            metered: ref.read(isMeteredConnectionProvider).value ?? true,
          )
        : _resolve(override: quality);
    final old = _videoCtrl;
    if (next == null) return false;

    // Même fichier (ou lecteur pas encore prêt) : on mémorise simplement le choix.
    if (old == null || next.url == _resolved?.url) {
      setState(() {
        _override = quality;
        _resolved = next;
      });
      return false;
    }

    final oldChewie = _chewieCtrl;
    final position = old.value.position;
    final wasPlaying = old.value.isPlaying;

    setState(() => _switching = true);

    final ctrl = _createController(next.url);
    try {
      await ctrl.initialize();
      await ctrl.seekTo(position);
      if (wasPlaying) await ctrl.play();
    } catch (_) {
      await ctrl.dispose();
      if (mounted) {
        setState(() => _switching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de charger cette qualité.')),
        );
      }
      return false;
    }
    if (!mounted) {
      await ctrl.dispose();
      return false;
    }

    // Bascule vers le nouveau lecteur, puis libère l'ancien.
    old.removeListener(_onTick);
    await old.pause();
    ctrl.addListener(_onTick);
    final chewie = _buildChewie(ctrl, autoPlay: false);

    setState(() {
      _override = quality;
      _resolved = next;
      _videoCtrl = ctrl;
      _chewieCtrl = chewie;
      _switching = false;
      _endHandled = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldChewie?.dispose();
      old.dispose();
    });
    return true;
  }

  // ── Fin de lecture : répéter, enchaîner ou s'arrêter ─────────────────────

  void _onTick() {
    final ctrl = _videoCtrl;
    if (ctrl == null || _switching) return;
    final v = ctrl.value;
    if (!v.isInitialized || v.duration <= Duration.zero) return;

    final ended =
        !v.isPlaying &&
        v.position >= v.duration - const Duration(milliseconds: 250);

    if (!ended) {
      // L'utilisateur est revenu en arrière : la prochaine fin comptera.
      if (_endHandled && v.position < v.duration - const Duration(seconds: 1)) {
        _endHandled = false;
      }
      return;
    }
    if (_endHandled) return;
    _endHandled = true;
    _onVideoEnded();
  }

  /// Vidéos enchaînables : liste transmise, sinon les vidéos du fil.
  List<VideoTestimony> _playlist() =>
      widget.playlist ??
      ref.read(feedNotifierProvider).whereType<VideoTestimony>().toList();

  /// Vidéo qui suit la vidéo en cours : sans liste imposée par l'appelant,
  /// la première suggestion du serveur ; sinon l'ordre de la liste, ou la
  /// première vidéo « similaire » si la vidéo en cours n'y est pas.
  VideoTestimony? _findNext() {
    if (widget.playlist == null) {
      final recommended = (ref
                  .read(recommendationsProvider(widget.testimonyId))
                  .value ??
              const <Testimony>[])
          .whereType<VideoTestimony>()
          .firstOrNull;
      if (recommended != null) return recommended;
    }
    final list = _playlist();
    final idx = list.indexWhere((t) => t.id == widget.testimonyId);
    if (idx < 0) {
      return list.where((t) => t.id != widget.testimonyId).firstOrNull;
    }
    return idx + 1 < list.length ? list[idx + 1] : null;
  }

  void _onVideoEnded() {
    final prefs = ref.read(playbackPreferencesProvider);

    // Répéter cette vidéo
    if (prefs.repeatMode == RepeatMode.one) {
      _restart();
      return;
    }

    // Lecture auto désactivée : on s'arrête (« Répéter la liste » implique
    // toujours la lecture auto, cf. PlaybackPreferencesNotifier).
    if (!prefs.autoplayNext) return;

    final next = _findNext();

    // Enchaîner la suivante
    if (next != null) {
      _startNextCountdown(next);
      return;
    }

    // Fin de liste + « Répéter la liste » → retour à la première vidéo
    if (prefs.repeatMode == RepeatMode.all) {
      final first = _playlist().firstOrNull;
      if (first == null || first.id == widget.testimonyId) {
        _restart();
      } else {
        _startNextCountdown(first);
      }
    }
    // Sinon : on s'arrête.
  }

  Future<void> _restart() async {
    final ctrl = _videoCtrl;
    if (ctrl == null) return;
    await ctrl.seekTo(Duration.zero);
    await ctrl.play();
  }

  void _startNextCountdown(VideoTestimony next) {
    _nextTimer?.cancel();
    setState(() {
      _nextUp = next;
      _nextCountdown = 5;
    });
    _nextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_nextCountdown <= 1) {
        timer.cancel();
        _goToVideo(next);
      } else {
        setState(() => _nextCountdown--);
      }
    });
  }

  void _cancelNext() {
    _nextTimer?.cancel();
    setState(() => _nextUp = null);
  }

  Future<void> _goToVideo(VideoTestimony t) async {
    _nextTimer?.cancel();
    // Quitter le plein écran de Chewie avant de remplacer la page.
    if (_chewieCtrl?.isFullScreen ?? false) {
      _chewieCtrl!.exitFullScreen();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerScreen(
          testimonyId: t.id,
          mediaPath: t.mediaPath,
          testimony: t,
          playlist: widget.playlist,
          qualityOverride: _override,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _nextTimer?.cancel();
    _videoCtrl?.removeListener(_onTick);
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedNotifierProvider);
    final testimony =
        feed
            .whereType<VideoTestimony>()
            .where((t) => t.id == widget.testimonyId)
            .firstOrNull ??
        _testimony;
    final prefs = ref.watch(playbackPreferencesProvider);
    // Garder l'état du réseau à jour (utilisé pour le mode Auto).
    ref.watch(isMeteredConnectionProvider);
    // Vidéo publiée par lien YouTube : lecteur YouTube, sans choix de qualité.
    final youtubeId = (testimony?.isYouTube ?? false) ? testimony!.youtubeId : null;
    final isOffline = _resolved?.isLocal ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            // ── Surface vidéo (16:9, fond noir) ────────────────────────────
            ColoredBox(
              color: Colors.black,
              child: SafeArea(
                bottom: false,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (youtubeId != null)
                        YouTubeVideoPlayer(videoId: youtubeId)
                      else if (_chewieCtrl != null)
                        Chewie(
                          key: ObjectKey(_chewieCtrl),
                          controller: _chewieCtrl!,
                        )
                      else
                        _VideoSurface(
                          title: testimony?.title ?? '',
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
                      // Retour (le lecteur Chewie n'en a pas)
                      if (_chewieCtrl != null || youtubeId != null)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: IconButton(
                            tooltip: 'Retour',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: AppColors.surface,
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      // Lecture d'un fichier téléchargé
                      if (isOffline)
                        const Positioned(
                          top: 12,
                          right: 12,
                          child: OfflineBadge(),
                        ),
                      // Chargement pendant le changement de qualité
                      if (_switching) const _QualitySwitchOverlay(),
                      // Annonce de la vidéo suivante
                      if (_nextUp != null)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: _UpNextOverlay(
                            title: _nextUp!.title,
                            seconds: _nextCountdown,
                            onCancel: _cancelNext,
                            onPlayNow: () => _goToVideo(_nextUp!),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Qualité · répétition · lecture auto ─────────────────────────
            // (masqué pour YouTube : qualité et fin de lecture gérées par YouTube)
            if (youtubeId == null)
              _PlaybackControlsRow(
                qualityLabel: videoQualityChipLabel(
                  _override ?? prefs.videoQuality,
                  _resolved,
                ),
                onQuality: _openQualitySheet,
                repeatMode: prefs.repeatMode,
                onRepeat: () => ref
                    .read(playbackPreferencesProvider.notifier)
                    .cycleRepeatMode(),
                autoplayNext: prefs.autoplayNext,
                onAutoplayChanged: (v) => ref
                    .read(playbackPreferencesProvider.notifier)
                    .setAutoplayNext(v),
                isBookmarked: _isBookmarked,
                onBookmark: _toggleSave,
              ),
            const Divider(height: 1, color: AppColors.border),
            // ── Zone blanche : infos, commentaires, suggestions ────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _VideoInfo(
                      testimony: testimony,
                      isLiked: _isLiked,
                      isPraying: _isPraying,
                      onPray: _togglePray,
                      onLike: _toggleLike,
                      onShare: () => _share(testimony),
                      onComment: () => _showCommentsSheet(context),
                    ),
                    _CommentsPreview(
                      count: testimony?.stats.comments ?? 0,
                      onTap: () => _showCommentsSheet(context),
                    ),
                    _RelatedVideosList(
                      currentTestimonyId: widget.testimonyId,
                      onOpen: _goToVideo,
                    ),
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

  // ── Actions réservées aux membres (mode invité : feuille « compte requis »)

  Future<void> _toggleLike() async {
    if (!await requireAccount(context, ref, reason: 'réagir aux témoignages')) {
      return;
    }
    if (!mounted) return;
    final wasLiked = _isLiked;
    setState(() => _isLiked = !_isLiked);
    final interactions = ref.read(interactionProvider.notifier);
    if (!wasLiked) {
      interactions.setReaction(widget.testimonyId, ReactionType.like);
    } else {
      interactions.removeReaction(widget.testimonyId);
    }
  }

  Future<void> _togglePray() async {
    if (!await requireAccount(context, ref, reason: 'réagir aux témoignages')) {
      return;
    }
    if (!mounted) return;
    setState(() => _isPraying = !_isPraying);
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

  void _share(VideoTestimony? t) {
    if (t == null) return;
    SharePlus.instance.share(ShareParams(text: '${t.title}\n\n${t.shareLink}'));
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
      builder: (_) =>
          _VideoCommentsBottomSheet(testimonyId: widget.testimonyId),
    );
  }
}

// ============================================================================
// Qualité vidéo — utilitaires partagés (lecteur + Shorts)
// ============================================================================

/// Libellé court du bouton « Qualité » : « Auto · 360p », « 720p », « Auto ».
String videoQualityChipLabel(VideoQuality effective, ResolvedMedia? resolved) {
  if (effective == VideoQuality.auto) {
    return resolved?.rendition != null ? 'Auto · ${resolved!.label}' : 'Auto';
  }
  if (resolved == null) return effective.label;
  return resolved.rendition != null ? resolved.label : 'Auto';
}

/// Pourquoi une seule qualité est proposée (versions allégées en préparation, ou absentes).
String singleQualityReason(String? renditionsStatus, {required bool video}) =>
    switch (renditionsStatus) {
      'pending' || 'processing' =>
        'Les autres qualités sont en préparation : réessayez dans quelques minutes.',
      _ => video
          ? 'Une seule qualité est disponible pour cette vidéo.'
          : 'Une seule qualité est disponible pour cet audio.',
    };

/// Ouvre la feuille « Qualité » pour une vidéo et renvoie le choix
/// (ou `null` si l'utilisateur ferme la feuille). Ne modifie pas la
/// préférence globale : le choix vaut pour la lecture en cours.
Future<VideoQuality?> showVideoQualitySheet(
  BuildContext context, {
  required String? original,
  required List<MediaRendition> renditions,
  required PlaybackPreferences prefs,
  required bool metered,
  required VideoQuality? override,
  String? renditionsStatus,
}) {
  final options = availableVideoQualities(renditions);

  // Qualité cochée : choix en cours, sinon la version réellement lue.
  var selected = override ?? prefs.videoQuality;
  if (!options.contains(selected)) {
    final r = resolveVideo(
      original: original,
      renditions: renditions,
      prefs: prefs,
      metered: metered,
      override: override,
    );
    selected = options.firstWhere(
      (q) => q != VideoQuality.auto && q.height == r?.rendition?.height,
      orElse: () => VideoQuality.auto,
    );
  }

  final autoLabel = resolveVideo(
    original: original,
    renditions: renditions,
    prefs: prefs,
    metered: metered,
    override: VideoQuality.auto,
  )?.rendition?.label;

  const settingsHint =
      'Qualité par défaut modifiable dans Paramètres › Lecture et données.';

  return showQualityPickerSheet<VideoQuality>(
    context,
    title: 'Qualité de la vidéo',
    options: [
      for (final q in options)
        QualityOption(value: q, label: q.label, hint: q.hint),
    ],
    selected: selected,
    currentLabel: autoLabel,
    footer: renditions.isEmpty
        ? '${singleQualityReason(renditionsStatus, video: true)}\n$settingsHint'
        : 'Ce choix vaut pour cette lecture uniquement.\n$settingsHint',
  );
}

// ============================================================================
// Playback Controls Row (qualité + répétition + lecture auto)
// ============================================================================

class _PlaybackControlsRow extends StatelessWidget {
  const _PlaybackControlsRow({
    required this.qualityLabel,
    required this.onQuality,
    required this.repeatMode,
    required this.onRepeat,
    required this.autoplayNext,
    required this.onAutoplayChanged,
    this.isBookmarked = false,
    this.onBookmark,
  });

  final String qualityLabel;
  final VoidCallback onQuality;
  final RepeatMode repeatMode;
  final VoidCallback onRepeat;
  final bool autoplayNext;
  final ValueChanged<bool> onAutoplayChanged;
  final bool isBookmarked;
  final VoidCallback? onBookmark;

  @override
  Widget build(BuildContext context) {
    final repeatIcon = switch (repeatMode) {
      RepeatMode.off => Icons.repeat,
      RepeatMode.one => Icons.repeat_one_rounded,
      RepeatMode.all => Icons.repeat_rounded,
    };
    final repeatActive = repeatMode != RepeatMode.off;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          // Bouton « Qualité » (pilule)
          Flexible(
            child: Tooltip(
              message: 'Qualité de la vidéo',
              child: InkWell(
                onTap: onQuality,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hd_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          qualityLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (onBookmark != null)
            IconButton(
              onPressed: onBookmark,
              tooltip: isBookmarked ? 'Retirer des favoris' : 'Sauvegarder',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
              color: isBookmarked ? AppColors.secondary : AppColors.textSecondary,
            ),
          // Répétition (off → une → liste)
          IconButton(
            onPressed: onRepeat,
            tooltip: repeatMode.label,
            visualDensity: VisualDensity.compact,
            icon: Icon(repeatIcon),
            iconSize: 22,
            color: repeatActive ? AppColors.primary : AppColors.textSecondary,
            style: repeatActive
                ? IconButton.styleFrom(backgroundColor: AppColors.primarySoft)
                : null,
          ),
          // Lecture automatique de la suivante
          Flexible(
            child: GestureDetector(
              onTap: () => onAutoplayChanged(!autoplayNext),
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Lecture auto',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: autoplayNext,
              onChanged: onAutoplayChanged,
              activeThumbColor: AppColors.surface,
              activeTrackColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Overlays : changement de qualité + vidéo suivante
// ============================================================================

class _QualitySwitchOverlay extends StatelessWidget {
  const _QualitySwitchOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Changement de qualité…',
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpNextOverlay extends StatelessWidget {
  const _UpNextOverlay({
    required this.title,
    required this.seconds,
    required this.onCancel,
    required this.onPlayNow,
  });

  final String title;
  final int seconds;
  final VoidCallback onCancel;
  final VoidCallback onPlayNow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPlayNow,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              const Icon(
                Icons.skip_next_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Suivant dans $seconds s',
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 40),
                ),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Video Surface  (16:9 + tap-to-reveal overlay)
// ============================================================================

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({
    required this.title,
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

  final String title;
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
                title: title,
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
                colors: [AppColors.primaryDark, Colors.black],
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
                  child: const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white38,
                    size: 28,
                  ),
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
    required this.title,
    required this.isPlaying,
    required this.progress,
    required this.elapsed,
    required this.total,
    required this.onPlayPause,
    required this.onSeek,
    required this.onFullscreen,
    required this.onBack,
  });

  final String title;
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
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
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 2,
                ),
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
              activeTrackColor: AppColors.secondary,
              inactiveTrackColor: Colors.white30,
              thumbColor: AppColors.secondary,
              overlayColor: Colors.white24,
            ),
            child: Slider(value: progress, onChanged: onSeek),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  elapsed,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: AppFonts.family,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/ $total',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontFamily: AppFonts.family,
                  ),
                ),
                const Spacer(),
                // HD badge
                _VideoBadge(label: 'HD'),
                const SizedBox(width: 8),
                // Captions
                const Icon(
                  Icons.closed_caption_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                // Settings
                const Icon(
                  Icons.settings_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
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
          fontFamily: AppFonts.family,
        ),
      ),
    );
  }
}

// ============================================================================
// Video Info (maquette écran 8) : titre, auteur, catégorie, actions
// ============================================================================

class _VideoInfo extends ConsumerWidget {
  const _VideoInfo({
    required this.testimony,
    required this.isLiked,
    required this.isPraying,
    required this.onPray,
    required this.onLike,
    required this.onShare,
    required this.onComment,
  });

  final VideoTestimony? testimony;
  final bool isLiked;
  final bool isPraying;
  final VoidCallback onPray;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = testimony;
    final fr = AppLocalizations.of(context).isFr;
    final currentUid = ref.watch(currentUserProvider)?.id;
    if (t == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final author = t.author;
    final isOwnProfile = author.uid == currentUid;
    final verse = t.bibleVerse;
    // Le compteur du serveur inclut déjà le « J'aime » éventuel de l'utilisateur.
    final likes = t.stats.likes + (isLiked == t.isLiked ? 0 : (isLiked ? 1 : -1));
    final prayers =
        t.stats.prayers + (isPraying == t.isPrayed ? 0 : (isPraying ? 1 : -1));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.title, style: AppTextStyles.h3),
          const SizedBox(height: 10),
          TestimonyAuthorRow(
            author: author,
            meta: viewsAndAge(t, fr: fr),
            onTap: () => openAuthorProfile(context, author.uid),
            trailing: isOwnProfile
                ? null
                : FollowButton(
                    userId: author.uid,
                    displayName: author.displayName,
                    compact: true,
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [CategoryBadge(category: t.category)],
          ),
          if (verse != null && verse.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            InsightVerseCard(
              verse: verse.trim(),
              reference: t.bibleVerseRef,
              title: fr ? 'Parole de Dieu' : 'Word of God',
            ),
          ],
          const SizedBox(height: 6),
          TestimonyStatsRow(
            testimony: t,
            likes: likes < 0 ? 0 : likes,
            isLiked: isLiked,
            prayers: prayers < 0 ? 0 : prayers,
            isPraying: isPraying,
            onPray: onPray,
            comments: t.stats.comments,
            onLike: onLike,
            onShare: onShare,
            onComment: onComment,
            fr: fr,
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
  const _CommentsPreview({required this.onTap, required this.count});

  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final fr = AppLocalizations.of(context).isFr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fr
                        ? '${formatCompactCount(count)} commentaire${count > 1 ? 's' : ''}'
                        : '${formatCompactCount(count, fr: false)} comment${count == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 22,
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
// Related Videos List
// ============================================================================

class _RelatedVideosList extends ConsumerWidget {
  const _RelatedVideosList({
    required this.currentTestimonyId,
    required this.onOpen,
  });
  final String currentTestimonyId;

  /// Ouvre la vidéo choisie (remplace l'écran courant).
  final ValueChanged<VideoTestimony> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Suggestions du serveur d'abord, repli sur les vidéos du fil.
    final recAsync = ref.watch(recommendationsProvider(currentTestimonyId));
    if (recAsync.isLoading) return const SizedBox.shrink();
    final recommended = (recAsync.value ?? const <Testimony>[])
        .whereType<VideoTestimony>()
        .toList();
    final related = recommended.isNotEmpty
        ? recommended
        : ref
            .watch(feedNotifierProvider)
            .whereType<VideoTestimony>()
            .where((t) => t.id != currentTestimonyId)
            .take(5)
            .toList();

    if (related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            AppLocalizations.of(context).isFr ? 'Vidéos similaires' : 'Related videos',
            style: AppTextStyles.h4,
          ),
        ),
        ...related.map(
          (t) => _RelatedVideoCard(testimony: t, onTap: () => onOpen(t)),
        ),
      ],
    );
  }
}

class _RelatedVideoCard extends StatefulWidget {
  const _RelatedVideoCard({required this.testimony, required this.onTap});
  final VideoTestimony testimony;
  final VoidCallback onTap;

  @override
  State<_RelatedVideoCard> createState() => _RelatedVideoCardState();
}

class _RelatedVideoCardState extends State<_RelatedVideoCard> {
  static const _gradients = [
    AppColors.delivranceGradient,
    AppColors.conversionGradient,
    AppColors.financesGradient,
    AppColors.protectionGradient,
    AppColors.guerisonGradient,
  ];

  late int _secs;

  @override
  void initState() {
    super.initState();
    _secs = widget.testimony.durationSeconds;
    // YouTube : pas de fichier à sonder, la durée n'est pas connue.
    if (_secs == 0 && !widget.testimony.isYouTube) _loadDuration();
  }

  Future<void> _loadDuration() async {
    final path = widget.testimony.mediaPath;
    if (path == null || path.isEmpty) return;
    try {
      final ctrl = path.startsWith('http')
          ? VideoPlayerController.networkUrl(Uri.parse(path))
          : VideoPlayerController.file(File(path));
      await ctrl.initialize();
      final secs = ctrl.value.duration.inSeconds;
      ctrl.dispose();
      if (mounted && secs > 0) setState(() => _secs = secs);
    } catch (_) {}
  }

  static String _fmtDuration(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  static String _fmtViews(int v) => '${formatCompactCount(v)} vue${v > 1 ? 's' : ''}';

  @override
  Widget build(BuildContext context) {
    final testimony = widget.testimony;
    final gradient =
        _gradients[testimony.id.hashCode.abs() % _gradients.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Miniature
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: SizedBox(
                        width: 120,
                        height: 68,
                        child: testimony.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                testimony.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _GradientThumb(gradient: gradient),
                              )
                            : _GradientThumb(gradient: gradient),
                      ),
                    ),
                    if (testimony.isYouTube)
                      const Positioned(
                        bottom: 5,
                        right: 6,
                        child: YouTubeBadge(compact: true),
                      )
                    else
                      Positioned(
                        bottom: 5,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            _fmtDuration(_secs),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.surface,
                              fontSize: 10,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testimony.title,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        testimony.author.displayName,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _fmtViews(testimony.stats.views),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
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

class _GradientThumb extends StatelessWidget {
  const _GradientThumb({required this.gradient});
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: gradient)),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white54,
          size: 30,
        ),
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

class _VideoCommentsBottomSheetState extends State<_VideoCommentsBottomSheet> {
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
                        const Icon(
                          Icons.favorite_border_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Text('$likeCount', style: AppTextStyles.bodySmall),
                      ],
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Répondre',
                      style: TextStyle(
                        fontFamily: AppFonts.family,
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
              gradient: LinearGradient(colors: AppColors.guerisonGradient),
            ),
            child: const Center(
              child: Text(
                'V',
                style: TextStyle(
                  color: Colors.white,
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
                hintText: 'Ajouter un commentaire...',
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
  State<_FullscreenVideoRoute> createState() => _FullscreenVideoRouteState();
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
                onRewind: () => setState(
                  () => _progress = (_progress - 15 / _totalSeconds).clamp(
                    0.0,
                    1.0,
                  ),
                ),
                onForward: () => setState(
                  () => _progress = (_progress + 15 / _totalSeconds).clamp(
                    0.0,
                    1.0,
                  ),
                ),
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
                      fontFamily: AppFonts.family,
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
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 2,
                ),
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
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: AppColors.secondary,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: AppColors.secondary,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(value: progress, onChanged: onSeek),
                ),
                // Controls row
                Row(
                  children: [
                    Text(
                      elapsed,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: AppFonts.family,
                      ),
                    ),
                    Text(
                      ' / $total',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontFamily: AppFonts.family,
                      ),
                    ),
                    const Spacer(),
                    // Rewind
                    IconButton(
                      onPressed: onRewind,
                      icon: const Icon(Icons.replay_10_rounded),
                      color: Colors.white,
                      iconSize: 26,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                    // Play/Pause
                    IconButton(
                      onPressed: onPlayPause,
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      color: Colors.white,
                      iconSize: 32,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    // Forward
                    IconButton(
                      onPressed: onForward,
                      icon: const Icon(Icons.forward_10_rounded),
                      color: Colors.white,
                      iconSize: 26,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
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
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    // Speed label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '1x',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: AppFonts.family,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Rotate lock
                    IconButton(
                      onPressed: onLockRotate,
                      icon: Icon(
                        rotateLocked
                            ? Icons.screen_lock_rotation_rounded
                            : Icons.screen_rotation_rounded,
                      ),
                      color: rotateLocked
                          ? AppColors.secondary
                          : Colors.white70,
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
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
            builder: (_) => VideoPlayerScreen(testimonyId: widget.testimonyId),
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
                  onTap: () => setState(() => _isPlaying = !_isPlaying),
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
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
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
