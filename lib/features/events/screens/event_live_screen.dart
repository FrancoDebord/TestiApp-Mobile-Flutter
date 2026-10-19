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
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/comments/comment_likes.dart';
import '../../../shared/widgets/mention_text.dart';
import '../../../shared/widgets/youtube_video_player.dart';
import '../models/event_models.dart';
import '../providers/events_providers.dart';
import '../widgets/event_widgets.dart' show EventLiveBadge;
import 'event_detail_screen.dart' show openEventComposer;

class EventLiveScreen extends ConsumerStatefulWidget {
  const EventLiveScreen({required this.eventId, this.keepScreenOn = true, super.key});

  final String eventId;

  /// Désactivé dans les tests (pas de plugin).
  final bool keepScreenOn;

  @override
  ConsumerState<EventLiveScreen> createState() => _EventLiveScreenState();
}

class _EventLiveScreenState extends ConsumerState<EventLiveScreen> {
  bool _fullscreen = false;
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
      unawaited(SystemChrome.setPreferredOrientations(
          const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]));
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

  /// Plein écran : la vidéo seule, bouton pour revenir.
  Widget _fullscreenLayout(String videoId) => Stack(
        children: [
          Center(child: YouTubeVideoPlayer(videoId: videoId)),
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

  /// Vue « YouTube » : vidéo en haut, informations et discussion en dessous.
  Widget _dockedLayout(ChristianEvent e, String videoId) {
    final l10n = context.l10n;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l10n.commonBack,
                onPressed: _close,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              if (e.isLiveNow) const EventLiveBadge(),
              const Spacer(),
              IconButton(
                tooltip: l10n.eventsOpenOnYoutube,
                onPressed: () => launchUrl(Uri.parse(e.youtubeLiveUrl!), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70),
              ),
              IconButton(
                key: const ValueKey('event-live-fullscreen'),
                tooltip: l10n.eventsLiveFullscreen,
                onPressed: _toggleFullscreen,
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
              ),
            ],
          ),
          YouTubeVideoPlayer(videoId: videoId),
          Expanded(
            child: Container(
              color: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h4.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(e.organizer.displayName,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Text(l10n.eventsLiveChat,
                        style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Expanded(child: _LiveChat(event: e)),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                      child: e.commentsEnabled || e.canManage
                          ? OutlinedButton.icon(
                              onPressed: () => openEventComposer(context, ref, e),
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              label: Text(l10n.eventsCommentPrompt, maxLines: 1, overflow: TextOverflow.ellipsis),
                            )
                          : Text(l10n.eventsCommentsClosed, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
        child: Text(context.l10n.eventsNoComments,
            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final c = items[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primarySoft,
              child: Text(c.user.displayName.isEmpty ? '?' : c.user.displayName[0].toUpperCase(),
                  style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.user.displayName,
                      style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700)),
                  MentionText(c.body, mentions: c.mentions, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            CommentLikeButton(
              comment: CommentRef.event(event.id, c.id),
              initialCount: c.likesCount,
              initialLiked: c.isLikedByMe,
            ),
          ],
        );
      },
    );
  }
}
