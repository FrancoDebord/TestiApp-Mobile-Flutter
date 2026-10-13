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
    SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
  );
}

/// Lance une action de scène et affiche son erreur, ou [success].
/// Le ScaffoldMessenger est pris avant l'attente (la feuille peut s'être refermée).
Future<void> _act(
  BuildContext context,
  Future<String?> Function() action, [
  String? success,
]) async {
  final messenger = ScaffoldMessenger.of(context);
  final text = await action() ?? success;
  if (text != null) {
    messenger.showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)),
    );
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
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 12),
          ],
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
                    ? const Icon(
                        Icons.mic_rounded,
                        color: Colors.white70,
                        size: 34,
                      )
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
                    Icon(
                      muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
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

/// Commandes de la personne à l'antenne : micro (pour couper le bruit ambiant),
/// caméra, quitter l'antenne. Seule la personne à l'antenne publie du son :
/// les spectateurs n'émettent jamais rien (jeton en lecture seule).
class LiveStageSelfBar extends StatelessWidget {
  const LiveStageSelfBar({required this.ctrl, super.key});

  final LiveRoomController ctrl;

  @override
  Widget build(BuildContext context) {
    if (!ctrl.onStage) return const SizedBox.shrink();
    final mic = ctrl.stageMicEnabled;
    final cam = ctrl.stageCameraEnabled;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xE6161022),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: mic ? kLiveRed.withAlpha(140) : Colors.white.withAlpha(40),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const LiveBadge(label: 'À L\'ANTENNE'),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mic
                      ? 'Tout le monde vous entend'
                      : 'Micro coupé : personne ne vous entend',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mic ? Colors.white : AppColors.secondary,
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StageControl(
                icon: mic ? Icons.mic_rounded : Icons.mic_off_rounded,
                label: mic ? 'Couper le micro' : 'Activer le micro',
                off: !mic,
                onTap: ctrl.toggleStageMic,
              ),
              _StageControl(
                icon: cam ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                label: cam ? 'Couper la caméra' : 'Activer la caméra',
                off: !cam,
                onTap: ctrl.toggleStageCamera,
              ),
              _StageControl(
                icon: Icons.call_end_rounded,
                label: 'Quitter l\'antenne',
                danger: true,
                onTap: ctrl.stageBusy
                    ? null
                    : () => _act(context, ctrl.leaveStage),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageControl extends StatelessWidget {
  const _StageControl({
    required this.icon,
    required this.label,
    this.onTap,
    this.off = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool off;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? AppColors.danger
        : off
        ? Colors.white
        : Colors.white.withAlpha(36);
    final fg = danger
        ? Colors.white
        : off
        ? AppColors.danger
        : Colors.white;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(
                  icon,
                  color: onTap == null ? Colors.white38 : fg,
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bouton d'ouverture (spectateur / diffuseur) ──────────────────────────────

/// Bouton « Intervenir » (spectateur) ou « Intervenants » (diffuseur, modération),
/// avec l'état de sa demande ou le nombre de personnes en attente.
/// [labeled] : pilule avec libellé (écran spectateur) ; sinon icône seule.
class LiveStageButton extends StatelessWidget {
  const LiveStageButton({
    required this.ctrl,
    required this.onPressed,
    this.labeled = false,
    this.light = false,
    super.key,
  });

  final LiveRoomController ctrl;
  final VoidCallback onPressed;
  final bool labeled;

  /// Sur fond clair (panneau de chat) : pilule bleue au lieu de sombre.
  final bool light;

  @override
  Widget build(BuildContext context) {
    final staff = ctrl.canModerate;
    final count = ctrl.stage.queueCount;
    final mine = ctrl.stage.mine;
    final invited = ctrl.pendingInvitation != null;
    final neutralBg = light ? AppColors.primary : Colors.black.withAlpha(140);
    final neutralBorder = light
        ? AppColors.primary
        : Colors.white.withAlpha(70);

    if (!labeled) {
      return Tooltip(
        message: staff ? 'Intervenants' : 'Demander à intervenir',
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

    // À l'antenne : la barre de l'intervenant prend le relais.
    if (!staff && ctrl.onStage) return const SizedBox.shrink();

    final (IconData icon, String label, Color bg, Color border) = staff
        ? (
            Icons.groups_rounded,
            count > 0 ? 'Intervenants · $count' : 'Intervenants',
            count > 0 ? kLiveRed : neutralBg,
            count > 0 ? kLiveRed : neutralBorder,
          )
        : invited
        ? (Icons.mic_rounded, 'C\'est votre tour !', kLiveRed, kLiveRed)
        : mine != null
        ? (
            Icons.hourglass_top_rounded,
            'En file · n°${mine.position ?? '?'}',
            light ? AppColors.primary : Colors.black.withAlpha(150),
            AppColors.secondary,
          )
        : (
            Icons.front_hand_rounded,
            'Intervenir',
            neutralBg,
            light ? AppColors.primary : Colors.white.withAlpha(90),
          );

    return Semantics(
      button: true,
      label: staff
          ? 'Gérer les intervenants'
          : 'Demander à intervenir en direct',
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: Padding(
            padding: light
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 7)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: !staff && mine != null && !invited
                      ? AppColors.secondary
                      : Colors.white,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
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
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
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
        content: Text(
          '${s.user.displayName} quittera l\'antenne : son micro et sa caméra seront coupés pour tous.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _act(
        context,
        () => ctrl.removeSpeaker(s),
        'Intervention terminée.',
      );
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
                const Text(
                  'Demandes',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Switch(
                  value: stage.enabled,
                  onChanged: ctrl.stageBusy
                      ? null
                      : (v) => _act(
                          context,
                          () => ctrl.setStageEnabled(v),
                          v
                              ? 'Demandes ouvertes.'
                              : 'Demandes fermées. La file est conservée.',
                        ),
                ),
              ],
            ),
          ),
          if (current != null)
            ListTile(
              leading: LiveAvatar(person: current.user, size: 40),
              title: Text(
                current.user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  current.isOnStage
                      ? 'À l\'antenne · ${current.camera ? 'caméra' : 'micro seulement'}'
                      : 'Invité · en attente de sa réponse',
                  if (current.message != null) '« ${current.message} »',
                ].join('\n'),
              ),
              isThreeLine: current.message != null,
              trailing: current.isOnStage
                  ? FilledButton(
                      onPressed: ctrl.stageBusy
                          ? null
                          : () => _remove(context, current),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      child: const Text('Terminer'),
                    )
                  : TextButton(
                      onPressed: ctrl.stageBusy
                          ? null
                          : () => _act(
                              context,
                              () => ctrl.declineSpeaker(current),
                              'Invitation annulée.',
                            ),
                      child: const Text('Annuler'),
                    ),
            ),
          const Divider(height: 1),
          if (queue.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Personne n\'attend pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
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
                    title: Text(
                      '${s.position ?? i + 1}. ${s.user.displayName}',
                    ),
                    subtitle: s.message == null
                        ? null
                        : Text('« ${s.message} »'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Retirer de la file',
                          onPressed: ctrl.stageBusy
                              ? null
                              : () => _act(
                                  context,
                                  () => ctrl.declineSpeaker(s),
                                  'Demande retirée de la file.',
                                ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        FilledButton.tonal(
                          // Une personne à la fois : désactivé tant que quelqu'un est invité ou à l'antenne.
                          onPressed: ctrl.stageBusy || current != null
                              ? null
                              : () => _act(
                                  context,
                                  () => ctrl.inviteSpeaker(s),
                                  'Invitation envoyée : ${s.user.displayName} a ${stage.inviteTimeout} s pour accepter.',
                                ),
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
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerPanel extends StatefulWidget {
  const _ViewerPanel({
    required this.ctrl,
    required this.loggedIn,
    this.onLogin,
  });
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

  Future<void> _request() => _act(context, () async {
    final err = await widget.ctrl.requestToSpeak(message: _message.text);
    if (err == null) _message.clear();
    return err;
  }, 'Demande envoyée : le diffuseur vous invitera à votre tour.');

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final stage = ctrl.stage;
    final mine = stage.mine;
    final someoneElse =
        stage.onStage != null && stage.onStage!.user.id != ctrl.currentUserId;

    final List<Widget> body;
    if (!widget.loggedIn) {
      body = [
        const _InfoCard(
          icon: Icons.lock_outline_rounded,
          title: 'Connexion requise',
          text:
              'Connectez-vous pour demander à intervenir et partager votre témoignage en direct.',
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          icon: Icons.login_rounded,
          label: 'Se connecter',
          onPressed: () {
            Navigator.pop(context);
            widget.onLogin?.call();
          },
        ),
      ];
    } else if (ctrl.onStage || mine?.isOnStage == true) {
      body = const [
        _InfoCard(
          icon: Icons.mic_rounded,
          color: kLiveRed,
          title: 'Vous êtes à l\'antenne',
          text:
              'Tout le monde vous entend. Utilisez la barre en bas de l\'écran pour couper '
              'votre micro ou quitter l\'antenne.',
        ),
      ];
    } else if (mine != null && mine.isInvited) {
      body = [
        const _InfoCard(
          icon: Icons.campaign_rounded,
          color: kLiveRed,
          title: 'C\'est votre tour !',
          text: 'Le diffuseur vous invite à l\'antenne.',
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          icon: Icons.mic_rounded,
          label: 'Répondre à l\'invitation',
          onPressed: () {
            Navigator.pop(context);
            unawaited(
              showLiveStageInvitation(context, ctrl: ctrl, invitation: mine),
            );
          },
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: ctrl.stageBusy
              ? null
              : () => _act(
                  context,
                  ctrl.withdrawStageRequest,
                  'Invitation refusée.',
                ),
          child: const Text('Refuser'),
        ),
      ];
    } else if (mine != null) {
      body = [
        _QueueCard(position: mine.position, message: mine.message),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: ctrl.stageBusy
              ? null
              : () => _act(
                  context,
                  ctrl.withdrawStageRequest,
                  'Demande retirée.',
                ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Annuler ma demande'),
        ),
      ];
    } else if (!stage.canRequest) {
      body = [
        _InfoCard(
          icon: Icons.do_not_disturb_on_outlined,
          title: 'Demandes fermées',
          text:
              stage.refusal ??
              'Les demandes d\'intervention sont fermées pour le moment.',
        ),
      ];
    } else {
      body = [
        const _Steps(),
        const SizedBox(height: 16),
        TextField(
          controller: _message,
          maxLength: 200,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Sujet de votre témoignage (facultatif)',
            hintText: 'Ex. : guérison, emploi, famille…',
            helperText: 'Seuls le diffuseur et les modérateurs le lisent.',
            prefixIcon: Icon(Icons.edit_note_rounded),
          ),
        ),
        const SizedBox(height: 12),
        _PrimaryButton(
          icon: Icons.front_hand_rounded,
          label: 'Demander à intervenir',
          busy: ctrl.stageBusy,
          onPressed: ctrl.stageBusy ? null : _request,
        ),
      ];
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Grabber(),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kLiveRed.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.front_hand_rounded, color: kLiveRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Témoigner en direct',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stage.queueCount == 0
                            ? 'Personne n\'attend : vous serez le prochain.'
                            : stage.queueCount == 1
                            ? '1 personne en attente'
                            : '${stage.queueCount} personnes en attente',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (someoneElse) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    LiveAvatar(person: stage.onStage!.user, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'À l\'antenne : ',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            TextSpan(
                              text: stage.onStage!.user.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const LiveBadge(label: 'LIVE'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            ...body,
          ],
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
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

/// Les trois étapes d'une intervention.
class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        Icons.front_hand_outlined,
        'Vous demandez',
        'Votre nom rejoint la file.',
      ),
      (
        Icons.notifications_active_outlined,
        'Vous êtes invité',
        'Une fenêtre s\'ouvre à votre tour.',
      ),
      (Icons.mic_none_rounded, 'Vous parlez', 'Micro coupable à tout moment.'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 10 : 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.surface,
                    child: Icon(
                      steps[i].$1,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${steps[i].$2}  ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: steps[i].$3,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 13),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
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

/// Place dans la file : grand numéro + sujet annoncé.
class _QueueCard extends StatelessWidget {
  const _QueueCard({this.position, this.message});
  final int? position;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.secondary.withAlpha(90)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: Text(
              position == null ? '?' : 'n°$position',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  position == 1
                      ? 'Vous êtes le prochain'
                      : 'Demande enregistrée',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Gardez le direct ouvert : une fenêtre s\'ouvrira à votre tour.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '« $message »',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: kLiveRed,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}

// ── Invitation ───────────────────────────────────────────────────────────────

/// « C'est votre tour » : compte à rebours, caméra et micro au choix, Refuser / Rejoindre.
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
  late final DateTime _expires =
      widget.invitation.expiresAt?.toLocal() ??
      DateTime.now().add(Duration(seconds: widget.ctrl.stage.inviteTimeout));
  late final int _total = _left.clamp(1, 600);
  Timer? _tick;
  bool _camera = false;
  bool _micMuted = false;
  bool _joining = false;

  int get _left => _expires.difference(DateTime.now()).inSeconds.clamp(0, 600);

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Invitation expirée ou annulée par le diffuseur : on referme.
      if (_left <= 0 ||
          (!_joining &&
              widget.ctrl.pendingInvitation?.id != widget.invitation.id)) {
        Navigator.pop(context);
        _snack(
          context,
          'L\'invitation n\'est plus valable. Vous pouvez refaire une demande.',
        );
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
    final err = await widget.ctrl.acceptInvitation(
      camera: _camera,
      mic: !_micMuted,
    );
    if (mounted) navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          err ??
              (_micMuted
                  ? 'Vous êtes à l\'antenne, micro coupé. Activez-le quand vous êtes prêt.'
                  : 'Vous êtes à l\'antenne. Parlez librement : tout le monde vous entend.'),
        ),
      ),
    );
  }

  Future<void> _decline() async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final err = await widget.ctrl.withdrawStageRequest();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(err ?? 'Invitation refusée.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête : compte à rebours ──────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF241640), Color(0xFF103675)],
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 74,
                    height: 74,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: left / _total,
                          strokeWidth: 4,
                          backgroundColor: Colors.white.withAlpha(30),
                          valueColor: AlwaysStoppedAnimation(
                            left <= 10 ? kLiveRed : AppColors.secondary,
                          ),
                        ),
                        Center(
                          child: Text(
                            '$left s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'C\'est votre tour !',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Le diffuseur vous invite à l\'antenne.\nVotre voix sera entendue par tous les spectateurs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            // ── Choix ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                children: [
                  _ChoiceTile(
                    icon: Icons.videocam_rounded,
                    title: 'Activer ma caméra',
                    subtitle: 'Sinon, les spectateurs voient votre nom.',
                    value: _camera,
                    onChanged: _joining
                        ? null
                        : (v) => setState(() => _camera = v),
                  ),
                  _ChoiceTile(
                    icon: Icons.mic_off_rounded,
                    title: 'Arriver micro coupé',
                    subtitle:
                        'Endroit bruyant ? Activez le micro au moment de parler.',
                    value: _micMuted,
                    onChanged: _joining
                        ? null
                        : (v) => setState(() => _micMuted = v),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text(
                'Vous pourrez couper le micro ou quitter l\'antenne à tout moment. '
                'Le diffuseur peut aussi terminer votre intervention.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),

            // ── Actions ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _joining ? null : _decline,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _PrimaryButton(
                      icon: Icons.mic_rounded,
                      label: 'Rejoindre',
                      busy: _joining,
                      onPressed: _joining ? null : _join,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      secondary: Icon(
        icon,
        color: value ? AppColors.primary : AppColors.textSecondary,
      ),
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }
}
