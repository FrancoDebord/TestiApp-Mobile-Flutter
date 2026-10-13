import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/prophecies_repository.dart';
import '../data/prophecy_reminders.dart';
import '../models/prophecy.dart';
import '../providers/prophecies_providers.dart';
import '../widgets/prophecy_widgets.dart';
import 'prophecy_reminder_sheet.dart';

enum _Mode { text, audio }

/// Nouvelle parole ([prophecyId] null) ou modification : date (aujourd'hui par
/// défaut), parole en texte ou en audio, qui l'a donnée, échéance, titre, rappel.
class ProphecyFormScreen extends ConsumerStatefulWidget {
  const ProphecyFormScreen({this.prophecyId, super.key});

  final String? prophecyId;

  @override
  ConsumerState<ProphecyFormScreen> createState() => _ProphecyFormScreenState();
}

class _ProphecyFormScreenState extends ConsumerState<ProphecyFormScreen> {
  final _form = GlobalKey<FormState>();
  ProphecyDraft _draft = ProphecyDraft();
  _Mode _mode = _Mode.text;
  bool _loading = false;
  bool _saving = false;

  // Enregistrement audio
  final _recorder = RecorderController();
  bool _recording = false;
  int _elapsed = 0;
  Timer? _timer;

  bool get _isEdit => widget.prophecyId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) _recorder.stop();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await ref.read(propheciesRepositoryProvider).show(widget.prophecyId!);
      if (!mounted) return;
      setState(() {
        _draft = ProphecyDraft.fromProphecy(p);
        _mode = p.hasAudio && p.bodyText == null ? _Mode.audio : _Mode.text;
        _loading = false;
      });
    } on ProphecyFailure catch (e) {
      _snack(e.message);
      if (mounted) context.pop();
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  // ── Audio ──────────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!await _recorder.checkPermission()) {
      _snack('Autorisez le micro dans les réglages du téléphone.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/parole_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.record(path: path);
    setState(() {
      _recording = true;
      _elapsed = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (path != null) {
        _draft
          ..localAudioPath = path
          ..audioUrl = null
          ..audioDuration = _elapsed;
      }
    });
  }

  void _deleteAudio() => setState(() {
        _draft
          ..localAudioPath = null
          ..audioUrl = null
          ..audioDuration = 0;
      });

  // ── Dates ──────────────────────────────────────────────────────────────────

  Future<void> _pickReceived() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _draft.receivedOn,
      firstDate: DateTime(now.year - 50),
      lastDate: now,
      locale: const Locale('fr'),
      helpText: 'Date de la parole',
    );
    if (d != null) setState(() => _draft.receivedOn = d);
  }

  /// Heure à laquelle la parole a été reçue (facultative).
  Future<void> _pickReceivedTime() async {
    final current = parseClockTime(_draft.receivedTime);
    final t = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: int.parse(current.substring(0, 2)), minute: int.parse(current.substring(3))),
      helpText: 'Heure de la parole',
    );
    if (t != null) {
      setState(() => _draft.receivedTime =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _draft.dueOn ?? now.add(const Duration(days: 365)),
      firstDate: _draft.receivedOn,
      lastDate: DateTime(now.year + 30),
      locale: const Locale('fr'),
      helpText: 'Échéance (facultative)',
    );
    if (d != null) setState(() => _draft.dueOn = d);
  }

  // ── Enregistrement ─────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_recording) await _stopRecording();
    if (!_form.currentState!.validate()) return;
    final hasText = _draft.bodyText.trim().isNotEmpty;
    final hasAudio = _draft.localAudioPath != null || _draft.audioUrl != null;
    if (!hasText && !hasAudio) {
      _snack('Écrivez la parole ou enregistrez-la en audio.');
      return;
    }
    setState(() => _saving = true);
    try {
      final p = await ref.read(propheciesRepositoryProvider).save(_draft, id: widget.prophecyId);
      await ProphecyReminders.apply(p);
      ref.invalidate(propheciesListProvider);
      if (_isEdit) ref.invalidate(prophecyProvider(p.id));
      if (!mounted) return;
      _snack(_isEdit ? 'Parole mise à jour.' : 'Parole gardée dans votre carnet.');
      if (_isEdit) {
        context.pop();
      } else {
        context.pushReplacement('/prophecies/${p.id}');
      }
    } on ProphecyFailure catch (e) {
      _snack(e.message);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier la parole' : 'Nouvelle parole prophétique'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _body(),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.primary,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.bookmark_add_rounded),
                  label: Text(_isEdit ? 'Enregistrer' : 'Garder cette parole'),
                ),
              ),
            ),
    );
  }

  Widget _body() {
    final d = _draft;
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 24),
        children: [
          // ── La parole ─────────────────────────────────────────────────────
          _Card(
            title: 'La parole',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_Mode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _Mode.text, icon: Icon(Icons.edit_note_rounded), label: Text('Texte')),
                    ButtonSegment(value: _Mode.audio, icon: Icon(Icons.mic_rounded), label: Text('Audio')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 14),
                if (_mode == _Mode.text)
                  TextFormField(
                    initialValue: d.bodyText,
                    minLines: 5,
                    maxLines: 14,
                    maxLength: 20000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Écrivez la parole telle que vous l\'avez reçue…',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (v) => d.bodyText = v,
                  )
                else
                  _audioBlock(),
              ],
            ),
          ),

          // ── Contexte ──────────────────────────────────────────────────────
          _Card(
            title: 'Contexte',
            child: Column(
              children: [
                _DateTile(
                  icon: Icons.event_note_rounded,
                  label: 'Date de la parole',
                  value: prophecyDay(d.receivedOn),
                  onTap: _pickReceived,
                ),
                const SizedBox(height: 10),
                _DateTile(
                  icon: Icons.schedule_rounded,
                  label: 'Heure de la parole (facultatif)',
                  value: d.receivedTime ?? 'Non précisée',
                  onTap: _pickReceivedTime,
                  onClear: d.receivedTime == null ? null : () => setState(() => d.receivedTime = null),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: d.givenBy,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Qui l\'a donnée ? (facultatif)',
                    hintText: 'Ex. : Pasteur Jean, lors du culte de jeudi',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  onChanged: (v) => d.givenBy = v,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: d.title,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Titre (facultatif)',
                    hintText: 'Ex. : Une porte ouverte',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  onChanged: (v) => d.title = v,
                ),
                const SizedBox(height: 4),
                _DateTile(
                  icon: Icons.flag_outlined,
                  label: 'Échéance (facultative)',
                  value: d.dueOn == null ? 'Aucune' : prophecyDay(d.dueOn!),
                  onTap: _pickDue,
                  onClear: d.dueOn == null ? null : () => setState(() => d.dueOn = null),
                ),
              ],
            ),
          ),

          // ── Rappel de prière ───────────────────────────────────────────────
          _Card(
            title: 'Rappel de prière',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
              title: Text(d.reminder?.label ?? 'Aucun rappel'),
              subtitle: const Text('Une notification pour prier sur cette parole.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final r = await showReminderSheet(context, current: d.reminder);
                if (r != null && mounted) setState(() => d.reminder = r.value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _audioBlock() {
    final d = _draft;
    if (kIsWeb) {
      return const Text("L'enregistrement audio se fait depuis l'application mobile.",
          style: TextStyle(color: AppColors.textSecondary));
    }
    if (_recording) {
      return Column(
        children: [
          AudioWaveforms(
            recorderController: _recorder,
            size: Size(MediaQuery.sizeOf(context).width - 80, 56),
            waveStyle: const WaveStyle(waveColor: AppColors.primary, extendWaveform: true, showMiddleLine: false),
          ),
          const SizedBox(height: 8),
          Text(formatClock(Duration(seconds: _elapsed)),
              style: AppTextStyles.h4.copyWith(color: AppColors.danger, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _stopRecording,
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size.fromHeight(46)),
            icon: const Icon(Icons.stop_rounded),
            label: const Text("Arrêter l'enregistrement"),
          ),
        ],
      );
    }
    if (d.localAudioPath != null || d.audioUrl != null) {
      return ProphecyAudioPlayer(
        key: ValueKey(d.localAudioPath ?? d.audioUrl),
        filePath: d.localAudioPath,
        url: d.localAudioPath == null ? d.audioUrl : null,
        onDelete: _deleteAudio,
      );
    }
    return Column(
      children: [
        const Text(
          'Enregistrez la parole de vive voix, ou faites écouter l\'enregistrement reçu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _startRecording,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.icon, required this.label, required this.value, required this.onTap, this.onClear});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: onClear == null
              ? const Icon(Icons.edit_calendar_outlined)
              : IconButton(tooltip: 'Retirer', onPressed: onClear, icon: const Icon(Icons.close_rounded)),
        ),
        child: Text(value),
      ),
    );
  }
}
