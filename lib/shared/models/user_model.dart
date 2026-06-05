// lib/shared/models/user_model.dart — Dart pur, sans génération de code.

enum UserRole {
  visiteur,
  utilisateur,
  moderateur,
  administrateur;

  static UserRole fromJson(String? v) => switch (v) {
    'moderateur'    => UserRole.moderateur,
    'administrateur'=> UserRole.administrateur,
    _               => UserRole.utilisateur,
  };

  String toJson() => name;
}

class UserModel {
  const UserModel({
    required this.id,
    this.displayName = '',
    this.email = '',
    this.phone = '',
    this.avatarUrl,
    this.country = '',
    this.role = UserRole.utilisateur,
    this.isEmailVerified = true,
    this.testimonyCount = 0,
    this.likeCount = 0,
    this.prayerCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String  id;
  final String  displayName;
  final String  email;
  final String  phone;
  final String? avatarUrl;
  final String  country;
  final UserRole role;
  final bool    isEmailVerified;
  final int     testimonyCount;
  final int     likeCount;
  final int     prayerCount;
  final String? createdAt;
  final String? updatedAt;

  // ── JSON ─────────────────────────────────────────────────────────────────────

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id:               j['id']               as String,
    displayName:      j['display_name']     as String? ?? j['name'] as String? ?? '',
    email:            j['email']            as String? ?? '',
    phone:            j['phone']            as String? ?? '',
    avatarUrl:        j['avatar_url']       as String?,
    country:          j['country']          as String? ?? '',
    role:             UserRole.fromJson(j['role'] as String?),
    isEmailVerified:  j['is_email_verified'] as bool? ?? true,
    testimonyCount:   (j['testimony_count'] as num?)?.toInt() ?? 0,
    likeCount:        (j['like_count']      as num?)?.toInt() ?? 0,
    prayerCount:      (j['prayer_count']    as num?)?.toInt() ?? 0,
    createdAt:        j['created_at']       as String?,
    updatedAt:        j['updated_at']       as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'display_name': displayName, 'email': email, 'phone': phone,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    'country': country, 'role': role.toJson(), 'is_email_verified': isEmailVerified,
    'testimony_count': testimonyCount, 'like_count': likeCount, 'prayer_count': prayerCount,
    if (createdAt != null) 'created_at': createdAt,
    if (updatedAt != null) 'updated_at': updatedAt,
  };

  UserModel copyWith({
    String? id, String? displayName, String? email, String? phone,
    String? avatarUrl, String? country, UserRole? role, bool? isEmailVerified,
    int? testimonyCount, int? likeCount, int? prayerCount,
    String? createdAt, String? updatedAt,
  }) => UserModel(
    id:              id              ?? this.id,
    displayName:     displayName     ?? this.displayName,
    email:           email           ?? this.email,
    phone:           phone           ?? this.phone,
    avatarUrl:       avatarUrl       ?? this.avatarUrl,
    country:         country         ?? this.country,
    role:            role            ?? this.role,
    isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    testimonyCount:  testimonyCount  ?? this.testimonyCount,
    likeCount:       likeCount       ?? this.likeCount,
    prayerCount:     prayerCount     ?? this.prayerCount,
    createdAt:       createdAt       ?? this.createdAt,
    updatedAt:       updatedAt       ?? this.updatedAt,
  );

  @override bool operator ==(Object other) =>
      other is UserModel && other.id == id;

  @override int get hashCode => id.hashCode;

  @override String toString() => 'UserModel($id, $displayName)';

  // ── Helpers ───────────────────────────────────────────────────────────────────

  bool get canPublish  => role != UserRole.visiteur;
  bool get canModerate => role == UserRole.moderateur || role == UserRole.administrateur;
  bool get isAdmin     => role == UserRole.administrateur;

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}
