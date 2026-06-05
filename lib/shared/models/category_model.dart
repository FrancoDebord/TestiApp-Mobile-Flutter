// lib/shared/models/category_model.dart — Dart pur, sans génération de code.

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon = '',
    this.color = '#6B21A8',
    this.count = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String icon;
  final String color;
  final int    count;

  factory CategoryModel.fromJson(Map<String, dynamic> j) => CategoryModel(
    id:    j['id']    as String,
    name:  j['name']  as String,
    slug:  j['slug']  as String,
    icon:  j['icon']  as String? ?? '',
    color: j['color'] as String? ?? '#6B21A8',
    count: (j['count'] as num?)?.toInt()
        ?? (j['testimony_count'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'slug': slug,
    'icon': icon, 'color': color, 'count': count,
  };

  @override bool operator ==(Object other) =>
      other is CategoryModel && other.id == id;
  @override int get hashCode => id.hashCode;
}
