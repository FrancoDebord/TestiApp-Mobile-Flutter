import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_constants.dart';
import '../../features/auth/providers/auth_notifier.dart'
    show authStateProvider, AuthStateAuthenticated;
import '../../services/api_service.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.isActive = true,
  });

  /// Identifiant serveur (UUID) ; vide pour la liste de secours.
  final String id;
  final String name;
  final String slug;
  final bool   isActive;

  factory CategoryModel.fromJson(Map<String, dynamic> j) => CategoryModel(
    // UUID côté serveur : l'ancien `as num` échouait toujours, et l'app
    // retombait sur la liste de secours (slugs inconnus du serveur).
    id:       '${j['id'] ?? ''}',
    name:     j['name']     as String? ?? '',
    slug:     j['slug']     as String? ?? '',
    isActive: (j['is_active'] ?? j['isActive']) as bool? ?? true,
  );
}

// ── Fallback hardcodé si serveur inaccessible ─────────────────────────────────

// Mêmes slugs que la table `categories` du serveur (CategorySeeder) :
// un slug inconnu fait échouer le partage (« category invalid »).
const _kFallbackCategories = [
  CategoryModel(id: '', name: 'Guérison',          slug: 'guerison'),
  CategoryModel(id: '', name: 'Délivrance',         slug: 'delivrance'),
  CategoryModel(id: '', name: 'Protection',         slug: 'protection'),
  CategoryModel(id: '', name: 'Provision',          slug: 'provision'),
  CategoryModel(id: '', name: 'Famille',            slug: 'famille'),
  CategoryModel(id: '', name: 'Salut',              slug: 'salut'),
  CategoryModel(id: '', name: 'Mariage',            slug: 'mariage'),
  CategoryModel(id: '', name: 'Emploi & Carrière',  slug: 'emploi'),
  CategoryModel(id: '', name: 'Études',             slug: 'etudes'),
  CategoryModel(id: '', name: 'Autre',              slug: 'autre'),
];

@visibleForTesting
const List<CategoryModel> kFallbackCategoriesForTest = _kFallbackCategories;

// ── Notifier ──────────────────────────────────────────────────────────────────

class ServerCategoriesNotifier
    extends AsyncNotifier<List<CategoryModel>> {
  @override
  Future<List<CategoryModel>> build() async {
    // Rebuild quand l'état auth change (évite de fetcher avec un token local fictif)
    final authValue = ref.watch(authStateProvider).value;
    if (authValue is! AuthStateAuthenticated) {
      debugPrint('[Categories] auth non prête — fallback local');
      return _kFallbackCategories;
    }

    try {
      final api      = ref.read(apiServiceProvider);
      final response = await api.get<List<dynamic>>(AppConstants.categories);
      final list = response.data
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .where((c) => c.isActive)
          .toList();
      debugPrint('[Categories] ✓ ${list.length} catégories chargées du serveur (ids: ${list.map((c) => '${c.slug}=${c.id}').join(', ')})');
      return list.isEmpty ? _kFallbackCategories : list;
    } catch (e) {
      debugPrint('[Categories] ✗ fetch échoué: $e — fallback local');
      return _kFallbackCategories;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final serverCategoriesProvider =
    AsyncNotifierProvider<ServerCategoriesNotifier, List<CategoryModel>>(
  ServerCategoriesNotifier.new,
);

// ── Providers dérivés synchrones ─────────────────────────────────────────────

/// Liste synchrone (fallback vide pendant le chargement)
final categoriesListProvider = Provider<List<CategoryModel>>((ref) {
  return ref.watch(serverCategoriesProvider).value ?? _kFallbackCategories;
});

/// Retrouve un CategoryModel par slug
final categoryBySlugProvider =
    Provider.family<CategoryModel?, String>((ref, slug) {
  final cats = ref.watch(categoriesListProvider);
  try {
    return cats.firstWhere((c) => c.slug == slug);
  } catch (_) {
    return null;
  }
});
