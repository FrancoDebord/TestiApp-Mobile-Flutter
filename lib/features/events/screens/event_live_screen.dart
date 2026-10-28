// Direct YouTube d'un événement, présenté comme sur YouTube : la vidéo en haut
// (16:9), la discussion en direct dessous ; bouton plein écran (paysage, vidéo
// seule). Le téléphone tourné en paysage passe aussi en plein écran.
// Backend : docs/fonctionnalites/evenements.md (youtubeLive) — discussion = commentaires.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/guest_gate.dart' show requireAccount;
import '../../home/providers/home_providers.dart' show ReactionType;
import '../../live/models/live_models.dart' show LiveComment, LivePerson;
import '../../live/widgets/live_widgets.dart' show LiveChatHeader, LiveChatWelcome, LiveCommentInput, LiveCommentsList;
import '../../repost/content_interactions.dart'
    show ContentInteractionsNotifier, ContentKind, contentInteractionsProvider;
import '../../../shared/widgets/youtube_video_player.dart';
import '../models/event_models.dart';
import '../providers/events_providers.dart';
import '../widgets/event_widgets.dart' show EventLiveBadge;

class EventLiveScreen extends ConsumerStatefulWidget {
  const EventLiveScreen({required this.eventId, this.keepScreenOn = true, this.playerBuilder, super.key});

  final String eventId;

  /// Tests : remplace le lecteur YouTube (WebView indisponible).
  @visibleForTesting
  final Widget Function(String videoId)? playerBuilder;

  /// Désactivé dans les tests (pas de plugin).
  final bool keepScreenOn;

  @override
  ConsumerState<EventLiveScreen> createState() => _EventLiveScreenState();
}

class _EventLiveScreenState extends ConsumerState<EventLiveScreen> {
  bool _fullscreen = false;

  /// Discussion affichée sous la vidéo (la croix la masque).
  bool _chatVisible = true;
  Timer? _chatTimer;

