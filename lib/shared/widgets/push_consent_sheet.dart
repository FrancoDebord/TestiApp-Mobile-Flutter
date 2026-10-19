// Notifications push sur consentement : avant la fenêtre du système, l'application
// explique ce que la personne recevra ; elle choisit ensuite les catégories dans
// Paramètres › Notifications (docs serveur fonctionnalites/notifications-push.md).

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../services/push_service.dart';

const _kAskedAtKey = 'push_consent_asked_at';

/// Demande le consentement tant que rien n'est décidé ; après « Plus tard »,
/// pas avant 7 jours.
Future<void> askPushConsent(BuildContext context, PushService push, FlutterSecureStorage storage) async {
  try {
    final last = DateTime.tryParse(await storage.read(key: _kAskedAtKey) ?? '');
    if (last != null && DateTime.now().difference(last) < const Duration(days: 7)) return;
  } catch (_) {}
  if (!context.mounted) return;
  final accept = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => const _PushConsentSheet(),
  );
  try {
    await storage.write(key: _kAskedAtKey, value: DateTime.now().toIso8601String());
  } catch (_) {}
  if (accept == true) await push.requestConsent();
}

class _PushConsentSheet extends StatelessWidget {
  const _PushConsentSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
            ],
          ),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          key: const ValueKey('push-consent'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.notifications_active_rounded, size: 44, color: AppColors.secondary),
            const SizedBox(height: 10),
            Text(l10n.pushConsentTitle, textAlign: TextAlign.center, style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(l10n.pushConsentBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            line(Icons.chat_bubble_outline_rounded, l10n.pushConsentComments),
            line(Icons.volunteer_activism_outlined, l10n.pushConsentPrayers),
            line(Icons.event_rounded, l10n.pushConsentEvents),
            line(Icons.verified_outlined, l10n.pushConsentAccount),
            const SizedBox(height: 4),
            Text(l10n.pushConsentChoose,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.pushConsentAccept),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.pushConsentLater),
            ),
          ],
        ),
      ),
    );
  }
}
