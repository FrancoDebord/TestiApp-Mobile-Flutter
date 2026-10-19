import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../widgets/live_replay.dart' show LiveAfterwardsSection;
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../controllers/live_room_controller.dart';
import '../data/live_repository.dart';
import '../models/live_models.dart';
import '../widgets/live_stage_widgets.dart';
import '../widgets/live_viewers_sheet.dart';
import '../widgets/live_widgets.dart';
import '../widgets/live_youtube_view.dart';

/// Regarder un direct : vidéo, réactions et commentaires en temps réel.
class LiveViewerScreen extends ConsumerStatefulWidget {
  const LiveViewerScreen({required this.liveId, super.key});

  final String liveId;

  @override
  ConsumerState<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends ConsumerState<LiveViewerScreen> {
  LiveRoomController? _ctrl;

  /// Direct diffusé sur YouTube, à l'antenne (pas de LiveKit).
  LiveSession? _youtubeLive;
  String? _loadError;
  bool _showComments = true;

  /// Plein écran demandé (vidéo en fond, chat posé dessus) ; sinon vue « YouTube ».
  bool _fullscreen = false;

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        _fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
  }

  /// Invitation déjà présentée (la fenêtre ne s'ouvre qu'une fois par invitation).
  String? _shownInvitationId;

