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

  final int    id;
  final String name;
  final String slug;
  final bool   isActive;

  factory CategoryModel.fromJson(Map<String, dynamic> j) => CategoryModel(
    id:       (j['id'] as num).toInt(),
    name:     j['name']     as String? ?? '',
    slug:     j['slug']     as String? ?? '',
    isActive: (j['is_active'] ?? j['isActive']) as bool? ?? true,
  );
}

// ── Fallback hardcodé si serveur inaccessible ─────────────────────────────────

const _kFallbackCategories = [
  CategoryModel(id: 0, name: 'Guérison',         slug: 'guerison'),
  CategoryModel(id: 0, name: 'Délivrance',        slug: 'delivrance'),
  CategoryModel(id: 0, name: 'Conversion',        slug: 'conversion'),
  CategoryModel(id: 0, name: 'Mariage',           slug: 'mariage'),
  CategoryModel(id: 0, name: 'Famille',           slug: 'famille'),
  CategoryModel(id: 0, name: 'Finances',          slug: 'finances'),
  CategoryModel(id: 0, name: 'Miracles',          slug: 'miracles'),
  CategoryModel(id: 0, name: 'Protection divine', slug: 'protection_divine'),
  CategoryModel(id: 0, name: 'Ministère',         slug: 'ministere'),
  CategoryModel(id: 0, name: 'Salut',             slug: 'salut'),
];

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
