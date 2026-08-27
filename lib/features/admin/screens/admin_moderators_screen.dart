import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_model.dart' show UserRole;
import '../models/admin_models.dart';
import '../providers/admin_provider.dart';

// =============================================================================
// AdminModeratorsScreen — Assign / Remove moderator role
//
// Widget tree:
//   Column
//     _SectionHeader ("Modérateurs actifs" count)
//     Expanded → ListView
//       _ModeratorCard (per moderator)
//       _PromoteCandidateCard (per utilisateur eligible)
// =============================================================================

class AdminModeratorsScreen extends ConsumerWidget {
  const AdminModeratorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allUsers = ref.watch(adminUsersListProvider);
    final moderators =
        allUsers.where((u) => u.role == UserRole.moderateur).toList();
    final candidates =
        allUsers.where((u) => u.role == UserRole.utilisateur).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Active moderators ────────────────────────────────────────────────
        _SectionHeader(
          title: 'Modérateurs actifs',
          count: moderators.length,
          color: const Color(0xFF3B82F6),
        ),
        ...moderators.map(
          (u) => _ModeratorCard(
            user: u,
            onRemove: () => _confirmAction(
              context,
              'Retirer le rôle de modérateur ?',
              '${u.displayName} redeviendra un utilisateur standard.',
              const Color(0xFFEF4444),
              () => ref
                  .read(adminUsersNotifierProvider.notifier)
                  .updateRole(u.uid, UserRole.utilisateur),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ── Promote candidates ───────────────────────────────────────────────
        _SectionHeader(
          title: 'Utilisateurs — Promouvoir',
          count: candidates.length,
          color: const Color(0xFF6B21A8),
        ),
        ...candidates.map(
          (u) => _CandidateCard(
            user: u,
            onPromote: () => _confirmAction(
              context,
              'Promouvoir ${u.displayName} ?',
              'Cet utilisateur pourra modérer les témoignages soumis.',
              const Color(0xFF6B21A8),
              () => ref
                  .read(adminUsersNotifierProvider.notifier)
                  .updateRole(u.uid, UserRole.moderateur),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmAction(
    BuildContext context,
    String title,
    String message,
    Color color,
    VoidCallback onConfirm,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF0F172A))),
        content: Text(message,
            style: const TextStyle(
                fontFamily: 'Inter', fontSize: 13, color: Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler',
                style:
                    TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer',
                style: TextStyle(
                    fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Moderator card ───────────────────────────────────────────────────────────

class _ModeratorCard extends StatelessWidget {
  const _ModeratorCard({required this.user, required this.onRemove});

  final AdminUser user;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _Avatar(user: user, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF0F172A))),
                Text(user.country ?? '',
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF64748B))),
              ],
            ),
          ),
          // Shield badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, size: 12, color: Color(0xFF3B82F6)),
                SizedBox(width: 4),
                Text('Modérateur',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded,
                size: 18, color: Color(0xFFEF4444)),
            tooltip: 'Retirer le rôle',
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─── Candidate card ───────────────────────────────────────────────────────────

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.user, required this.onPromote});

  final AdminUser user;
  final VoidCallback onPromote;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _Avatar(user: user, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF0F172A))),
                Text(user.email,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF64748B))),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onPromote,
            icon: const Icon(Icons.add_moderator_outlined, size: 14),
            label: const Text('Promouvoir'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B21A8),
              textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared avatar ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.color});

  final AdminUser user;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initials = user.displayName
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    if (user.avatarUrl != null) {
      return CircleAvatar(
          radius: 18, backgroundImage: NetworkImage(user.avatarUrl!));
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withAlpha(20),
      child: Text(initials,
          style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: color)),
    );
  }
}
