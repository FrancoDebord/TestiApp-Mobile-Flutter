// lib/features/testimony/providers/recommendations_provider.dart
//
// Suggestions du serveur pour un témoignage :
//   GET /testimonies/{id}/recommendations?limit=10
// Classement selon le témoignage en cours, les centres d'intérêt et les
// comptes suivis ; les témoignages déjà vus passent en fin de liste.
// Liste vide en cas d'erreur : les écrans retombent alors sur leur calcul local.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart';

/// Nombre de suggestions demandées au serveur.
const int kRecommendationsLimit = 10;

/// Convertit `data` de la réponse en témoignages (éléments invalides ignorés,
/// témoignage courant [excludeId] retiré par sécurité).
List<Testimony> parseRecommendations(
  Object? data, {
  required String excludeId,
}) {
  if (data is! List) return const [];
  return data
      .map(testimonyFromApiJson)
      .whereType<Testimony>()
      .where((t) => t.id.isNotEmpty && t.id != excludeId)
      .toList();
}

final recommendationsProvider = FutureProvider.autoDispose
    .family<List<Testimony>, String>((ref, id) async {
      try {
        final res = await ref
            .read(apiServiceProvider)
            .get<dynamic>(
              AppConstants.testimonyRecommendations(id),
              query: {'limit': kRecommendationsLimit},
            );
        return parseRecommendations(res.data, excludeId: id);
      } catch (_) {
        return const [];
      }
    });
