// Page d'un événement : report / annulation (gestionnaires), signalement,
// sondage d'après l'événement (« A-t-il vraiment eu lieu ? »), bandeaux d'état
// et bloc des modérateurs. Doc serveur : docs/fonctionnalites/evenements.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/events_repository.dart';
import '../models/event_models.dart';
import '../providers/events_providers.dart';
import 'event_widgets.dart';

const _postponedColor = Color(0xFFB54708);

// ── Bandeaux d'état ──────────────────────────────────────────────────────────

/// Bandeaux : masqué par la modération, annulé (motif), reporté (ancienne date
/// barrée, nouvelle date ou « date à confirmer »), non confirmé.
class EventStatusBanners extends StatelessWidget {
  const EventStatusBanners({required this.event, super.key});

  final ChristianEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final reason = e.statusReason == null ? '' : ' Motif : ${e.statusReason}';
    final banners = <Widget>[
      if (e.isHidden)
        _Banner(
          icon: Icons.visibility_off_outlined,
          color: const Color(0xFF475467),
          title: 'Masqué par la modération',
          text: e.hiddenReason ?? "L'événement n'apparaît plus au public.",
        ),
      if (e.isCancelled)
        _Banner(
          icon: Icons.event_busy_rounded,
          color: AppColors.danger,
          title: 'Événement annulé',
          text: 'Les réponses ne sont plus possibles.$reason',
        )
      else if (e.isPostponed)
        _Banner(
          icon: Icons.event_repeat_rounded,
          color: _postponedColor,
          title: e.dateTbd ? 'Reporté — date à confirmer' : 'Événement reporté',
          text: [
            if (!e.dateTbd) 'Nouvelle date : ${formatEventRange(e.startsAt, e.endsAt)}.',
            'Votre réponse « Je participe » est conservée.',
            if (e.statusReason != null) 'Motif : ${e.statusReason}',
          ].join(' '),
          footer: e.originalStartsAt == null
              ? null
              : Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Date initiale : '),
                    TextSpan(
                      text: formatEventRange(e.originalStartsAt, e.originalEndsAt),
                      style: const TextStyle(decoration: TextDecoration.lineThrough),
                    ),
                  ]),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
        ),
      if (e.isUnconfirmed)
        const _Banner(
          icon: Icons.help_outline_rounded,
          color: Color(0xFFB42318),
          title: 'Non confirmé',
          text: "La majorité des personnes qui ont répondu au sondage disent que cet "
              "événement n'a pas eu lieu. La modération vérifie.",
        ),
    ];
    if (banners.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in banners) Padding(padding: const EdgeInsets.only(top: 12), child: b),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.title, required this.text, this.footer});

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                if (footer != null) ...[const SizedBox(height: 4), footer!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Report et annulation (gestionnaires) ─────────────────────────────────────

/// Feuille « Reporter l'événement » : nouvelles dates ou « date à confirmer »,
/// motif facultatif. Renvoie true si le report est enregistré.
Future<bool?> showPostponeSheet(BuildContext context, ChristianEvent event) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _PostponeSheet(event: event),
    );

class _PostponeSheet extends ConsumerStatefulWidget {
  const _PostponeSheet({required this.event});
  final ChristianEvent event;

  @override
  ConsumerState<_PostponeSheet> createState() => _PostponeSheetState();
}

