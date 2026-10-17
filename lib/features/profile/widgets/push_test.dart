// lib/features/profile/widgets/push_test.dart
//
// Paramètres › « Tester les notifications » : autorisation vérifiée, jeton de
// l'appareil réenregistré, puis POST /me/push-test ; le résultat est affiché
// dans une boîte de dialogue.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/push_service.dart';

/// Texte affiché pour un résultat de test.
String pushTestMessage(AppLocalizations l10n, PushTestResult r) => switch (r.outcome) {
      PushTestOutcome.sent => r.devices != null && r.devices! > 0
          ? l10n.pushTestSentDevices(r.devices!)
          : l10n.pushTestSent,
      PushTestOutcome.permissionDenied => l10n.pushTestPermissionDenied,
      PushTestOutcome.noToken => l10n.pushTestNoToken,
      PushTestOutcome.notDeployed => l10n.pushTestNotDeployed,
      PushTestOutcome.serverError =>
        l10n.pushTestServerError(r.serverMessage ?? l10n.commonErrorGeneric),
      PushTestOutcome.networkError => l10n.pushTestNetworkError,
    };

Future<void> runPushTest(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final push = ref.read(pushServiceProvider);
  // init() : autorisation et écoute (sans effet si déjà fait).
  final future = push.init().then((_) => push.sendTestPush());
  final result = await showDialog<PushTestResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => FutureBuilder<PushTestResult>(
      future: future,
      builder: (ctx, snap) {
        final r = snap.data;
        if (r == null) {
          return AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                const SizedBox(width: 16),
                Expanded(child: Text(l10n.pushTestSending)),
              ],
            ),
          );
        }
        return AlertDialog(
          key: const ValueKey('push-test-result'),
          icon: Icon(
            r.ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: r.ok ? Colors.green : Theme.of(ctx).colorScheme.error,
          ),
          title: Text(l10n.pushTestTitle),
          content: Text(r.ok
              ? '${pushTestMessage(l10n, r)}\n\n${l10n.pushTestNotReceived}'
              : pushTestMessage(l10n, r)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(r),
              child: Text(l10n.commonOk),
            ),
          ],
        );
      },
    ),
  );
  debugPrint('Test des notifications : ${result?.outcome}');
}
