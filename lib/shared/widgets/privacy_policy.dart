// Politique de confidentialité : lien visible sans compte (connexion, inscription,
// mode invité, profil, À propos), ouvert dans un écran de l'application.
// Serveur : /confidentialite (français), /privacy (anglais) —
// docs serveur fonctionnalites/confidentialite-et-suppression.md

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_constants.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../l10n/app_localizations.dart';

/// Adresse de la politique sur le site, dans la langue de l'application.
String privacyPolicyUrl(String languageCode) =>
    '${AppConstants.webBaseUrl}/${languageCode == 'en' ? 'privacy' : 'confidentialite'}';

/// Ouverture d'une page web dans le navigateur intégré (remplacée dans les tests).
final inAppBrowserLauncherProvider = Provider<Future<bool> Function(Uri uri)>(
  (_) => (uri) => launchUrl(uri, mode: LaunchMode.inAppBrowserView),
);

/// true si une connexion réseau est disponible (remplacée dans les tests).
final networkAvailableProvider = Provider<Future<bool> Function()>(
  (_) => () async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // Inconnu : on tente l'ouverture.
    }
  },
);

/// Ouvre la politique dans l'application (écran natif, sans navigateur ;
/// lib/features/profile/screens/privacy_policy_screen.dart).
Future<void> openPrivacyPolicy(BuildContext context) =>
    context.push(AppPaths.privacyPolicyPath);

/// Lien « Politique de confidentialité » (connexion, inscription).
class PrivacyPolicyLink extends StatelessWidget {
  const PrivacyPolicyLink({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: TextButton.icon(
          key: const ValueKey('privacy-policy-link'),
          onPressed: () => openPrivacyPolicy(context),
          icon: const Icon(Icons.privacy_tip_outlined, size: 18),
          label: Text(context.l10n.privacyPolicyLink),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      );
}

/// Mention sous un bouton Google : « En continuant, vous acceptez la politique de confidentialité ».
class GooglePrivacyNotice extends StatelessWidget {
  const GooglePrivacyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        key: const ValueKey('google-privacy-notice'),
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${l10n.privacyGoogleNoticePrefix} ', style: style, textAlign: TextAlign.center),
          InkWell(
            onTap: () => openPrivacyPolicy(context),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                l10n.privacyPolicyLinkLower,
                style: style.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