  /// Invitation reçue → fenêtre « C'est votre tour » ; messages ponctuels → bandeau.
  void _onControllerChange() {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    final notice = ctrl.takeStageNotice();
    final invitation = ctrl.pendingInvitation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (notice != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(notice)),
        );
      }
      if (invitation != null && invitation.id != _shownInvitationId) {
        _shownInvitationId = invitation.id;
        unawaited(HapticFeedback.mediumImpact());
        unawaited(
          showLiveStageInvitation(context, ctrl: ctrl, invitation: invitation),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    unawaited(_open());
  }

  Future<void> _open() async {
    setState(() => _loadError = null);
    final repo = ref.read(liveRepositoryProvider);
    try {
      final live = await repo.show(widget.liveId);
      if (!mounted) return;
      if (live.isYoutube && live.status != LiveStatus.ended) {
        setState(() => _youtubeLive = live);
        return;
      }
      if (_youtubeLive != null) setState(() => _youtubeLive = null);
      _ctrl?.removeListener(_onControllerChange);
      _ctrl?.dispose(); // « Réessayer » : fermer l'ancienne connexion
      final ctrl = LiveRoomController(
        repository: repo,
        live: live,
        isHostMode: false,
        currentUserId: ref.read(currentUserProvider)?.id,
      )..addListener(_onControllerChange);
      setState(() => _ctrl = ctrl);
      if (live.status == LiveStatus.ended) return; // écran de fin direct
      await ctrl.joinAsViewer();
    } on LiveFailure catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    if (_fullscreen) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    _ctrl?.removeListener(_onControllerChange);
    _ctrl?.dispose();
    super.dispose();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: _youtubeLive != null
            ? LiveYoutubeView(
                live: _youtubeLive!,
                onClose: _close,
                // Fin du direct : écran de fin (bilan, rediffusion YouTube).
                onEnded: () => unawaited(_open()),
              )
            : ctrl == null
            ? _Loading(error: _loadError, onRetry: _open, onClose: _close)
            : ListenableBuilder(
                listenable: ctrl,
                builder: (context, _) => _buildRoom(context, ctrl),
              ),
      ),
    );
  }

  Widget _buildRoom(BuildContext context, LiveRoomController ctrl) {
    final live = ctrl.live;

    if (ctrl.ended || live.status == LiveStatus.ended) {
      return LiveEndedView(
        title: live.title,
        host: live.host,
        reason: liveEndReasonLabel(ctrl.endReason ?? live.endReason),
        peakViewers: ctrl.peakViewers > 0 ? ctrl.peakViewers : live.peakViewers,
        duration: live.duration,
        commentCount: live.commentCount > ctrl.comments.length
            ? live.commentCount
            : ctrl.comments.length,
        reactions: ctrl.reactions.total >= live.reactions.total
            ? ctrl.reactions
            : live.reactions,
        onClose: _close,
        footer: LiveAfterwardsSection(liveId: live.id, title: live.title, youtubeId: live.isYoutube ? live.youtubeId : null),
      );
    }

    final canInteract = !ctrl.banned;
    // Les modérateurs peuvent écrire même si le public ne le peut pas.
    final commentsOpen =
        (live.commentsEnabled || live.canModerate) && canInteract;

    // Téléphone en paysage : toujours le plein écran (comme YouTube).
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return _fullscreen || landscape
        ? _buildFullscreen(context, ctrl, canInteract, commentsOpen)
        : _buildDocked(context, ctrl, canInteract, commentsOpen);
  }

  // ── Éléments communs aux deux dispositions ─────────────────────────────────

  Widget _topBar(LiveRoomController ctrl) => _TopBar(
    live: ctrl.live,
    viewers: ctrl.viewers,
    onClose: _close,
    fullscreen: _fullscreen,
    onToggleFullscreen: _toggleFullscreen,
    // Modération : « Quitter » (le direct continue) et « Couper le
    // direct » sont deux actions distinctes, dans un menu à part.
    onModerate: ctrl.live.canModerate ? () => _moderatorMenu(ctrl) : null,
  );

  Widget? _pinned(LiveRoomController ctrl) => ctrl.pinnedComment == null
      ? null
      : LivePinnedBanner(
          comment: ctrl.pinnedComment!,
          hostId: ctrl.live.host.id,
          // Le message épinglé du diffuseur ne se retire que par lui.
          onUnpin: ctrl.canChangePin
              ? () => unpinWithFeedback(context, ctrl)
              : null,
        );

  Widget _comments(LiveRoomController ctrl, {required bool fadeTop}) =>
      LiveCommentsList(
        comments: ctrl.comments,
        hostId: ctrl.live.host.id,
        pinnedId: ctrl.pinnedComment?.id,
        fadeTop: fadeTop,
        onModerate: ctrl.live.canModerate
            ? (c) => showCommentModerationSheet(
                context,
                comment: c,
                controller: ctrl,
              )
            : null,
      );

  Widget? _stageButton(LiveRoomController ctrl, bool canInteract) =>
      ctrl.live.isOnAir && (canInteract || ctrl.live.canModerate)
      ? LiveStageButton(
          ctrl: ctrl,
          labeled: true,
          onPressed: () => showLiveStageSheet(
            context,
            ctrl: ctrl,
            loggedIn: ref.read(currentUserProvider) != null,
            onLogin: () => context.push('/login'),
          ),
        )
      : null;

  Widget _input(LiveRoomController ctrl, bool commentsOpen) => LiveCommentInput(
    enabled: commentsOpen,
    showPinOption: ctrl.canChangePin,
    disabledHint: ctrl.banned
        ? context.l10n.liveCannotComment
        : context.l10n.liveCommentsDisabled,
    onSend: ctrl.sendComment,
  );

  Widget _reactions(
    LiveRoomController ctrl,
    bool canInteract,
    Axis direction,
  ) => LiveReactionButtons(
    counts: ctrl.reactions,
    enabled: canInteract,
    direction: direction,
    onReact: (t) async {
      final err = await ctrl.react(t);
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(err)),
        );
      }
    },
  );

  // ── Vue « YouTube » : vidéo 16:9 en haut, panneau « Chat en direct » dessous ──

  Widget _buildDocked(
    BuildContext context,
    LiveRoomController ctrl,
    bool canInteract,
    bool commentsOpen,
  ) {
    // Le Scaffold retire le clavier de MediaQuery : on le lit sur la vue.
    final keyboardOpen = View.of(context).viewInsets.bottom > 0;
    final live = ctrl.live;
    final pinned = ctrl.pinnedComment;
    final showStage = live.isOnAir && (canInteract || live.canModerate);
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, box) {
          // Carte d'accueil seulement s'il y a la place (pas sur un petit écran).
          final showWelcome = !keyboardOpen && box.maxHeight >= 640;
          // Vidéo en 16:9, réduite si le chat n'a plus la place (clavier, petit écran).
          final videoHeight = math.max(
            0.0,
            math.min(
              box.maxWidth * 9 / 16,
              box.maxHeight - (keyboardOpen ? 150 : (showWelcome ? 350 : 260)),
            ),
          );
          return Column(
            children: [
              SizedBox(
                height: videoHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _VideoArea(
                      ctrl: ctrl,
                      onRetry: _open,
                      fit: lk.VideoViewFit.contain,
                    ),
                    const _TopScrim(),
                    FloatingReactionsLayer(reactions: ctrl.floatingReactions),
                    Align(
                      alignment: Alignment.topCenter,
                      child: _VideoOverlayBar(
                        live: live,
                        viewers: ctrl.viewers,
                        onClose: _close,
                        onFullscreen: _toggleFullscreen,
                        onModerate: live.canModerate
                            ? () => _moderatorMenu(ctrl)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              LiveConnectionBanner(link: ctrl.link),
              if (!_showComments)
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton.icon(
                        key: const ValueKey('live-show-chat'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        onPressed: () => setState(() => _showComments = true),
                        icon: const Icon(Icons.forum_outlined),
                        label: Text(context.l10n.liveChatShow),
                      ),
                    ),
                  ),
                )
              else
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Clavier ouvert : seuls les messages et la saisie restent.
                        if (!keyboardOpen) ...[
                          // Poignée, comme une feuille posée sous la vidéo.
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          LiveChatHeader(
                            subtitle: live.title.isEmpty ? live.host.displayName : live.title,
                            count: ctrl.viewers,
                            onClose: () => setState(() => _showComments = false),
                            trailing: showStage
                                ? LiveStageButton(
                                    ctrl: ctrl,
                                    labeled: true,
                                    light: true,
                                    onPressed: () => showLiveStageSheet(
                                      context,
                                      ctrl: ctrl,
                                      loggedIn:
                                          ref.read(currentUserProvider) != null,
                                      onLogin: () => context.push('/login'),
                                    ),
                                  )
                                : null,
                          ),
                          const Divider(height: 1, color: AppColors.border),
                        ],
                        if (pinned != null)
                          LivePinnedBanner(
                            comment: pinned,
                            hostId: live.host.id,
                            light: true,
                            onUnpin: ctrl.canChangePin
                                ? () => unpinWithFeedback(context, ctrl)
                                : null,
                          ),
                        // Messages : les nouveaux arrivent en bas et poussent les
                        // anciens vers le haut ; la liste se fait défiler.
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: ctrl.comments.isEmpty
                                      ? const _EmptyChat()
                                      : LiveCommentsList(
                                          comments: ctrl.comments,
                                          hostId: live.host.id,
                                          pinnedId: pinned?.id,
                                          fadeTop: false,
                                          light: true,
                                          onModerate: live.canModerate
                                              ? (c) =>
                                                    showCommentModerationSheet(
                                                      context,
                                                      comment: c,
                                                      controller: ctrl,
                                                    )
                                              : null,
                                        ),
                                ),
                              ),
                              Positioned(
                                right: 12,
                                top: 8,
                                child: LiveStagePip(ctrl: ctrl),
                              ),
                              if (!keyboardOpen)
                                Positioned(
                                  right: 12,
                                  bottom: 8,
                                  child: _ReactionFab(
                                    enabled: canInteract,
                                    onReact: (t) => _react(ctrl, t),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        LiveStageSelfBar(ctrl: ctrl),
                        // Accueil (bienveillance, vie privée), comme sur YouTube.
                        if (showWelcome) const LiveChatWelcome(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: LiveCommentInput(
                            light: true,
                            hint: context.l10n.liveChatHint,
                            enabled: commentsOpen,
                            showPinOption: ctrl.canChangePin,
                            disabledHint: ctrl.banned
                                ? context.l10n.liveCannotComment
                                : context.l10n.liveCommentsDisabled,
                            onSend: ctrl.sendComment,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _react(LiveRoomController ctrl, LiveReactionType t) async {
    final err = await ctrl.react(t);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(err)),
      );
    }
  }

  // ── Plein écran : vidéo en fond, chat posé dessus ──────────────────────────

  Widget _buildFullscreen(
    BuildContext context,
    LiveRoomController ctrl,
    bool canInteract,
    bool commentsOpen,
  ) {
    final pinned = _pinned(ctrl);
    final stage = _stageButton(ctrl, canInteract);
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Vidéo ───────────────────────────────────────────────────────
        _VideoArea(ctrl: ctrl, onRetry: _open),

        // Dégradés pour la lisibilité des textes posés sur la vidéo.
        const _Scrims(),

        FloatingReactionsLayer(reactions: ctrl.floatingReactions),

        // Intervenant à l'antenne : médaillon en haut à droite, sous la barre du haut.
        Positioned(
          right: 12,
          top:
              MediaQuery.paddingOf(context).top +
              (ctrl.pinnedComment != null ? 140 : 72),
          child: LiveStagePip(ctrl: ctrl),
        ),

        SafeArea(
          child: Column(
            children: [
              LiveConnectionBanner(link: ctrl.link),
              _topBar(ctrl),
              ?pinned,
              const Spacer(),
              LiveStageSelfBar(ctrl: ctrl),
              // La zone du bas rétrécit (clavier ouvert, petit écran) au lieu
              // de faire déborder la colonne.
              Flexible(
                flex: 8,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_showComments)
                              Flexible(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight:
                                        MediaQuery.sizeOf(context).height *
                                        0.40,
                                  ),
                                  child: _comments(ctrl, fadeTop: true),
                                ),
                              ),
                            const SizedBox(height: 8),
                            // Intervenir (spectateur) / file (modération) + commentaires.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (stage != null)
                                  Flexible(child: stage)
                                else
                                  const SizedBox.shrink(),
                                IconButton(
                                  tooltip: _showComments
                                      ? context.l10n.liveHideComments
                                      : context.l10n.liveShowComments,
                                  onPressed: () => setState(
                                    () => _showComments = !_showComments,
                                  ),
                                  icon: Icon(
                                    _showComments
                                        ? Icons.chat_bubble_rounded
                                        : Icons.chat_bubble_outline_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _input(ctrl, commentsOpen),
                          ],
                        ),
                      ),
                      // Clavier ouvert : la colonne de réactions laisse la
                      // place à la saisie.
                      if (View.of(context).viewInsets.bottom == 0)
                        _reactions(ctrl, canInteract, Axis.vertical),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Menu de modération : quitter simplement (le direct continue) ou couper
  /// le direct pour tout le monde (avec confirmation).
  Future<void> _moderatorMenu(LiveRoomController ctrl) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                context.l10n.liveModerationTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(context.l10n.liveModerationSubtitle),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: Text(context.l10n.liveLeaveLive),
              subtitle: Text(context.l10n.liveContinuesForOthers),
              onTap: () => Navigator.pop(context, 'leave'),
            ),
            // Couper le direct : administrateurs seulement (jamais un modérateur).
            if (ctrl.live.canEnd)
              ListTile(
                leading: const Icon(
                  Icons.stop_circle_outlined,
                  color: AppColors.danger,
                ),
                title: Text(
                  context.l10n.liveCutForAll,
                  style: const TextStyle(color: AppColors.danger),
                ),
                subtitle: Text(context.l10n.liveCutForAllHint),
                onTap: () => Navigator.pop(context, 'cut'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'leave') _close();
    if (choice == 'cut') await _cutLive(ctrl);
  }

  Future<void> _cutLive(LiveRoomController ctrl) async {
    if (!await confirmEndLive(context, asHost: false)) return;
    final err = await ctrl.endLive();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(err)),
      );
    }
  }
}

