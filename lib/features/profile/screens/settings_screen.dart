import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show authStateProvider;
import '../../../l10n/app_localizations.dart';
import '../models/profile_models.dart';
import '../providers/profile_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    final notifier = ref.read(userSettingsProvider.notifier);
    final locale   = ref.watch(localeProvider);
    final isFr     = locale.languageCode == 'fr';

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.settingsTitle,
            style: const TextStyle(
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
          // ── Langue ─────────────────────────────────────────────────────
          _SectionHeader(l10n.settingsLanguage),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                _LangButton(
                  label: l10n.settingsFrench,
                  flag: '🇫🇷',
                  selected: isFr,
                  onTap: () => ref.read(localeProvider.notifier).setFrench(),
                ),
                const SizedBox(width: 12),
                _LangButton(
                  label: l10n.settingsEnglish,
                  flag: '🇬🇧',
                  selected: !isFr,
                  onTap: () => ref.read(localeProvider.notifier).setEnglish(),
                ),
              ],
            ),
          ),

          // ── Notifications ──────────────────────────────────────────────
          _SectionHeader(l10n.settingsNotifs),
          _ToggleTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: l10n.detailComments,
            subtitle: l10n.settingsNotifComment,
            value: settings.pushComments,
            onChanged: (_) => notifier.togglePushComments(),
          ),
          _ToggleTile(
            icon: Icons.favorite_outline_rounded,
            title: l10n.detailLike,
            subtitle: l10n.settingsNotifLike,
            value: settings.pushLikes,
            onChanged: (_) => notifier.togglePushLikes(),
          ),
          _ToggleTile(
            icon: Icons.volunteer_activism_outlined,
            title: l10n.profilePrayers,
            subtitle: l10n.settingsNotifPray,
            value: settings.pushPrayers,
            onChanged: (_) => notifier.togglePushPrayers(),
          ),
          _ToggleTile(
            icon: Icons.check_circle_outline_rounded,
            title: isFr ? 'Validation' : 'Approval',
            subtitle: l10n.settingsNotifApproved,
            value: settings.pushApproval,
            onChanged: (_) => notifier.togglePushApproval(),
            isLast: true,
          ),

          // ── Commentaires ───────────────────────────────────────────────
          _SectionHeader(l10n.detailComments),
          _SelectTile<CommentPermission>(
            icon: Icons.lock_outline_rounded,
            title: l10n.settingsWhoCanComment,
            value: settings.commentPermission,
            items: CommentPermission.values,
            labelOf: (v) => v.label,
            onChanged: notifier.setCommentPermission,
            isLast: true,
          ),

          // ── Apparence ──────────────────────────────────────────────────
          _SectionHeader(l10n.settingsAppearance),
          _SelectTile<AppTheme>(
            icon: Icons.palette_outlined,
            title: l10n.settingsTheme,
            value: settings.appTheme,
            items: AppTheme.values,
            labelOf: (v) => v.label,
            onChanged: notifier.setTheme,
            isLast: true,
          ),

          // ── Communauté ─────────────────────────────────────────────────
          _SectionHeader(l10n.settingsCommunity),
          _NavTile(
            icon: Icons.group_add_rounded,
            title: l10n.settingsInvite,
            onTap: () => SharePlus.instance.share(
              ShareParams(
                subject: isFr
                    ? 'Découvre l\'application Témoignages'
                    : 'Discover the Testimonies app',
                text: isFr
                    ? 'Je t\'invite à rejoindre l\'application Témoignages — '
                        'un espace pour partager et vivre les miracles de Dieu 🙏\n\n'
                        'Télécharge-la ici : https://testi.app/download'
                    : 'I invite you to join the Testimonies app — '
                        'a space to share and live God\'s miracles 🙏\n\n'
                        'Download it here: https://testi.app/download',
              ),
            ),
            isLast: true,
          ),

          // ── Compte ─────────────────────────────────────────────────────
          _SectionHeader(l10n.settingsAccount),
          _NavTile(
            icon: Icons.person_outline_rounded,
            title: l10n.profileEdit,
            onTap: () => context.pushNamed(AppRoutes.editProfile),
          ),
          _NavTile(
            icon: Icons.logout_rounded,
            title: l10n.settingsLogout,
            color: AppColors.danger,
            onTap: () => _confirmLogout(context, ref),
          ),
          _NavTile(
            icon: Icons.delete_forever_rounded,
            title: l10n.settingsDelete,
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
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.settingsLogout,
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: Text(l10n.settingsLogoutConfirm,
            style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: Text(l10n.settingsLogout,
                style: const TextStyle(fontFamily: 'Inter')),
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

class _LangButton extends StatelessWidget {
  const _LangButton({
    required this.label,
    required this.flag,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
