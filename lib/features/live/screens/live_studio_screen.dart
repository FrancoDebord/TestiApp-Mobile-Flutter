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

/// Paramètres d'ouverture du studio (passés en `extra` par go_router).
class LiveStudioArgs {
  const LiveStudioArgs({
    required LiveSession this.live,
    required LiveCredentials this.credentials,
    this.previewTrack,
    this.cameraPosition = lk.CameraPosition.front,
  }) : _liveId = null;

  /// Reprise d'un direct existant : le studio charge le direct et un
  /// nouveau jeton diffuseur.
  const LiveStudioArgs.resume(
    String liveId, {
    this.previewTrack,
    this.cameraPosition = lk.CameraPosition.front,
  })  : _liveId = liveId,
        live = null,
        credentials = null;

  final String? _liveId;
  final LiveSession? live;
  final LiveCredentials? credentials;
  final lk.LocalVideoTrack? previewTrack;
  final lk.CameraPosition cameraPosition;

  String get liveId => live?.id ?? _liveId!;
}

/// Studio du diffuseur : aperçu, passage à l'antenne, contrôles, commentaires.
class LiveStudioScreen extends ConsumerStatefulWidget {
  const LiveStudioScreen({required this.args, super.key});

  final LiveStudioArgs args;

  @override
  ConsumerState<LiveStudioScreen> createState() => _LiveStudioScreenState();
}

class _LiveStudioScreenState extends ConsumerState<LiveStudioScreen> {
  LiveRoomController? _ctrl;
  String? _error;
  Timer? _clock;

