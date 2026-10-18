import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;
import 'package:video_player/video_player.dart';

import '../providers/comments_provider.dart' show commentsProvider;
import '../../../shared/widgets/mention_text.dart' show MentionText;
import '../../../shared/models/mention.dart' show MentionCodec;
import '../../../shared/models/comment_model.dart';
import '../../../shared/comments/comment_likes.dart';
import '../prayer/pray_for_testimony.dart' show prayForTestimony;
import '../../../core/media/media_quality.dart';
import '../../../core/media/video_source.dart' show networkVideoController, videoPlaybackChain;
import '../../../core/media/playback_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart';
import '../../../shared/widgets/guest_gate.dart';
import '../widgets/testimony_info.dart';
import '../providers/view_tracker.dart';
import 'video_player_screen.dart' show showVideoQualitySheet, videoQualityChipLabel;
import '../../../shared/widgets/video_poster.dart';

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

  /// Qualité choisie manuellement : s'applique à tous les shorts de la session.
  VideoQuality? _override;

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

  /// Un short doit-il tourner en boucle ? (« Répéter la liste » implique
  /// toujours la lecture auto, cf. PlaybackPreferencesNotifier.)
  /// • « Répéter ce témoignage » ou lecture auto désactivée → boucle
  /// • dernier short sans « Répéter la liste » → boucle
  bool _shouldLoop(int index, PlaybackPreferences prefs) {
    if (prefs.repeatMode == RepeatMode.one || !prefs.autoplayNext) return true;
    if (widget.testimonies.length <= 1) return true;
    final isLast = index == widget.testimonies.length - 1;
    return isLast && prefs.repeatMode != RepeatMode.all;
  }

  /// Fin d'un short (sans boucle) : passer au suivant, ou revenir au début.
  void _onShortEnded(int index) {
    if (index != _currentPage || !_pageController.hasClients) return;
    if (index < widget.testimonies.length - 1) {
      _pageController.animateToPage(
        index + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else if (_allowWrap(ref.read(playbackPreferencesProvider))) {
      _pageController.jumpToPage(0);
    }
  }

  static bool _allowWrap(PlaybackPreferences p) =>
      p.autoplayNext && p.repeatMode == RepeatMode.all;

  Future<void> _openQualitySheet(VideoTestimony current) async {
    final picked = await showVideoQualitySheet(
      context,
      original: current.mediaPath,
      hlsUrl: current.hlsUrl,
      renditions: current.renditions,
      prefs: ref.read(playbackPreferencesProvider),
      metered: ref.read(isMeteredConnectionProvider).value ?? true,
      override: _override,
      renditionsStatus: current.renditionsStatus,
    );
    if (picked == null || !mounted) return;
    setState(() => _override = picked);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(playbackPreferencesProvider);
    final metered = ref.watch(isMeteredConnectionProvider).value ?? true;
    final current = widget.testimonies.isEmpty
        ? null
        : widget.testimonies[
            _currentPage.clamp(0, widget.testimonies.length - 1)];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.l10n.navShorts,
          style: TextStyle(
            fontFamily: AppFonts.family,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          if (current != null)
            _ShortsQualityChip(
              label: videoQualityChipLabel(
                _override ?? prefs.videoQualityFor(metered: metered),
                resolveVideoTestimony(
                  current,
                  prefs: prefs,
                  metered: metered,
                  override: _override,
                ),
              ),
              onTap: () => _openQualitySheet(current),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: widget.testimonies.isEmpty
          ? Center(
              child: Text(
                context.l10n.homeEmptyVideos,
                style: const TextStyle(color: Colors.white),
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
                  loop: _shouldLoop(index, prefs),
                  qualityOverride: _override,
                  onEnded: () => _onShortEnded(index),
                );
              },
            ),
    );
  }
}

// ── Bouton « Qualité » discret (en haut à droite) ─────────────────────────────

class _ShortsQualityChip extends StatelessWidget {
  const _ShortsQualityChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Tooltip(
        message: context.l10n.playerVideoQualityTitle,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(77)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hd_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
// _ShortPage — one video page
// ============================================================================

class _ShortPage extends ConsumerStatefulWidget {
  const _ShortPage({
    required this.testimony,
    required this.isActive,
    required this.loop,
    required this.onEnded,
    this.qualityOverride,
    super.key,
  });

  final VideoTestimony testimony;
  final bool isActive;

  /// Rejouer en boucle (sinon [onEnded] est appelé à la fin).
  final bool loop;
  final VoidCallback onEnded;

  /// Qualité choisie pour la session Shorts (`null` = préférence par défaut).
  final VideoQuality? qualityOverride;

  @override
  ConsumerState<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends ConsumerState<_ShortPage> {
  VideoPlayerController? _videoController;
  bool _controllerReady = false;
  bool _showPlayIcon = false;
  Timer? _playIconTimer;

  // Tracks whether we showed the play icon overlay recently.
  bool _isPlaying = false;

  /// URL en cours de lecture (version choisie selon la qualité).
  String? _currentUrl;

  /// Évite de signaler deux fois la même fin de lecture.
  bool _endHandled = false;

  /// Données mobiles : pas de lecture automatique, l'affiche attend un toucher
  /// (rien n'est téléchargé avant, pas même la page suivante préchargée).
  bool _awaitingTap = false;
  bool _userStarted = false;

  @override
  void initState() {
    super.initState();
    // Décaler l'init après le premier frame pour ne pas bloquer l'animation de swipe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initVideo();
    });
    ref.listenManual<AsyncValue<bool>>(
      isMeteredConnectionProvider,
      (prev, next) => _onNetworkChanged(prev?.value, next.value),
    );
  }

  /// Wi-Fi ⇄ données mobiles : le short actif, en mode Auto (pas de choix
  /// manuel), bascule sur la version adaptée en gardant sa position.
  Future<void> _onNetworkChanged(bool? was, bool? now) async {
    if (now == null || was == null || was == now) return;
    // Passage en Wi-Fi : la lecture automatique redevient possible.
    if (!now && _awaitingTap) {
      setState(() => _awaitingTap = false);
      await _initVideo();
      return;
    }
    if (!widget.isActive || widget.qualityOverride != null) return;
    final resolved = resolveVideoTestimony(
      widget.testimony,
      prefs: ref.read(playbackPreferencesProvider),
      metered: now,
    );
    if (resolved == null || resolved.url == _currentUrl) return;
    final switched = await _switchQuality();
    if (!switched || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.l10n.playerQualityAdjusted(
          resolved.label,
          now ? context.l10n.playerNetworkMobile : context.l10n.playerNetworkWifi,
        )),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  /// Version à lire selon préférences + réseau + choix manuel.
  String? _resolveUrl() => resolveVideoTestimony(
        widget.testimony,
        prefs: ref.read(playbackPreferencesProvider),
        metered: ref.read(isMeteredConnectionProvider).value ?? true,
        override: widget.qualityOverride,
      )?.url;

  VideoPlayerController _createController(String path) {
    if (kIsWeb || path.startsWith('http://') || path.startsWith('https://')) {
      return networkVideoController(path);
    }
    // Fichier local (vidéo téléchargée).
    return VideoPlayerController.file(File(localFilePath(path)));
  }

  Future<void> _initVideo() async {
    final resolved = resolveVideoTestimony(
      widget.testimony,
      prefs: ref.read(playbackPreferencesProvider),
      metered: ref.read(isMeteredConnectionProvider).value ?? true,
      override: widget.qualityOverride,
    );
    final path = resolved?.url;
    debugPrint('⚡ _initVideo id=${widget.testimony.id} path=$path');
    if (path == null || path.isEmpty) {
      debugPrint('⚡ _initVideo: path null/empty → placeholder');
      return;
    }
    final metered = ref.read(isMeteredConnectionProvider).value ?? true;
    if (metered && !resolved!.isLocal && !_userStarted) {
      if (mounted) setState(() => _awaitingTap = true);
      return;
    }

    // Version choisie (HLS en Auto), puis, si le lecteur ne s'initialise pas,
    // le MP4 de secours et l'ancien fichier (/storage/media/…mp4).
    final t = widget.testimony;
    final chain = videoPlaybackChain(
      primary: path,
      playbackUrl: t.hlsUrl,
      mp4Url: t.mp4Url,
      legacyUrl: t.mediaPath,
    );
    for (final url in chain) {
      final controller = _createController(url);
      _videoController = controller;
      _currentUrl = url;
      try {
        await controller.initialize();
        await controller.setLooping(widget.loop);
        controller.addListener(_onTick);
        if (mounted) {
          setState(() => _controllerReady = true);
          _isPlaying = widget.isActive;
          if (widget.isActive) {
            controller.play();
            _countView();
          }
        }
        return;
      } catch (e) {
        debugPrint('⚡ _initVideo FAIL path=$url error=$e');
        if (_videoController == controller) _videoController = null;
        await controller.dispose();
        if (!mounted) return;
      }
    }
    if (mounted) setState(() => _controllerReady = false);
  }

  /// Changement de qualité : nouveau lecteur à la même position.
  /// Retourne `true` si le lecteur a changé de fichier.
  Future<bool> _switchQuality() async {
    final old = _videoController;
    final path = _resolveUrl();
    if (path == null || path.isEmpty || path == _currentUrl) return false;
    if (old == null || !_controllerReady) {
      // Lecteur pas encore prêt : on repart simplement de zéro.
      old?.removeListener(_onTick);
      old?.dispose();
      _videoController = null;
      await _initVideo();
      return true;
    }

    final position = old.value.position;
    final controller = _createController(path);
    try {
      await controller.initialize();
      await controller.setLooping(widget.loop);
      await controller.seekTo(position);
      if (widget.isActive && old.value.isPlaying) await controller.play();
    } catch (e) {
      debugPrint('⚡ _switchQuality FAIL path=$path error=$e');
      await controller.dispose();
      return false;
    }
    if (!mounted || _videoController != old) {
      await controller.dispose();
      return false;
    }
    old.removeListener(_onTick);
    await old.pause();
    controller.addListener(_onTick);
    setState(() {
      _videoController = controller;
      _currentUrl = path;
      _endHandled = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    return true;
  }

  /// Détecte la fin d'un short non bouclé.
  void _onTick() {
    final ctrl = _videoController;
    if (ctrl == null || widget.loop || !widget.isActive) return;
    final v = ctrl.value;
    if (!v.isInitialized || v.duration <= Duration.zero) return;
    final ended = !v.isPlaying &&
        v.position >= v.duration - const Duration(milliseconds: 250);
    if (!ended) {
      if (v.position < v.duration - const Duration(seconds: 1)) {
        _endHandled = false;
      }
      return;
    }
    if (_endHandled) return;
    _endHandled = true;
    widget.onEnded();
  }

  @override
  void didUpdateWidget(covariant _ShortPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loop != widget.loop) {
      _videoController?.setLooping(widget.loop);
    }
    if (oldWidget.qualityOverride != widget.qualityOverride) {
      _switchQuality();
    }
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _endHandled = false;
        // play() repart de zéro si la vidéo était terminée.
        _videoController?.play();
        if (_videoController != null) _countView();
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
    _videoController?.removeListener(_onTick);
    _videoController?.dispose();
    super.dispose();
  }

  /// Lecture démarrée : vue comptée (une fois par session).
  void _countView() => ref.read(testimonyViewTrackerProvider.notifier).record(widget.testimony.id);

  /// Toucher de l'affiche (données mobiles) : chargement puis lecture.
  void _playFromPoster() {
    _userStarted = true;
    setState(() => _awaitingTap = false);
    _initVideo();
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
          else if (_awaitingTap)
            VideoPoster(
              thumbnailUrl: widget.testimony.thumbnailUrl,
              durationSeconds: widget.testimony.durationSeconds,
              hint: context.l10n.shortsMobileDataTapToPlay,
              fit: BoxFit.contain,
              onPlay: _playFromPoster,
            )
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.67), Colors.transparent],
                ),
              ),
            ),
          ),
          // Bottom overlay (for info + actions)
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.87), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── 3. Bottom-left info ─────────────────────────────────────────
          Positioned(
            left: 16,
            right: 72, // leave room for the action column
            bottom: 24,
            child: _ShortInfo(
              testimony: widget.testimony,
              isOffline: OfflineMedia.isLocalPath(_currentUrl),
            ),
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
              style: TextStyle(
            fontFamily: AppFonts.family,
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
  const _ShortInfo({required this.testimony, this.isOffline = false});
  final VideoTestimony testimony;

  /// Lecture d'un fichier téléchargé.
  final bool isOffline;

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
                      style: TextStyle(
            fontFamily: AppFonts.family,
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
          style: TextStyle(
            fontFamily: AppFonts.family,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),

        // Catégorie (badge jaune) + « Hors ligne » si fichier téléchargé
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            CategoryBadge(category: testimony.category),
            if (isOffline) const OfflineBadge(),
          ],
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
    // Compteurs du serveur : la réaction de la personne y est déjà comptée (une seule fois).
    final state  = ref.watch(interactionProvider);
    final liked  = state.likedOf(testimony);
    final prayed = state.prayedOf(testimony);
    final saved  = ref.watch(savedIdsProvider).contains(testimony.id);

    final effectiveLikes   = state.likesOf(testimony);
    final effectivePrayers = state.prayersOf(testimony);

    // Actions réservées aux membres (mode invité : feuille « compte requis »).
    Future<void> guarded(String reason, void Function() action) async {
      if (await requireAccount(context, ref, reason: reason)) action();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Heart / Like ────────────────────────────────────────────────
        _ActionButton(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? AppColors.danger : Colors.white,
          label: _formatCount(effectiveLikes),
          onTap: () => guarded(
            context.l10n.homeReasonReact,
            () => ref.read(interactionProvider.notifier).toggleLike(testimony),
          ),
        ),
        const SizedBox(height: 20),

        // ── Prière ──────────────────────────────────────────────────────
        _ActionButton(
          icon: Icons.volunteer_activism_rounded,
          color: prayed ? AppColors.sun : Colors.white,
          label: _formatCount(effectivePrayers),
          onTap: () => guarded(
            context.l10n.homeReasonReact,
            () => prayForTestimony(context, ref, testimony),
          ),
        ),
        const SizedBox(height: 20),

        // ── Comments ────────────────────────────────────────────────────
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          color: Colors.white,
          label: _formatCount(testimony.stats.comments),
          onTap: () => guarded(
            context.l10n.authGuestReasonComment,
            () => _openComments(context),
          ),
        ),
        const SizedBox(height: 20),

        // ── Bookmark / Save ─────────────────────────────────────────────
        _ActionButton(
          icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: saved ? AppColors.secondary : Colors.white,
          label: saved ? context.l10n.shortsSaved : context.l10n.detailSave,
          onTap: () => guarded(
            context.l10n.authGuestReasonSaved,
            () => ref.read(interactionProvider.notifier).toggleSave(testimony.id),
          ),
        ),
        const SizedBox(height: 20),

        // ── Share ───────────────────────────────────────────────────────
        _ActionButton(
          icon: Icons.share_rounded,
          color: Colors.white,
          label: context.l10n.detailShare,
          onTap: () => SharePlus.instance.share(
            ShareParams(
              text: '${testimony.title}\n\n${testimony.shareLink}\n\n'
                  '${context.l10n.shortsSharedFromApp}',
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

  /// Envoi au serveur (POST /testimonies/{id}/comments) : affiché tout de suite,
  /// remplacé par la version du serveur. Les commentaires restaient avant sur le
  /// téléphone, invisibles des autres.
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    if (!await requireAccount(context, ref, reason: context.l10n.homeReasonReact)) return;
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      await ref.read(commentsProvider(widget.testimonyId).notifier).addComment(text);
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom = keyboard height; animates with keyboard
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final async = ref.watch(commentsProvider(widget.testimonyId));
    // Erreur réseau : liste vide plutôt qu'un indicateur sans fin.
    final List<CommentModel>? comments = async.hasError ? const [] : async.value;

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
                  context.l10n.detailComments,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Commentaires du serveur (« J'aime » compris).
          Expanded(
            child: comments == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : comments.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.detailFirstComment,
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
                    itemCount: comments.length,
                    itemBuilder: (_, i) =>
                        _CommentTile(comment: comments[i]),
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
                      hintText: context.l10n.detailAddComment,
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
  final CommentModel comment;

  @override
  Widget build(BuildContext context) {
    final author = comment.user?.displayName ?? context.l10n.commonAnonymous;
    final initials = author.isNotEmpty ? author[0].toUpperCase() : '?';
    final createdAt = DateTime.tryParse(comment.createdAt ?? '')?.toLocal() ?? DateTime.now();
    final diff = DateTime.now().difference(createdAt);
    final timeAgo = diff.inMinutes < 1
        ? context.l10n.timeJustNow
        : diff.inMinutes < 60
            ? context.l10n.shortsAgoMinutes(diff.inMinutes)
            : context.l10n.commentsAgoHoursShort(diff.inHours);

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
                colors: AppColors.blueGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: AppFonts.family,
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
                    Flexible(
                      child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    ),
                    const SizedBox(width: 6),
                    Text(timeAgo,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
                const SizedBox(height: 3),
                MentionText(
                  MentionCodec.encode(comment.text, comment.mentions),
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
                ),
                CommentLikeButton(
                  comment: CommentRef.testimony(comment.id),
                  initialCount: comment.likesCount,
                  initialLiked: comment.isLikedByMe,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


