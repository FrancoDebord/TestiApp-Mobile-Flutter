import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/moderation_models.dart';
import '../providers/moderation_provider.dart';
import '../widgets/review_bottom_sheet.dart';
import '../widgets/testimony_type_badge.dart';

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
        appBar: AppBar(title: const Text('Témoignage')),
        body: const Center(child: Text('Témoignage introuvable.')),
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
            foregroundColor: const Color(0xFF0F172A),
            title: const Text(
              'Prévisualisation',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Color(0xFF0F172A),
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
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Color(0xFF0F172A),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ContentSection(item: item),
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
          backgroundColor: const Color(0xFF6B21A8).withAlpha(20),
          backgroundImage: author.avatarUrl != null
              ? NetworkImage(author.avatarUrl!)
              : null,
          child: author.avatarUrl == null
              ? Text(
                  initials,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF6B21A8),
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
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                author.country,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Soumis',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
            ),
            Text(
              _formatDate(item.submittedAt),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Color(0xFF64748B),
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF6B21A8).withAlpha(15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            item.category,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B21A8),
            ),
          ),
        ),
        const SizedBox(width: 8),
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
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            item.contentPreview ??
                'Contenu du témoignage non disponible pour la prévisualisation.',
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontStyle: FontStyle.italic,
              fontSize: 15,
              color: Color(0xFF0F172A),
              height: 1.8,
            ),
          ),
        );

      case TestimonyType.audio:
        return _MediaPlaceholder(
          icon: Icons.headphones_rounded,
          label: 'Témoignage audio',
          sublabel: 'Appuyer pour écouter',
          color: const Color(0xFFF59E0B),
        );

      case TestimonyType.video:
        return _MediaPlaceholder(
          icon: Icons.play_circle_fill_rounded,
          label: 'Témoignage vidéo',
          sublabel: 'Appuyer pour visionner',
          color: const Color(0xFF22C55E),
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
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: TextStyle(
              fontFamily: 'Inter',
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
        const Text(
          'Action de modération',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        _FullActionButton(
          label: 'Approuver le témoignage',
          icon: Icons.check_circle_rounded,
          backgroundColor: const Color(0xFF22C55E),
          onTap: () => _doApprove(context, ref),
        ),
        const SizedBox(height: 10),
        _FullActionButton(
          label: 'Demander une modification',
          icon: Icons.edit_rounded,
          backgroundColor: const Color(0xFFF59E0B),
          onTap: () => _showSheet(context, ref, ReviewAction.requestEdit),
        ),
        const SizedBox(height: 10),
        _FullActionButton(
          label: 'Rejeter le témoignage',
          icon: Icons.cancel_rounded,
          backgroundColor: const Color(0xFFEF4444),
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
          const SnackBar(
            content: Text('Témoignage approuvé',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
            backgroundColor: Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
            backgroundColor: const Color(0xFFEF4444),
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
            fontFamily: 'Inter',
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
          'En attente',
          const Color(0xFFFFF7ED),
          const Color(0xFFF59E0B),
        ),
      ModerationStatus.inReview => (
          'En révision',
          const Color(0xFFEFF6FF),
          const Color(0xFF3B82F6),
        ),
      ModerationStatus.approved => (
          'Approuvé',
          const Color(0xFFF0FDF4),
          const Color(0xFF22C55E),
        ),
      ModerationStatus.rejected => (
          'Rejeté',
          const Color(0xFFFEF2F2),
          const Color(0xFFEF4444),
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
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 11,
          color: fg,
        ),
      ),
    );
  }
}
