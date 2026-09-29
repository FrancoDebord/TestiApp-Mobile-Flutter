import 'package:flutter/material.dart';

import '../../../shared/models/user_model.dart' show UserRole;
import '../models/admin_models.dart';

// =============================================================================
// AdminUserRow
// Table-style row: Avatar | Name + Email | Role chip | Status chip | Actions menu
// =============================================================================

class AdminUserRow extends StatelessWidget {
  const AdminUserRow({
    required this.user,
    required this.onSuspend,
    required this.onBan,
    required this.onPromote,
    required this.onRestore,
    super.key,
  });

  final AdminUser user;
  final VoidCallback onSuspend;
  final VoidCallback onBan;
  final VoidCallback onPromote;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E7EC))),
      ),
      child: Row(
        children: [
          // Avatar
          _UserAvatar(user: user),
          const SizedBox(width: 12),
          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF263238),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    color: Color(0xFF667085),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Role chip
          _RoleChip(role: user.role),
          const SizedBox(width: 6),
          // Status chip
          _StatusChip(status: user.status),
          const SizedBox(width: 4),
          // Actions popup menu
          _ActionsMenu(
            user: user,
            onSuspend: onSuspend,
            onBan: onBan,
            onPromote: onPromote,
            onRestore: onRestore,
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final initials = user.displayName
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    if (user.avatarUrl != null) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(user.avatarUrl!),
      );
    }

    final (bg, fg) = switch (user.role) {
      UserRole.administrateur => (
          const Color(0xFF184797).withAlpha(20),
          const Color(0xFF184797),
        ),
      UserRole.moderateur => (
          const Color(0xFF2B5DB0).withAlpha(20),
          const Color(0xFF2B5DB0),
        ),
      _ => (
          const Color(0xFF667085).withAlpha(20),
          const Color(0xFF667085),
        ),
    };

    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: fg,
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (role) {
      UserRole.administrateur => (
          const Color(0xFFEAF1FC),
          const Color(0xFF184797),
        ),
      UserRole.moderateur => (
          const Color(0xFFEAF1FC),
          const Color(0xFF2B5DB0),
        ),
      UserRole.utilisateur => (
          const Color(0xFFECFDF3),
          const Color(0xFF12B76A),
        ),
      UserRole.visiteur => (
          const Color(0xFFF8FAFC),
          const Color(0xFF667085),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final UserAccountStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, dot) = switch (status) {
      UserAccountStatus.active => (
          const Color(0xFFECFDF3),
          const Color(0xFF12B76A),
          const Color(0xFF12B76A),
        ),
      UserAccountStatus.suspended => (
          const Color(0xFFFFF1E2),
          const Color(0xFFF79009),
          const Color(0xFFF79009),
        ),
      UserAccountStatus.banned => (
          const Color(0xFFFEF3F2),
          const Color(0xFFD92D20),
          const Color(0xFFD92D20),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({
    required this.user,
    required this.onSuspend,
    required this.onBan,
    required this.onPromote,
    required this.onRestore,
  });

  final AdminUser user;
  final VoidCallback onSuspend;
  final VoidCallback onBan;
  final VoidCallback onPromote;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          size: 18, color: Color(0xFF667085)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      itemBuilder: (_) => [
        if (user.status != UserAccountStatus.active)
          _menuItem('restore', Icons.restore_rounded, 'Réactiver',
              const Color(0xFF12B76A)),
        if (user.status == UserAccountStatus.active)
          _menuItem('suspend', Icons.pause_circle_outline_rounded, 'Suspendre',
              const Color(0xFFF79009)),
        if (user.status != UserAccountStatus.banned)
          _menuItem('ban', Icons.block_rounded, 'Bannir',
              const Color(0xFFD92D20)),
        if (user.role == UserRole.utilisateur)
          _menuItem('promote', Icons.admin_panel_settings_outlined,
              'Promouvoir modérateur', const Color(0xFF184797)),
        if (user.role == UserRole.moderateur)
          _menuItem('promote_admin', Icons.shield_outlined,
              'Promouvoir admin', const Color(0xFF184797)),
      ],
      onSelected: (value) {
        switch (value) {
          case 'suspend':
            onSuspend();
          case 'ban':
            onBan();
          case 'promote':
          case 'promote_admin':
            onPromote();
          case 'restore':
            onRestore();
        }
      },
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
