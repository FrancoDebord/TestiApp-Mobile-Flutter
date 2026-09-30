import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import '../../../core/media/media_quality.dart' show autoVideoHeight;
import '../../../core/media/playback_preferences.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show authStateProvider;
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/quality_picker_sheet.dart';
import '../models/profile_models.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_menu.dart';

/// Écran 12 de la maquette : « Paramètres ».
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    final notifier = ref.read(userSettingsProvider.notifier);
    final locale   = ref.watch(localeProvider);
    final isFr     = locale.languageCode == 'fr';
    final playback = ref.watch(playbackPreferencesProvider);
    final playCtl  = ref.read(playbackPreferencesProvider.notifier);

    // Plafonds réels du mode Auto (tiennent compte de l'économiseur).
    final autoMobile =
        autoVideoHeight(metered: true, dataSaver: playback.dataSaver);
    final autoWifi =
        autoVideoHeight(metered: false, dataSaver: playback.dataSaver);

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.settingsTitle,
            style: AppTextStyles.h4.copyWith(fontSize: 18)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxxl),
        children: [
          // ── Menu principal (maquette) ───────────────────────────────────
          ProfileMenuCard(
            children: [
              ProfileMenuTile(
                icon: Icons.shield_outlined,
                title: l10n.settingsAccountSecurity,
                onTap: () => _showAccountSheet(context),
              ),
              ProfileMenuTile(
                icon: Icons.notifications_none_rounded,
                title: l10n.settingsNotifs,
                onTap: () => _showNotificationsSheet(context),
              ),
              ProfileMenuTile(
                icon: Icons.language_rounded,
                title: l10n.settingsLanguage,
                value: isFr ? 'Français' : 'English',
                onTap: () => context.pushNamed(AppRoutes.language),
              ),
              ProfileMenuTile(
                icon: Icons.download_for_offline_outlined,
                title: l10n.settingsOffline,
                subtitle: l10n.settingsOfflineDesc,
                trailing: _BrandSwitch(
                  value: playback.offlineMode,
                  onChanged: playCtl.setOfflineMode,
                ),
                onTap: () => playCtl.setOfflineMode(!playback.offlineMode),
              ),
              ProfileMenuTile(
                icon: Icons.sd_storage_outlined,
                title: l10n.settingsStorage,
                subtitle: l10n.profileDownloads,
                onTap: () => context.go(AppPaths.downloadsPath),
              ),
              ProfileMenuTile(
                icon: Icons.help_outline_rounded,
                title: l10n.profileHelp,
                onTap: () => context.pushNamed(AppRoutes.help),
              ),
              ProfileMenuTile(
                icon: Icons.info_outline_rounded,
                title: l10n.profileAbout,
                onTap: () => context.pushNamed(AppRoutes.about),
              ),
            ],
          ),

          // ── Lecture et données ─────────────────────────────────────────
          const SizedBox(height: AppSpacing.xxl),
          ProfileMenuCard(
            title: l10n.settingsPlayback,
            children: [
              ProfileMenuTile(
                icon: Icons.hd_outlined,
                title: 'Qualité vidéo par défaut',
                value: playback.videoQuality.label,
                onTap: () async {
                  final q = await showQualityPickerSheet<VideoQuality>(
                    context,
                    title: 'Qualité vidéo par défaut',
                    options: [
                      for (final v in VideoQuality.values)
                        QualityOption(value: v, label: v.label, hint: v.hint),
                    ],
                    selected: playback.videoQuality,
                    footer: 'Auto : ${autoMobile}p sur données mobiles, '
                        '${autoWifi}p en Wi-Fi.',
                  );
                  if (q != null) playCtl.setVideoQuality(q);
                },
              ),
              ProfileMenuTile(
                icon: Icons.graphic_eq_rounded,
                title: 'Qualité audio par défaut',
                value: playback.audioQuality.label,
                onTap: () async {
                  final q = await showQualityPickerSheet<AudioQuality>(
                    context,
                    title: 'Qualité audio par défaut',
                    options: [
                      for (final v in AudioQuality.values)
                        QualityOption(value: v, label: v.label, hint: v.hint),
                    ],
                    selected: playback.audioQuality,
                  );
                  if (q != null) playCtl.setAudioQuality(q);
                },
              ),
              _toggle(
                icon: Icons.data_saver_on_rounded,
                title: 'Économiseur de données',
                subtitle: 'Qualité réduite sur données mobiles',
                value: playback.dataSaver,
                onChanged: playCtl.setDataSaver,
              ),
              _toggle(
                icon: Icons.playlist_play_rounded,
                title: 'Lecture automatique',
                subtitle: 'Enchaîner le témoignage suivant',
                value: playback.autoplayNext,
                onChanged: playCtl.setAutoplayNext,
              ),
              _select<RepeatMode>(
                context,
                icon: Icons.repeat_rounded,
                title: 'Répétition',
                value: playback.repeatMode,
                items: RepeatMode.values,
                labelOf: (v) => v.label,
                onChanged: playCtl.setRepeatMode,
              ),
              _select<FeedLayout>(
                context,
                icon: Icons.view_agenda_outlined,
                title: 'Affichage du fil',
                value: playback.feedLayout,
                items: FeedLayout.values,
                labelOf: (v) => v.label,
                onChanged: playCtl.setFeedLayout,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, 0),
            child: Text(
              'Auto : ${autoMobile}p sur données mobiles, ${autoWifi}p en Wi-Fi.',
              style: AppTextStyles.bodySmall,
            ),
          ),

          // ── Préférences : commentaires, apparence, communauté ──────────
          const SizedBox(height: AppSpacing.xxl),
          ProfileMenuCard(
            title: 'Préférences',
            children: [
              _select<CommentPermission>(
                context,
                icon: Icons.lock_outline_rounded,
                title: l10n.settingsWhoCanComment,
                value: settings.commentPermission,
                items: CommentPermission.values,
                labelOf: (v) => v.label,
                onChanged: notifier.setCommentPermission,
              ),
              _select<AppTheme>(
                context,
                icon: Icons.palette_outlined,
                title: l10n.settingsTheme,
                value: settings.appTheme,
                items: AppTheme.values,
                labelOf: (v) => v.label,
                onChanged: notifier.setTheme,
              ),
              ProfileMenuTile(
                icon: Icons.group_add_outlined,
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
              ),
            ],
          ),

          // ── Déconnexion ────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.xxxl),
          AppButton(
            label: l10n.settingsLogout,
            leadingIcon: Icons.logout_rounded,
            variant: AppButtonVariant.danger,
            fullWidth: true,
            onPressed: () => _confirmLogout(context, ref),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'Témoignages de Gloire v1.0',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary.withAlpha(150)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Compte et sécurité ───────────────────────────────────────────────────

  void _showAccountSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => _SheetFrame(
        title: l10n.settingsAccountSecurity,
        child: ProfileMenuCard(
          children: [
            ProfileMenuTile(
              icon: Icons.person_outline_rounded,
              title: l10n.profileEdit,
              onTap: () {
                Navigator.pop(sheet);
                context.pushNamed(AppRoutes.editProfile);
              },
            ),
            ProfileMenuTile(
              icon: Icons.lock_outline_rounded,
              title: 'Sécurité et mot de passe',
              onTap: () {
                Navigator.pop(sheet);
                context.pushNamed(AppRoutes.changePassword);
              },
            ),
            ProfileMenuTile(
              icon: Icons.delete_forever_outlined,
              title: l10n.settingsDelete,
              color: AppColors.danger,
              onTap: () {
                Navigator.pop(sheet);
                context.pushNamed(AppRoutes.deleteAccount);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Notifications (préférences existantes) ──────────────────────────────

  void _showNotificationsSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SheetFrame(
        title: l10n.settingsNotifs,
        child: Consumer(builder: (context, ref, _) {
          final settings = ref.watch(userSettingsProvider);
          final notifier = ref.read(userSettingsProvider.notifier);
          final isFr = ref.watch(localeProvider).languageCode == 'fr';
          return ProfileMenuCard(
            children: [
              _toggle(
                icon: Icons.chat_bubble_outline_rounded,
                title: l10n.detailComments,
                subtitle: l10n.settingsNotifComment,
                value: settings.pushComments,
                onChanged: (_) => notifier.togglePushComments(),
              ),
              _toggle(
                icon: Icons.favorite_outline_rounded,
                title: l10n.detailLike,
                subtitle: l10n.settingsNotifLike,
                value: settings.pushLikes,
                onChanged: (_) => notifier.togglePushLikes(),
              ),
              _toggle(
                icon: Icons.volunteer_activism_outlined,
                title: l10n.profilePrayers,
                subtitle: l10n.settingsNotifPray,
                value: settings.pushPrayers,
                onChanged: (_) => notifier.togglePushPrayers(),
              ),
              _toggle(
                icon: Icons.check_circle_outline_rounded,
                title: isFr ? 'Validation' : 'Approval',
                subtitle: l10n.settingsNotifApproved,
                value: settings.pushApproval,
                onChanged: (_) => notifier.togglePushApproval(),
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.settingsLogout, style: AppTextStyles.h4),
        content: Text(l10n.settingsLogoutConfirm, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.commonCancel,
                style: const TextStyle(
                    fontFamily: AppFonts.family,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          AppButton(
            label: l10n.settingsLogout,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialog, true),
          ),
        ],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
    );
    if (ok == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }
}

// ── Sous-widgets ──────────────────────────────────────────────────────────

Widget _toggle({
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return ProfileMenuTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    trailing: _BrandSwitch(value: value, onChanged: onChanged),
    onTap: () => onChanged(!value),
  );
}

Widget _select<T>(
  BuildContext context, {
  required IconData icon,
  required String title,
  required T value,
  required List<T> items,
  required String Function(T) labelOf,
  required ValueChanged<T> onChanged,
}) {
  return ProfileMenuTile(
    icon: icon,
    title: title,
    value: labelOf(value),
    onTap: () => showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const _SheetHandle(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: AppTextStyles.h4),
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => ListTile(
                  title: Text(labelOf(item),
                      style: AppTextStyles.bodyMedium.copyWith(
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
                    Navigator.pop(sheet);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

class _BrandSwitch extends StatelessWidget {
  const _BrandSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.success,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: AppColors.border,
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
            color: AppColors.border, borderRadius: BorderRadius.circular(2)),
      );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
