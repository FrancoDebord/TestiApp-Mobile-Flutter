// Intervenants d'un direct : médaillon, barre « à l'antenne », file d'attente,
// invitation. Une seule personne à l'antenne à la fois.
// Backend : docs/fonctionnalites/lives-intervenants.md

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../../core/theme/app_colors.dart';
import '../controllers/live_room_controller.dart';
import '../models/live_models.dart';
import 'live_widgets.dart';

void _snack(BuildContext context, String? message) {
  if (message == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)));
}

/// Lance une action de scène et affiche son erreur, ou [success].
/// Le ScaffoldMessenger est pris avant l'attente (la feuille peut s'être refermée).
Future<void> _act(BuildContext context, Future<String?> Function() action, [String? success]) async {
  final messenger = ScaffoldMessenger.of(context);
  final text = await action() ?? success;
  if (text != null) {
    messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }
}

// ── Médaillon ────────────────────────────────────────────────────────────────

/// Intervenant à l'antenne, dans un coin de la vidéo du diffuseur
/// (sa caméra, ou ses initiales s'il intervient au micro seulement).
class LiveStagePip extends StatelessWidget {
  const LiveStagePip({required this.ctrl, super.key});

  final LiveRoomController ctrl;

  @override
  Widget build(BuildContext context) {
    final speaker = ctrl.stage.onStage;
    if (!ctrl.onStage && speaker == null) return const SizedBox.shrink();

    final person = ctrl.onStage ? speaker?.user : speaker!.user;
    final name = ctrl.onStage ? 'Vous' : person?.displayName ?? 'Intervenant';
    final track = ctrl.guestVideo;
    final muted = ctrl.guestMicMuted;

    return Semantics(
      label: 'À l\'antenne : $name${muted ? ', micro coupé' : ''}',
      child: Container(
        width: 104,
        height: 138,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF2D3A42),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(210), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12)],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (track != null && !track.muted)
              lk.VideoTrackRenderer(
                track,
                key: ValueKey(track.sid),
                fit: lk.VideoViewFit.cover,
                mirrorMode: ctrl.onStage
                    ? lk.VideoViewMirrorMode.mirror
                    : lk.VideoViewMirrorMode.off,
              )
            else
              Center(
                child: person == null
                    ? const Icon(Icons.mic_rounded, color: Colors.white70, size: 34)
                    : LiveAvatar(person: person, size: 52),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: const Color(0xBF000000),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Icon(muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barre de l'intervenant (soi-même à l'antenne) ────────────────────────────

class LiveStageSelfBar extends StatelessWidget {
  const LiveStageSelfBar({required this.ctrl, super.key});

  final LiveRoomController ctrl;

  @override
  Widget build(BuildContext context) {
    if (!ctrl.onStage) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(170),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const LiveBadge(label: 'À L\'ANTENNE'),
          const Spacer(),
          IconButton(
            tooltip: ctrl.stageMicEnabled ? 'Couper mon micro' : 'Rétablir mon micro',
            onPressed: ctrl.toggleStageMic,
            icon: Icon(
              ctrl.stageMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
              color: ctrl.stageMicEnabled ? Colors.white : AppColors.danger,
            ),
          ),
          IconButton(
            tooltip: ctrl.stageCameraEnabled ? 'Couper ma caméra' : 'Activer ma caméra',
            onPressed: ctrl.toggleStageCamera,
            icon: Icon(
              ctrl.stageCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: ctrl.stageBusy
                ? null
                : () => _act(context, ctrl.leaveStage),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.call_end_rounded, size: 18),
            label: const Text('Terminer'),
          ),
        ],
      ),
    );
  }
}

// ── Bouton d'ouverture (spectateur / diffuseur) ──────────────────────────────

/// Bouton « Témoigner » (spectateur) ou « Intervenants » (diffuseur, modération),
/// avec le nombre de personnes en attente.
class LiveStageButton extends StatelessWidget {
  const LiveStageButton({required this.ctrl, required this.onPressed, super.key});

