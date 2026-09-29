import '../../home/models/testimony_model.dart';

// ── Filter / sort enums ───────────────────────────────────────────────────────

enum ExploreTypeFilter { all, text, audio, video }

extension ExploreTypeFilterLabel on ExploreTypeFilter {
  String get label => switch (this) {
        ExploreTypeFilter.all => 'Tout',
        ExploreTypeFilter.text => 'Texte',
        ExploreTypeFilter.audio => 'Audio',
        ExploreTypeFilter.video => 'Vidéo',
      };
}

enum ExploreSortOrder { recent, popular, recommended }

extension ExploreSortOrderLabel on ExploreSortOrder {
  String get label => switch (this) {
        ExploreSortOrder.recent => 'Récent',
        ExploreSortOrder.popular => 'Populaire',
        ExploreSortOrder.recommended => 'Recommandé',
      };
}

// ── Category card metadata ────────────────────────────────────────────────────

class CategoryCardData {
  const CategoryCardData({
    required this.category,
    required this.count,
    required this.gradientColors,
    required this.iconCodePoint,
  });

  final TestimonyCategory category;
  final int count;
  final List<int> gradientColors; // ARGB ints for const compatibility
  final int iconCodePoint;        // MaterialIcons codePoint

  static const List<CategoryCardData> all = [
    CategoryCardData(
      category: TestimonyCategory.guerison,
      count: 342,
      gradientColors: [0xFF184797, 0xFF4B7ACB],
      iconCodePoint: 0xe3f3, // Icons.healing_outlined
    ),
    CategoryCardData(
      category: TestimonyCategory.delivrance,
      count: 218,
      gradientColors: [0xFF103675, 0xFF2B5DB0],
      iconCodePoint: 0xe1af, // Icons.lock_open_outlined
    ),
    CategoryCardData(
      category: TestimonyCategory.conversion,
      count: 187,
      gradientColors: [0xFFD96F0B, 0xFF12B76A],
      iconCodePoint: 0xef6e, // Icons.rotate_right
    ),
    CategoryCardData(
      category: TestimonyCategory.mariage,
      count: 134,
      gradientColors: [0xFFF18717, 0xFFFCC11D],
      iconCodePoint: 0xe87d, // Icons.favorite_rounded
    ),
    CategoryCardData(
      category: TestimonyCategory.famille,
      count: 276,
      gradientColors: [0xFFC48A06, 0xFFF79009],
      iconCodePoint: 0xe533, // Icons.people_alt_outlined
    ),
    CategoryCardData(
      category: TestimonyCategory.finances,
      count: 159,
      gradientColors: [0xFF184797, 0xFF12B76A],
      iconCodePoint: 0xe263, // Icons.attach_money
    ),
    CategoryCardData(
      category: TestimonyCategory.miracles,
      count: 423,
      gradientColors: [0xFFD96F0B, 0xFFF18717],
      iconCodePoint: 0xe518, // Icons.auto_awesome
    ),
    CategoryCardData(
      category: TestimonyCategory.protection,
      count: 98,
      gradientColors: [0xFF103675, 0xFF4B7ACB],
      iconCodePoint: 0xe32a, // Icons.shield_outlined
    ),
    CategoryCardData(
      category: TestimonyCategory.ministere,
      count: 67,
      gradientColors: [0xFF103675, 0xFF4B7ACB],
      iconCodePoint: 0xe547, // Icons.record_voice_over_outlined
    ),
    CategoryCardData(
      category: TestimonyCategory.salut,
      count: 312,
      gradientColors: [0xFFD96F0B, 0xFFD92D20],
      iconCodePoint: 0xe838, // Icons.star_rounded
    ),
  ];
}
