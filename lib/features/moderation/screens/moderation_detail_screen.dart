import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/video_source.dart';
import '../../../shared/widgets/testimony_proofs_card.dart';
import '../../../shared/widgets/video_poster.dart';
import '../../../shared/widgets/video_status_views.dart';
import '../../testimony/screens/video_player_screen.dart';
import '../models/moderation_models.dart';
import '../providers/moderation_provider.dart';
import '../widgets/review_bottom_sheet.dart';
import '../widgets/testimony_type_badge.dart';
import '../../../l10n/app_localizations.dart';

// =============================================================================
// ModerationDetailScreen — Full testimony preview for a moderator
//
// Widget tree:
//   Scaffold
//     CustomScrollView
//       SliverAppBar (back button, title)
//       SliverToBoxAdapter
//         _AuthorHeader
//         _MetaRow (category chip, type badge, submitted time)
//         _ContentSection (full preview text / audio/video placeholder)
//         _ActionSection (3 action buttons)
// =============================================================================

class ModerationDetailScreen extends ConsumerWidget {
  const ModerationDetailScreen({required this.reportId, super.key});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(moderationItemByIdProvider(reportId));

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.modTestimony)),
        body: Center(child: Text(context.l10n.modNotFound)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            foregroundColor: const Color(0xFF263238),
            title: Text(
              context.l10n.modPreview,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Color(0xFF263238),
              ),
            ),
            actions: [
              _StatusChip(status: item.status),
              const SizedBox(width: 12),
            ],
          ),

          // ── Content ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AuthorHeader(item: item),
                  const SizedBox(height: 16),
                  _MetaRow(item: item),
                  const SizedBox(height: 20),
                  // Title
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Color(0xFF263238),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ContentSection(item: item),
                  // Preuves jointes par l'auteur (jamais publiées)
                  ...switch (ref.watch(moderationProofsProvider(item.id))) {
                    AsyncData(:final value) when value.isNotEmpty => [
                        const SizedBox(height: 20),
                        TestimonyProofsCard(
                          proofs: value,
                          margin: EdgeInsets.zero,
                        ),
                      ],
                    _ => const <Widget>[],
                  },
                  const SizedBox(height: 28),
                  _ActionSection(item: item),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Author header ────────────────────────────────────────────────────────────

class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader({required this.item});
  final ModerationItem item;

  @override
  Widget build(BuildContext context) {
    final author = item.author;
    final initials = author.displayName
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF184797).withAlpha(20),
          backgroundImage: author.avatarUrl != null
              ? NetworkImage(author.avatarUrl!)
              : null,
          child: author.avatarUrl == null
              ? Text(
                  initials,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF184797),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Color(0xFF263238),
                ),
              ),
              Text(
                author.country,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  color: Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              L10n.current.modSubmitted,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                color: Color(0xFF98A2B3),
              ),
            ),
            Text(
              _formatDate(item.submittedAt),
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Color(0xFF667085),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

// ─── Meta row ─────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item});
  final ModerationItem item;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF184797).withAlpha(15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            item.category,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF184797),
            ),
          ),
        ),
        TestimonyTypeBadge(type: item.type),
      ],
    );
  }
}

// ─── Content section ──────────────────────────────────────────────────────────

class _ContentSection extends StatelessWidget {
  const _ContentSection({required this.item});
  final ModerationItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case TestimonyType.text:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Text(
            item.contentPreview ??
                L10n.current.modContentUnavailable,
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontStyle: FontStyle.italic,
              fontSize: 15,
              color: Color(0xFF263238),
              height: 1.8,
            ),
          ),
        );

      case TestimonyType.audio:
        return _MediaPlaceholder(
          icon: Icons.headphones_rounded,
          label: L10n.current.modAudio,
          sublabel: L10n.current.modAudioPlay,
          color: const Color(0xFFF79009),
        );

      case TestimonyType.video:
        // En traitement : badge, pas de lecture ; en échec : message (le
        // renvoi est réservé à l'auteur) ; prête : miniature, durée, lecture.
        final ready = item.videoState == VideoProcessingState.ready;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ready
                ? VideoPoster(
                    thumbnailUrl: item.thumbnailUrl,
                    durationSeconds: item.durationSeconds,
                    onPlay: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => VideoPlayerScreen(testimonyId: item.id),
                      ),
                    ),
                  )
                : VideoNotReadySurface(
                    state: item.videoState,
                    thumbnailUrl: item.thumbnailUrl,
                  ),
          ),
        );
    }
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              color: color.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action section ───────────────────────────────────────────────────────────

class _ActionSection extends ConsumerWidget {
  const _ActionSection({required this.item});
  final ModerationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.modActionTitle,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Color(0xFF263238),
          ),
        ),
        const SizedBox(height: 12),
        _FullActionButton(
          label: context.l10n.modApprove,
          icon: Icons.check_circle_rounded,
          backgroundColor: const Color(0xFF12B76A),
          onTap: () => _doApprove(context, ref),
        ),
        const SizedBox(height: 10),
        _FullActionButton(
          label: context.l10n.modRequestEdit,
          icon: Icons.edit_rounded,
          backgroundColor: const Color(0xFFF79009),
          onTap: () => _showSheet(context, ref, ReviewAction.requestEdit),
        ),
        const SizedBox(height: 10),
        _FullActionButton(
          label: context.l10n.modReject,
          icon: Icons.cancel_rounded,
          backgroundColor: const Color(0xFFD92D20),
          onTap: () => _showSheet(context, ref, ReviewAction.reject),
        ),
      ],
    );
  }

  Future<void> _doApprove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(moderationNotifierProvider.notifier).approve(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.modApprovedSnack,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13)),
            backgroundColor: const Color(0xFF12B76A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.moderationError('$e'),
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13)),
            backgroundColor: const Color(0xFFD92D20),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSheet(BuildContext context, WidgetRef ref, ReviewAction action) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewBottomSheet(
        item: item,
        action: action,
        onConfirm: (reason, note) async {
          if (action == ReviewAction.reject && reason != null) {
            try {
              await ref
                  .read(moderationNotifierProvider.notifier)
                  .reject(item.id, reason: reason, note: note);
            } catch (_) {}
          }
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _FullActionButton extends StatelessWidget {
  const _FullActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ModerationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      ModerationStatus.pending => (
          context.l10n.modStatusPending,
          const Color(0xFFFFF1E2),
          const Color(0xFFF79009),
        ),
      ModerationStatus.inReview => (
          context.l10n.modStatusInReview,
          const Color(0xFFEAF1FC),
          const Color(0xFF2B5DB0),
        ),
      ModerationStatus.approved => (
          context.l10n.modStatusApproved,
          const Color(0xFFECFDF3),
          const Color(0xFF12B76A),
        ),
      ModerationStatus.rejected => (
          context.l10n.modStatusRejected,
          const Color(0xFFFEF3F2),
          const Color(0xFFD92D20),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w600,
          fontSize: 11,
          color: fg,
        ),
      ),
    );
  }
}
