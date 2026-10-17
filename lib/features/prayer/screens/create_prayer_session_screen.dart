import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/prayer_repository.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';
import '../widgets/prayer_widgets.dart';

/// Programmer (ou modifier, [sessionId]) une session de prière. Tout compte connecté peut
/// programmer ; [eventId] : session d'un événement (réservé à ses gestionnaires, vérifié par le serveur).
class CreatePrayerSessionScreen extends ConsumerStatefulWidget {
  const CreatePrayerSessionScreen({this.sessionId, this.eventId, super.key});

  final String? sessionId;
  final String? eventId;

  @override
  ConsumerState<CreatePrayerSessionScreen> createState() => _CreatePrayerSessionScreenState();
}

class _CreatePrayerSessionScreenState extends ConsumerState<CreatePrayerSessionScreen> {
  static const durations = [15, 30, 45, 60, 90, 120, 180, 240, 360, 480];

  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _topic = TextEditingController();
  PrayerSessionDraft? _draft;
  bool _saving = false;

  bool get _editing => widget.sessionId != null;

  @override
  void initState() {
    super.initState();
    if (!_editing) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      _draft = PrayerSessionDraft(
        startsAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 20),
        eventId: widget.eventId,
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _topic.dispose();
    super.dispose();
  }

  void _load(PrayerSession s) {
    if (_draft != null) return;
    _draft = PrayerSessionDraft.from(s);
    _title.text = s.title;
    _description.text = s.description ?? '';
  }

  static String _durationLabel(int m) {
    final l = L10n.current;
    return m < 60
        ? l.prayerDurationMinutes(m)
        : (m % 60 == 0 ? l.prayerDurationHours(m ~/ 60) : l.prayerDurationHoursMinutes(m ~/ 60, m % 60));
  }

  Future<void> _pickDate() async {
    final d = _draft!;
    final picked = await showDatePicker(
      context: context,
      initialDate: d.startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => d.startsAt = DateTime(picked.year, picked.month, picked.day, d.startsAt.hour, d.startsAt.minute));
    }
  }

  Future<void> _pickTime() async {
    final d = _draft!;
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(d.startsAt));
    if (picked != null) {
      setState(() => d.startsAt = DateTime(d.startsAt.year, d.startsAt.month, d.startsAt.day, picked.hour, picked.minute));
    }
  }

  void _addTopic() {
    final t = _topic.text.trim();
    if (t.isEmpty || _draft!.topics.length >= 10) return;
    setState(() {
      _draft!.topics.add(t.length > 150 ? t.substring(0, 150) : t);
      _topic.clear();
    });
  }

  Future<void> _save() async {
    final d = _draft;
    if (d == null || _saving || !(_form.currentState?.validate() ?? false)) return;
    if (!_editing && d.startsAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.prayerSessionMustBeFuture)));
      return;
    }
    if (_topic.text.trim().isNotEmpty) _addTopic();
    d
      ..title = _title.text
      ..description = _description.text;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(prayerRepositoryProvider).saveSession(d, id: widget.sessionId);
      ref.invalidate(prayerSessionListProvider);
      if (_editing) ref.read(prayerSessionProvider(saved.id).notifier).replace(saved);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? context.l10n.prayerSessionUpdated : context.l10n.prayerSessionScheduled)),
      );
      if (_editing) {
        context.pop(saved);
      } else {
        context.pushReplacement('/prayer-sessions/${saved.id}');
      }
    } on PrayerFailure catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editing && _draft == null) {
      final async = ref.watch(prayerSessionProvider(widget.sessionId!));
      if (async.value case final s?) {
        _load(s);
      } else {
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.prayerEditSession)),
          body: Center(
            child: async.hasError
                ? Text(async.error is PrayerFailure ? (async.error! as PrayerFailure).message : context.l10n.prayerSessionNotFound)
                : const CircularProgressIndicator(),
          ),
        );
      }
    }
    final d = _draft!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editing ? context.l10n.prayerEditSession : context.l10n.prayerScheduleSession),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(
              context.l10n.prayerSessionFormIntro,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (d.eventId != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                const Icon(Icons.event_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(context.l10n.prayerSessionLinkedToEvent,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                ),
              ]),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _title,
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  labelText: context.l10n.prayerSessionTitleLabel, hintText: context.l10n.prayerSessionTitleHint),
              validator: (v) => (v?.trim().isEmpty ?? true) ? context.l10n.prayerSessionTitleRequired : null,
            ),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              maxLength: 3000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: context.l10n.prayerSessionDescriptionLabel),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(context.l10n.prayerSessionTopics, style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (i, t) in d.topics.indexed)
                InputChip(label: Text(t), onDeleted: () => setState(() => d.topics.removeAt(i))),
            ]),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _topic,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _addTopic(),
                  decoration: InputDecoration(hintText: d.topics.length >= 10 ? context.l10n.prayerTopicsMax : context.l10n.prayerAddTopicHint),
                ),
              ),
              IconButton(onPressed: _addTopic, icon: const Icon(Icons.add_circle_outline), tooltip: context.l10n.prayerAddTopicTooltip),
            ]),
            const SizedBox(height: AppSpacing.md),
            Text(context.l10n.prayerWhen, style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(formatPrayerDay(d.startsAt)),
              ),
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(TimeOfDay.fromDateTime(d.startsAt).format(context)),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: durations.contains(d.durationMinutes) ? d.durationMinutes : 60,
              decoration: InputDecoration(labelText: context.l10n.prayerDuration),
              items: [for (final m in durations) DropdownMenuItem(value: m, child: Text(_durationLabel(m)))],
              onChanged: (v) => setState(() => d.durationMinutes = v ?? 60),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(context.l10n.prayerReminderInfo,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            Text(context.l10n.prayerWhoCanSee, style: AppTextStyles.labelMedium),
            RadioGroup<PrayerVisibility>(
              groupValue: d.visibility == PrayerVisibility.followers ? PrayerVisibility.followers : PrayerVisibility.public,
              onChanged: (v) => setState(() => d.visibility = v ?? PrayerVisibility.public),
              child: Column(children: [
                RadioListTile<PrayerVisibility>(
                    value: PrayerVisibility.public,
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.prayerVisibilityPublic)),
                RadioListTile<PrayerVisibility>(
                    value: PrayerVisibility.followers,
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.prayerVisibilityFollowers)),
              ]),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_editing ? context.l10n.commonSave : context.l10n.prayerScheduleTheSession),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
