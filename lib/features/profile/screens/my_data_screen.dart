// « Mes données » (Paramètres › Compte) : supprimer ce qu'on a publié élément par
// élément, sans supprimer son compte (exigence Google Play) ; demander la
// suppression d'autres données sur le site ; supprimer le compte.
// Serveur : docs/fonctionnalites/confidentialite-et-suppression.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/privacy_policy.dart' show inAppBrowserLauncherProvider, networkAvailableProvider;
import '../widgets/profile_menu.dart';

/// Adresse de contact (repli si la page de suppression ne s'ouvre pas) :
/// `--dart-define=CONTACT_EMAIL=…`. Vide tant qu'elle n'est pas fixée (la politique
/// du serveur indique encore « [adresse e-mail de contact] ») : pas d'e-mail alors.
const kContactEmail = String.fromEnvironment('CONTACT_EMAIL');

/// Page « Suppression de compte » du site, dans la langue de l'application.
String accountDeletionPageUrl(String languageCode) =>
    '${AppConstants.webBaseUrl}/${languageCode == 'en' ? 'delete-account' : 'suppression-compte'}';

/// Ouvre la page de suppression dans le navigateur intégré ; sinon un e-mail.
Future<void> openDeletionRequest(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final page = Uri.parse(accountDeletionPageUrl(l10n.localeName.split('_').first));
  var opened = false;
  if (await container.read(networkAvailableProvider)()) {
    try {
      opened = await container.read(inAppBrowserLauncherProvider)(page);
    } catch (_) {}
  }
  if (opened) return;
  // Repli : e-mail à l'adresse de contact, si elle est configurée.
  if (kContactEmail.isNotEmpty) {
    final mail = Uri(scheme: 'mailto', path: kContactEmail, queryParameters: {'subject': l10n.myDataRequestOther});
    try {
      if (await launchUrl(mail)) return;
    } catch (_) {}
  }
  messenger?.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 8),
    content: Text(kContactEmail.isNotEmpty
        ? l10n.myDataRequestFailed(kContactEmail)
        : l10n.myDataRequestFailedNoEmail(page.toString())),
  ));
}

class MyDataScreen extends ConsumerWidget {
  const MyDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.myDataTitle),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xxxl),
        children: [
          Text(l10n.myDataIntro, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: AppSpacing.lg),
          ProfileMenuCard(
            children: [
              ProfileMenuTile(
                key: const ValueKey('my-data-testimonies'),
                icon: Icons.auto_stories_outlined,
                title: l10n.myDataTestimonies,
                subtitle: l10n.myDataItemHint,
                onTap: () => context.pushNamed(AppRoutes.myTestimonies),
              ),
              ProfileMenuTile(
                key: const ValueKey('my-data-prayers'),
                icon: Icons.volunteer_activism_outlined,
                title: l10n.myDataPrayerRequests,
                subtitle: l10n.myDataItemHint,
                onTap: () => context.push('/prayer-requests?tab=mine'),
              ),
              ProfileMenuTile(
                key: const ValueKey('my-data-prophecies'),
                icon: Icons.record_voice_over_outlined,
                title: l10n.myDataProphecies,
                subtitle: l10n.myDataItemHint,
                onTap: () => context.push('/prophecies'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            key: const ValueKey('my-data-request-other'),
            onPressed: () => openDeletionRequest(context),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l10n.myDataRequestOther, textAlign: TextAlign.center),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 6),
          Text(l10n.myDataRequestOtherHint,
              textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xxl),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          ProfileMenuCard(
            children: [
              ProfileMenuTile(
                key: const ValueKey('my-data-delete-account'),
                icon: Icons.delete_forever_outlined,
                title: l10n.settingsDelete,
                subtitle: l10n.myDataDeleteAccountHint,
                color: AppColors.danger,
                onTap: () => context.pushNamed(AppRoutes.deleteAccount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
