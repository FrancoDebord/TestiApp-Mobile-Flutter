// Direct diffusé sur YouTube (source youtube) : la vidéo YouTube en haut, la
// discussion du direct dessous (comme le direct YouTube d'un événement).
// Pas de LiveKit : discussion lue toutes les 8 s, « je regarde » toutes les 30 s.
// Backend : docs/fonctionnalites/lives.md (source youtube, POST lives/{id}/heartbeat)

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/guest_gate.dart' show requireAccount;
import '../../../shared/widgets/youtube_video_player.dart';
import '../data/live_repository.dart';
import '../models/live_models.dart';
import 'live_widgets.dart';

/// Identifiant anonyme de cet appareil pour le compte des spectateurs.
final String _viewerId = List.generate(
  24,
  (_) => '0123456789abcdef'[math.Random.secure().nextInt(16)],
).join();

class LiveYoutubeView extends ConsumerStatefulWidget {
  const LiveYoutubeView({
    required this.live,
    required this.onClose,
    required this.onEnded,
    this.playerBuilder,
    super.key,
  });

  final LiveSession live;
  final VoidCallback onClose;

  /// Le direct vient de se terminer (par le diffuseur ou la modération).
  final VoidCallback onEnded;

  /// Tests : remplace le lecteur YouTube (WebView indisponible).
  @visibleForTesting
  final Widget Function(String videoId)? playerBuilder;

  @override
  ConsumerState<LiveYoutubeView> createState() => _LiveYoutubeViewState();
}

class _LiveYoutubeViewState extends ConsumerState<LiveYoutubeView> {
  final _comments = <LiveComment>[];
  LiveComment? _pinned;
  int? _viewers;
  bool _fullscreen = false;
  bool _chatVisible = true;
  bool _ended = false;
  Timer? _commentsTimer;
  Timer? _beatTimer;

  LiveSession get _live => widget.live;
  LiveRepository get _repo => ref.read(liveRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _pinned = _live.pinnedComment;
    _viewers = _live.liveStats?.viewers;
    unawaited(_loadComments());
    unawaited(_beat());
    _commentsTimer = Timer.periodic(const Duration(seconds: 8), (_) => _loadComments());
    _beatTimer = Timer.periodic(const Duration(seconds: 30), (_) => _beat());
  }

