// lib/features/daily_verse/design/verse_design_catalog.dart
//
// Catalogue des designs actifs côté serveur (GET /verse-designs, public), mis
// en cache 24 h dans shared_preferences. Le sélecteur n'affiche que ces
// designs, triés par « order » ; un id inconnu de l'application est ignoré.
// Sans catalogue (premier lancement hors connexion), tous les designs de
// l'application sont proposés.

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import 'verse_design.dart';

/// Ids des designs actifs côté serveur, dans l'ordre (« order ») du serveur.
class VerseDesignCatalog {
  const VerseDesignCatalog(this.ids);

  final List<String> ids;

  /// Lit la réponse de GET /verse-designs.
  factory VerseDesignCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['designs'];
    final entries = <({String id, num order})>[
      if (raw is List)
        for (final d in raw)
          if (d is Map && d['id'] is String)
            (id: d['id'] as String, order: (d['order'] as num?) ?? 0),
    ]..sort((a, b) => a.order.compareTo(b.order));
    return VerseDesignCatalog([for (final e in entries) e.id]);
  }

  /// Designs de l'application présents dans le catalogue, dans son ordre.
  List<VerseDesign> resolve() =>
      [for (final id in ids) ?verseDesignById(id)];
}

/// Durée de validité du catalogue en cache.
const Duration kVerseCatalogTtl = Duration(hours: 24);

class VerseDesignCatalogNotifier extends AsyncNotifier<VerseDesignCatalog?> {
  static const _kJson = 'verse_designs_catalog';
  static const _kFetchedAt = 'verse_designs_catalog_at';

  /// Horloge (remplaçable dans les tests).
  DateTime Function() now = DateTime.now;

  @override
  Future<VerseDesignCatalog?> build() async {
    SharedPreferences? prefs;
    VerseDesignCatalog? cached;
    DateTime? fetchedAt;
    try {
      prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kJson);
      fetchedAt = DateTime.tryParse(prefs.getString(_kFetchedAt) ?? '');
      if (raw != null) {
        cached = VerseDesignCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}

    final fresh = cached != null && fetchedAt != null && now().difference(fetchedAt) < kVerseCatalogTtl;
    if (fresh) return cached;

    try {
      final res = await ref.read(apiServiceProvider).get<Map<String, dynamic>>(AppConstants.verseDesigns);
      final catalog = VerseDesignCatalog.fromJson(res.data);
      await prefs?.setString(_kJson, jsonEncode(res.data));
      await prefs?.setString(_kFetchedAt, now().toIso8601String());
      return catalog;
    } catch (e) {
      debugPrint('VerseDesigns ✗ $e');
      // Hors connexion : catalogue périmé plutôt que rien.
      return cached;
    }
  }
}

final verseDesignCatalogProvider =
    AsyncNotifierProvider<VerseDesignCatalogNotifier, VerseDesignCatalog?>(
        VerseDesignCatalogNotifier.new);

/// Designs proposés : ceux du catalogue serveur connus de l'application, dans
/// l'ordre du serveur ; sinon (pas de catalogue, ou aucun id connu) tous.
final availableVerseDesignsProvider = Provider<List<VerseDesign>>((ref) {
  final resolved = ref.watch(verseDesignCatalogProvider).value?.resolve() ?? const [];
  return resolved.isEmpty ? kVerseDesigns : resolved;
});