class _PostponeSheetState extends ConsumerState<_PostponeSheet> {
  bool _tbd = false;
  DateTime? _start;
  DateTime? _end;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? initial) async {
    final now = DateTime.now();
    final base = initial ?? now.add(const Duration(days: 7));
    final day = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (!_tbd && (_start == null || _end == null)) {
      setState(() => _error = 'Choisissez les nouvelles dates, ou « Date à confirmer ».');
      return;
    }
    if (!_tbd && _end!.isBefore(_start!)) {
      setState(() => _error = 'La fin doit être après le début.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref.read(eventDetailProvider(widget.event.id).notifier).apply((repo) => repo.postpone(
          widget.event.id,
          startsAt: _tbd ? null : _start,
          endsAt: _tbd ? null : _end,
          reason: _reason.text,
        ));
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget dateButton(String label, DateTime? value, ValueChanged<DateTime> onPicked) => OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  final d = await _pick(value);
                  if (d != null) setState(() => onPicked(d));
                },
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text(
            value == null ? label : '$label : ${formatEventDay(value)} '
                '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.screen, 16, AppSpacing.screen, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Reporter l'événement", style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
              const SizedBox(height: 6),
              Text('Les personnes qui participent sont prévenues. La date initiale reste affichée, barrée.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _tbd,
                onChanged: _busy ? null : (v) => setState(() => _tbd = v),
                title: const Text('Date à confirmer'),
                subtitle: const Text('La nouvelle date sera annoncée plus tard.'),
              ),
              if (!_tbd) ...[
                dateButton('Nouveau début', _start, (d) {
                  _start = d;
                  if (_end == null || _end!.isBefore(d)) {
                    final length = widget.event.endsAt != null && widget.event.startsAt != null
                        ? widget.event.endsAt!.difference(widget.event.startsAt!)
                        : const Duration(hours: 3);
                    _end = d.add(length);
                  }
                }),
                const SizedBox(height: 8),
                dateButton('Nouvelle fin', _end, (d) => _end = d),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _reason,
                maxLength: 500,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Motif (facultatif)'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                ),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.event_repeat_rounded),
                label: const Text('Reporter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialogue « Annuler l'événement » (motif facultatif). Renvoie le motif, ou null si abandon.
Future<String?> showCancelEventDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Annuler l'événement ?"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('La page reste visible avec la mention « Annulé ». '
                'Les personnes qui participent sont prévenues.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Motif (facultatif)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text("Annuler l'événement"),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

// ── Signalement ──────────────────────────────────────────────────────────────

/// Feuille « Signaler l'événement ». Renvoie le message de confirmation, ou null.
Future<String?> showReportEventSheet(BuildContext context, ChristianEvent event) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ReportSheet(event: event),
    );

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.event});
  final ChristianEvent event;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  EventReportReason? _reason;
  final _comment = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Choisissez la raison du signalement.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await ref.read(eventsRepositoryProvider).report(widget.event.id, reason, comment: _comment.text);
      if (!mounted) return;
      ref.invalidate(eventDetailProvider(widget.event.id));
      Navigator.pop(context, msg);
    } on EventFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.screen, 16, AppSpacing.screen, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Signaler l'événement", style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
              const SizedBox(height: 4),
              Text('Votre signalement est anonyme pour l\'organisateur et examiné par la modération.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              RadioGroup<EventReportReason>(
                groupValue: _reason,
                onChanged: (v) {
                  if (!_busy) setState(() => _reason = v);
                },
                child: Column(
                  children: [
                    for (final r in EventReportReason.values)
                      RadioListTile<EventReportReason>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: r,
                        title: Text(r.label),
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _comment,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Commentaire (facultatif)'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                ),
              FilledButton(
                onPressed: _busy ? null : _send,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Envoyer le signalement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sondage d'après l'événement ──────────────────────────────────────────────

/// Bloc « Votre avis » d'un événement terminé : résultats publics, formulaire
/// (a-t-il eu lieu ? note 1-5, avis), puis la liste des avis.
class EventSurveyCard extends ConsumerStatefulWidget {
  const EventSurveyCard({required this.event, this.onLoginRequired, super.key});

  final ChristianEvent event;

  /// Invité : demander la connexion (true si connecté ensuite).
  final Future<bool> Function()? onLoginRequired;

  @override
  ConsumerState<EventSurveyCard> createState() => _EventSurveyCardState();
}

class _EventSurveyCardState extends ConsumerState<EventSurveyCard> {
  EventAttendance? _attended;
  int? _rating;
  late final TextEditingController _body;
  bool _editing = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final mine = widget.event.survey.mine;
    _attended = mine?.attended;
    _rating = mine?.rating;
    _body = TextEditingController(text: mine?.body ?? '');
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final attended = _attended;
    if (attended == null) {
      setState(() => _error = "Dites-nous si l'événement a eu lieu.");
      return;
    }
    if (attended == EventAttendance.yes && _rating == null) {
      setState(() => _error = 'Donnez une note de 1 à 5.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref.read(eventDetailProvider(widget.event.id).notifier).apply(
          (repo) => repo.review(widget.event.id, attended, rating: _rating, body: _body.text),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) _editing = false;
    });
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Merci pour votre avis !')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final s = e.survey;
    final mine = s.mine;
    final showForm = s.canAnswer && (mine == null || _editing);

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
              const Icon(Icons.how_to_vote_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Votre avis',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.total == 0 ? 'Aucun avis pour le moment.' : s.summary,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          if (e.canManage)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Les organisateurs et gestionnaires ne répondent pas au sondage de leur propre événement.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.5),
              ),
            )
          else if (showForm) ...[
            const SizedBox(height: 12),
            Text("L'événement a-t-il eu lieu ?",
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
            RadioGroup<EventAttendance>(
              groupValue: _attended,
              onChanged: (v) {
                if (_busy) return;
                setState(() {
                  _attended = v;
                  if (v != EventAttendance.yes) _rating = null;
                });
              },
              child: Column(
                children: [
                  for (final a in EventAttendance.values)
                    RadioListTile<EventAttendance>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: a,
                      title: Text(a.label),
                    ),
                ],
              ),
            ),
            if (_attended == EventAttendance.yes) ...[
              Text('Votre note', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              EventStarPicker(value: _rating, onChanged: _busy ? null : (v) => setState(() => _rating = v)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _body,
              maxLength: 2000,
              maxLines: 4,
              minLines: 2,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Votre avis (facultatif)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
              ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(mine == null ? 'Envoyer mon avis' : 'Enregistrer'),
            ),
          ] else if (mine != null) ...[
            const SizedBox(height: 10),
            Text(
              'Votre réponse : ${mine.attended.label}${mine.rating != null ? ' · ${mine.rating}/5' : ''}',
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
            if (s.canAnswer && mine.canEdit) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier mon avis'),
                ),
              ),
              if (mine.editableUntil != null)
                Text("Modifiable jusqu'au ${formatEventDay(mine.editableUntil!)}.",
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.5)),
            ],
          ] else if (s.open && widget.onLoginRequired != null && !s.canAnswer) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => widget.onLoginRequired!(),
              child: const Text('Se connecter pour donner son avis'),
            ),
          ],
          if (s.total > 0) ...[
            const SizedBox(height: 10),
            EventReviewsList(eventId: e.id),
          ],
        ],
      ),
    );
  }
}