  @override
  void dispose() {
    _commentsTimer?.cancel();
    _beatTimer?.cancel();
    if (_fullscreen) _restoreSystemUi();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final list = await _repo.comments(_live.id);
      if (!mounted) return;
      setState(() => _comments
        ..clear()
        ..addAll(list));
    } catch (_) {}
  }

  Future<void> _beat() async {
    try {
      final s = await _repo.heartbeat(_live.id, viewerId: _viewerId);
      if (!mounted) return;
      setState(() {
        _viewers = s.viewers;
        _pinned = s.pinnedComment;
      });
      if (s.status == LiveStatus.ended) _markEnded();
    } catch (_) {}
  }

  void _markEnded() {
    if (_ended) return;
    _ended = true;
    if (_fullscreen) _toggleFullscreen();
    widget.onEnded();
  }

  void _restoreSystemUi() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]));
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
      unawaited(SystemChrome.setPreferredOrientations(
          const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]));
    } else {
      _restoreSystemUi();
    }
  }

  void _snack(String text) => ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));

  Future<void> _end() async {
    final l10n = context.l10n;
    final host = _live.isHost;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(host ? l10n.liveEndConfirmTitle : l10n.liveCutConfirmTitle),
        content: Text(host ? l10n.liveEndConfirmBody : l10n.liveCutConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(
            key: const ValueKey('youtube-live-end-confirm'),
            style: FilledButton.styleFrom(backgroundColor: kLiveRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(host ? l10n.liveEndAction : l10n.liveCutAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.end(_live.id);
      _markEnded();
    } on LiveFailure catch (e) {
      _snack(e.message);
    }
  }

  Future<String?> _send(String text) async {
    final l10n = context.l10n;
    if (!await requireAccount(context, ref, reason: l10n.liveChatLoginRequired)) {
      return l10n.liveChatLoginRequired;
    }
    try {
      final c = await _repo.postComment(_live.id, text);
      if (mounted && !_comments.any((x) => x.id == c.id)) setState(() => _comments.add(c));
      return null;
    } on LiveFailure catch (e) {
      return e.message;
    }
  }

  Future<void> _like() async {
    if (!await requireAccount(context, ref, reason: context.l10n.liveChatLoginRequired)) return;
    unawaited(HapticFeedback.lightImpact());
    try {
      await _repo.react(_live.id, LiveReactionType.like);
    } on LiveFailure catch (e) {
      _snack(e.message);
    }
  }

  /// Modération d'un message : épingler, masquer, exclure l'auteur.
  Future<void> _moderate(LiveComment c) async {
    final l10n = context.l10n;
    final isPinned = _pinned?.id == c.id;
    final isHostComment = c.user.id == _live.host.id;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(isPinned ? l10n.liveUnpin : l10n.livePinTop),
              onTap: () => Navigator.pop(ctx, isPinned ? 'unpin' : 'pin'),
            ),
            if (!isHostComment || _live.isHost)
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: Text(l10n.liveHideComment),
                onTap: () => Navigator.pop(ctx, 'hide'),
              ),
            if (!isHostComment)
              ListTile(
                leading: const Icon(Icons.block_rounded, color: AppColors.danger),
                title: Text(l10n.liveBan, style: const TextStyle(color: AppColors.danger)),
                subtitle: Text(l10n.liveBanHint),
                onTap: () => Navigator.pop(ctx, 'ban'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      switch (action) {
        case 'pin':
          final p = await _repo.pinComment(_live.id, c.id);
          if (mounted) setState(() => _pinned = p);
        case 'unpin':
          await _repo.unpinComment(_live.id);
          if (mounted) setState(() => _pinned = null);
        case 'hide':
          await _repo.hideComment(_live.id, c.id);
          if (mounted) setState(() => _comments.removeWhere((x) => x.id == c.id));
        case 'ban':
          await _repo.ban(_live.id, c.user.id);
          if (mounted) setState(() => _comments.removeWhere((x) => x.user.id == c.user.id));
      }
    } on LiveFailure catch (e) {
      _snack(e.message);
    }
  }

  Widget _player() =>
      widget.playerBuilder?.call(_live.youtubeId!) ?? YouTubeVideoPlayer(videoId: _live.youtubeId!);

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreen) _toggleFullscreen();
      },
      child: (_fullscreen || landscape) ? _fullscreenLayout() : _dockedLayout(),
    );
  }

  Widget _fullscreenLayout() => Stack(
        children: [
          Center(child: _player()),
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: IconButton(
                tooltip: context.l10n.eventsLiveExitFullscreen,
                onPressed: _fullscreen ? _toggleFullscreen : widget.onClose,
                icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      );

  Widget _dockedLayout() {
    final l10n = context.l10n;
    final keyboardOpen = View.of(context).viewInsets.bottom > 0;
    final canWrite = _live.commentsEnabled || _live.canModerate;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barre au-dessus de la vidéo : retour, EN DIRECT, spectateurs, YouTube, plein écran, terminer.
          SizedBox(
            height: 44,
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.commonBack,
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LiveBadge(),
                        if (_viewers != null) ...[
                          const SizedBox(width: 6),
                          LiveChip(icon: Icons.visibility_rounded, label: '$_viewers'),
                        ],
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (_live.youtubeUrl != null)
                  IconButton(
                    tooltip: l10n.eventsOpenOnYoutube,
                    onPressed: () => launchUrl(Uri.parse(_live.youtubeUrl!), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                  ),
                IconButton(
                  tooltip: l10n.eventsLiveFullscreen,
                  onPressed: _toggleFullscreen,
                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                ),
                if (_live.canEnd || _live.canModerate)
                  IconButton(
                    key: const ValueKey('youtube-live-end'),
                    tooltip: _live.isHost ? l10n.liveEndAction : l10n.liveCutAction,
                    onPressed: _end,
                    icon: const Icon(Icons.stop_circle_rounded, color: kLiveRed),
                  ),
              ],
            ),
          ),
          if (!keyboardOpen) _player(),
          if (!_chatVisible)
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    onPressed: () => setState(() => _chatVisible = true),
                    icon: const Icon(Icons.forum_outlined),
                    label: Text(l10n.liveChatShow),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(builder: (context, box) {
                    // Carte de bienvenue seulement s'il reste de la place pour la discussion.
                    final ts = MediaQuery.textScalerOf(context).scale(100) / 100;
                    final showWelcome = !keyboardOpen && box.maxHeight >= 200 + 260 * ts;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!keyboardOpen) ...[
                          LiveChatHeader(
                            subtitle: _live.title,
                            count: _viewers,
                            onClose: () => setState(() => _chatVisible = false),
                          ),
                          const Divider(height: 1, color: AppColors.border),
                        ],
                        if (_pinned != null && !keyboardOpen)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: LivePinnedBanner(
                              comment: _pinned!,
                              hostId: _live.host.id,
                              light: true,
                              onUnpin: _live.canModerate
                                  ? () => _moderate(_pinned!)
                                  : null,
                            ),
                          ),
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _comments.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Text(l10n.liveReplayEmpty,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(color: AppColors.textSecondary)),
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: LiveCommentsList(
                                          comments: List.of(_comments),
                                          hostId: _live.host.id,
                                          pinnedId: _pinned?.id,
                                          fadeTop: false,
                                          light: true,
                                          onModerate: _live.canModerate ? _moderate : null,
                                        ),
                                      ),
                              ),
                              if (!keyboardOpen)
                                Positioned(
                                  right: 12,
                                  bottom: 8,
                                  child: Material(
                                    color: AppColors.surface,
                                    shape: const CircleBorder(),
                                    elevation: 4,
                                    child: IconButton(
                                      key: const ValueKey('youtube-live-like'),
                                      tooltip: LiveReactionType.like.label,
                                      onPressed: _like,
                                      icon: const Icon(Icons.favorite_rounded, color: Color(0xFFE11D48), size: 28),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (showWelcome) const LiveChatWelcome(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: LiveCommentInput(
                            light: true,
                            hint: l10n.liveChatHint,
                            enabled: canWrite,
                            disabledHint: l10n.eventsCommentsClosed,
                            onSend: (text, {bool pin = false}) => _send(text),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
