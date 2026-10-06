import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/content/encouragements.dart';
import '../../publish/providers/publish_provider.dart' show publishProphecyProvider;
import '../data/prophecies_repository.dart';
import '../data/prophecy_reminders.dart';
import '../models/prophecy.dart';
import '../providers/prophecies_providers.dart';
import '../widgets/prophecy_widgets.dart';
import 'prophecy_reminder_sheet.dart';

/// Une parole prophétique : la parole (texte / audio), le journal de prière,
/// le rappel, la proclamation en plein écran et l'accomplissement (témoigner).
class ProphecyDetailScreen extends ConsumerStatefulWidget {
  const ProphecyDetailScreen({required this.prophecyId, super.key});

  final String prophecyId;

  @override
  ConsumerState<ProphecyDetailScreen> createState() => _ProphecyDetailScreenState();
}

class _ProphecyDetailScreenState extends ConsumerState<ProphecyDetailScreen> {
  bool _busy = false;

  String get _id => widget.prophecyId;
  PropheciesRepository get _repo => ref.read(propheciesRepositoryProvider);

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  /// Exécute une action et rafraîchit la parole, la liste et le journal.
  Future<void> _run(Future<Prophecy> Function() action, String ok) async {
    setState(() => _busy = true);
    try {
      final p = await action();
      await ProphecyReminders.apply(p);
      ref
        ..invalidate(prophecyProvider(_id))
        ..invalidate(prophecyPrayersProvider(_id))
        ..invalidate(propheciesListProvider);
      _snack(ok);
    } on ProphecyFailure catch (e) {
      _snack(e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pray() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _PrayDialog(),
    );
    if (note == null) return;
    unawaited(HapticFeedback.mediumImpact());
    await _run(() => _repo.pray(_id, note: note), 'Prière enregistrée. Dieu veille sur sa parole pour l\'accomplir.');
  }

  Future<void> _reminder(Prophecy p) async {
    final r = await showReminderSheet(context, current: p.reminder);
    if (r == null) return;
    await _run(() => _repo.setReminder(_id, r.value), r.value == null ? 'Rappel supprimé.' : 'Rappel : ${r.value!.label}.');
  }

  void _testify(Prophecy p) {
    ref.read(publishProphecyProvider.notifier).attach(p.id, p.displayTitle(prophecyDay));
    context.go('/publish');
  }

  Future<void> _fulfilled(Prophecy p) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text('Gloire à Dieu ! La parole s\'est accomplie',
                  style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.campaign_rounded, color: AppColors.primary),
              title: const Text('Témoigner de son accomplissement'),
              subtitle: const Text('Publiez votre témoignage ; vous choisirez de montrer la parole avec lui.'),
              onTap: () => Navigator.pop(context, 'testify'),
            ),
            ListTile(
              leading: const Icon(Icons.verified_outlined, color: AppColors.success),
              title: const Text('Marquer accomplie, sans témoigner pour l\'instant'),
              onTap: () => Navigator.pop(context, 'mark'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'testify') _testify(p);
    if (choice == 'mark') await _run(() => _repo.setFulfilled(_id, true), 'Parole marquée comme accomplie.');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette parole ?'),
        content: const Text('La parole et son journal de prière seront supprimés. '
            'Un témoignage déjà publié reste publié.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(_id);
      await ProphecyReminders.cancel(_id);
      ref.invalidate(propheciesListProvider);
      _snack('Parole supprimée.');
      if (mounted) context.pop();
    } on ProphecyFailure catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(prophecyProvider(_id));
    final p = async.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Parole prophétique'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (p != null)
            PopupMenuButton<String>(
              tooltip: 'Options',
              onSelected: (a) async {
                if (a == 'edit') {
                  await context.push('/prophecies/${p.id}/edit');
                  ref.invalidate(prophecyProvider(_id));
                }
                if (a == 'waiting') await _run(() => _repo.setFulfilled(_id, false), 'Parole remise en attente.');
                if (a == 'delete') await _delete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                if (p.fulfilled && p.testimonyId == null)
                  const PopupMenuItem(value: 'waiting', child: Text('Remettre en attente')),
                const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
        ],
      ),
      body: switch (async) {
        AsyncValue(value: final p?) => _content(p),
        AsyncValue(:final error?) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error is ProphecyFailure ? error.message : 'Parole introuvable.', textAlign: TextAlign.center),
                  TextButton(onPressed: () => ref.invalidate(prophecyProvider(_id)), child: const Text('Réessayer')),
                ],
              ),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _content(Prophecy p) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(prophecyPrayersProvider(_id));
        ref.invalidate(prophecyProvider(_id));
        await ref.read(prophecyProvider(_id).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 32),
        children: [
          Row(children: [ProphecyStatusChip(prophecy: p)]),
          const SizedBox(height: 10),
          Text(p.displayTitle(prophecyDay),
              style: AppTextStyles.h3.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _InfoLine(Icons.event_note_rounded, 'Reçue le ${prophecyDay(p.receivedOn)}'),
          if (p.givenBy != null) _InfoLine(Icons.person_outline_rounded, 'Donnée par ${p.givenBy}'),
          if (p.dueOn != null) _InfoLine(Icons.flag_outlined, 'Échéance : ${prophecyDay(p.dueOn!)}'),
          if (p.fulfilledOn != null)
            _InfoLine(Icons.verified_rounded, 'Accomplie le ${prophecyDay(p.fulfilledOn!)}', color: AppColors.success),
          const SizedBox(height: 14),

          // ── La parole ─────────────────────────────────────────────────────
          if (p.bodyText != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.cardRadius,
                border: const Border(left: BorderSide(color: AppColors.sun, width: 4)),
              ),
              child: SelectableText(
                p.bodyText!,
                style: AppTextStyles.bodyLarge.copyWith(height: 1.6, color: AppColors.textPrimary),
              ),
            ),
          if (p.hasAudio) ...[
            if (p.bodyText != null) const SizedBox(height: 10),
            ProphecyAudioPlayer(key: ValueKey(p.audioUrl), url: p.audioUrl),
          ],
          const SizedBox(height: 14),

          // ── Actions ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _pray,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.volunteer_activism_rounded),
                  label: const Text("J'ai prié"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => ProclaimScreen(prophecy: p),
                  )),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  icon: const Icon(Icons.record_voice_over_rounded),
                  label: const Text('Proclamer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!p.fulfilled)
            FilledButton.icon(
              onPressed: _busy ? null : () => _fulfilled(p),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: AppColors.success),
              icon: const Icon(Icons.celebration_rounded),
              label: const Text("Elle s'est accomplie"),
            )
          else if (p.testimonyId != null)
            OutlinedButton.icon(
              onPressed: () => context.push('/testimony/${p.testimonyId}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(p.isPublic ? 'Voir mon témoignage (parole publiée)' : 'Voir mon témoignage'),
            )
          else
            FilledButton.icon(
              onPressed: () => _testify(p),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: AppColors.secondary),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Témoigner de son accomplissement'),
            ),
          const SizedBox(height: 18),

          // ── Rappel ────────────────────────────────────────────────────────
          if (!p.fulfilled)
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.cardRadius, side: const BorderSide(color: AppColors.border)),
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                title: Text(p.reminder?.label ?? 'Aucun rappel de prière'),
                subtitle: const Text('Notification sur ce téléphone'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _busy ? null : () => _reminder(p),
              ),
            ),
          const SizedBox(height: 22),

          // ── Journal de prière ──────────────────────────────────────────────
          Text('Journal de prière', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            p.prayerCount == 0
                ? 'Pas encore de prière enregistrée.'
                : 'Priée ${p.prayerCount} fois${p.lastPrayedAt != null ? ' · dernière fois ${prayedAgo(p.lastPrayedAt!)}' : ''}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          _PrayerJournal(prophecyId: p.id, onDelete: (pr) => _run(() => _repo.deletePrayer(_id, pr.id), 'Prière retirée du journal.')),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text, {this.color = AppColors.textSecondary});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: color))),
        ],
      ),
    );
  }
}