// ── Morceaux d'écran ─────────────────────────────────────────────────────────

class _VideoArea extends StatelessWidget {
  const _VideoArea({
    required this.ctrl,
    required this.onRetry,
    this.fit = lk.VideoViewFit.cover,
  });
  final LiveRoomController ctrl;
  final VoidCallback onRetry;
  final lk.VideoViewFit fit;

  @override
  Widget build(BuildContext context) {
    final track = ctrl.video;
    if (track != null) {
      return lk.VideoTrackRenderer(track, fit: fit, key: ValueKey(track.sid));
    }
    final waiting = ctrl.link == LiveLinkState.connecting
        ? context.l10n.liveConnectingToLive
        : ctrl.error ??
              (ctrl.live.isOnAir
                  ? context.l10n.liveWaitingHostImage
                  : context.l10n.liveStartingSoon);
    return Container(
      color: const Color(0xFF120A1F),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiveAvatar(person: ctrl.live.host, size: 84),
            const SizedBox(height: 18),
            if (ctrl.error == null)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white70,
                ),
              )
            else
              const Icon(Icons.error_outline_rounded, color: Colors.white70),
            const SizedBox(height: 14),
            Text(
              waiting,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
              ),
            ),
            if (ctrl.error != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barre discrète posée sur la vidéo : EN DIRECT, spectateurs, plein écran, fermer.
class _VideoOverlayBar extends StatelessWidget {
  const _VideoOverlayBar({
    required this.live,
    required this.viewers,
    required this.onClose,
    required this.onFullscreen,
    this.onModerate,
  });

  final LiveSession live;
  final int viewers;
  final VoidCallback onClose;
  final VoidCallback onFullscreen;
  final VoidCallback? onModerate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 2, 0),
      child: Row(
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (live.isOnAir) const LiveBadge(),
                  const SizedBox(width: 6),
                  LiveViewersChip(liveId: live.id, viewers: viewers),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (onModerate != null)
            IconButton(
              tooltip: context.l10n.liveModeration,
              visualDensity: VisualDensity.compact,
              onPressed: onModerate,
              icon: const Icon(Icons.shield_outlined, color: Colors.white),
            ),
          IconButton(
            tooltip: context.l10n.liveFullscreen,
            visualDensity: VisualDensity.compact,
            onPressed: onFullscreen,
            icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: context.l10n.liveLeaveLive,
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ReactionFab extends StatefulWidget {
  const _ReactionFab({required this.enabled, required this.onReact});

  final bool enabled;
  final void Function(LiveReactionType type) onReact;

  @override
  State<_ReactionFab> createState() => _ReactionFabState();
}

class _ReactionFabState extends State<_ReactionFab> {
  bool _open = false;
  Timer? _timer;

  void _arm() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _open = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _bubble(
    String emoji, {
    required double size,
    required VoidCallback? onTap,
    String? label,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Text(emoji, style: TextStyle(fontSize: size * 0.45)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_open)
            for (final t in LiveReactionType.values.skip(1))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _bubble(
                  t.emoji,
                  size: 42,
                  label: t.label,
                  onTap: () {
                    widget.onReact(t);
                    _arm();
                  },
                ),
              ),
          Tooltip(
            message: context.l10n.liveReact,
            child: _bubble(
              LiveReactionType.like.emoji,
              size: 52,
              label: LiveReactionType.like.label,
              onTap: widget.enabled
                  ? () {
                      widget.onReact(LiveReactionType.like);
                      setState(() => _open = true);
                      _arm();
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dégradé sous la barre du haut posée sur la vidéo 16:9.
class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: FractionallySizedBox(
          heightFactor: 0.45,
          widthFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xAA000000), Colors.transparent],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.l10n.liveChatEmpty,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 13,
        ),
      ),
    );
  }
}

class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // Hauteurs bornées par la place disponible (clavier ouvert, petit écran).
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          return Column(
            children: [
              Container(
                height: math.min(160, h * 0.25),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xAA000000), Colors.transparent],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                height: math.min(320, h * 0.6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.live,
    required this.viewers,
    required this.onClose,
    required this.fullscreen,
    required this.onToggleFullscreen,
    this.onModerate,
  });

  final LiveSession live;
  final int viewers;
  final VoidCallback onClose;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;

  /// Modérateurs : menu (quitter / couper le direct).
  final VoidCallback? onModerate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          LiveAvatar(person: live.host, size: 38),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  live.host.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  live.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Badge + spectateurs : réduits plutôt que de déborder (texte agrandi).
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (live.isOnAir) const LiveBadge(),
                  const SizedBox(width: 6),
                  LiveViewersChip(liveId: live.id, viewers: viewers),
                ],
              ),
            ),
          ),
          if (onModerate != null)
            IconButton(
              tooltip: context.l10n.liveModeration,
              onPressed: onModerate,
              icon: const Icon(Icons.shield_outlined, color: Colors.white),
            ),
          IconButton(
            tooltip: fullscreen ? context.l10n.liveExitFullscreen : context.l10n.liveFullscreen,
            onPressed: onToggleFullscreen,
            icon: Icon(
              fullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              color: Colors.white,
            ),
          ),
          IconButton(
            tooltip: context.l10n.liveLeaveLive,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.onRetry, required this.onClose, this.error});

  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: error == null
                  ? const CircularProgressIndicator(color: Colors.white70)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.live_tv_rounded,
                          color: Colors.white54,
                          size: 52,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton(
                          onPressed: onRetry,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          child: Text(context.l10n.commonRetry),
                        ),
                      ],
                    ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