  @override
  void initState() {
    super.initState();
    if (widget.keepScreenOn) unawaited(WakelockPlus.enable().catchError((_) {}));
    // Discussion « en direct » : nouveaux messages toutes les 15 s.
    _chatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(eventCommentsProvider(widget.eventId));
    });
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    if (widget.keepScreenOn) unawaited(WakelockPlus.disable().catchError((_) {}));
    if (_fullscreen) _restoreSystemUi();
    super.dispose();
  }

  void _restoreSystemUi() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]));
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    } else {
      _restoreSystemUi();
    }
  }

  void _close() {
    if (_fullscreen) {
      _toggleFullscreen();
      return;
    }
    context.canPop() ? context.pop() : context.go('/events/${widget.eventId}');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventDetailProvider(widget.eventId));
    final e = async.value;
    final videoId = e?.youtubeLiveId;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreen) _toggleFullscreen();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          key: const ValueKey('event-live'),
          backgroundColor: Colors.black,
          body: e == null || videoId == null
              ? Center(
                  child: async.isLoading
                      ? const CircularProgressIndicator()
                      : Text(context.l10n.eventsNoYoutubeLive, style: const TextStyle(color: Colors.white70)),
                )
              : (_fullscreen || landscape)
              ? _fullscreenLayout(videoId)
              : _dockedLayout(e, videoId),
        ),
      ),
    );
  }

  Widget _player(String videoId) => widget.playerBuilder?.call(videoId) ?? YouTubeVideoPlayer(videoId: videoId);

  /// Plein écran : la vidéo seule, bouton pour revenir.
  Widget _fullscreenLayout(String videoId) => Stack(
    children: [
      Center(child: _player(videoId)),
      Positioned(
        top: 8,
        left: 8,
        child: SafeArea(
          child: IconButton(
            tooltip: context.l10n.eventsLiveExitFullscreen,
            onPressed: _fullscreen ? _toggleFullscreen : _close,
            icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
          ),
        ),
      ),
    ],
  );

  /// Vue « YouTube » : vidéo en haut, feuille « Discussion en direct » dessous
  /// (mêmes éléments que les directs de l'application).
  Widget _dockedLayout(ChristianEvent e, String videoId) {
    final l10n = context.l10n;
    final keyboardOpen = View.of(context).viewInsets.bottom > 0;
    final canWrite = e.commentsEnabled || e.canManage;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barre fine au-dessus de la vidéo : retour, EN DIRECT, YouTube, plein écran.
          SizedBox(
            height: 44,
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.commonBack,
                  onPressed: _close,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                ),
                // Texte agrandi : le badge se réduit plutôt que de déborder.
                if (e.isLiveNow)
                  const Flexible(
                    child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: EventLiveBadge()),
                  )
                else
                  const Spacer(),
                if (e.isLiveNow) const Spacer(),
                IconButton(
                  tooltip: l10n.eventsOpenOnYoutube,
                  onPressed: () => launchUrl(Uri.parse(e.youtubeLiveUrl!), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                ),
                IconButton(
                  key: const ValueKey('event-live-fullscreen'),
                  tooltip: l10n.eventsLiveFullscreen,
                  onPressed: _toggleFullscreen,
                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          if (!keyboardOpen) _player(videoId),
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
                  // Carte de bienvenue seulement s'il reste de la place pour la
                  // discussion (texte agrandi, petits écrans).
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final ts = MediaQuery.textScalerOf(context).scale(100) / 100;
                      final showWelcome = !keyboardOpen && box.maxHeight >= 200 + 260 * ts;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!keyboardOpen) ...[
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
                              subtitle: e.title,
                              count: e.goingCount > 0 ? e.goingCount : null,
                              onClose: () => setState(() => _chatVisible = false),
                            ),
                            const Divider(height: 1, color: AppColors.border),
                          ],
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(child: _LiveChat(event: e)),
                                if (!keyboardOpen) Positioned(right: 12, bottom: 8, child: _HeartFab(event: e)),
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
                              onSend: (text, {bool pin = false}) async {
                                if (!await requireAccount(context, ref, reason: l10n.eventsReasonComment)) {
                                  return l10n.liveChatLoginRequired;
                                }
                                return (await ref.read(eventCommentsProvider(e.id).notifier).add(text)).error;
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cœur flottant : « J'aime » sur l'événement (comme le cœur du chat YouTube).
class _HeartFab extends ConsumerWidget {
  const _HeartFab({required this.event});
  final ChristianEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ContentInteractionsNotifier.key(ContentKind.event, event.id);
    final r = ref.watch(contentInteractionsProvider.select((m) => m[key])) ?? event.reactions;
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          if (!await requireAccount(context, ref, reason: context.l10n.eventsReasonComment)) return;
          unawaited(HapticFeedback.lightImpact());
          await ref
              .read(contentInteractionsProvider.notifier)
              .react(ContentKind.event, event.id, r, r.isLiked ? null : ReactionType.like);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            r.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: const Color(0xFFE11D48),
            size: 30,
          ),
        ),
      ),
    );
  }
}

class _LiveChat extends ConsumerWidget {
  const _LiveChat({required this.event});
  final ChristianEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(eventCommentsProvider(event.id)).value?.items ?? const <EventComment>[];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.eventsNoComments,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    // Commentaires de l'événement (du plus récent au plus ancien) → chat chronologique.
    final comments = [
      for (final c in items.reversed)
        LiveComment(
          id: c.id,
          body: c.body,
          mentions: c.mentions,
          createdAt: c.createdAt,
          user: LivePerson.fromJson({
            'id': c.user.id,
            'displayName': c.user.displayName,
            'initials': c.user.initials,
            'avatarUrl': c.user.avatarUrl,
          }),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LiveCommentsList(comments: comments, hostId: event.organizer.id, fadeTop: false, light: true),
    );
  }
}