  /// Nouvelle demande d'intervention : bandeau d'information.
  void _onControllerChange() {
    final notice = _ctrl?.takeStageNotice();
    if (notice == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(notice)));
    });
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    // Chronomètre affiché : simple rafraîchissement chaque seconde.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_ctrl?.live.isOnAir ?? false)) setState(() {});
    });
    unawaited(_open());
  }

  Future<void> _open() async {
    setState(() => _error = null);
    final repo = ref.read(liveRepositoryProvider);
    try {
      final args = widget.args;
      final live = args.live ?? await repo.show(args.liveId);
      final creds = args.credentials ?? await repo.hostToken(args.liveId);
      if (!mounted) return;
      _ctrl?.removeListener(_onControllerChange);
      _ctrl?.dispose(); // « Réessayer » : fermer l'ancienne connexion
      final ctrl = LiveRoomController(
        repository: repo,
        live: live,
        isHostMode: true,
        currentUserId: ref.read(currentUserProvider)?.id,
      )..addListener(_onControllerChange);
      setState(() => _ctrl = ctrl);
      await ctrl.connectAsHost(
        creds,
        previewTrack: args.previewTrack,
        cameraPosition: args.cameraPosition,
      );
    } on LiveFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    WakelockPlus.disable();
    _ctrl?.removeListener(_onControllerChange);
    _ctrl?.dispose();
    // Aperçu confié par l'écran de préparation : libérer la caméra même si
    // le studio a échoué avant de le publier (sans effet s'il est déjà arrêté).
    unawaited(widget.args.previewTrack?.stop());
    super.dispose();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/home');

  Future<void> _goLive(LiveRoomController ctrl) async {
    final err = await ctrl.goLive();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: err == null ? kLiveRed : AppColors.danger,
      content: Text(err ?? 'Vous êtes en direct !'),
    ));
  }

  Future<void> _end(LiveRoomController ctrl) async {
    if (!await confirmEndLive(context, asHost: true)) return;
    final err = await ctrl.endLive();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(err)));
    }
  }

  /// Retour : terminer, ou quitter en gardant la possibilité de reprendre.
  Future<void> _onBack(LiveRoomController? ctrl) async {
    if (ctrl == null || ctrl.ended) {
      _close();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le studio ?'),
        content: Text(ctrl.live.isOnAir
            ? 'Vous êtes en direct. Vous pouvez le terminer, ou quitter et revenir '
                'dans les 5 minutes pour le reprendre (sinon il sera clôturé).'
            : 'Le direct n\'a pas commencé. Vous pouvez y revenir depuis la liste des directs.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Rester')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'leave'),
              child: const Text('Quitter')),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'end'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'end') {
      await ctrl.endLive();
    } else if (choice == 'leave') {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack(ctrl));
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: ctrl == null
              ? _StudioLoading(error: _error, onRetry: _open, onClose: _close)
              : ListenableBuilder(
                  listenable: ctrl,
                  builder: (context, _) => _buildStudio(context, ctrl),
                ),
        ),
      ),
    );
  }

  Widget _buildStudio(BuildContext context, LiveRoomController ctrl) {
    final live = ctrl.live;

    if (ctrl.ended) {
      return LiveEndedView(
        title: live.title,
        reason: liveEndReasonLabel(ctrl.endReason ?? live.endReason ?? 'host'),
        peakViewers: ctrl.peakViewers,
        duration: live.duration,
        onClose: _close,
      );
    }

    final connected = ctrl.link == LiveLinkState.connected ||
        ctrl.link == LiveLinkState.reconnecting;
    final track = ctrl.video;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Retour caméra ───────────────────────────────────────────────
        if (track != null && ctrl.cameraEnabled)
          lk.VideoTrackRenderer(
            track,
            fit: lk.VideoViewFit.cover,
            mirrorMode: ctrl.cameraPosition == lk.CameraPosition.front
                ? lk.VideoViewMirrorMode.mirror
                : lk.VideoViewMirrorMode.off,
          )
        else
          Container(
            color: const Color(0xFF120A1F),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ctrl.cameraEnabled
                      ? Icons.videocam_outlined
                      : Icons.videocam_off_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
                const SizedBox(height: 10),
                Text(
                  ctrl.error ??
                      (ctrl.cameraEnabled
                          ? 'Ouverture de la caméra…'
                          : 'Caméra coupée : les spectateurs ne vous voient plus'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70, fontFamily: 'Plus Jakarta Sans'),
                ),
                if (ctrl.error != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _open,
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Réessayer'),
                  ),
                ],
              ],
            ),
          ),

        const _StudioScrims(),
        FloatingReactionsLayer(reactions: ctrl.floatingReactions),

        // Intervenant à l'antenne (le diffuseur le voit et l'entend).
        Positioned(
          right: 12,
          top: MediaQuery.paddingOf(context).top + (ctrl.pinnedComment != null ? 140 : 72),
          child: LiveStagePip(ctrl: ctrl),
        ),

        SafeArea(
          child: Column(
            children: [
              LiveConnectionBanner(link: ctrl.link),
              _StudioTopBar(
                ctrl: ctrl,
                onClose: () => _onBack(ctrl),
              ),
              if (ctrl.pinnedComment != null)
                LivePinnedBanner(
                  comment: ctrl.pinnedComment!,
                  hostId: live.host.id,
                  onUnpin: () => unpinWithFeedback(context, ctrl),
                ),
              const Spacer(),

              // ── Commentaires (modérables, épinglables) ─────────────────
              // Toujours visibles : même commentaires fermés au public, les
              // messages du diffuseur y apparaissent.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.34,
                  child: LiveCommentsList(
                    comments: ctrl.comments,
                    hostId: live.host.id,
                    pinnedId: ctrl.pinnedComment?.id,
                    onModerate: (c) => showCommentModerationSheet(context,
                        comment: c, controller: ctrl),
                  ),
                ),
              ),

              // ── Message du diffuseur (📌 pour l'épingler à l'envoi) ─────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: LiveCommentInput(
                  enabled: connected,
                  showPinOption: true,
                  hint: live.commentsEnabled
                      ? 'Écrire aux spectateurs…'
                      : 'Écrire aux spectateurs (commentaires fermés au public)…',
                  disabledHint: 'Connexion au direct…',
                  onSend: ctrl.sendComment,
                ),
              ),

              // ── Réactions reçues ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final t in LiveReactionType.values)
                      Tooltip(
                        message: t.label,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(110),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${t.emoji} ${ctrl.reactions[t]}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Contrôles ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    _RoundControl(
                      icon: ctrl.micEnabled
                          ? Icons.mic_rounded
                          : Icons.mic_off_rounded,
                      tooltip: ctrl.micEnabled ? 'Couper le micro' : 'Rétablir le micro',
                      active: ctrl.micEnabled,
                      onTap: connected ? ctrl.toggleMic : null,
                    ),
                    const SizedBox(width: 10),
                    _RoundControl(
                      icon: ctrl.cameraEnabled
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded,
                      tooltip: ctrl.cameraEnabled ? 'Couper la caméra' : 'Rétablir la caméra',
                      active: ctrl.cameraEnabled,
                      onTap: connected ? ctrl.toggleCamera : null,
                    ),
                    const SizedBox(width: 10),
                    _RoundControl(
                      icon: Icons.cameraswitch_rounded,
                      tooltip: 'Changer de caméra',
                      active: true,
                      onTap: connected && ctrl.cameraEnabled
                          ? ctrl.switchCamera
                          : null,
                    ),
                    // File des intervenants (une personne à l'antenne à la fois).
                    if (live.isOnAir) ...[
                      const SizedBox(width: 6),
                      LiveStageButton(
                        ctrl: ctrl,
                        onPressed: () => showLiveStageSheet(context, ctrl: ctrl, loggedIn: true),
                      ),
                    ],
                    const SizedBox(width: 12),
                    Expanded(
                      child: live.isOnAir
                          ? FilledButton.icon(
                              onPressed: () => _end(ctrl),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                minimumSize: const Size.fromHeight(50),
                              ),
                              icon: const Icon(Icons.stop_rounded),
                              label: const Text('Terminer'),
                            )
                          : FilledButton.icon(
                              onPressed: connected && !ctrl.goingLive && ctrl.video != null
                                  ? () => _goLive(ctrl)
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: kLiveRed,
                                minimumSize: const Size.fromHeight(50),
                              ),
                              icon: ctrl.goingLive
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.sensors_rounded),
                              label: Text(connected
                                  ? 'Passer à l\'antenne'
                                  : 'Connexion…'),
                            ),
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
}

