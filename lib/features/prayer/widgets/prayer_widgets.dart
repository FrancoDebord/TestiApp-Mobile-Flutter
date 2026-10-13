import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/guest_gate.dart' show requireAccount;
import '../../../shared/widgets/mention_text.dart' show MentionText;
import '../../../shared/widgets/organization_badge.dart';
import '../data/prayer_repository.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';

const _days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// « mar. 7 oct., 20:30 » (sans données de langue d'intl).
String formatPrayerDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}, ${two(d.hour)}:${two(d.minute)}';
}

/// Avatar d'une personne (initiales sans photo), ou masque pour une requête anonyme.
class PrayerAvatar extends StatelessWidget {
  const PrayerAvatar({this.person, this.radius = 20, super.key});

  final PrayerPerson? person;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = person;
    if (p == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.border,
        child: Icon(Icons.visibility_off_rounded, size: radius, color: AppColors.textSecondary),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
      child: p.avatarUrl == null
          ? Text(p.initials,
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontSize: radius * 0.7))
          : null,
    );
  }
}

/// Pastille « Exaucée ».
class PrayerAnsweredBadge extends StatelessWidget {
  const PrayerAnsweredBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.successSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
          const SizedBox(width: 4),
          Text('Exaucée', style: AppTextStyles.labelSmall.copyWith(color: AppColors.success)),
        ]),
      );
}

/// Carte d'une requête de prière, réutilisable (liste, fils « Pour vous » / « Mon fil »,
/// page d'un événement). « Je prie » fonctionne directement depuis la carte ;
/// [onChanged] reçoit la requête à jour. Toucher la carte ouvre le détail.
class PrayerRequestFeedCard extends ConsumerStatefulWidget {
  const PrayerRequestFeedCard({
    required this.request,
    this.onChanged,
    this.showEvent = true,
    this.maxLines = 6,
    super.key,
  });

  final PrayerRequest request;
  final ValueChanged<PrayerRequest>? onChanged;
  final bool showEvent;
  final int maxLines;

  @override
  ConsumerState<PrayerRequestFeedCard> createState() => _PrayerRequestFeedCardState();
}

class _PrayerRequestFeedCardState extends ConsumerState<PrayerRequestFeedCard> {
  late PrayerRequest _r = widget.request;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant PrayerRequestFeedCard old) {
    super.didUpdateWidget(old);
    if (old.request != widget.request) _r = widget.request;
  }

  Future<void> _togglePray() async {
    if (_busy) return;
    if (!await requireAccount(context, ref, reason: 'prier pour cette requête')) return;
    final previous = _r;
    final target = !_r.hasPrayed;
    setState(() {
      _busy = true;
      _r = _r.withPrayed(target);
    });
    try {
      final updated = await ref.read(prayerRepositoryProvider).pray(_r.id, prayed: target);
      if (!mounted) return;
      setState(() => _r = updated);
      widget.onChanged?.call(updated);
    } on PrayerFailure catch (e) {
      if (!mounted) return;
      setState(() => _r = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Container(
      decoration: AppShadows.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: () => context.push('/prayer-requests/${r.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PrayerAvatar(person: r.author, radius: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(r.authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary)),
                            ),
                            if (r.author?.isVerified ?? false)
                              OrganizationBadge(isOrganization: r.author!.isOrganization, isVerified: true, size: 14),
                          ]),
                          Text(
                            [
                              'Requête de prière',
                              prayerTimeAgo(r.createdAt),
                              if (r.visibility != PrayerVisibility.public) r.visibility.label,
                              if (r.isAnonymous && r.author != null) 'anonyme',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (r.isAnswered) ...[const SizedBox(width: 6), const PrayerAnsweredBadge()],
                  ],
                ),
                if (r.isHidden) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _HiddenNotice(reason: r.hiddenReason),
                ],
                const SizedBox(height: AppSpacing.md),
                MentionText(r.body,
                    mentions: r.mentions,
                    maxLines: widget.maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.45)),
                if (widget.showEvent && r.event != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    const Icon(Icons.event_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(r.event!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ],
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PrayButton(prayed: r.hasPrayed, count: r.prayerCount, onPressed: r.isHidden ? null : _togglePray),
                    TextButton.icon(
                      onPressed: () => context.push('/prayer-requests/${r.id}'),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: Text('${r.messageCount}'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton « Je prie » (rempli quand la personne prie déjà) avec le compteur.
class PrayButton extends StatelessWidget {
  const PrayButton({required this.prayed, required this.count, this.onPressed, this.large = false, super.key});

  final bool prayed;
  final int count;
  final VoidCallback? onPressed;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final label = Text(count > 0 ? 'Je prie · $count' : 'Je prie');
    const icon = Icon(Icons.volunteer_activism_rounded, size: 18);
    final padding = EdgeInsets.symmetric(horizontal: large ? 18 : 12, vertical: large ? 12 : 6);
    return prayed
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: icon,
            label: label,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: padding,
              visualDensity: large ? null : VisualDensity.compact,
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: icon,
            label: label,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondaryDark,
              side: const BorderSide(color: AppColors.secondary),
              padding: padding,
              visualDensity: large ? null : VisualDensity.compact,
            ),
          );
  }
}

class _HiddenNotice extends StatelessWidget {
  const _HiddenNotice({this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Row(children: [
          const Icon(Icons.visibility_off_rounded, size: 16, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(reason ?? 'Retirée par la modération.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
          ),
        ]),
      );
}

// ── Sessions ──────────────────────────────────────────────────────────────────

/// Pastille de phase d'une session (À venir / En cours / Terminée / Annulée).
class PrayerSessionPhaseBadge extends StatelessWidget {
  const PrayerSessionPhaseBadge({required this.phase, super.key});
  final PrayerSessionPhase phase;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (phase) {
      PrayerSessionPhase.live => (AppColors.danger, AppColors.dangerSoft),
      PrayerSessionPhase.upcoming => (AppColors.primary, AppColors.primarySoft),
      PrayerSessionPhase.cancelled => (AppColors.danger, AppColors.dangerSoft),
      PrayerSessionPhase.ended => (AppColors.textSecondary, AppColors.background),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (phase == PrayerSessionPhase.live) ...[
          Icon(Icons.circle, size: 8, color: fg),
          const SizedBox(width: 4),
        ],
        Text(phase.label, style: AppTextStyles.labelSmall.copyWith(color: fg)),
      ]),
    );
  }
}