class _PrayerJournal extends ConsumerWidget {
  const _PrayerJournal({required this.prophecyId, required this.onDelete});
  final String prophecyId;
  final void Function(ProphecyPrayer) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(prophecyPrayersProvider(prophecyId)).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final pr in items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.volunteer_activism_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${prophecyDay(pr.prayedAt)} · ${pr.prayedAt.hour.toString().padLeft(2, '0')}:${pr.prayedAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      if (pr.note != null) ...[
                        const SizedBox(height: 2),
                        Text(pr.note!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Retirer du journal',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onDelete(pr),
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// « J'ai prié » : note facultative. Renvoie la note ('' sans note), null si annulé.
class _PrayDialog extends StatefulWidget {
  const _PrayDialog();

  @override
  State<_PrayDialog> createState() => _PrayDialogState();
}

class _PrayDialogState extends State<_PrayDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("J'ai prié pour cette parole"),
      content: TextField(
        controller: _note,
        maxLength: 1000,
        minLines: 2,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Note (facultative)',
          hintText: 'Ce que Dieu vous a mis à cœur…',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, _note.text), child: const Text('Enregistrer')),
      ],
    );
  }
}

/// Proclamer la parole : plein écran, grand texte, audio, verset d'Habakuk 2:3.
class ProclaimScreen extends StatelessWidget {
  const ProclaimScreen({required this.prophecy, super.key});
  final Prophecy prophecy;

  @override
  Widget build(BuildContext context) {
    final p = prophecy;
    final verse = prophecyVerses.first;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1B3D),
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.record_voice_over_rounded, color: AppColors.sun, size: 34),
                      const SizedBox(height: 14),
                      Text(
                        p.displayTitle(prophecyDay),
                        style: const TextStyle(
                          color: AppColors.sun,
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (p.bodyText != null)
                        Text(
                          p.bodyText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 24,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (p.hasAudio) ...[
                        const SizedBox(height: 20),
                        ProphecyAudioPlayer(url: p.audioUrl, dark: true),
                      ],
                      const SizedBox(height: 28),
                      Container(height: 1, color: Colors.white24),
                      const SizedBox(height: 18),
                      Text('« ${verse.text} »',
                          style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, height: 1.5)),
                      const SizedBox(height: 6),
                      Text(verse.reference!,
                          style: const TextStyle(color: AppColors.sun, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