/// Note de 1 à 5 étoiles (sélection).
class EventStarPicker extends StatelessWidget {
  const EventStarPicker({required this.value, required this.onChanged, super.key});

  final int? value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i sur 5',
            visualDensity: VisualDensity.compact,
            onPressed: onChanged == null ? null : () => onChanged!(i),
            icon: Icon(
              (value ?? 0) >= i ? Icons.star_rounded : Icons.star_outline_rounded,
              color: AppColors.secondary,
              size: 30,
            ),
          ),
      ],
    );
  }
}

/// Avis publics (première page).
class EventReviewsList extends ConsumerWidget {
  const EventReviewsList({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(eventReviewsProvider(eventId)).value ?? const <EventReviewItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        for (final r in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(r.user.displayName,
                        style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                    if (r.rating != null)
                      Semantics(
                        label: '${r.rating} sur 5',
                        excludeSemantics: true,
                        child: Text('★' * r.rating! + '☆' * (5 - r.rating!),
                            style: const TextStyle(color: AppColors.secondary, fontSize: 12)),
                      ),
                    Text(r.attended.label,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.5)),
                  ],
                ),
                if (r.body != null) ...[
                  const SizedBox(height: 2),
                  Text(r.body!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ── Modération ───────────────────────────────────────────────────────────────

/// Bloc des modérateurs : signalements, fiabilité de l'organisateur, masquer /
/// rétablir / rejeter les signalements.
class EventModerationCard extends ConsumerWidget {
  const EventModerationCard({required this.event, super.key});

  final ChristianEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = event.moderation!;
    Future<void> run(String action) async {
      final messenger = ScaffoldMessenger.of(context);
      final err = await ref
          .read(eventDetailProvider(event.id).notifier)
          .apply((repo) => repo.moderate(event.id, action));
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(err ??
            switch (action) {
              'hide' => 'Événement masqué.',
              'restore' => 'Événement rétabli.',
              _ => 'Signalements classés.',
            }),
      ));
    }

    Widget stat(String label, int value, Color color) => Expanded(
          child: Column(
            children: [
              Text('$value', style: AppTextStyles.h3.copyWith(color: color, fontWeight: FontWeight.w800)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        );

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
          Text('Modération', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            '${m.reportCount} signalement${m.reportCount > 1 ? 's' : ''}'
            '${m.pendingReports > 0 ? ' · ${m.pendingReports} à traiter' : ''}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Text("Fiabilité de l'organisateur (${m.total} événement${m.total > 1 ? 's' : ''})",
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              stat('Confirmés', m.confirmed, AppColors.success),
              stat('Non confirmés', m.unconfirmed, m.unconfirmed > 0 ? AppColors.danger : AppColors.textPrimary),
              stat('Signalés', m.reported, m.reported > 0 ? _postponedColor : AppColors.textPrimary),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (event.isHidden)
                OutlinedButton.icon(
                  onPressed: () => run('restore'),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Rétablir'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => run('hide'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.visibility_off_outlined, size: 18),
                  label: const Text('Masquer'),
                ),
              if (m.pendingReports > 0 || event.isUnconfirmed)
                TextButton.icon(
                  onPressed: () => run('dismiss'),
                  icon: const Icon(Icons.done_rounded, size: 18),
                  label: const Text('Rejeter les signalements'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
