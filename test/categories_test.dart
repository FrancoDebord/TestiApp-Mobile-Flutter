import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/providers/categories_provider.dart';

// Réponse réelle de GET /api/v1/categories (testi.airid-africa.com).
const _serverSlugs = [
  'guerison', 'delivrance', 'protection', 'provision', 'famille',
  'salut', 'mariage', 'emploi', 'etudes', 'autre',
];

void main() {
  test('lit une catégorie du serveur (identifiant UUID)', () {
    final c = CategoryModel.fromJson({
      'id': '0a46f972-e445-462b-8cd3-e8e737909614',
      'name': 'Guérison', 'slug': 'guerison', 'icon': '🙏',
      'color': '#10B981', 'testimonyCount': 3, 'displayOrder': 1, 'isActive': true,
    });
    expect(c.id, '0a46f972-e445-462b-8cd3-e8e737909614');
    expect(c.slug, 'guerison');
    expect(c.isActive, isTrue);
  });

  test('la liste de secours ne contient que des catégories connues du serveur', () {
    final slugs = kFallbackCategoriesForTest.map((c) => c.slug).toList();
    expect(slugs.where((s) => !_serverSlugs.contains(s)), isEmpty,
        reason: 'un slug inconnu donne « category invalid » au partage');
    expect(slugs, contains('autre'), reason: 'catégorie par défaut du carnet');
  });
}