  final LiveRoomController ctrl;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final staff = ctrl.canModerate;
    final count = ctrl.stage.queueCount;
    final invited = ctrl.pendingInvitation != null;
    return Tooltip(
      message: staff ? 'Intervenants' : 'Témoigner en direct',
      child: Badge(
        isLabelVisible: (staff && count > 0) || invited,
        label: Text(invited ? '!' : '$count'),
        backgroundColor: kLiveRed,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            staff ? Icons.groups_rounded : Icons.front_hand_rounded,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Feuille : file d'attente (personnel) ou demande (spectateur) ─────────────

Future<void> showLiveStageSheet(
  BuildContext context, {
  required LiveRoomController ctrl,
  required bool loggedIn,
  VoidCallback? onLogin,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListenableBuilder(
          listenable: ctrl,
          builder: (context, _) => ctrl.canModerate
              ? _StaffPanel(ctrl: ctrl)
              : _ViewerPanel(ctrl: ctrl, loggedIn: loggedIn, onLogin: onLogin),
        ),
      ),
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.title, {this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 17)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _StaffPanel extends StatelessWidget {
  const _StaffPanel({required this.ctrl});
  final LiveRoomController ctrl;

  Future<void> _remove(BuildContext context, LiveSpeaker s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer l\'intervention ?'),
        content: Text('${s.user.displayName} quittera l\'antenne : son micro et sa caméra seront coupés pour tous.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _act(context, () => ctrl.removeSpeaker(s), 'Intervention terminée.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = ctrl.stage;
    final current = stage.current;
    final queue = stage.queue ?? const <LiveSpeaker>[];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetTitle(
            'Intervenants',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Demandes', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Switch(
                  value: stage.enabled,
                  onChanged: ctrl.stageBusy
                      ? null
                      : (v) => _act(context, () => ctrl.setStageEnabled(v),
                          v ? 'Demandes ouvertes.' : 'Demandes fermées. La file est conservée.'),
                ),
              ],
            ),
          ),
          if (current != null)
            ListTile(
              leading: LiveAvatar(person: current.user, size: 40),
              title: Text(current.user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([
                current.isOnStage
                    ? 'À l\'antenne · ${current.camera ? 'caméra' : 'micro seulement'}'
                    : 'Invité · en attente de sa réponse',
                if (current.message != null) '« ${current.message} »',
              ].join('\n')),
              isThreeLine: current.message != null,
              trailing: current.isOnStage
                  ? FilledButton(
                      onPressed: ctrl.stageBusy ? null : () => _remove(context, current),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                      child: const Text('Terminer'),
                    )
                  : TextButton(
                      onPressed: ctrl.stageBusy
                          ? null
                          : () => _act(context, () => ctrl.declineSpeaker(current), 'Invitation annulée.'),
                      child: const Text('Annuler'),
                    ),
            ),
          const Divider(height: 1),
          if (queue.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Personne n\'attend pour le moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: queue.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = queue[i];
                  return ListTile(
                    leading: LiveAvatar(person: s.user, size: 36),
                    title: Text('${s.position ?? i + 1}. ${s.user.displayName}'),
                    subtitle: s.message == null ? null : Text('« ${s.message} »'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Retirer de la file',
                          onPressed: ctrl.stageBusy
                              ? null
                              : () => _act(context, () => ctrl.declineSpeaker(s), 'Demande retirée de la file.'),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        FilledButton.tonal(
                          // Une personne à la fois : désactivé tant que quelqu'un est invité ou à l'antenne.
                          onPressed: ctrl.stageBusy || current != null
                              ? null
                              : () => _act(context, () => ctrl.inviteSpeaker(s),
                                  'Invitation envoyée : ${s.user.displayName} a ${stage.inviteTimeout} s pour accepter.'),
                          child: const Text('Inviter'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Une personne à la fois. L\'invitation expire après ${stage.inviteTimeout} s sans réponse.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerPanel extends StatefulWidget {
  const _ViewerPanel({required this.ctrl, required this.loggedIn, this.onLogin});
  final LiveRoomController ctrl;
  final bool loggedIn;
  final VoidCallback? onLogin;

  @override
  State<_ViewerPanel> createState() => _ViewerPanelState();
}

class _ViewerPanelState extends State<_ViewerPanel> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final stage = ctrl.stage;
    final mine = stage.mine;

    Widget body;
    if (!widget.loggedIn) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Connectez-vous pour demander à intervenir et partager votre témoignage en direct.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: widget.onLogin, child: const Text('Se connecter')),
        ],
      );
    } else if (ctrl.onStage || mine?.isOnStage == true) {
      body = const Text('Vous êtes à l\'antenne : tout le monde vous entend.');
    } else if (mine != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(mine.isInvited
              ? 'C\'est votre tour ! Le diffuseur vous invite à l\'antenne.'
              : 'Votre demande est enregistrée : vous êtes n°${mine.position ?? '?'} dans la file. '
                  'Gardez le direct ouvert, vous serez prévenu à votre tour.'),
          const SizedBox(height: 12),
          if (mine.isInvited)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                unawaited(showLiveStageInvitation(context, ctrl: ctrl, invitation: mine));
              },
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Répondre à l\'invitation'),
            ),
          TextButton(
            onPressed: ctrl.stageBusy
                ? null
                : () => _act(context, ctrl.withdrawStageRequest,
                    mine.isInvited ? 'Invitation refusée.' : 'Demande retirée.'),
            child: Text(mine.isInvited ? 'Refuser' : 'Annuler ma demande'),
          ),
        ],
      );
    } else if (!stage.canRequest) {
      body = Text(stage.refusal ?? 'Les demandes d\'intervention sont fermées pour le moment.',
          style: const TextStyle(color: AppColors.textSecondary));
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _message,
            maxLength: 200,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'De quoi voulez-vous témoigner ? (facultatif)',
              hintText: 'Ex. : guérison, emploi, famille…',
              helperText: 'Seuls le diffuseur et les modérateurs lisent ce sujet.',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: ctrl.stageBusy
                ? null
                : () => _act(context, () async {
                      final err = await ctrl.requestToSpeak(message: _message.text);
                      if (err == null) _message.clear();
                      return err;
                    }, 'Demande envoyée : le diffuseur vous invitera à votre tour.'),
            icon: const Icon(Icons.front_hand_rounded),
            label: const Text('Demander à intervenir'),
          ),
        ],
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetTitle('Témoigner en direct',
              trailing: stage.queueCount > 0
                  ? Text(stage.queueCount > 1 ? '${stage.queueCount} en attente' : '1 en attente',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))
                  : null),
          if (stage.onStage != null && stage.onStage!.user.id != ctrl.currentUserId)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('À l\'antenne : ${stage.onStage!.user.displayName}',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), child: body),
        ],
      ),
    );
  }
}

