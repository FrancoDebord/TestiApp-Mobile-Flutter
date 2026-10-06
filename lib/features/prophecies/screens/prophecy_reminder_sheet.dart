import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/prophecy.dart';

/// Choix du rappel de prière. Renvoie `(value: null)` pour « aucun rappel »,
/// et null si la feuille est fermée sans choix.
Future<({ProphecyReminder? value})?> showReminderSheet(BuildContext context, {ProphecyReminder? current}) {
  return showModalBottomSheet<({ProphecyReminder? value})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _ReminderSheet(current: current),
  );
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({this.current});
  final ProphecyReminder? current;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late ReminderFrequency? _frequency = widget.current?.frequency;
  late TimeOfDay _time = widget.current == null
      ? const TimeOfDay(hour: 6, minute: 0)
      : TimeOfDay(hour: widget.current!.hour, minute: widget.current!.minute);
  late int _weekday = widget.current?.weekday ?? DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rappel de prière', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Une notification sur ce téléphone pour prier sur la parole, jusqu\'à son accomplissement.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            SegmentedButton<ReminderFrequency?>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: null, label: Text('Aucun')),
                ButtonSegment(value: ReminderFrequency.daily, label: Text('Chaque jour')),
                ButtonSegment(value: ReminderFrequency.weekly, label: Text('Chaque semaine')),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) => setState(() => _frequency = s.first),
            ),
            if (_frequency != null) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded, color: AppColors.primary),
                title: const Text('Heure'),
                trailing: Text(_time.format(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _time);
                  if (t != null) setState(() => _time = t);
                },
              ),
              if (_frequency == ReminderFrequency.weekly)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 1; i <= 7; i++)
                      ChoiceChip(
                        label: Text(ProphecyReminder.weekdays[i - 1].substring(0, 3)),
                        selected: _weekday == i,
                        onSelected: (_) => setState(() => _weekday = i),
                      ),
                  ],
                ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, (
                value: _frequency == null
                    ? null
                    : ProphecyReminder(
                        frequency: _frequency!,
                        hour: _time.hour,
                        minute: _time.minute,
                        weekday: _frequency == ReminderFrequency.weekly ? _weekday : null,
                      ),
              )),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }
}
