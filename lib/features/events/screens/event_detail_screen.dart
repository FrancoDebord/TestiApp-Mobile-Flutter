import 'dart:async';

import '../../../shared/comments/comment_likes.dart';
import '../../repost/content_interactions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/categories_provider.dart' show categoriesListProvider;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/guest_gate.dart' show requireAccount;
import '../../../shared/widgets/mention_text.dart';
import '../../../shared/widgets/mention_text_field.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../home/widgets/compact_testimony_tile.dart';
import '../../publish/providers/publish_provider.dart' show publishEventProvider;
import '../../offline/outbox_controller.dart' show showQueuedSnack;
import '../data/events_repository.dart';
import '../models/event_models.dart';
import '../providers/events_providers.dart';
import '../widgets/event_location_widgets.dart';
import '../widgets/event_trust_widgets.dart';
import '../widgets/event_widgets.dart';
import '../widgets/manager_widgets.dart';
import '../../../shared/content/encouragements.dart';
import '../../../shared/widgets/encouragement_card.dart';
import '../../prayer/widgets/prayer_widgets.dart' show EventPrayerSection;

/// Page d'un événement : carrousel, infos, « Participer », direct, témoignages
/// officiels et commentaires ; outils de gestion pour l'organisateur.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

enum _Tab { testimonies, comments }

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  _Tab _tab = _Tab.testimonies;
  bool _answering = false;

  String get _id => widget.eventId;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  Future<void> _answer(EventParticipation answer) async {
    if (!await requireAccount(context, ref, reason: context.l10n.eventsReasonParticipate)) return;
    setState(() => _answering = true);
    final err = await ref.read(eventDetailProvider(_id).notifier).answer(answer);
    if (!mounted) return;
    setState(() => _answering = false);
    if (err != null) _snack(err);
    if (err == null) unawaited(HapticFeedback.selectionClick());
  }

  /// Partager : sur TestiApp (avec ses abonnés), copier le lien, autres applications.
  void _share(ChristianEvent e) {
    final when = formatEventRange(e.startsAt, e.endsAt);
    final reactions = ref.read(contentInteractionsProvider.notifier).of(ContentKind.event, e.id, e.reactions);
    showContentShareSheet(
      context,
      ref,
      kind: ContentKind.event,
      id: e.id,
      title: '${e.title}\n$when${e.place != null ? '\n${e.place}' : ''}',
      webUrl: e.webUrl,
      reactions: reactions,
    );
  }

  /// « Raconter ce que j'ai vécu » : formulaire de témoignage. Un gestionnaire publie un témoignage
  /// officiel rattaché ; un participant écrit son témoignage sous l'événement (onglet Témoignages des
  /// participants), ou publie un témoignage classique si les commentaires sont fermés.
  Future<void> _tellExperience(ChristianEvent e) async {
    if (e.canManage) return _manage(e, 'testimony');
    if (!e.commentsEnabled) {
      if (!await requireAccount(context, ref, reason: context.l10n.eventsReasonComment)) return;
      if (mounted) context.go('/publish');
      return;
    }
    setState(() => _tab = _Tab.comments);
    await openEventComposer(context, ref, e);
  }

  // ── Gestion ────────────────────────────────────────────────────────────────

  Future<void> _manage(ChristianEvent e, String action) async {
    switch (action) {
      case 'edit':
        await context.push('/events/${e.id}/edit');
        if (mounted) unawaited(ref.read(eventDetailProvider(_id).notifier).reload());
      case 'testimony':
        ref.read(publishEventProvider.notifier).attach(e.id, e.title);
        context.go('/publish');
      case 'managers':
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (_) => EventManagersSheet(
            event: e,
            currentUserId: ref.read(currentUserProvider)?.id,
          ),
        );
      case 'postpone':
        final ok = await showPostponeSheet(context, e);
        if (ok == true && mounted) _snack(context.l10n.eventsPostponedNotified);
      case 'cancel':
        final reason = await showCancelEventDialog(context);
        if (reason == null || !mounted) return;
        final err = await ref
            .read(eventDetailProvider(_id).notifier)
            .apply((repo) => repo.cancelEvent(e.id, reason: reason));
        if (mounted) _snack(err ?? context.l10n.eventsCancelledNotified);
      case 'report':
        if (e.hasReported) {
          _snack(context.l10n.eventsAlreadyReportedThanks);
          return;
        }
        if (!await requireAccount(context, ref, reason: context.l10n.eventsReasonReport)) return;
        if (!mounted) return;
        final msg = await showReportEventSheet(context, e);
        if (msg != null) _snack(msg);
      case 'participants':
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (_) => _ParticipantsSheet(event: e),
        );
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.eventsDeleteConfirmTitle),
            content: Text(context.l10n.eventsDeleteConfirmText),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.commonCancel)),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                child: Text(context.l10n.commonDelete),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        try {
          await ref.read(eventsRepositoryProvider).delete(e.id);
          ref.invalidate(eventListProvider);
          ref.invalidate(upcomingEventsProvider);
          if (!mounted) return;
          _snack(context.l10n.eventsDeleted);
          context.canPop() ? context.pop() : context.go('/events');
        } on EventFailure catch (err) {
          _snack(err.message);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventDetailProvider(_id));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: switch (async) {
        AsyncValue(:final value?) => _content(value),
        AsyncValue(:final error?) => _ErrorView(
            message: error is EventFailure ? error.message : context.l10n.eventsDetailLoadError,
            onRetry: () => ref.invalidate(eventDetailProvider(_id)),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _content(ChristianEvent e) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(eventDetailProvider(_id).notifier).reload();
        ref.invalidate(eventCommentsProvider(_id));
        ref.invalidate(eventTestimoniesProvider(_id));
      },
      child: CustomScrollView(
        slivers: [
          _header(e),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Summary(event: e),
                  // Masqué, annulé, reporté, non confirmé.
                  EventStatusBanners(event: e),
                  if (e.live != null && (e.live!.isOnAir || e.canManage)) ...[
                    const SizedBox(height: 14),
                    _LiveBanner(event: e),
                  ],
                  // Direct sur YouTube (lien fourni par l'organisateur).
                  if (e.youtubeLiveId != null) ...[
                    const SizedBox(height: 14),
                    _YouTubeLiveCard(event: e),
                  ],
                  const SizedBox(height: 14),
                  _ParticipationCard(
                    event: e,
                    busy: _answering,
                    onAnswer: _answer,
                  ),
                  // J'aime, je prie, partager (docs serveur fonctionnalites/reactions.md).
                  if (!e.isDraft) ...[
                    const SizedBox(height: 6),
                    ContentReactionBar(
                      kind: ContentKind.event,
                      id: e.id,
                      initial: e.reactions,
                      title: e.title,
                      webUrl: e.webUrl,
                      comments: e.commentCount,
                    ),
                  ],
                  // Sondage d'après l'événement : « Votre avis ».
                  if (e.survey.open || e.survey.total > 0) ...[
                    const SizedBox(height: 14),
                    EventSurveyCard(
                      key: ValueKey('survey-${e.id}-${e.survey.mine?.attended}'),
                      event: e,
                      onLoginRequired: () => requireAccount(context, ref, reason: context.l10n.eventsReasonSurvey),
                    ),
                  ],
                  if (e.moderation != null) ...[
                    const SizedBox(height: 14),
                    EventModerationCard(event: e),
                  ],
                  // Lieu : adresse, mini-carte, itinéraire.
                  if (e.hasPlace) ...[
                    const SizedBox(height: 14),
                    EventPlaceCard(event: e),
                  ],
                  if (e.canManage) ...[
                    const SizedBox(height: 14),
                    _ManagerPanel(event: e, onAction: (a) => _manage(e, a)),
                  ],
                  if (e.guests.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _SectionTitle(context.l10n.eventsFormGuests),
                    const SizedBox(height: 10),
                    _Guests(guests: e.guests),
                  ],
                  if (e.description != null) ...[
                    const SizedBox(height: 22),
                    _SectionTitle(context.l10n.eventsAbout),
                    const SizedBox(height: 8),
                    _Description(text: e.description!),
                  ],
                  // Requêtes et sessions de prière (docs serveur fonctionnalites/requetes-de-priere.md).
                  const SizedBox(height: 22),
                  EventPrayerSection(eventId: e.id, canManage: e.canManage),
                  const SizedBox(height: 24),
                  _Tabs(
                    selected: _tab,
                    testimonies: e.testimonyCount,
                    comments: e.commentCount,
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (_tab == _Tab.testimonies)
            _TestimoniesSliver(event: e, onPublish: () => _manage(e, 'testimony'))
          else
            _CommentsSliver(event: e),
          // Invitation à témoigner (Apocalypse 12:11).
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 20, AppSpacing.screen, 0),
              child: EncouragementCard(
                message: encouragementVerses.first,
                actionLabel: context.l10n.eventsTellExperience,
                onAction: () => _tellExperience(e),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _header(ChristianEvent e) {
    final top = MediaQuery.paddingOf(context).top;
    Widget roundButton(IconData icon, String tooltip, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: Colors.black.withAlpha(90),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: tooltip,
              onPressed: onTap,
              icon: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        );

    return SliverAppBar(
      pinned: true,
      expandedHeight: 250 + top * 0.3,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: roundButton(Icons.arrow_back_rounded, context.l10n.commonBack,
          () => context.canPop() ? context.pop() : context.go('/events')),
      actions: [
        roundButton(Icons.share_rounded, context.l10n.commonShare, () => _share(e)),
        // Menu ⋮ : signaler (pas les gestionnaires).
        if (!e.canManage && !e.isDraft)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Material(
              color: Colors.black.withAlpha(90),
              shape: const CircleBorder(),
              child: PopupMenuButton<String>(
                tooltip: context.l10n.eventsMoreOptions,
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                onSelected: (a) => _manage(e, a),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'report',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(e.hasReported ? context.l10n.eventsAlreadyReported : context.l10n.commonReport),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: EventCoverCarousel(
          event: e,
          overlay: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Colors.transparent, Color(0x55000000)],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ── Résumé ───────────────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({required this.event});
  final ChristianEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secondarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(eventTypeIcon(e.type), size: 13, color: AppColors.secondaryDark),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                    e.type.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryDark,
                      fontFamily: AppFonts.family,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                    ),
                  ),
                ],
              ),
            ),
            EventPhaseBadge(event: e),
            if (e.isLiveNow) const EventLiveBadge(),
            ...EventFlagBadge.forEvent(e),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          e.title,
          style: AppTextStyles.h3.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.calendar_month_rounded,
          title: eventScheduleText(e),
          subtitle: !e.dateTbd && e.startsAt != null && e.endsAt != null &&
                  e.endsAt!.difference(e.startsAt!).inHours >= 24
              ? context.l10n.eventsDateRangeDays(formatEventDay(e.startsAt!), formatEventDay(e.endsAt!))
              : null,
          below: e.isPostponed && e.originalStartsAt != null ? EventOriginalDate(event: e) : null,
        ),
        if (e.place != null) _InfoRow(icon: Icons.place_rounded, title: e.place!),
        _InfoRow(
          icon: Icons.apartment_rounded,
          title: e.organizer.displayName,
          subtitle: e.organizer.isReliable ? context.l10n.eventsReliableOrganizer : context.l10n.eventsOrganizer,
          trailing: e.organizer.isVerified
              ? Tooltip(
                  message: context.l10n.eventsVerifiedOrganization,
                  child: const Icon(Icons.verified_rounded, size: 18, color: AppColors.primary),
                )
              : null,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, this.subtitle, this.trailing, this.below});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Ligne supplémentaire (ancienne date barrée d'un événement reporté).
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                    if (trailing != null) ...[const SizedBox(width: 4), trailing!],
                  ],
                ),
                if (subtitle != null)
                  Text(subtitle!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ?below,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Direct ───────────────────────────────────────────────────────────────────

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.event});
  final ChristianEvent event;

  @override
  Widget build(BuildContext context) {
    final live = event.live!;
    final onAir = live.isOnAir;
    // Gestionnaires de l'événement : le studio ; le public regarde toujours (même en préparation).
    final path = event.canManage ? '/lives/${live.id}/studio' : '/lives/${live.id}';
    return Material(
      color: onAir ? const Color(0xFFE11D48) : const Color(0xFF475467),
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => context.push(path),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(onAir ? Icons.sensors_rounded : Icons.videocam_outlined, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      onAir ? context.l10n.eventsLiveOnAir : context.l10n.eventsLivePreparing,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.family,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      onAir
                          ? (event.canManage ? context.l10n.eventsOpenStudio : context.l10n.eventsJoinBroadcast)
                          : context.l10n.eventsLivePrivateUntilOnAir,
                      style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Direct YouTube ───────────────────────────────────────────────────────────

class _YouTubeLiveCard extends StatelessWidget {
  const _YouTubeLiveCard({required this.event});
  final ChristianEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = switch (event.phase) {
      EventPhase.upcoming => l10n.eventsYoutubeLiveUpcoming,
      EventPhase.ongoing => l10n.eventsYoutubeLiveOngoing,
      EventPhase.past => l10n.eventsYoutubeLivePast,
    };
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
            child: Row(
              children: [
                const Icon(Icons.smart_display_rounded, color: Color(0xFFE11D48), size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.eventsYoutubeLiveTitle,
                          style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary, fontWeight: FontWeight.w800)),
                      Text(subtitle,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(event.youtubeLiveUrl!),
                      mode: LaunchMode.externalApplication),
                  child: Text(l10n.eventsOpenOnYoutube),
                ),
              ],
            ),
          ),
          // Miniature : le direct s'ouvre dans sa page (vue « YouTube », plein écran, discussion).
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Material(
              color: Colors.black,
              child: InkWell(
                key: const ValueKey('event-youtube-watch'),
                onTap: () => context.push('/events/${event.id}/live'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://i.ytimg.com/vi/${event.youtubeLiveId}/hqdefault.jpg', // i18n-ignore
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    Container(color: Colors.black.withAlpha(70)),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white),
                          const SizedBox(height: 6),
                          Text(context.l10n.eventsWatchLive,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Participation ────────────────────────────────────────────────────────────

class _ParticipationCard extends StatelessWidget {
  const _ParticipationCard({required this.event, required this.busy, required this.onAnswer});

  final ChristianEvent event;
  final bool busy;
  final ValueChanged<EventParticipation> onAnswer;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final mine = e.myParticipation;
    final open = e.acceptsParticipation;

    Widget choice(EventParticipation value, IconData icon, String label) {
      final selected = mine == value;
      final color = value == EventParticipation.going ? AppColors.primary : AppColors.textSecondary;
      return Expanded(
        child: OutlinedButton.icon(
          onPressed: !open || busy ? null : () => onAnswer(value),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            backgroundColor: selected ? color : null,
            foregroundColor: selected ? Colors.white : color,
            side: BorderSide(color: selected ? color : AppColors.border, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            textStyle: const TextStyle(fontFamily: AppFonts.family, fontWeight: FontWeight.w700),
          ),
          icon: Icon(selected ? Icons.check_circle_rounded : icon, size: 19),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  !open
                      ? (e.isCancelled ? context.l10n.eventsIsCancelled : context.l10n.eventsIsOver)
                      : mine == EventParticipation.going
                          ? context.l10n.eventsYouAreGoing
                          : mine == EventParticipation.notGoing
                              ? context.l10n.eventsYouAreNotGoing
                              : context.l10n.eventsAreYouGoing,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (busy)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            e.goingCount == 0
                ? context.l10n.eventsBeFirstToAnswer
                : context.l10n.eventsGoingCount(e.goingCount),
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          if (open) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                choice(EventParticipation.going, Icons.event_available_rounded, context.l10n.eventsGoing),
                const SizedBox(width: 10),
                choice(EventParticipation.notGoing, Icons.event_busy_rounded, context.l10n.eventsNotGoing),
              ],
            ),
            if (mine != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  context.l10n.eventsTapAgainToRemove,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.5),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Gestion ──────────────────────────────────────────────────────────────────

class _ManagerPanel extends StatelessWidget {
  const _ManagerPanel({required this.event, required this.onAction});

  final ChristianEvent event;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final e = event;
    // Direct : lien YouTube saisi dans le formulaire (plus de direct dans l'application).
    final canLive = e.youtubeLiveId == null && e.phase != EventPhase.past;
    final l10n = context.l10n;
    final actions = <(IconData, String, String, Color?)>[
      (Icons.edit_rounded, l10n.commonEdit, 'edit', null),
      if (canLive) (Icons.smart_display_outlined, l10n.eventsAddYoutubeLive, 'edit', const Color(0xFFE11D48)),
      (Icons.post_add_rounded, l10n.profilePublishTestimony, 'testimony', null),
      (Icons.groups_rounded, l10n.eventsParticipantsCount(e.goingCount), 'participants', null),
      (Icons.manage_accounts_outlined,
          l10n.eventsManagersTitle(e.managers.length, ChristianEvent.maxManagers), 'managers', null),
      // Reporter / annuler : événement publié (ou reporté) pas encore terminé.
      if (e.canChangeSchedule) ...[
        (Icons.event_repeat_rounded, l10n.eventsPostpone, 'postpone', null),
        (Icons.event_busy_rounded, l10n.eventsCancelEvent, 'cancel', AppColors.danger),
      ],
      // Supprimer : organisateur, gestionnaires de l'organisation, admin (ni les co-gestionnaires ni les modérateurs).
      if (e.canDelete) (Icons.delete_outline_rounded, l10n.commonDelete, 'delete', AppColors.danger),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  e.isDraft ? l10n.eventsManageDraft : l10n.eventsManagePage,
                  style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (icon, label, action, color) in actions)
                ActionChip(
                  avatar: Icon(icon, size: 17, color: color ?? AppColors.primary),
                  label: Text(label),
                  labelStyle: TextStyle(
                    color: color ?? AppColors.textPrimary,
                    fontFamily: AppFonts.family,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  backgroundColor: AppColors.surface,
                  onPressed: () => onAction(action),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.eventsManageHelp,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _ParticipantsSheet extends ConsumerWidget {
  const _ParticipantsSheet({required this.event});
  final ChristianEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: FutureBuilder<EventPage<EventAttendee>>(
          future: ref.read(eventsRepositoryProvider).participants(event.id),
          builder: (context, snap) {
            final items = snap.data?.items ?? const <EventAttendee>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    context.l10n.eventsParticipantsCount(event.goingCount),
                    style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (snap.connectionState != ConnectionState.done)
                  const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
                else if (snap.hasError)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(snap.error is EventFailure ? '${snap.error}' : context.l10n.commonError,
                        textAlign: TextAlign.center),
                  )
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(context.l10n.eventsNoParticipants,
                        textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: _Avatar(person: items[i].person, size: 38),
                        title: Text(items[i].person.displayName),
                        subtitle: items[i].respondedAt == null
                            ? null
                            : Text(context.l10n.eventsRespondedOn(formatEventDay(items[i].respondedAt!))),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Invités, description ─────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      );
}

class _Guests extends StatelessWidget {
  const _Guests({required this.guests});
  final List<EventGuest> guests;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Hauteur suivant la taille du texte (accessibilité).
      height: MediaQuery.textScalerOf(context).scale(122),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: guests.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final g = guests[i];
          final initials = g.name
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join();
          return Container(
            width: 120,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.sunSoft,
                  child: Text(initials,
                      style: const TextStyle(
                          color: AppColors.sunText, fontWeight: FontWeight.w800, fontFamily: AppFonts.family)),
                ),
                const SizedBox(height: 6),
                Text(g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                if (g.role != null)
                  Text(g.role!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Description extends StatefulWidget {
  const _Description({required this.text});
  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 280;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded || !long ? null : 6,
          overflow: _expanded || !long ? null : TextOverflow.fade,
          style: AppTextStyles.bodyMedium.copyWith(height: 1.5, color: AppColors.textPrimary),
        ),
        if (long)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(_expanded ? context.l10n.commonSeeLess : context.l10n.eventsReadMore),
          ),
      ],
    );
  }
}

// ── Onglets : témoignages / commentaires ─────────────────────────────────────

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.testimonies,
    required this.comments,
    required this.onChanged,
  });

  final _Tab selected;
  final int testimonies;
  final int comments;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_Tab>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: _Tab.testimonies,
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(context.l10n.eventsTabTestimonies(testimonies)),
        ),
        ButtonSegment(
          value: _Tab.comments,
          icon: const Icon(Icons.forum_outlined, size: 18),
          label: Text(context.l10n.eventsTabComments(comments)),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _TestimoniesSliver extends ConsumerWidget {
  const _TestimoniesSliver({required this.event, required this.onPublish});

  final ChristianEvent event;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventTestimoniesProvider(event.id));
    return switch (async) {
      AsyncValue(:final value?) when value.isEmpty => SliverToBoxAdapter(
          child: _Empty(
            icon: Icons.auto_awesome_outlined,
            text: event.canManage
                ? context.l10n.eventsNoTestimoniesManager
                : context.l10n.eventsNoTestimoniesPublic,
            action: event.canManage
                ? TextButton.icon(
                    onPressed: onPublish,
                    icon: const Icon(Icons.post_add_rounded),
                    label: Text(context.l10n.profilePublishTestimony),
                  )
                : null,
          ),
        ),
      AsyncValue(:final value?) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          sliver: SliverList.separated(
            itemCount: value.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => CompactTestimonyTile(testimony: value[i]),
          ),
        ),
      AsyncValue(:final error?) => SliverToBoxAdapter(
          child: _Empty(
            icon: Icons.wifi_off_rounded,
            text: error is EventFailure ? error.message : context.l10n.eventsTestimoniesLoadError,
          ),
        ),
      _ => const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
        ),
    };
  }
}

/// Formulaire « Racontez ce que Dieu a fait pour vous » (témoignage d'un participant sous l'événement).
Future<void> openEventComposer(BuildContext context, WidgetRef ref, ChristianEvent event) async {
  if (!await requireAccount(context, ref, reason: context.l10n.eventsReasonComment)) return;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _Composer(eventId: event.id),
  );
}

class _CommentsSliver extends ConsumerWidget {
  const _CommentsSliver({required this.event});
  final ChristianEvent event;

  Future<void> _compose(BuildContext context, WidgetRef ref) => openEventComposer(context, ref, event);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventCommentsProvider(event.id));
    final canWrite = event.commentsEnabled || event.canManage;

    final composer = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 12),
      child: canWrite
          ? Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () => _compose(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(context.l10n.eventsCommentPrompt,
                            style: const TextStyle(color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Text(context.l10n.eventsCommentsClosed,
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
    );

    return switch (async) {
      AsyncValue(:final value?) => SliverList.builder(
          itemCount: value.items.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) return composer;
            if (i == value.items.length + 1) {
              if (value.items.isEmpty) {
                return _Empty(
                  icon: Icons.forum_outlined,
                  text: context.l10n.eventsNoComments,
                );
              }
              return value.hasMore
                  ? Center(
                      child: TextButton(
                        onPressed: () => ref.read(eventCommentsProvider(event.id).notifier).loadMore(),
                        child: value.loadingMore
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(context.l10n.eventsMoreComments),
                      ),
                    )
                  : const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 10),
              child: _CommentCard(event: event, comment: value.items[i - 1]),
            );
          },
        ),
      AsyncValue(:final error?) => SliverToBoxAdapter(
          child: _Empty(
            icon: Icons.wifi_off_rounded,
            text: error is EventFailure ? error.message : context.l10n.eventsCommentsLoadError,
          ),
        ),
      _ => const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
        ),
    };
  }
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.eventId});
  final String eventId;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  /// Saisie avec mentions « @ » : envoie les jetons `@[Nom](user:id)`.
  final _text = MentionEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_text.text.trim().length < 2 || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final (:error, :queued) = await ref.read(eventCommentsProvider(widget.eventId).notifier).add(_text.encodedText);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(error)));
      return;
    }
    // Hors connexion : gardé sur le téléphone, envoyé au retour du réseau.
    if (queued) showQueuedSnack(context);
    Navigator.pop(context);
    if (queued) return;
    messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating, content: Text(context.l10n.eventsCommentThanks)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.publishYourTestimony, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            context.l10n.eventsComposerHelp,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          MentionTextField(
            controller: _text,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            maxLength: 3000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: context.l10n.eventsComposerHint),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _text.text.trim().length < 2 || _sending ? null : _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppColors.primary,
            ),
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(context.l10n.commonPublish),
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends ConsumerWidget {
  const _CommentCard({required this.event, required this.comment});

  final ChristianEvent event;
  final EventComment comment;

  Future<void> _promote(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String title, String? category})>(
      context: context,
      builder: (_) => _PromoteDialog(comment: comment),
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final (err, ok) = await ref
        .read(eventCommentsProvider(event.id).notifier)
        .promote(comment, title: result.title, category: result.category);
    messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(err ?? ok!)));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.eventsDeleteCommentTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final deleted = context.l10n.eventsCommentDeleted;
    final err = await ref.read(eventCommentsProvider(event.id).notifier).delete(comment);
    messenger.showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(err ?? deleted)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = comment;
    final promoted = c.testimonyId != null;
    // Auteur, gestionnaires de l'événement ou administrateur (`canDelete` de l'API).
    final canDelete = c.isMine || c.canDelete || event.canManage;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: promoted ? AppColors.sun : AppColors.border, width: promoted ? 1.4 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(person: c.user, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(c.user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ),
                    if (c.user.isVerified) ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                    ],
                    if (c.createdAt != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('· ${c.isPending ? context.l10n.outboxPendingBadge : _ago(c.createdAt!)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Mentions « @Nom » cliquables (docs serveur fonctionnalites/mentions.md).
                MentionText(c.body, mentions: c.mentions, style: AppTextStyles.bodyMedium.copyWith(height: 1.45)),
                const SizedBox(height: 2),
                CommentLikeButton(
                  comment: CommentRef.event(event.id, c.id),
                  initialCount: c.likesCount,
                  initialLiked: c.isLikedByMe,
                ),
                if (promoted) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => context.push('/testimony/${c.testimonyId}'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sunSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.sunText),
                          const SizedBox(width: 4),
                          Text(context.l10n.eventsSavedAsTestimony,
                              style: const TextStyle(
                                  color: AppColors.sunText, fontWeight: FontWeight.w700, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ),
                ] else if (event.canManage) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _promote(context, ref),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                    label: Text(context.l10n.eventsSaveAsTestimony),
                  ),
                ],
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              tooltip: context.l10n.commonDelete,
              visualDensity: VisualDensity.compact,
              onPressed: () => _delete(context, ref),
              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

