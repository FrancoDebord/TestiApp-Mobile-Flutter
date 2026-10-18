// Types de témoignages que le compte (ou le compte administré) peut publier :
// réglages de l'administrateur, globaux ou propres au profil.
// Backend : docs/fonctionnalites/types-de-temoignages.md — GET /me/publishing
//   → { allowed: ["text","audio","video","youtube"], global: { text: bool, … } }

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;

/// Liste des types autorisés ; null si inconnue (invité, serveur plus ancien,
/// hors ligne) : l'écran se rabat alors sur `UserModel.canPublishType`.
final publishingRulesProvider = FutureProvider.autoDispose<List<String>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  try {
    final res = await ref.read(apiServiceProvider).get<dynamic>(AppConstants.mePublishing);
    final data = res.data;
    if (data is Map && data['allowed'] is List) {
      return [for (final t in data['allowed'] as List) '$t'];
    }
  } catch (_) {}
  return user.allowedTestimonyTypes;
});
