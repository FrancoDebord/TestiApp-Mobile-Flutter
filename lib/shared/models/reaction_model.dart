// lib/shared/models/reaction_model.dart — Dart pur, sans génération de code.

enum ReactionType {
  like, love, pray, amen, fire;

  static ReactionType fromJson(String? v) => switch (v) {
    'love' => ReactionType.love,
    'pray' => ReactionType.pray,
    'amen' => ReactionType.amen,
    'fire' => ReactionType.fire,
    _      => ReactionType.like,
  };
  String toJson() => name;
}

class ReactionModel {
  const ReactionModel({
    required this.id,
    required this.type,
    required this.userId,
    required this.testimonyId,
    this.createdAt,
  });

  final String       id;
  final ReactionType type;
  final String       userId;
  final String       testimonyId;
  final String?      createdAt;

  factory ReactionModel.fromJson(Map<String, dynamic> j) => ReactionModel(
    id:          j['id']           as String,
    type:        ReactionType.fromJson(j['type'] as String?),
    userId:      j['user_id']      as String? ?? '',
    testimonyId: j['testimony_id'] as String? ?? '',
    createdAt:   j['created_at']   as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type.toJson(), 'user_id': userId,
    'testimony_id': testimonyId,
    if (createdAt != null) 'created_at': createdAt,
  };

  @override bool operator ==(Object other) =>
      other is ReactionModel && other.id == id;
  @override int get hashCode => id.hashCode;
}
