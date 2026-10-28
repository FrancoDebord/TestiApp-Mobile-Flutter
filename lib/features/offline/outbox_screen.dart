// Écran « À envoyer » : ce qui a été fait hors connexion et attend d'être envoyé
// (file d'envoi, outbox_controller.dart), avec les éléments refusés par le
// serveur à renvoyer ou supprimer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'outbox_controller.dart';

class OutboxScreen extends ConsumerWidget {
  const OutboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(outboxProvider);
    final l10n = context.l10n;
    final failed = [for (final i in s.items) if (i.isFailed) i];
    // Les créations d'abord, puis le reste, plus récents d'abord.
    final pending = [for (final i in s.items.reversed) if (!i.isFailed) i]
      ..sort((a, b) => (b.kind.isCreation ? 1 : 0) - (a.kind.isCreation ? 1 : 0));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 0,
        title: Text(l10n.outboxTitle, style: AppTextStyles.h3),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(outboxProvider.notifier).flush(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxl),
          children: [
            _StatusCard(state: s),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.outboxIntro, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            if (s.items.isEmpty) ...[
              const SizedBox(height: AppSpacing.xxxl),
              const Icon(Icons.cloud_done_outlined, size: 56, color: AppColors.success),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.outboxEmpty, style: AppTextStyles.h4, textAlign: TextAlign.center),
            ],
            if (failed.isNotEmpty) ...[
              _SectionTitle(l10n.outboxSectionFailed, failed.length, color: AppColors.danger),
              for (final i in failed) _OutboxTile(item: i),
            ],
            if (pending.isNotEmpty) ...[
              _SectionTitle(l10n.outboxSectionPending, pending.length, color: AppColors.primary),
              for (final i in pending) _OutboxTile(item: i),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.state});

  final OutboxState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final online = state.online;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: online ? AppColors.successSoft : AppColors.sunSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: online ? AppColors.success.withValues(alpha: 0.3) : AppColors.sunBorder),
      ),
      child: Row(
        children: [
          Icon(online ? Icons.cloud_queue_rounded : Icons.cloud_off_rounded,
              size: 20, color: online ? AppColors.success : AppColors.sunText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              state.syncing ? l10n.outboxSending : (online ? l10n.outboxOnline : l10n.outboxOffline),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            ),
          ),
          if (state.syncing)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else if (online && state.pendingCount > 0)
            TextButton(
              onPressed: () => ref.read(outboxProvider.notifier).flush(),
              child: Text(l10n.outboxSendNow),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.count, {required this.color});

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Text('$title ($count)', style: AppTextStyles.labelMedium.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _OutboxTile extends ConsumerWidget {
  const _OutboxTile({required this.item});

  final OutboxItem item;

  static IconData _icon(OutboxKind k) => switch (k) {
        OutboxKind.testimony => Icons.auto_stories_outlined,
        OutboxKind.videoTestimony => Icons.videocam_outlined,
        OutboxKind.prayerRequest => Icons.volunteer_activism_outlined,
        OutboxKind.prayerSession => Icons.groups_2_outlined,
        OutboxKind.event => Icons.event_outlined,
        OutboxKind.testimonyComment ||
        OutboxKind.eventComment ||
        OutboxKind.verseComment => Icons.chat_bubble_outline_rounded,
        OutboxKind.prayerMessage => Icons.favorite_border_rounded,
        OutboxKind.reaction => Icons.thumb_up_alt_outlined,
        OutboxKind.save => Icons.bookmark_outline_rounded,
        OutboxKind.request => Icons.sync_rounded,
      };

  static String _kindLabel(OutboxKind k) {
    final l = L10n.current;
    return switch (k) {
      OutboxKind.testimony => l.outboxKindTestimony,
      OutboxKind.videoTestimony => l.outboxKindVideo,
      OutboxKind.prayerRequest => l.outboxKindPrayerRequest,
      OutboxKind.prayerSession => l.outboxKindPrayerSession,
      OutboxKind.event => l.outboxKindEvent,
      OutboxKind.testimonyComment || OutboxKind.eventComment || OutboxKind.verseComment => l.outboxKindComment,
      OutboxKind.prayerMessage => l.outboxKindEncouragement,
      OutboxKind.reaction => l.outboxKindReaction,
      OutboxKind.save => l.outboxKindSave,
      OutboxKind.request => l.outboxKindOther,
    };
  }

  /// Texte du contenu (mentions « @[Nom](user:id) » ramenées à « @Nom »).
  static String _plain(String label) =>
      label.replaceAllMapped(RegExp(r'@\[([^\]]+)\]\([^)]*\)'), (m) => '@${m[1]}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final failed = item.isFailed;
    final next = item.nextTryAt;
    final status = failed
        ? (item.error ?? l10n.commonErrorGeneric)
        : next != null && next.isAfter(DateTime.now())
            ? l10n.outboxRetryLater(formatTime(next))
            : l10n.outboxWaiting;
    // Réactions et enregistrements : le libellé est le titre visé, pas un texte écrit.
    final label = item.kind == OutboxKind.save ? '' : _plain(item.label).trim();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: failed ? AppColors.dangerSoft : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: failed ? AppColors.danger.withValues(alpha: 0.25) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: failed ? AppColors.surface : AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon(item.kind), size: 18, color: failed ? AppColors.danger : AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_kindLabel(item.kind), style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                    if (label.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMedium),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.outboxSavedAt(formatDateTime(item.createdAt))} · $status',
                      style: AppTextStyles.bodySmall.copyWith(color: failed ? AppColors.danger : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(l10n.outboxDelete),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              ),
              if (failed)
                TextButton.icon(
                  onPressed: () => ref.read(outboxProvider.notifier).retry(item.id),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l10n.outboxRetry),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.outboxDeleteTitle),
        content: Text(l10n.outboxDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l10n.outboxDelete),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(outboxProvider.notifier).remove(item.id);
  }
}