/// Titre (et catégorie) du témoignage créé à partir d'un commentaire.
class _PromoteDialog extends ConsumerStatefulWidget {
  const _PromoteDialog({required this.comment});
  final EventComment comment;

  @override
  ConsumerState<_PromoteDialog> createState() => _PromoteDialogState();
}

class _PromoteDialogState extends ConsumerState<_PromoteDialog> {
  final _title = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesListProvider);
    return AlertDialog(
      title: Text(context.l10n.eventsSaveAsTestimony),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.eventsPromoteHelp(widget.comment.user.displayName),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l10n.prophecyTitleLabel,
                hintText: context.l10n.eventsPromoteTitleHint,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.l10n.exploreFilterCategory),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.slug, child: Text(c.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, (title: _title.text, category: _category)),
          child: Text(context.l10n.commonSave),
        ),
      ],
    );
  }
}

// ── Petits éléments ──────────────────────────────────────────────────────────

String _ago(DateTime d) {
  final diff = DateTime.now().difference(d);
  final l = L10n.current;
  if (diff.inMinutes < 1) return l.timeJustNow;
  if (diff.inMinutes < 60) return l.eventsAgoMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l.eventsAgoHours(diff.inHours);
  if (diff.inDays < 30) return l.eventsAgoDays(diff.inDays);
  return formatEventDay(d);
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.person, this.size = 36});
  final EventPerson person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = person.avatarUrl;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(person.initials ?? '?',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: size * 0.36))
          : null,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textSecondary.withAlpha(150)),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ?action,
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_busy_rounded, size: 52, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(
              onPressed: () => context.canPop() ? context.pop() : context.go('/events'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
