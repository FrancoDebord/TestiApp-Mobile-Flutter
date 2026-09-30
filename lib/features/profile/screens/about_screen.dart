import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_logo.dart';
import '../widgets/profile_menu.dart';

/// À propos de l'application.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Version affichée (pubspec.yaml : version 1.0.0+1).
  static const String appVersion = '1.0.0';

  Future<void> _openSite(BuildContext context) async {
    final ok = await launchUrl(Uri.parse(AppConstants.webBaseUrl),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir le site web")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.profileAbout, style: AppTextStyles.h4.copyWith(fontSize: 18)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xxxl),
        children: [
          const Center(child: AppLogo(markSize: 88, titleSize: 26)),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.sunSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.sunBorder),
              ),
              child: Text(
                'Version $appVersion',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.sunText, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: AppShadows.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notre mission', style: AppTextStyles.h4),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Témoignages de Gloire rassemble les récits de vies '
                  'transformées pour la gloire de Dieu. Partagez ce que Dieu '
                  'a fait pour vous en vidéo, en audio, en texte ou en image, '
                  'et soyez édifiés par les témoignages de la communauté — '
                  'même hors connexion.',
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.55),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '« Ils l\'ont vaincu à cause du sang de l\'Agneau et à cause '
                  'de la parole de leur témoignage. » — Apocalypse 12:11',
                  style: AppTextStyles.bodySmall.copyWith(
                      fontStyle: FontStyle.italic, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ProfileMenuCard(
            children: [
              ProfileMenuTile(
                icon: Icons.public_rounded,
                title: 'Site web',
                subtitle: AppConstants.webBaseUrl
                    .replaceFirst(RegExp('^https?://'), ''),
                onTap: () => _openSite(context),
              ),
              ProfileMenuTile(
                icon: Icons.help_outline_rounded,
                title: l10n.profileHelp,
                onTap: () => context.pushNamed(AppRoutes.help),
              ),
              ProfileMenuTile(
                icon: Icons.description_outlined,
                title: 'Licences open source',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Témoignages de Gloire',
                  applicationVersion: appVersion,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Conçu par ARISE & SHINE Krea',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            '© ${DateTime.now().year} Témoignages de Gloire. Tous droits réservés.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}
