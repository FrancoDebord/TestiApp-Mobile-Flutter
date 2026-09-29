import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/live_room_controller.dart';
import '../models/live_models.dart';

const kLiveRed = Color(0xFFE11D48);

String formatLiveDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

// ── Pastilles ───────────────────────────────────────────────────────────────

class LiveBadge extends StatelessWidget {
  const LiveBadge({this.label = 'EN DIRECT', this.color = kLiveRed, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulsingDot(),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Pastille semi-transparente pour les infos posées sur la vidéo.
class LiveChip extends StatelessWidget {
  const LiveChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(110),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class LiveAvatar extends StatelessWidget {
  const LiveAvatar({required this.person, this.size = 36, super.key});

  final LivePerson person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        person.initials,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
    final url = person.avatarUrl;
    if (url == null) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => fallback,
        placeholder: (_, _) => fallback,
      ),
    );
  }
}

// ── Bandeau d'état de connexion ────────────────────────────────────────────

class LiveConnectionBanner extends StatelessWidget {
  const LiveConnectionBanner({required this.link, super.key});

  final LiveLinkState link;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (link) {
      LiveLinkState.reconnecting => (
        'Connexion instable… reconnexion en cours',
        AppColors.secondary,
      ),
      LiveLinkState.disconnected => ('Connexion perdue', AppColors.danger),
      _ => (null, null),
    };
    if (text == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: color!.withAlpha(230),
      child: Row(
        children: [
          if (link == LiveLinkState.reconnecting)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            const Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Commentaires ────────────────────────────────────────────────────────────

/// Fil des commentaires posé sur la vidéo (les plus récents en bas).
///
/// [onModerate] : si fourni (diffuseur / modérateur), un appui long sur un
/// commentaire ouvre les actions Masquer / Exclure.
class LiveCommentsList extends StatefulWidget {
  const LiveCommentsList({
    required this.comments,
    this.onModerate,
    this.hostId,
    this.pinnedId,
    super.key,
  });

  final List<LiveComment> comments;
  final void Function(LiveComment comment)? onModerate;
  final String? hostId;

  /// Commentaire épinglé, repéré par 📌 dans le fil.
  final String? pinnedId;

  @override
  State<LiveCommentsList> createState() => _LiveCommentsListState();
}

class _LiveCommentsListState extends State<LiveCommentsList> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(LiveCommentsList old) {
    super.didUpdateWidget(old);
    if (widget.comments.length != old.comments.length) {
      // Liste inversée : 0 = bas. Rester collé aux nouveaux messages.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients && _scroll.offset < 80) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.comments.reversed.toList();
    return ShaderMask(
      // Fondu en haut pour que les anciens messages s'effacent.
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
        stops: [0, 0.25],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _scroll,
        reverse: true,
        padding: const EdgeInsets.only(top: 40),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final c = items[i];
          final isHost = widget.hostId != null && c.user.id == widget.hostId;
          final isPinned = c.id == widget.pinnedId;
          return GestureDetector(
            onLongPress: widget.onModerate == null
                ? null
                : () => widget.onModerate!(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveAvatar(person: c.user, size: 28),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(11, 6, 11, 7),
                      decoration: BoxDecoration(
                        // Message du diffuseur mis en évidence ; épinglé : liseré ambré.
                        color: isHost
                            ? Colors.black.withAlpha(150)
                            : Colors.black.withAlpha(105),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                        border: Border.all(
                          color: isPinned
                              ? AppColors.secondary.withAlpha(180)
                              : Colors.white.withAlpha(isHost ? 40 : 18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPinned) ...[
                                const Icon(
                                  Icons.push_pin_rounded,
                                  size: 12,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 3),
                              ],
                              Flexible(
                                child: Text(
                                  c.user.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isHost
                                        ? AppColors.secondary
                                        : Colors.white.withAlpha(210),
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (isHost) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Diffuseur',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.body,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13.5,
                              height: 1.35,
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
        },
      ),
    );
  }
}

/// Zone de saisie d'un commentaire (500 caractères max, cf. backend).
class LiveCommentInput extends StatefulWidget {
  const LiveCommentInput({
    required this.onSend,
    this.enabled = true,
    this.disabledHint,
    this.showPinOption = false,
    this.hint = 'Écrire un commentaire…',
    super.key,
  });

  /// Renvoie un message d'erreur, ou null si le commentaire est publié.
  /// [pin] : épingler le message dès son envoi (option du diffuseur).
  final Future<String?> Function(String text, {bool pin}) onSend;
  final bool enabled;
  final String? disabledHint;
  final String hint;

  /// Affiche le bouton 📌 « épingler ce message » (diffuseur / modérateurs).
  final bool showPinOption;

  @override
  State<LiveCommentInput> createState() => _LiveCommentInputState();
}

class _LiveCommentInputState extends State<LiveCommentInput> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  bool _pin = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await widget.onSend(text, pin: _pin);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error == null) {
      _ctrl.clear();
      _pin = false; // une seule fois : le message suivant n'est pas épinglé
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {})); // compteur et bouton d'envoi
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_sending;
    final length = _ctrl.text.characters.length;
    final canSend = enabled && _ctrl.text.trim().isNotEmpty;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.fromLTRB(16, 4, 5, 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(130),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _pin
              ? AppColors.secondary.withAlpha(200)
              : Colors.white.withAlpha(60),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: _ctrl,
                enabled: enabled,
                maxLength: 500,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14.5,
                  height: 1.3,
                ),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: !widget.enabled
                      ? (widget.disabledHint ?? 'Commentaires désactivés')
                      : _pin
                      ? 'Message à épingler…'
                      : widget.hint,
                  hintStyle: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          ),
          // Compteur : seulement à l'approche de la limite.
          if (length > 400)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 14),
              child: Text(
                '$length/500',
                style: TextStyle(
                  color: length >= 500 ? AppColors.danger : Colors.white70,
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                ),
              ),
            ),
          if (widget.showPinOption)
            IconButton(
              tooltip: _pin
                  ? 'Ne pas épingler ce message'
                  : 'Épingler ce message en haut du direct',
              onPressed: enabled ? () => setState(() => _pin = !_pin) : null,
              icon: Icon(
                _pin ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: _pin ? AppColors.secondary : Colors.white70,
                size: 20,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: canSend ? kLiveRed : Colors.white.withAlpha(40),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: canSend ? _send : null,
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Semantics(
                            label: 'Envoyer',
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Commentaire épinglé ─────────────────────────────────────────────────────

/// Bandeau du commentaire épinglé, en haut du direct. Un appui déplie le
/// texte ; [onUnpin] (diffuseur / modérateurs) affiche la croix.
class LivePinnedBanner extends StatefulWidget {
  const LivePinnedBanner({
    required this.comment,
    this.hostId,
    this.onUnpin,
    super.key,
  });

  final LiveComment comment;
  final String? hostId;
  final VoidCallback? onUnpin;

  @override
  State<LivePinnedBanner> createState() => _LivePinnedBannerState();
}

class _LivePinnedBannerState extends State<LivePinnedBanner> {
  bool _expanded = false;

  @override
  void didUpdateWidget(LivePinnedBanner old) {
    super.didUpdateWidget(old);
    if (old.comment.id != widget.comment.id) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final byHost = widget.hostId != null && c.user.id == widget.hostId;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(150),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondary.withAlpha(170)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.push_pin_rounded,
                  color: AppColors.secondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      byHost
                          ? 'Épinglé · ${c.user.displayName} (diffuseur)'
                          : 'Épinglé · ${c.user.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.body,
                      maxLines: _expanded ? 8 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onUnpin != null)
                IconButton(
                  tooltip: 'Désépingler',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onUnpin,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Désépingle et signale le résultat.
Future<void> unpinWithFeedback(
  BuildContext context,
  LiveRoomController controller,
) async {
  final error = await controller.unpinComment();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(error ?? 'Commentaire désépinglé.'),
    ),
  );
}

// ── Réactions ───────────────────────────────────────────────────────────────

/// Colonne de boutons de réaction avec leur compteur.
class LiveReactionButtons extends StatelessWidget {
  const LiveReactionButtons({
    required this.counts,
    required this.onReact,
    this.enabled = true,
    super.key,
  });

  final LiveReactionCounts counts;
  final void Function(LiveReactionType type) onReact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in LiveReactionType.values)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: InkResponse(
                onTap: enabled ? () => onReact(t) : null,
                radius: 28,
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        t.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _compact(counts[t]),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        shadows: [Shadow(blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _compact(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}k';
  return '${(n / 1000000).toStringAsFixed(1)}M';
}

/// Réactions qui montent et s'effacent (les siennes et celles des autres).
class FloatingReactionsLayer extends StatelessWidget {
  const FloatingReactionsLayer({required this.reactions, super.key});

  final List<FloatingReaction> reactions;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final r in reactions)
            _FloatingEmoji(key: ValueKey(r.id), reaction: r),
        ],
      ),
    );
  }
}

class _FloatingEmoji extends StatefulWidget {
  const _FloatingEmoji({required this.reaction, super.key});
  final FloatingReaction reaction;

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  // Légère dérive horizontale propre à chaque réaction.
  late final double _drift = ((widget.reaction.id * 37) % 60 - 30).toDouble();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_c.value);
        return Positioned(
          right: 18 + _drift * t,
          bottom: 40 + 260 * t,
          child: Opacity(
            opacity: (1 - _c.value).clamp(0, 1),
            child: Transform.scale(scale: 0.8 + 0.5 * t, child: child),
          ),
        );
      },
      child: Text(
        widget.reaction.type.emoji,
        style: const TextStyle(fontSize: 30),
      ),
    );
  }
}