/// Carte d'une session de prière.
class PrayerSessionCard extends StatelessWidget {
  const PrayerSessionCard({required this.session, this.onTap, super.key});

  final PrayerSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Container(
      decoration: AppShadows.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: onTap ?? () => context.push('/prayer-sessions/${s.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  PrayerSessionPhaseBadge(phase: s.phase),
                  if (s.isRegistered)
                    _Pill(icon: Icons.check_rounded, label: 'Inscrit', color: AppColors.success, soft: AppColors.successSoft),
                  if (s.visibility == PrayerVisibility.followers)
                    const _Pill(icon: Icons.group_rounded, label: 'Abonnés', color: AppColors.textSecondary, soft: AppColors.background),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Text(s.title, style: AppTextStyles.h4, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (s.description != null) ...[
                  const SizedBox(height: 4),
                  Text(s.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: AppSpacing.md),
                _InfoRow(icon: Icons.schedule_rounded, text: '${formatPrayerDate(s.startsAt)} · ${s.durationMinutes} min'),
                const SizedBox(height: 4),
                _InfoRow(icon: Icons.person_outline_rounded, text: 'Animée par ${s.host.displayName}'),
                const SizedBox(height: 4),
                _InfoRow(
                    icon: Icons.groups_2_outlined,
                    text: '${s.participantCount} ${s.participantCount > 1 ? 'inscrits' : 'inscrit'}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color, required this.soft});
  final IconData icon;
  final String label;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        ),
      ]);
}

// ── Page d'un événement ───────────────────────────────────────────────────────

/// Bloc « Prière » de la page d'un événement : sessions à venir rattachées et
/// dernières requêtes, avec « Confier une requête » (et « Programmer une session »
/// pour ses gestionnaires).
class EventPrayerSection extends ConsumerWidget {
  const EventPrayerSection({required this.eventId, this.canManage = false, super.key});

  final String eventId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(prayerRequestsPageProvider((PrayerRequestScope.event, eventId)));
    final sessions = ref.watch(prayerSessionListProvider((scope: PrayerSessionScope.event, eventId: eventId)));
    final upcoming = (sessions.value?.items ?? const <PrayerSession>[]).where((s) => !s.isOver).take(3).toList();
    final items = requests.value?.items.take(3).toList() ?? const <PrayerRequest>[];
    final total = requests.value?.total ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.volunteer_activism_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 6),
          Expanded(child: Text('Prière', style: AppTextStyles.h4)),
          if (total > 0) Text('$total ${total > 1 ? 'requêtes' : 'requête'}', style: AppTextStyles.bodySmall),
        ]),
        const SizedBox(height: AppSpacing.md),
        for (final s in upcoming) ...[
          PrayerSessionCard(session: s),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final r in items) ...[
          PrayerRequestFeedCard(request: r, showEvent: false, maxLines: 4),
          const SizedBox(height: AppSpacing.md),
        ],
        if (requests.isLoading && items.isEmpty)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          OutlinedButton.icon(
            onPressed: () async {
              if (!await requireAccount(context, ref, reason: 'confier une requête de prière')) return;
              if (context.mounted) context.push('/prayer-requests/new?event=$eventId');
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Confier une requête'),
          ),
          if (canManage)
            TextButton.icon(
              onPressed: () => context.push('/prayer-sessions/new?event=$eventId'),
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Programmer une session'),
            ),
        ]),
      ],
    );
  }
}
