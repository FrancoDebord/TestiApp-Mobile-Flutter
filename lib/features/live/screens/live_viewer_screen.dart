import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../controllers/live_room_controller.dart';
import '../data/live_repository.dart';
import '../models/live_models.dart';
import '../widgets/live_stage_widgets.dart';
import '../widgets/live_viewers_sheet.dart';
import '../widgets/live_widgets.dart';

/// Regarder un direct : vidéo, réactions et commentaires en temps réel.
class LiveViewerScreen extends ConsumerStatefulWidget {
  const LiveViewerScreen({required this.liveId, super.key});

  final String liveId;

  @override
  ConsumerState<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends ConsumerState<LiveViewerScreen> {
  LiveRoomController? _ctrl;
  String? _loadError;
  bool _showComments = true;

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
            SnackBar(behavior: SnackBarBehavior.floating, content: Text(notice)));
      }
      if (invitation != null && invitation.id != _shownInvitationId) {
        _shownInvitationId = invitation.id;
        unawaited(HapticFeedback.mediumImpact());
        unawaited(showLiveStageInvitation(context, ctrl: ctrl, invitation: invitation));
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
        body: ctrl == null
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
        reason: liveEndReasonLabel(ctrl.endReason ?? live.endReason),
        peakViewers: ctrl.peakViewers > 0 ? ctrl.peakViewers : live.peakViewers,
        duration: live.duration,
        onClose: _close,
      );
    }

    final canInteract = !ctrl.banned;
    // Les modérateurs peuvent écrire même si le public ne le peut pas.
    final commentsOpen =
        (live.commentsEnabled || live.canModerate) && canInteract;

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
          top: MediaQuery.paddingOf(context).top + (ctrl.pinnedComment != null ? 140 : 72),
          child: LiveStagePip(ctrl: ctrl),
        ),

        SafeArea(
          child: Column(
            children: [
              LiveConnectionBanner(link: ctrl.link),
              _TopBar(
                live: live,
                viewers: ctrl.viewers,
                onClose: _close,
                onEnd: live.canModerate ? () => _cutLive(ctrl) : null,
              ),
              if (ctrl.pinnedComment != null)
                LivePinnedBanner(
                  comment: ctrl.pinnedComment!,
                  hostId: live.host.id,
                  // Le message épinglé du diffuseur ne se retire que par lui.
                  onUnpin: ctrl.canChangePin
                      ? () => unpinWithFeedback(context, ctrl)
                      : null,
                ),
              const Spacer(),
              LiveStageSelfBar(ctrl: ctrl),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_showComments)
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.40,
                              child: LiveCommentsList(
                                comments: ctrl.comments,
                                hostId: live.host.id,
                                pinnedId: ctrl.pinnedComment?.id,
                                onModerate: live.canModerate
                                    ? (c) => showCommentModerationSheet(context,
                                        comment: c, controller: ctrl)
                                    : null,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: LiveCommentInput(
                                  enabled: commentsOpen,
                                  showPinOption: ctrl.canChangePin,
                                  disabledHint: ctrl.banned
                                      ? 'Vous ne pouvez plus commenter ce direct'
                                      : 'Commentaires désactivés',
                                  onSend: ctrl.sendComment,
                                ),
                              ),
                              // Témoigner (spectateur) ou gérer la file (modération).
                              if (live.isOnAir && (canInteract || live.canModerate))
                                LiveStageButton(
                                  ctrl: ctrl,
                                  onPressed: () => showLiveStageSheet(
                                    context,
                                    ctrl: ctrl,
                                    loggedIn: ref.read(currentUserProvider) != null,
                                    onLogin: () => context.push('/login'),
                                  ),
                                ),
                              IconButton(
                                tooltip: _showComments
                                    ? 'Masquer les commentaires'
                                    : 'Afficher les commentaires',
                                onPressed: () => setState(
                                    () => _showComments = !_showComments),
                                icon: Icon(
                                  _showComments
                                      ? Icons.chat_bubble_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    LiveReactionButtons(
                      counts: ctrl.reactions,
                      enabled: canInteract,
                      onReact: (t) async {
                        final err = await ctrl.react(t);
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text(err)));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _cutLive(LiveRoomController ctrl) async {
    if (!await confirmEndLive(context, asHost: false)) return;
    final err = await ctrl.endLive();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(err)));
    }
  }
}

// ── Morceaux d'écran ─────────────────────────────────────────────────────────

class _VideoArea extends StatelessWidget {
  const _VideoArea({required this.ctrl, required this.onRetry});
  final LiveRoomController ctrl;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final track = ctrl.video;
    if (track != null) {
      return lk.VideoTrackRenderer(
        track,
        fit: lk.VideoViewFit.cover,
        key: ValueKey(track.sid),
      );
    }
    final waiting = ctrl.link == LiveLinkState.connecting
        ? 'Connexion au direct…'
        : ctrl.error ??
            (ctrl.live.isOnAir
                ? 'En attente de l\'image du diffuseur…'
                : 'Le direct va bientôt commencer…');
    return Container(
      color: const Color(0xFF120A1F),
      alignment: Alignment.center,
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
                  strokeWidth: 2.4, color: Colors.white70),
            )
          else
            const Icon(Icons.error_outline_rounded, color: Colors.white70),
          const SizedBox(height: 14),
          Text(
            waiting,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70, fontFamily: 'Plus Jakarta Sans', fontSize: 14),
          ),
          if (ctrl.error != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 160,
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
            height: 320,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.live,
    required this.viewers,
    required this.onClose,
    this.onEnd,
  });

  final LiveSession live;
  final int viewers;
  final VoidCallback onClose;

  /// Modérateurs : couper le direct.
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          LiveAvatar(person: live.host, size: 38),
          const SizedBox(width: 10),
          Expanded(
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
          if (live.isOnAir) const LiveBadge(),
          const SizedBox(width: 6),
          LiveViewersChip(liveId: live.id, viewers: viewers),
          if (onEnd != null)
            IconButton(
              tooltip: 'Couper le direct',
              onPressed: onEnd,
              icon: const Icon(Icons.stop_circle_outlined,
                  color: AppColors.danger),
            ),
          IconButton(
            tooltip: 'Fermer',
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
                        const Icon(Icons.live_tv_rounded,
                            color: Colors.white54, size: 52),
                        const SizedBox(height: 14),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 14),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton(
                          onPressed: onRetry,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white),
                          child: const Text('Réessayer'),
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
