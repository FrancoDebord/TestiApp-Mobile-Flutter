import 'package:flutter/material.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/core/theme/app_text_styles.dart';
import 'package:testi_app/shared/widgets/app_button.dart';

// ── Preset configurations ──────────────────────────────────────────────────────

enum EmptyStatePreset {
  noTestimonies,
  noResults,
  noNotifications,
  noInternet,
  noFavorites,
  custom,
}

class _PresetData {
  const _PresetData({
    required this.iconData,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
  final IconData iconData;
  final Color iconColor;
  final String title;
  final String subtitle;
}

const _presets = <EmptyStatePreset, _PresetData>{
  EmptyStatePreset.noTestimonies: _PresetData(
    iconData: Icons.auto_stories_rounded,
    iconColor: AppColors.primaryLight,
    title: 'Aucun témoignage',
    subtitle:
        'Soyez le premier à partager comment Dieu a agi dans votre vie.',
  ),
  EmptyStatePreset.noResults: _PresetData(
    iconData: Icons.search_off_rounded,
    iconColor: AppColors.textSecondary,
    title: 'Aucun résultat',
    subtitle: 'Essayez d\'autres mots-clés ou changez de catégorie.',
  ),
  EmptyStatePreset.noNotifications: _PresetData(
    iconData: Icons.notifications_none_rounded,
    iconColor: AppColors.secondary,
    title: 'Pas de notifications',
    subtitle: 'Vous êtes à jour ! Revenez plus tard.',
  ),
  EmptyStatePreset.noInternet: _PresetData(
    iconData: Icons.wifi_off_rounded,
    iconColor: AppColors.danger,
    title: 'Pas de connexion',
    subtitle:
        'Vérifiez votre connexion internet et réessayez.',
  ),
  EmptyStatePreset.noFavorites: _PresetData(
    iconData: Icons.bookmark_border_rounded,
    iconColor: AppColors.primaryLight,
    title: 'Aucun favori',
    subtitle:
        'Les témoignages que vous sauvegardez apparaîtront ici.',
  ),
  EmptyStatePreset.custom: _PresetData(
    iconData: Icons.inbox_rounded,
    iconColor: AppColors.textSecondary,
    title: 'Rien à afficher',
    subtitle: '',
  ),
};

// ── Public widget ──────────────────────────────────────────────────────────────

/// Empty-state screen with an illustration slot, title, subtitle, and an
/// optional CTA button.
///
/// Supply a [lottieWidget] (e.g. a `Lottie.asset(...)`) to replace the default
/// icon illustration.  The widget is displayed as-is inside a constrained box.
///
/// Example — preset:
/// ```dart
/// EmptyState(
///   preset: EmptyStatePreset.noTestimonies,
///   ctaLabel: 'Publier un témoignage',
///   onCtaTap: () => context.go(AppPaths.publish),
/// )
/// ```
///
/// Example — custom:
/// ```dart
/// EmptyState(
///   preset: EmptyStatePreset.custom,
///   title: 'Profil incomplet',
///   subtitle: 'Complétez votre profil pour une meilleure expérience.',
///   lottieWidget: Lottie.asset('assets/lottie/profile.json', width: 180),
///   ctaLabel: 'Compléter le profil',
///   onCtaTap: _navigateToSettings,
/// )
/// ```
class EmptyState extends StatelessWidget {
  const EmptyState({
    this.preset = EmptyStatePreset.custom,
    this.title,
    this.subtitle,
    this.lottieWidget,
    this.ctaLabel,
    this.onCtaTap,
    this.ctaVariant = AppButtonVariant.primary,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
    super.key,
  });

  final EmptyStatePreset preset;

  /// Overrides the preset title when provided.
  final String? title;

  /// Overrides the preset subtitle when provided.
  final String? subtitle;

  /// Drop in any widget here — intended for a Lottie animation, SVG, or image.
  /// When `null` the default icon illustration is shown.
  final Widget? lottieWidget;

  /// Label for the optional CTA button. The button is hidden when `null`.
  final String? ctaLabel;
  final VoidCallback? onCtaTap;
  final AppButtonVariant ctaVariant;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final data = _presets[preset]!;
    final resolvedTitle = title ?? data.title;
    final resolvedSubtitle = subtitle ?? data.subtitle;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration
            _Illustration(
              lottieWidget: lottieWidget,
              iconData: data.iconData,
              iconColor: data.iconColor,
            ),
            const SizedBox(height: 28),

            // Title
            Text(
              resolvedTitle,
              style: AppTextStyles.h3.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),

            // Subtitle
            if (resolvedSubtitle.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                resolvedSubtitle,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],

            // CTA
            if (ctaLabel != null && onCtaTap != null) ...[
              const SizedBox(height: 32),
              AppButton(
                label: ctaLabel!,
                onPressed: onCtaTap,
                variant: ctaVariant,
                size: AppButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Illustration ───────────────────────────────────────────────────────────────

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.lottieWidget,
    required this.iconData,
    required this.iconColor,
  });

  final Widget? lottieWidget;
  final IconData iconData;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    if (lottieWidget != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
        child: lottieWidget,
      );
    }

    // Fallback: icon inside a soft gradient circle
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: iconColor.withAlpha(20),
      ),
      child: Icon(
        iconData,
        size: 56,
        color: iconColor,
      ),
    );
  }
}
