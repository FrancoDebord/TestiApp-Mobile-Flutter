import 'package:flutter/material.dart';

import '../models/moderation_models.dart';
import 'testimony_type_badge.dart';

// =============================================================================
// ModerationItemCard
// 120 px review card rendered in the moderation list.
// =============================================================================

class ModerationItemCard extends StatelessWidget {
  const ModerationItemCard({
    required this.item,
    required this.onApprove,
    required this.onRequestEdit,
    required this.onReject,
    required this.onPreview,
    super.key,
  });

  final ModerationItem item;
  final VoidCallback onApprove;
  final VoidCallback onRequestEdit;
  final VoidCallback onReject;
  final VoidCallback onPreview;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top section ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                Row(
                  children: [
                    _AuthorAvatar(author: item.author),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.author.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF263238),
                            ),
                          ),
                          Text(
                            item.author.country,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 11,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Submitted time
                    Text(
                      _timeAgo(item.submittedAt),
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        color: Color(0xFF98A2B3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Title
                Text(
                  item.truncatedTitle,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF263238),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                // Category + type chips row
                Row(
                  children: [
                    // Les puces passent à la ligne si la catégorie est longue.
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _CategoryChip(label: item.category),
                          TestimonyTypeBadge(type: item.type),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Preview link
                    GestureDetector(
                      onTap: onPreview,
                      behavior: HitTestBehavior.opaque,
                      child: const Text(
                        'Prévisualiser',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF184797),
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF184797),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Divider ─────────────────────────────────────────────────────────
          const Divider(height: 1, color: Color(0xFFE4E7EC)),
          // ── Action buttons ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Approuver',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF12B76A),
                    onTap: onApprove,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionButton(
                    label: 'Modif.',
                    icon: Icons.edit_outlined,
                    color: const Color(0xFFF79009),
                    onTap: onRequestEdit,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionButton(
                    label: 'Rejeter',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFD92D20),
                    onTap: onReject,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Private sub-widgets ──────────────────────────────────────────────────────

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.author});
  final ModerationAuthor author;

  @override
  Widget build(BuildContext context) {
    if (author.avatarUrl != null) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(author.avatarUrl!),
      );
    }
    final initials = author.displayName
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF184797).withAlpha(20),
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: Color(0xFF184797),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF184797).withAlpha(15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF184797),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(15),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
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
