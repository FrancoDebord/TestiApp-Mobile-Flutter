// Politique de confidentialité affichée dans l'application (sans navigateur).
// Texte unique côté serveur : GET legal/privacy?lang=fr|en → { title,
// updated_at, html, url } (docs serveur fonctionnalites/confidentialite-et-suppression.md).
// La dernière version lue est gardée sur l'appareil pour la relire hors ligne.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/html_content.dart';
import '../../../shared/widgets/privacy_policy.dart' show privacyPolicyUrl;

class PrivacyPolicyDoc {
  const PrivacyPolicyDoc({
    required this.title,
    required this.html,
    this.updatedAt,
    this.url,
    this.savedCopy = false,
  });

  final String title;
  final String html;
  final DateTime? updatedAt;
  final String? url;

  /// Vrai si le serveur n'a pas répondu : version gardée sur l'appareil.
  final bool savedCopy;

  static PrivacyPolicyDoc? fromJson(Object? json, {bool savedCopy = false}) {
    if (json is! Map) return null;
    final html = json['html'];
    if (html is! String || html.trim().isEmpty) return null;
    return PrivacyPolicyDoc(
      title: json['title'] as String? ?? '',
      html: html,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      url: json['url'] as String?,
      savedCopy: savedCopy,
    );
  }
}

/// Chargement de la politique (remplacé dans les tests).
final privacyPolicyLoaderProvider = Provider<Future<PrivacyPolicyDoc> Function(String lang)>((ref) {
  final api = ref.watch(apiServiceProvider);
  return (lang) async {
    final key = 'privacy_policy_$lang'; // i18n-ignore
    try {
      final res = await api.get<Map<String, dynamic>>(AppConstants.legalPrivacy, query: {'lang': lang});
      final doc = PrivacyPolicyDoc.fromJson(res.data);
      if (doc == null) throw const FormatException('privacy policy'); // i18n-ignore
      try {
        await (await SharedPreferences.getInstance()).setString(key, jsonEncode(res.data));
      } catch (_) {}
      return doc;
    } catch (_) {
      String? saved;
      try {
        saved = (await SharedPreferences.getInstance()).getString(key);
      } catch (_) {}
      final doc = saved == null ? null : PrivacyPolicyDoc.fromJson(jsonDecode(saved), savedCopy: true);
      if (doc != null) return doc;
      rethrow;
    }
  };
});

/// Politique dans la langue demandée (fr | en).
final privacyPolicyProvider = FutureProvider.autoDispose.family<PrivacyPolicyDoc, String>(
  (ref, lang) => ref.watch(privacyPolicyLoaderProvider)(lang),
);

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Langue affichée par l'application, pas celle du système.
    final lang = l10n.localeName.split('_').first;
    final async = ref.watch(privacyPolicyProvider(lang));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.privacyPolicyLink, style: AppTextStyles.h4.copyWith(fontSize: 18)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Failed(
          onRetry: () => ref.invalidate(privacyPolicyProvider(lang)),
          webUrl: privacyPolicyUrl(lang),
        ),
        data: (doc) => RefreshIndicator(
          onRefresh: () => ref.refresh(privacyPolicyProvider(lang).future),
          child: ListView(
            key: const ValueKey('privacy-policy-content'),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxxl),
            children: [
              if (doc.savedCopy) const _SavedCopyBanner(),
              Text(doc.title, style: AppTextStyles.h2.copyWith(color: AppColors.primaryDark)),
              if (doc.updatedAt != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.sunSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.sunBorder),
                    ),
                    child: Text(
                      l10n.privacyUpdatedOn(formatDateLong(doc.updatedAt!)),
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.sunText),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              HtmlContent(doc.html),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedCopyBanner extends StatelessWidget {
  const _SavedCopyBanner();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(context.l10n.privacySavedCopy,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
          ),
        ]),
      );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry, required this.webUrl});

  final VoidCallback onRetry;
  final String webUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.privacy_tip_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.privacyOpenFailed,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey('privacy-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.commonRetry),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
            TextButton(
              onPressed: () => launchUrl(Uri.parse(webUrl), mode: LaunchMode.inAppBrowserView),
              child: Text(l10n.privacyViewOnWeb),
            ),
          ],
        ),
      ),
    );
  }
}
