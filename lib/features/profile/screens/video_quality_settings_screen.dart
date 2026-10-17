// lib/features/profile/screens/video_quality_settings_screen.dart
//
// Paramètres › Qualité vidéo : qualité par défaut selon le réseau (détecté
// avec connectivity_plus), enregistrée sur l'appareil.
//   • Sur données mobiles : Standard (360p, par défaut) ou Économie (240p) ;
//     jamais de lecture automatique, la miniature s'affiche d'abord.
//   • En Wi-Fi : Auto (par défaut, flux adaptatif), HD, Standard ou Économie.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/playback_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/profile_menu.dart';

class VideoQualitySettingsScreen extends ConsumerWidget {
  const VideoQualitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(playbackPreferencesProvider);
    final ctl = ref.read(playbackPreferencesProvider.notifier);
    final metered = ref.watch(isMeteredConnectionProvider).value;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.settingsVideoQuality,
            style: AppTextStyles.h4.copyWith(fontSize: 18)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxl),
        children: [
          if (metered != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    metered
                        ? Icons.signal_cellular_alt_rounded
                        : Icons.wifi_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      metered
                          ? l10n.settingsCurrentConnectionMobile
                          : l10n.settingsCurrentConnectionWifi,
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          _QualityGroup(
            title: l10n.settingsOnMobileData,
            choices: VideoQuality.mobileChoices,
            selected: prefs.videoQualityMobile,
            onSelected: ctl.setVideoQualityMobile,
            footer: l10n.settingsMobileDataFooter,
          ),
          const SizedBox(height: AppSpacing.xxl),
          _QualityGroup(
            title: l10n.settingsOnWifi,
            choices: VideoQuality.wifiChoices,
            selected: prefs.videoQualityWifi,
            onSelected: ctl.setVideoQualityWifi,
            footer: l10n.settingsWifiFooter,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.settingsQualityDuringPlayback,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _QualityGroup extends StatelessWidget {
  const _QualityGroup({
    required this.title,
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.footer,
  });

  final String title;
  final List<VideoQuality> choices;
  final VideoQuality selected;
  final ValueChanged<VideoQuality> onSelected;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileMenuCard(
          title: title,
          children: [
            for (final q in choices)
              ProfileMenuTile(
                icon: q == selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: q == selected ? AppColors.primary : null,
                title: q.fullLabel,
                subtitle: q.hint,
                showChevron: false,
                onTap: () => onSelected(q),
              ),
          ],
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, 0),
            child: Text(footer!, style: AppTextStyles.bodySmall),
          ),
      ],
    );
  }
}