// ── Invitation ───────────────────────────────────────────────────────────────

/// « C'est votre tour » : compte à rebours, caméra facultative, Refuser / Rejoindre.
Future<void> showLiveStageInvitation(
  BuildContext context, {
  required LiveRoomController ctrl,
  required LiveSpeaker invitation,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _InvitationDialog(ctrl: ctrl, invitation: invitation),
  );
}

class _InvitationDialog extends StatefulWidget {
  const _InvitationDialog({required this.ctrl, required this.invitation});
  final LiveRoomController ctrl;
  final LiveSpeaker invitation;

  @override
  State<_InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends State<_InvitationDialog> {
  late final DateTime _expires = widget.invitation.expiresAt?.toLocal() ??
      DateTime.now().add(Duration(seconds: widget.ctrl.stage.inviteTimeout));
  Timer? _tick;
  bool _camera = false;
  bool _joining = false;

  int get _left => _expires.difference(DateTime.now()).inSeconds.clamp(0, 600);

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Invitation expirée ou annulée par le diffuseur : on referme.
      if (_left <= 0 || (!_joining && widget.ctrl.pendingInvitation?.id != widget.invitation.id)) {
        Navigator.pop(context);
        _snack(context, 'L\'invitation n\'est plus valable. Vous pouvez refaire une demande.');
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final err = await widget.ctrl.acceptInvitation(camera: _camera);
    if (mounted) navigator.pop();
    messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(err ?? 'Vous êtes à l\'antenne. Parlez librement : tout le monde vous entend.')));
  }

  Future<void> _decline() async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final err = await widget.ctrl.withdrawStageRequest();
    messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(err ?? 'Invitation refusée.')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('C\'est votre tour'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Le diffuseur vous invite à l\'antenne. Votre voix sera entendue par tous les spectateurs. '
              'Répondez dans $_left s.'),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _camera,
            onChanged: _joining ? null : (v) => setState(() => _camera = v),
            title: const Text('Activer ma caméra'),
            subtitle: const Text('Sinon, les spectateurs voient votre nom.'),
          ),
          const Text('Le diffuseur peut terminer votre intervention à tout moment. Vous pouvez aussi la terminer vous-même.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
      actions: [
        TextButton(onPressed: _joining ? null : _decline, child: const Text('Refuser')),
        FilledButton.icon(
          onPressed: _joining ? null : _join,
          icon: _joining
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.mic_rounded),
          label: const Text('Rejoindre l\'antenne'),
        ),
      ],
    );
  }
}
