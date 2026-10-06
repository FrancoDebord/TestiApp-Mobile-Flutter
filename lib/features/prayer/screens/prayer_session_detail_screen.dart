import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/guest_gate.dart' show requireAccount;
import '../data/prayer_repository.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';
import '../widgets/prayer_widgets.dart';

/// Détail d'une session de prière : « Je serai là », puis rejoindre la salle.
/// La salle est un direct : l'hôte l'ouvre (studio `/lives/{id}/studio`), les autres la
/// rejoignent (`/lives/{id}` : vidéo, commentaires, demande de prise de parole).
class PrayerSessionDetailScreen extends ConsumerStatefulWidget {
  const PrayerSessionDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<PrayerSessionDetailScreen> createState() => _PrayerSessionDetailScreenState();
}

class _PrayerSessionDetailScreenState extends ConsumerState<PrayerSessionDetailScreen> {
  bool _busy = false;

  String get _id => widget.sessionId;
  PrayerRepository get _repo => ref.read(prayerRepositoryProvider);

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _run(Future<PrayerSession?> Function() action, [String? success]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = await action();
      if (s != null) ref.read(prayerSessionProvider(_id).notifier).replace(s);
      ref.invalidate(prayerSessionListProvider);
      if (success != null && mounted) _snack(success);
    } on PrayerFailure catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRegistration(PrayerSession s) async {
    if (!await requireAccount(context, ref, reason: "vous inscrire à la session")) return;
    await _run(() => _repo.setRegistered(_id, !s.isRegistered),
        s.isRegistered ? 'Inscription retirée.' : "Inscription enregistrée : vous serez prévenu à l'ouverture de la salle.");
  }

  /// Hôte : ouvre (ou reprend) la salle puis le studio du direct.
  Future<void> _openRoom() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final liveId = await _repo.startSession(_id);
      if (!mounted) return;
      await context.push('/lives/$liveId/studio');
      if (mounted) await ref.read(prayerSessionProvider(_id).notifier).reload();
    } on PrayerFailure catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinRoom(PrayerSession s) async {
    await context.push('/lives/${s.liveId}');
    if (mounted) await ref.read(prayerSessionProvider(_id).notifier).reload();
  }

  Future<bool> _confirm(String title, String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Retour')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _menu(String action, PrayerSession s) async {
    switch (action) {
      case 'edit':
        await context.push('/prayer-sessions/${s.id}/edit');
      case 'cancel':
        if (await _confirm('Annuler la session ?', 'Elle restera visible comme « Annulée » ; la salle sera fermée.', 'Annuler la session')) {
          await _run(() => _repo.cancelSession(_id), 'Session annulée.');
        }
      case 'delete':
        if (await _confirm('Supprimer la session ?', 'La session sera supprimée et sa salle fermée si elle est ouverte.', 'Supprimer')) {
          try {
            await _repo.deleteSession(_id);
            ref.invalidate(prayerSessionListProvider);
            if (!mounted) return;
            _snack('Session supprimée.');
            context.pop();
          } on PrayerFailure catch (e) {
            if (mounted) _snack(e.message);
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(prayerSessionProvider(_id));
    final s = async.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Session de prière'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (s != null && (s.canEdit || s.canDelete))
            PopupMenuButton<String>(
              onSelected: (v) => _menu(v, s),
              itemBuilder: (_) => [
                if (s.canEdit) const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Modifier'))),
                if (s.canDelete && !s.isOver)
                  const PopupMenuItem(value: 'cancel', child: ListTile(leading: Icon(Icons.event_busy_outlined), title: Text('Annuler la session'))),
                if (s.canDelete)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(leading: Icon(Icons.delete_outline, color: AppColors.danger), title: Text('Supprimer')),
                  ),
              ],
            ),
        ],
      ),
      body: switch (async) {
        AsyncValue(:final value?) => RefreshIndicator(
            onRefresh: () => ref.read(prayerSessionProvider(_id).notifier).reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, 40),
              children: [
                _Header(session: value),
                const SizedBox(height: AppSpacing.lg),
                _RoomCard(
                  session: value,
                  busy: _busy,
                  onOpen: _openRoom,
                  onJoin: () => _joinRoom(value),
                  onToggleRegistration: () => _toggleRegistration(value),
                ),
                if (value.description != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('Présentation', style: AppTextStyles.h4),
                  const SizedBox(height: AppSpacing.sm),
                  Text(value.description!, style: AppTextStyles.bodyMedium.copyWith(height: 1.5)),
                ],
                if (value.topics.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('Sujets de prière', style: AppTextStyles.h4),
                  const SizedBox(height: AppSpacing.sm),
                  for (final t in value.topics)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.volunteer_activism_rounded, size: 16, color: AppColors.secondary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(t, style: AppTextStyles.bodyMedium)),
                      ]),
                    ),
                ],
              ],
            ),
          ),
        AsyncValue(:final error?) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.search_off_rounded, size: 56, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(error is PrayerFailure ? error.message : 'Impossible de charger la session.', textAlign: TextAlign.center),
                TextButton(onPressed: () => ref.invalidate(prayerSessionProvider(_id)), child: const Text('Réessayer')),
              ]),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session});
  final PrayerSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        PrayerSessionPhaseBadge(phase: s.phase),
        if (s.visibility == PrayerVisibility.followers)
          Text('· Réservée aux abonnés', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Text(s.title, style: AppTextStyles.h2),
      const SizedBox(height: AppSpacing.md),
      _Line(icon: Icons.schedule_rounded, text: '${formatPrayerDate(s.startsAt)} · ${s.durationMinutes} min'),
      _Line(
        icon: Icons.person_outline_rounded,
        text: 'Animée par ${s.host.displayName}',
        onTap: () => context.push('/users/${s.host.id}'),
      ),
      _Line(icon: Icons.groups_2_outlined, text: '${s.participantCount} ${s.participantCount > 1 ? 'inscrits' : 'inscrit'}'),
      if (s.event != null)
        _Line(icon: Icons.event_rounded, text: s.event!.title, color: AppColors.primary, onTap: () => context.push('/events/${s.event!.id}')),
    ]);
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.onTap, this.color});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: color ?? AppColors.textPrimary))),
          ]),
        ),
      );
}

