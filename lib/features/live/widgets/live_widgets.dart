import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/mention_text.dart';
import '../../../shared/widgets/mention_text_field.dart';
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
  const LiveBadge({this.label, this.color = kLiveRed, super.key});

  /// null : « EN DIRECT ».
  final String? label;
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
            label ?? context.l10n.liveBadge,
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
        context.l10n.liveConnectionUnstable,
        AppColors.secondary,
      ),
      LiveLinkState.disconnected => (context.l10n.liveConnectionLost, AppColors.danger),
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
    this.fadeTop = true,
    this.light = false,
    super.key,
  });

  /// Fondu des anciens messages en haut (utile posé sur la vidéo).
  final bool fadeTop;

  /// Panneau clair sous la vidéo : rangées simples (avatar, nom gris, texte).
  final bool light;

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
    final list = ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: EdgeInsets.only(top: widget.fadeTop ? 40 : 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final c = items[i];
        final isHost = widget.hostId != null && c.user.id == widget.hostId;
        final isPinned = c.id == widget.pinnedId;
        if (widget.light) {
          return GestureDetector(
            onLongPress: widget.onModerate == null
                ? null
                : () => widget.onModerate!(c),
            child: _LightCommentRow(
              comment: c,
              isHost: isHost,
              isPinned: isPinned,
            ),
          );
        }
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
                                child: Text(
                                  context.l10n.liveHostTag,
                                  style: const TextStyle(
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
                        MentionText(
                          c.body,
                          mentions: c.mentions,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                          mentionStyle: const TextStyle(
                            color: AppColors.secondary,
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
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
    );
    if (!widget.fadeTop) return list;
    return ShaderMask(
      // Fondu en haut pour que les anciens messages s'effacent.
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
        stops: [0, 0.25],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: list,
    );
  }
}

/// Rangée de chat claire : avatar, nom en gris (badge « Diffuseur »), texte.
class _LightCommentRow extends StatelessWidget {
  const _LightCommentRow({
    required this.comment,
    required this.isHost,
    required this.isPinned,
  });

  final LiveComment comment;
  final bool isHost;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    const font = 'Plus Jakarta Sans'; // i18n-ignore
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiveAvatar(person: comment.user, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isPinned) ...[
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        comment.user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isHost
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontFamily: font,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
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
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.l10n.liveHostTag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: font,
                            fontWeight: FontWeight.w700,
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                MentionText(
                  comment.body,
                  mentions: comment.mentions,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: font,
                    fontSize: 14,
                    height: 1.35,
                  ),
                  mentionStyle: const TextStyle(
                    color: AppColors.primary,
                    fontFamily: font,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

/// Zone de saisie d'un commentaire (500 caractères max, cf. backend).
class LiveCommentInput extends StatefulWidget {
  const LiveCommentInput({
    required this.onSend,
    this.enabled = true,
    this.disabledHint,
    this.showPinOption = false,
    this.hint,
    this.light = false,
    super.key,
  });

  /// Pilule grise sur fond clair (panneau de chat sous la vidéo).
  final bool light;

  /// Renvoie un message d'erreur, ou null si le commentaire est publié.
  /// [pin] : épingler le message dès son envoi (option du diffuseur).
  final Future<String?> Function(String text, {bool pin}) onSend;
  final bool enabled;
  final String? disabledHint;
  /// null : « Écrire un commentaire… ».
  final String? hint;

  /// Affiche le bouton 📌 « épingler ce message » (diffuseur / modérateurs).
  final bool showPinOption;

  @override
  State<LiveCommentInput> createState() => _LiveCommentInputState();
}

class _LiveCommentInputState extends State<LiveCommentInput> {
  // Mentions « @ » (docs serveur fonctionnalites/mentions.md) : envoyées sous forme de jetons.
  final _ctrl = MentionEditingController();
  final _focus = FocusNode();
  bool _sending = false;
  bool _pin = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {})); // compteur et bouton d'envoi
    _focus.addListener(() => setState(() {})); // liseré au focus
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty || _sending) return;
    final text = _ctrl.encodedText;
    setState(() => _sending = true);
    final error = await widget.onSend(text, pin: _pin && widget.showPinOption);
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
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_sending;
    final length = _ctrl.text.characters.length;
    final canSend = enabled && _ctrl.text.trim().isNotEmpty;
    final pin = _pin && widget.showPinOption;
    final focused = _focus.hasFocus;
    final light = widget.light;
    final textColor = light ? AppColors.textPrimary : Colors.white;
    final mutedColor = light ? AppColors.textSecondary : Colors.white70;

    // Le thème global remplit les champs en blanc (InputDecorationTheme) :
    // tout est neutralisé ici pour garder un texte blanc lisible sur fond sombre.
    const none = InputBorder.none;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.fromLTRB(16, 4, 5, 4),
      decoration: BoxDecoration(
        color: light ? const Color(0xFFF0F1F4) : const Color(0xE6161022),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          width: focused || pin ? 1.5 : 1,
          color: pin
              ? AppColors.secondary
              : light
              ? (focused ? AppColors.primary : Colors.transparent)
              : focused
              ? Colors.white.withAlpha(170)
              : Colors.white.withAlpha(55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: MentionTextField(
              controller: _ctrl,
              focusNode: _focus,
              enabled: enabled,
              maxLength: 500,
              minLines: 1,
              maxLines: 4,
              maxSuggestionsHeight: 180,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: TextStyle(
                color: textColor,
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14.5,
                height: 1.35,
              ),
              cursorColor: light ? AppColors.primary : AppColors.secondary,
              decoration: InputDecoration(
                filled: false,
                fillColor: Colors.transparent,
                counterText: '',
                border: none,
                enabledBorder: none,
                focusedBorder: none,
                disabledBorder: none,
                errorBorder: none,
                focusedErrorBorder: none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: !widget.enabled
                    ? (widget.disabledHint ?? context.l10n.liveCommentsDisabled)
                    : pin
                    ? context.l10n.livePinMessageHint
                    : (widget.hint ?? context.l10n.liveCommentHint),
                hintMaxLines: 1,
                hintStyle: TextStyle(
                  color: light
                      ? AppColors.textSecondary
                      : Colors.white.withAlpha(140),
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
          // Compteur : seulement à l'approche de la limite.
          if (length > 400)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '$length/500',
                style: TextStyle(
                  color: length >= 500 ? AppColors.danger : mutedColor,
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                ),
              ),
            ),
          if (widget.showPinOption)
            IconButton(
              tooltip: pin
                  ? context.l10n.liveDontPinMessage
                  : context.l10n.livePinMessage,
              visualDensity: VisualDensity.compact,
              onPressed: enabled ? () => setState(() => _pin = !_pin) : null,
              icon: Icon(
                pin ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: pin ? AppColors.secondary : mutedColor,
                size: 20,
              ),
            ),
          const SizedBox(width: 4),
          Material(
            color: canSend
                ? (light ? AppColors.primary : kLiveRed)
                : (light
                      ? const Color(0xFFDDE0E6)
                      : Colors.white.withAlpha(30)),
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
                          label: context.l10n.commonSend,
                          child: Icon(
                            Icons.send_rounded,
                            color: canSend
                                ? Colors.white
                                : (light
                                      ? AppColors.textSecondary
                                      : Colors.white54),
                            size: 18,
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
    this.light = false,
    super.key,
  });

  final LiveComment comment;
  final String? hostId;
  final VoidCallback? onUnpin;

  /// Carte claire dans le panneau de chat sous la vidéo.
  final bool light;

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
            color: widget.light
                ? const Color(0xFFF5F6F8)
                : Colors.black.withAlpha(150),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.light
                  ? AppColors.border
                  : AppColors.secondary.withAlpha(170),
            ),
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
                          ? context.l10n.livePinnedByHost(c.user.displayName)
                          : context.l10n.livePinnedBy(c.user.displayName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.light
                            ? AppColors.textSecondary
                            : AppColors.secondary,
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
                      style: TextStyle(
                        color: widget.light
                            ? AppColors.textPrimary
                            : Colors.white,
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
                  tooltip: context.l10n.liveUnpin,
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onUnpin,
                  icon: Icon(
                    Icons.close_rounded,
                    color: widget.light
                        ? AppColors.textSecondary
                        : Colors.white70,
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
      content: Text(error ?? context.l10n.liveCommentUnpinned),
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
    this.direction = Axis.vertical,
    super.key,
  });

  final LiveReactionCounts counts;
  final void Function(LiveReactionType type) onReact;
  final bool enabled;

  /// Colonne sur la vidéo (plein écran) ou ligne sous le chat (vue « YouTube »).
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    final vertical = direction == Axis.vertical;
    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in LiveReactionType.values)
          Padding(
            padding: vertical
                ? const EdgeInsets.only(top: 10)
                : const EdgeInsets.only(left: 6),
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

/// Fin du direct : bilan (durée, audience, commentaires, réactions).
class LiveEndedView extends StatelessWidget {
  const LiveEndedView({
    required this.title,
    required this.reason,
    required this.onClose,
    this.host,
    this.peakViewers,
    this.duration,
    this.commentCount,
    this.reactions,
    this.asHost = false,
    this.footer,
    super.key,
  });

  /// Sous le bilan : revoir la discussion, témoigner (LiveAfterwardsSection).
  final Widget? footer;

  final String title;
  final String reason;
  final VoidCallback onClose;
  final LivePerson? host;
  final int? peakViewers;
  final Duration? duration;
  final int? commentCount;
  final LiveReactionCounts? reactions;

  /// Bilan vu par le diffuseur (formulation « votre direct »).
  final bool asHost;

  static const _ink = Color(0xFF120A1F);
  static const _card = Color(0xFF1E1530);

  @override
  Widget build(BuildContext context) {
    final r = reactions;
    final totalReactions = r?.total ?? 0;
    final l10n = context.l10n;
    final tiles = <(IconData, String, String)>[
      if (duration != null)
        (Icons.timer_outlined, formatLiveDuration(duration!), l10n.liveStatDuration),
      if (peakViewers != null)
        (
          Icons.visibility_outlined,
          _compact(peakViewers!),
          l10n.liveStatPeakViewers,
        ),
      if (commentCount != null)
        (
          Icons.chat_bubble_outline_rounded,
          _compact(commentCount!),
          l10n.liveStatComments,
        ),
      if (r != null)
        (Icons.favorite_border_rounded, _compact(totalReactions), l10n.liveStatReactions),
    ];
    final sorted = [...LiveReactionType.values]
      ..sort((a, b) => (r?[b] ?? 0).compareTo(r?[a] ?? 0));

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF241640), _ink],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: l10n.commonClose,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── En-tête ─────────────────────────────────────────
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withAlpha(60),
                                  width: 2,
                                ),
                              ),
                              child: host != null
                                  ? LiveAvatar(person: host!, size: 76)
                                  : const CircleAvatar(
                                      radius: 38,
                                      backgroundColor: _card,
                                      child: Icon(
                                        Icons.live_tv_rounded,
                                        color: Colors.white70,
                                        size: 34,
                                      ),
                                    ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: -8,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF475467),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _ink, width: 2),
                                  ),
                                  child: Text(
                                    l10n.liveBadgeEnded,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9.5,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          asHost
                              ? l10n.liveYourLiveEnded
                              : l10n.liveEnded,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withAlpha(220),
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          host == null || asHost
                              ? reason
                              : '${host!.displayName} · $reason',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13,
                          ),
                        ),

                        // ── Chiffres clés ───────────────────────────────────
                        if (tiles.isNotEmpty) ...[
                          const SizedBox(height: 26),
                          _SectionLabel(
                            asHost ? l10n.liveSummaryHost : l10n.liveSummaryNumbers,
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, c) {
                              final w = (c.maxWidth - 10) / 2;
                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final (icon, value, label) in tiles)
                                    SizedBox(
                                      width: w,
                                      child: _StatTile(
                                        icon: icon,
                                        value: value,
                                        label: label,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],

                        // ── Détail des réactions ────────────────────────────
                        if (r != null && totalReactions > 0) ...[
                          const SizedBox(height: 22),
                          _SectionLabel(l10n.liveStatReactions),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withAlpha(18),
                              ),
                            ),
                            child: Column(
                              children: [
                                for (final t in sorted)
                                  if (r[t] > 0)
                                    _ReactionBar(
                                      emoji: t.emoji,
                                      label: t.label,
                                      count: r[t],
                                      share: r[t] / totalReactions,
                                    ),
                              ],
                            ),
                          ),
                        ],

                        ?footer,
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: onClose,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(l10n.commonClose),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: LiveEndedView._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(38),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: AppColors.secondary),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
    required this.emoji,
    required this.label,
    required this.count,
    required this.share,
  });
  final String emoji;
  final String label;
  final int count;
  final double share;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          SizedBox(
            width: 70,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share.clamp(0.02, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withAlpha(20),
                valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              _compact(count),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
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
                isPinned ? context.l10n.liveUnpin : context.l10n.livePinTop,
              ),
              subtitle: isPinned || controller.pinnedComment == null
                  ? null
                  : Text(context.l10n.livePinReplaces),
              onTap: () => Navigator.pop(context, isPinned ? 'unpin' : 'pin'),
            ),
          if (!canPin && controller.pinnedComment != null)
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(context.l10n.liveHostPinnedMessage),
              subtitle: Text(context.l10n.liveHostPinnedOnlyHost),
            ),
          if (canHide)
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(context.l10n.liveHideComment),
              onTap: () => Navigator.pop(context, 'hide'),
            ),
          // Le diffuseur et les modérateurs ne peuvent pas être exclus.
          if (!isHostComment)
            ListTile(
              leading: const Icon(Icons.block_rounded, color: AppColors.danger),
              title: Text(
                context.l10n.liveBan,
                style: const TextStyle(color: AppColors.danger),
              ),
              subtitle: Text(
                context.l10n.liveBanHint,
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
              'pin' => context.l10n.liveCommentPinned,
              'unpin' => context.l10n.liveCommentUnpinned,
              'hide' => context.l10n.liveCommentHidden,
              _ => context.l10n.liveUserBanned(comment.user.displayName),
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
      title: Text(asHost ? context.l10n.liveEndConfirmTitle : context.l10n.liveCutConfirmTitle),
      content: Text(
        asHost
            ? context.l10n.liveEndConfirmBody
            : context.l10n.liveCutConfirmBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: Text(asHost ? context.l10n.liveEndAction : context.l10n.liveCutAction),
        ),
      ],
    ),
  );
  return ok ?? false;
}
