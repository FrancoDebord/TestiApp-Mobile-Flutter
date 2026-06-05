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
      gradientColors: [0xFF6B21A8, 0xFFA855F7],
      iconCodePoint: 0xe3f3, // Icons.healing_outlined
    ),
    CategoryCardData(
      category: TestimonyCategory.delivrance,
      count: 218,
      gradientColors: [0xFF1E3A8A, 0xFF3B82F6],
      iconCodePoint: 0xe1af, // Icons.lock_open_outlined
    ),
    CategoryCardData(
      category: TestimonyCategory.conversion,
      count: 187,
      gradientColors: [0xFF065F46, 0xFF10B981],
      iconCodePoint: 0xef6e, // Icons.rotate_right
    ),
    CategoryCardData(
      category: TestimonyCategory.mariage,
      count: 134,
      gradientColors: [0xFF9D174D, 0xFFF43F5E],
      iconCodePoint: 0xe87d, // Icons.favorite_rounded
    ),
    CategoryCardData(
      category: TestimonyCategory.famille,
      count: 276,
      gradientColors: [0xFF92400E, 0xFFF59E0B],
      iconCodePoint: 0xe533, // Icons.people_alt_outlined
    ),
    CategoryCardData(
      category: TestimonyCategory.finances,
      count: 159,
      gradientColors: [0xFF14532D, 0xFF22C55E],
      iconCodePoint: 0xe263, // Icons.attach_money
    ),
    CategoryCardData(
      category: TestimonyCategory.miracles,
      count: 423,
      gradientColors: [0xFF7C2D12, 0xFFF97316],
      iconCodePoint: 0xe518, // Icons.auto_awesome
    ),
    CategoryCardData(
      category: TestimonyCategory.protection,
      count: 98,
      gradientColors: [0xFF1E3A5F, 0xFF0EA5E9],
      iconCodePoint: 0xe32a, // Icons.shield_outlined
    ),
    CategoryCardData(
      category: TestimonyCategory.ministere,
      count: 67,
      gradientColors: [0xFF4A1D96, 0xFF8B5CF6],
      iconCodePoint: 0xe547, // Icons.record_voice_over_outlined
    ),
    CategoryCardData(
      category: TestimonyCategory.salut,
      count: 312,
      gradientColors: [0xFF7F1D1D, 0xFFEF4444],
      iconCodePoint: 0xe838, // Icons.star_rounded
    ),
  ];
}