/// Carte d'action : ouvrir / rejoindre la salle, « Je serai là ».
class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.session,
    required this.busy,
    required this.onOpen,
    required this.onJoin,
    required this.onToggleRegistration,
  });

  final PrayerSession session;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onJoin;
  final VoidCallback onToggleRegistration;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final children = <Widget>[];

    if (s.phase == PrayerSessionPhase.cancelled) {
      children.add(Text('Cette session a été annulée.', style: AppTextStyles.bodyMedium));
    } else if (s.isHost) {
      if (s.canStart) {
        children
          ..add(FilledButton.icon(
            onPressed: busy ? null : onOpen,
            icon: const Icon(Icons.sensors_rounded),
            label: Text(s.hasRoom ? 'Retourner dans la salle' : 'Ouvrir la salle'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.secondary, padding: const EdgeInsets.symmetric(vertical: 14)),
          ))
          ..add(const SizedBox(height: 6))
          ..add(Text("Vous arrivez dans le studio : passez à l'antenne pour commencer. Les inscrits sont prévenus.",
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)));
      } else if (s.phase == PrayerSessionPhase.upcoming) {
        children.add(Text(
          'Vous pourrez ouvrir la salle à partir du ${formatPrayerDate(s.opensAt ?? s.startsAt.subtract(const Duration(minutes: 30)))}.',
          style: AppTextStyles.bodyMedium,
        ));
      } else {
        children.add(Text('Cette session est terminée.', style: AppTextStyles.bodyMedium));
      }
    } else {
      if (s.hasRoom && s.liveStatus == 'live') {
        children
          ..add(FilledButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.meeting_room_rounded),
            label: const Text('Rejoindre la salle'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.secondary, padding: const EdgeInsets.symmetric(vertical: 14)),
          ))
          ..add(const SizedBox(height: 6))
          ..add(Text('Commentez et demandez à prendre la parole depuis la salle.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)));
      } else if (s.phase == PrayerSessionPhase.ended) {
        children.add(Text('Cette session est terminée.', style: AppTextStyles.bodyMedium));
      } else {
        children.add(Text(
          s.isRegistered ? "La salle s'ouvrira à l'heure prévue : vous serez prévenu." : "La salle s'ouvrira à l'heure prévue.",
          style: AppTextStyles.bodyMedium,
        ));
      }
      if (s.phase != PrayerSessionPhase.ended) {
        children
          ..add(const SizedBox(height: AppSpacing.md))
          ..add(s.isRegistered
              ? FilledButton.icon(
                  onPressed: busy ? null : onToggleRegistration,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Je serai là'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                )
              : OutlinedButton.icon(
                  onPressed: busy ? null : onToggleRegistration,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Je serai là'),
                ));
        if (s.isRegistered) {
          children.add(Text("Toucher à nouveau pour retirer l'inscription.",
              textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)));
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppShadows.cardDecoration,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('La salle de prière', style: AppTextStyles.h4),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ]),
    );
  }
}
