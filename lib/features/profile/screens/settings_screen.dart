import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show authStateProvider;
import '../models/profile_models.dart';
import '../providers/profile_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    final notifier = ref.read(userSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paramètres',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: AppColors.textPrimary,
            )),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        children: [
          // ── Notifications ──────────────────────────────────────────────
          _SectionHeader('Notifications'),
          _ToggleTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Commentaires',
            subtitle: 'Quand quelqu\'un commente',
            value: settings.pushComments,
            onChanged: (_) => notifier.togglePushComments(),
          ),
          _ToggleTile(
            icon: Icons.favorite_outline_rounded,
            title: "J'aime",
            subtitle: 'Quand quelqu\'un aime votre témoignage',
            value: settings.pushLikes,
            onChanged: (_) => notifier.togglePushLikes(),
          ),
          _ToggleTile(
            icon: Icons.volunteer_activism_outlined,
            title: 'Prières',
            subtitle: 'Quand quelqu\'un prie avec vous',
            value: settings.pushPrayers,
            onChanged: (_) => notifier.togglePushPrayers(),
          ),
          _ToggleTile(
            icon: Icons.check_circle_outline_rounded,
            title: 'Validation',
            subtitle: 'Quand votre témoignage est approuvé',
            value: settings.pushApproval,
            onChanged: (_) => notifier.togglePushApproval(),
            isLast: true,
          ),

          // ── Commentaires ───────────────────────────────────────────────
          _SectionHeader('Commentaires'),
          _SelectTile<CommentPermission>(
            icon: Icons.lock_outline_rounded,
            title: 'Qui peut commenter',
            value: settings.commentPermission,
            items: CommentPermission.values,
            labelOf: (v) => v.label,
            onChanged: notifier.setCommentPermission,
            isLast: true,
          ),

          // ── Apparence ──────────────────────────────────────────────────
          _SectionHeader('Apparence'),
          _SelectTile<AppTheme>(
            icon: Icons.palette_outlined,
            title: 'Thème',
            value: settings.appTheme,
            items: AppTheme.values,
            labelOf: (v) => v.label,
            onChanged: notifier.setTheme,
            isLast: true,
          ),

          // ── Compte ─────────────────────────────────────────────────────
          _SectionHeader('Compte'),
          _NavTile(
            icon: Icons.person_outline_rounded,
            title: 'Modifier le profil',
            onTap: () => context.pushNamed(AppRoutes.editProfile),
          ),
          _NavTile(
            icon: Icons.logout_rounded,
            title: 'Se déconnecter',
            color: AppColors.danger,
            onTap: () => _confirmLogout(context, ref),
          ),
          _NavTile(
            icon: Icons.delete_forever_rounded,
            title: 'Supprimer le compte',
            color: AppColors.danger,
            onTap: () => context.pushNamed(AppRoutes.deleteAccount),
            isLast: true,
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'Témoignages v1.0',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textSecondary.withAlpha(120),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Se déconnecter',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text(
            'Voulez-vous vraiment vous déconnecter ?',
            style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: const Text('Déconnecter',
                style: TextStyle(fontFamily: 'Inter')),
          ),
        ],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
    if (ok == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }
}

// ── Sous-widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _TileContainer(
      isLast: isLast,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    )),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withAlpha(80),
          ),
        ],
      ),
    );
  }
}

class _SelectTile<T> extends StatelessWidget {
  const _SelectTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.isLast = false,
  });
  final IconData icon;
  final String title;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _TileContainer(
      isLast: isLast,
      onTap: () => _showSheet(context),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                )),
          ),
          Text(labelOf(value),
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.primary)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    )),
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => ListTile(
                  title: Text(labelOf(item),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: item == value
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: item == value
                            ? FontWeight.w600
                            : FontWeight.normal,
                      )),
                  trailing: item == value
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 20)
                      : null,
                  onTap: () {
                    onChanged(item);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.isLast = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return _TileContainer(
      isLast: isLast,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: c,
                )),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: color != null ? color! : AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _TileContainer extends StatelessWidget {
  const _TileContainer({
    required this.child,
    this.isLast = false,
    this.onTap,
  });
  final Widget child;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      color: AppColors.surface,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: child,
            ),
          ),
          if (!isLast)
            const Divider(
                height: 1, indent: 50, color: AppColors.border),
        ],
      ),
    );

    return onTap != null
        ? Material(color: Colors.transparent, child: tile)
        : tile;
  }
}
