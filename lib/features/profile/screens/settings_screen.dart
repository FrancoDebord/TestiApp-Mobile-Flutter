import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../testimony/providers/detail_layout_provider.dart';
import '../../../core/media/playback_preferences.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../features/accounts/providers/acting_account_provider.dart'
    show actingAccountProvider, myAccountsProvider;
import '../../../features/accounts/widgets/account_widgets.dart'
    show ensureOwnerAction, returnToOwnAccount, showAccountSwitcher;
import '../../../features/auth/providers/auth_notifier.dart'
    show authStateProvider;
import '../../../features/location/nearby_widgets.dart' show locationSettingsPath;
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/quality_picker_sheet.dart';
import '../models/profile_models.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_menu.dart';
import '../widgets/push_test.dart';

/// Écran 12 de la maquette : « Paramètres ».
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    final notifier = ref.read(userSettingsProvider.notifier);
    final playback = ref.watch(playbackPreferencesProvider);
    final playCtl  = ref.read(playbackPreferencesProvider.notifier);

    final l10n = context.l10n;

    // Agit pour un compte administré : les réglages réservés au titulaire
    // (sécurité, notifications, localisation, commentaires) sont bloqués.
    final acting = ref.watch(actingAccountProvider);
    final canSwitch = acting != null ||
        (ref.watch(myAccountsProvider).value?.managed.isNotEmpty ?? false);

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
          if (acting != null) ...[
            _ActingNotice(
              name: acting.displayName,
              onReturn: () => returnToOwnAccount(context, ref),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // ── Menu principal (maquette) ───────────────────────────────────
          ProfileMenuCard(
            children: [
              ProfileMenuTile(
                icon: Icons.shield_outlined,
                title: l10n.settingsAccountSecurity,
                onTap: () => _showAccountSheet(context),
              ),
              // Administrateurs du compte : tous les comptes (2 personnes au plus).
              ProfileMenuTile(
                icon: Icons.manage_accounts_outlined,
                title: l10n.accountsManagersTitle,
                subtitle: l10n.settingsManagersSubtitle,
                onTap: () => context.push('/managers'),
              ),
              if (canSwitch)
                ProfileMenuTile(
                  icon: Icons.swap_horiz_rounded,
                  title: l10n.settingsSwitchAccount,
                  subtitle: acting == null
                      ? l10n.settingsSwitchAccountSubtitle
                      : l10n.accountsActingAs(acting.displayName),
                  onTap: () => showAccountSwitcher(context),
                ),
              ProfileMenuTile(
                icon: Icons.notifications_none_rounded,
                title: l10n.settingsNotifs,
                onTap: () {
                  if (ensureOwnerAction(context, ref)) {
                    _showNotificationsSheet(context);
                  }
                },
              ),
              // « Tester les notifications » : POST /me/push-test.
              ProfileMenuTile(
                key: const ValueKey('push-test-tile'),
                icon: Icons.notifications_active_outlined,
                title: l10n.pushTestTitle,
                subtitle: l10n.pushTestSubtitle,
                onTap: () => runPushTest(context, ref),
              ),
              ProfileMenuTile(
                icon: Icons.language_rounded,
                title: l10n.settingsLanguage,
                value: switch (ref.watch(appLanguageProvider)) {
                  AppLanguage.system => l10n.languageSystem,
                  AppLanguage.fr => l10n.languageFrench,
                  AppLanguage.en => l10n.languageEnglish,
                },
                onTap: () => context.pushNamed(AppRoutes.language),
              ),
              // Localisation privée : fils classés par zone (docs serveur : localisation.md).
              ProfileMenuTile(
                icon: Icons.location_on_outlined,
                title: l10n.settingsLocation,
                subtitle: l10n.settingsLocationSubtitle,
                onTap: () {
                  if (ensureOwnerAction(context, ref)) {
                    context.push(locationSettingsPath);
                  }
                },
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
                onTap: () => context.push(AppPaths.downloadsPath),
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
              // Affichage d'un témoignage : classique ou immersif.
              _toggle(
                icon: Icons.self_improvement_rounded,
                title: l10n.immersiveSettingTitle,
                subtitle: l10n.immersiveSettingSubtitle,
                value: ref.watch(testimonyDetailLayoutProvider) == TestimonyDetailLayout.immersive,
                onChanged: (v) => ref.read(testimonyDetailLayoutProvider.notifier).set(
                    v ? TestimonyDetailLayout.immersive : TestimonyDetailLayout.classic),
              ),
              ProfileMenuTile(
                icon: Icons.hd_outlined,
                title: l10n.settingsVideoQuality,
                subtitle: l10n.settingsVideoQualitySubtitle(
                    playback.videoQualityMobile.fullLabel,
                    playback.videoQualityWifi.fullLabel),
                onTap: () => context.pushNamed(AppRoutes.videoQuality),
              ),
              ProfileMenuTile(
                icon: Icons.graphic_eq_rounded,
                title: l10n.settingsAudioQuality,
                value: playback.audioQuality.label,
                onTap: () async {
                  final q = await showQualityPickerSheet<AudioQuality>(
                    context,
                    title: l10n.settingsAudioQuality,
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
                title: l10n.settingsDataSaver,
                subtitle: l10n.settingsDataSaverSubtitle,
                value: playback.dataSaver,
                onChanged: playCtl.setDataSaver,
              ),
              _toggle(
                icon: Icons.playlist_play_rounded,
                title: l10n.settingsAutoplay,
                subtitle: l10n.settingsAutoplaySubtitle,
                value: playback.autoplayNext,
                onChanged: playCtl.setAutoplayNext,
              ),
              _select<RepeatMode>(
                context,
                icon: Icons.repeat_rounded,
                title: l10n.settingsRepeat,
                value: playback.repeatMode,
                items: RepeatMode.values,
                labelOf: (v) => v.label,
                onChanged: playCtl.setRepeatMode,
              ),
              _select<FeedLayout>(
                context,
                icon: Icons.view_agenda_outlined,
                title: l10n.settingsFeedLayout,
                value: playback.feedLayout,
                items: FeedLayout.values,
                labelOf: (v) => v.label,
                onChanged: playCtl.setFeedLayout,
              ),
            ],
          ),

          // ── Préférences : commentaires, apparence, communauté ──────────
          const SizedBox(height: AppSpacing.xxl),
          ProfileMenuCard(
            title: l10n.settingsPreferences,
            children: [
              if (acting != null)
                ProfileMenuTile(
                  icon: Icons.lock_outline_rounded,
                  title: l10n.settingsWhoCanComment,
                  value: settings.commentPermission.label,
                  onTap: () => ensureOwnerAction(context, ref),
                )
              else
                _select<CommentPermission>(
                  context,
                  icon: Icons.lock_outline_rounded,
                  title: l10n.settingsWhoCanComment,
                  value: settings.commentPermission,
                  items: CommentPermission.values,
                  labelOf: (v) => v.label,
                  onChanged: notifier.setCommentPermission,
                ),
              ProfileMenuTile(
                icon: Icons.group_add_outlined,
                title: l10n.settingsInvite,
                onTap: () => SharePlus.instance.share(
                  ShareParams(
                    subject: l10n.settingsInviteSubject,
                    text: l10n.settingsInviteText('https://testi.app/download'),
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
            onPressed: () => confirmLogout(context, ref),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'Témoignages de Gloire v1.0', // i18n-ignore
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
    final l10n = context.l10n;
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
              title: l10n.settingsSecurityPassword,
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
    final l10n = context.l10n;
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
                title: l10n.settingsNotifApprovalTitle,
                subtitle: l10n.settingsNotifApproved,
                value: settings.pushApproval,
                onChanged: (_) => notifier.togglePushApproval(),
              ),
              _toggle(
                icon: Icons.person_add_alt_outlined,
                title: l10n.settingsNotifFollowedTitle,
                subtitle: l10n.settingsNotifFollowed,
                value: settings.push('push_new_followed'),
                onChanged: (_) => notifier.togglePush('push_new_followed'),
              ),
              _toggle(
                icon: Icons.group_add_outlined,
                title: l10n.settingsNotifFollowsTitle,
                subtitle: l10n.settingsNotifFollows,
                value: settings.push('push_follows'),
                onChanged: (_) => notifier.togglePush('push_follows'),
              ),
              _toggle(
                icon: Icons.event_outlined,
                title: l10n.settingsNotifEventsTitle,
                subtitle: l10n.settingsNotifEvents,
                value: settings.push('push_events'),
                onChanged: (_) => notifier.togglePush('push_events'),
              ),
              _toggle(
                icon: Icons.manage_accounts_outlined,
                title: l10n.settingsNotifAccountTitle,
                subtitle: l10n.settingsNotifAccount,
                value: settings.push('push_account'),
                onChanged: (_) => notifier.togglePush('push_account'),
              ),
              if (ref.watch(currentUserProvider)?.canModerate ?? false)
                _toggle(
                  icon: Icons.shield_outlined,
                  title: l10n.settingsNotifModerationTitle,
                  subtitle: l10n.settingsNotifModeration,
                  value: settings.push('push_moderation'),
                  onChanged: (_) => notifier.togglePush('push_moderation'),
                ),
            ],
          );
        }),
      ),
    );
  }
}

/// Demande confirmation puis déconnecte (Paramètres et Mon profil).
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
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

// ── Sous-widgets ──────────────────────────────────────────────────────────

/// Encadré affiché quand on agit pour un compte administré.
class _ActingNotice extends StatelessWidget {
  const _ActingNotice({required this.name, required this.onReturn});
  final String name;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.secondary.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: l10n.accountsActingAsPrefix),
              TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: l10n.settingsActingNoticeSuffix),
            ]),
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.4),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onReturn, child: Text(l10n.accountsReturnToMine)),
          ),
        ],
      ),
    );
  }
}

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