// ── Morceaux d'écran ─────────────────────────────────────────────────────────

class _StudioTopBar extends StatelessWidget {
  const _StudioTopBar({required this.ctrl, required this.onClose});

  final LiveRoomController ctrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final live = ctrl.live;
    final (qIcon, qLabel) = switch (ctrl.connectionQuality) {
      lk.ConnectionQuality.excellent => (Icons.signal_cellular_alt_rounded, 'Excellent'),
      lk.ConnectionQuality.good => (Icons.signal_cellular_alt_2_bar_rounded, 'Bon'),
      lk.ConnectionQuality.poor => (Icons.signal_cellular_alt_1_bar_rounded, 'Faible'),
      lk.ConnectionQuality.lost => (Icons.signal_cellular_off_rounded, 'Perdu'),
      _ => (Icons.signal_cellular_alt_rounded, '…'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          live.isOnAir
              ? const LiveBadge()
              : const LiveBadge(label: 'EN PRÉPARATION', color: Color(0xFF475467)),
          const SizedBox(width: 6),
          if (live.isOnAir && live.duration != null)
            LiveChip(icon: Icons.timer_outlined, label: formatLiveDuration(live.duration!)),
          const SizedBox(width: 6),
          LiveViewersChip(liveId: live.id, viewers: ctrl.viewers),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Qualité du réseau : $qLabel',
            child: LiveChip(icon: qIcon, label: qLabel),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Quitter le studio',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.tooltip,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? Colors.white.withAlpha(40) : Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 50,
            height: 50,
            child: Icon(icon,
                color: onTap == null
                    ? Colors.white38
                    : (active ? Colors.white : AppColors.danger)),
          ),
        ),
      ),
    );
  }
}

class _StudioScrims extends StatelessWidget {
  const _StudioScrims();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: 140,
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
            height: 360,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xDD000000), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioLoading extends StatelessWidget {
  const _StudioLoading({required this.onRetry, required this.onClose, this.error});

  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: error == null
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white70),
                    SizedBox(height: 14),
                    Text('Ouverture du studio…',
                        style: TextStyle(color: Colors.white70, fontFamily: 'Plus Jakarta Sans')),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 44),
                    const SizedBox(height: 12),
                    Text(error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontFamily: 'Plus Jakarta Sans')),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: onClose,
                          child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: onRetry,
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