// ── Fin du direct ───────────────────────────────────────────────────────────

class LiveEndedView extends StatelessWidget {
  const LiveEndedView({
    required this.title,
    required this.reason,
    required this.onClose,
    this.peakViewers,
    this.duration,
    super.key,
  });

  final String title;
  final String reason;
  final VoidCallback onClose;
  final int? peakViewers;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xF0120A1F),
      padding: const EdgeInsets.all(28),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white70,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Direct terminé',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
              ),
            ),
            if (peakViewers != null || duration != null) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (duration != null)
                    LiveChip(
                      icon: Icons.timer_outlined,
                      label: formatLiveDuration(duration!),
                    ),
                  if (peakViewers != null)
                    LiveChip(
                      icon: Icons.visibility_outlined,
                      label: '$peakViewers au plus fort',
                    ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Actions de modération sur un commentaire ────────────────────────────────

/// Feuille d'actions (Épingler / Masquer / Exclure) ; résultat en snackbar.
Future<void> showCommentModerationSheet(
  BuildContext context, {
  required LiveComment comment,
  required LiveRoomController controller,
}) async {
  final isHostComment = controller.live.host.id == comment.user.id;
  final isPinned = controller.pinnedComment?.id == comment.id;
  // Message du diffuseur : lui seul l'épingle, le retire ou le masque.
  final canPin = controller.canChangePin;
  final canHide = !isHostComment || controller.isHostMode;
  final action = await showModalBottomSheet<String>(
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
              comment.user.displayName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              comment.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          if (canPin)
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                color: AppColors.secondary,
              ),
              title: Text(
                isPinned ? 'Désépingler' : 'Épingler en haut du direct',
              ),
              subtitle: isPinned || controller.pinnedComment == null
                  ? null
                  : const Text('Remplace le commentaire actuellement épinglé.'),
              onTap: () => Navigator.pop(context, isPinned ? 'unpin' : 'pin'),
            ),
          if (!canPin && controller.pinnedComment != null)
            const ListTile(
              leading: Icon(Icons.push_pin_outlined),
              title: Text('Le diffuseur a épinglé un message'),
              subtitle: Text('Lui seul peut le retirer ou le remplacer.'),
            ),
          if (canHide)
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Masquer ce commentaire'),
              onTap: () => Navigator.pop(context, 'hide'),
            ),
          // Le diffuseur et les modérateurs ne peuvent pas être exclus.
          if (!isHostComment)
            ListTile(
              leading: const Icon(Icons.block_rounded, color: AppColors.danger),
              title: const Text(
                'Exclure du direct',
                style: TextStyle(color: AppColors.danger),
              ),
              subtitle: const Text(
                'Ses commentaires sont masqués ; plus de commentaires ni de réactions.',
              ),
              onTap: () => Navigator.pop(context, 'ban'),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  final error = switch (action) {
    'pin' => await controller.pinComment(comment),
    'unpin' => await controller.unpinComment(),
    'hide' => await controller.hideComment(comment),
    _ => await controller.banUser(comment.user),
  };
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
        error ??
            switch (action) {
              'pin' => 'Commentaire épinglé.',
              'unpin' => 'Commentaire désépinglé.',
              'hide' => 'Commentaire masqué.',
              _ =>
                '${comment.user.displayName} ne peut plus commenter ni réagir.',
            },
      ),
    ),
  );
}

/// Confirmation avant de terminer / couper un direct.
Future<bool> confirmEndLive(
  BuildContext context, {
  required bool asHost,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(asHost ? 'Terminer le direct ?' : 'Couper ce direct ?'),
      content: Text(
        asHost
            ? 'Les spectateurs verront « Direct terminé ». Cette action est définitive.'
            : 'Le direct sera arrêté immédiatement pour tout le monde.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: Text(asHost ? 'Terminer' : 'Couper le direct'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
