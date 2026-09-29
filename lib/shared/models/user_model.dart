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

/// Type de compte : personne physique ou organisation (église, ministère…).
enum AccountType {
  individual,
  organization;

  static AccountType fromJson(String? v) =>
      v == 'organization' ? AccountType.organization : AccountType.individual;

  String toJson() => name;
}

/// Type d'organisation (valeurs API en anglais, libellés en français).
enum OrganizationType {
  church('church', 'Église'),
  ministry('ministry', 'Ministère'),
  association('association', 'Association'),
  ngo('ngo', 'ONG'),
  media('media', 'Média chrétien'),
  other('other', 'Autre');

  const OrganizationType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static OrganizationType? fromJson(String? v) {
    if (v == null || v.isEmpty) return null;
    for (final t in values) {
      if (t.apiValue == v) return t;
    }
    return OrganizationType.other;
  }

  String toJson() => apiValue;
}

/// Statut de vérification d'une organisation par l'équipe.
enum VerificationStatus {
  pending,
  verified,
  rejected;

  static VerificationStatus? fromJson(String? v) => switch (v) {
    'pending'  => VerificationStatus.pending,
    'verified' => VerificationStatus.verified,
    'rejected' => VerificationStatus.rejected,
    _          => null,
  };

  String toJson() => name;
}

class UserModel {
  const UserModel({
    required this.id,
    this.displayName = '',
    this.email = '',
    this.phone = '',
    this.phoneCountry,
    this.isPhoneVerified = false,
    this.avatarUrl,
    this.coverUrl,
    this.country = '',
    this.role = UserRole.utilisateur,
    this.isEmailVerified = true,
    this.testimonyCount = 0,
    this.likeCount = 0,
    this.prayerCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.createdAt,
    this.updatedAt,
    this.accountType = AccountType.individual,
    this.organizationName,
    this.organizationType,
    this.organizationCity,
    this.organizationWebsite,
    this.isVerified = false,
    this.verificationStatus,
  });

  final String  id;
  final String  displayName;
  final String  email;
  final String  phone;

  /// Code ISO du pays de l'indicatif (« bj »), pour réafficher le numéro.
  final String? phoneCountry;

  /// Numéro confirmé par SMS (connexion par téléphone) : non modifiable dans le profil.
  final bool isPhoneVerified;
  final String? avatarUrl;

  /// Photo de couverture du profil (bandeau), null si aucune.
  final String? coverUrl;
  final String  country;
  final UserRole role;
  final bool    isEmailVerified;
  final int     testimonyCount;
  final int     likeCount;
  final int     prayerCount;
  final int     followerCount;
  final int     followingCount;
  final String? createdAt;
  final String? updatedAt;

  // ── Organisation ─────────────────────────────────────────────────────────────
  final AccountType accountType;
  final String? organizationName;
  final OrganizationType? organizationType;
  final String? organizationCity;
  final String? organizationWebsite;
  /// Badge vérifié accordé par un administrateur.
  final bool isVerified;
  final VerificationStatus? verificationStatus;

  // ── JSON ─────────────────────────────────────────────────────────────────────

  factory UserModel.fromJson(Map<String, dynamic> j) {
    // Accepte display_name, name, ou first_name + last_name selon le serveur
    final first  = (j['first_name'] as String?)?.trim() ?? '';
    final last   = (j['last_name']  as String?)?.trim() ?? '';
    final joined = [first, last].where((s) => s.isNotEmpty).join(' ');
    final dn     = (j['display_name'] as String?)?.trim() ?? '';
    final nm     = (j['name']         as String?)?.trim() ?? '';
    final rawEmail = (j['email'] as String?)?.trim() ?? '';
    final emailPrefix = rawEmail.contains('@') ? rawEmail.split('@').first : '';
    final displayName = dn.isNotEmpty ? dn
        : nm.isNotEmpty ? nm
        : joined.isNotEmpty ? joined
        : emailPrefix;
    // ignore: avoid_print
    if (displayName.isEmpty) print('[UserModel] ⚠ no name fields. Keys=${j.keys.toList()}');

    return UserModel(
      id:               j['id']               as String,
      displayName:      displayName,
      email:            j['email']            as String? ?? '',
      phone:            j['phone']            as String? ?? '',
      phoneCountry:     _str(j['phone_country']),
      isPhoneVerified:  _bool(j['is_phone_verified']),
      avatarUrl:        j['avatar_url']       as String?,
      coverUrl:         _str(j['cover_url']),
      country:          j['country']          as String? ?? '',
      role:             UserRole.fromJson(j['role'] as String?),
      isEmailVerified:  j['is_email_verified'] as bool? ?? true,
      testimonyCount:   (j['testimony_count']  as num?)?.toInt() ?? 0,
      likeCount:        (j['like_count']        as num?)?.toInt() ?? 0,
      prayerCount:      (j['prayer_count']      as num?)?.toInt() ?? 0,
      followerCount:    (j['follower_count']    as num?)?.toInt() ?? 0,
      followingCount:   (j['following_count']   as num?)?.toInt() ?? 0,
      createdAt:        j['created_at']         as String?,
      updatedAt:        j['updated_at']         as String?,
      accountType:      AccountType.fromJson(j['account_type'] as String?),
      organizationName: _str(j['organization_name']),
      organizationType: OrganizationType.fromJson(j['organization_type'] as String?),
      organizationCity: _str(j['organization_city']),
      organizationWebsite: _str(j['organization_website']),
      isVerified:       _bool(j['is_verified']) ||
                        j['verification_status'] == 'verified',
      verificationStatus:
          VerificationStatus.fromJson(j['verification_status'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'display_name': displayName, 'email': email, 'phone': phone,
    if (phoneCountry != null) 'phone_country': phoneCountry,
    'is_phone_verified': isPhoneVerified,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    if (coverUrl != null) 'cover_url': coverUrl,
    'country': country, 'role': role.toJson(), 'is_email_verified': isEmailVerified,
    'testimony_count': testimonyCount, 'like_count': likeCount, 'prayer_count': prayerCount,
    'follower_count': followerCount, 'following_count': followingCount,
    if (createdAt != null) 'created_at': createdAt,
    if (updatedAt != null) 'updated_at': updatedAt,
    'account_type': accountType.toJson(),
    if (organizationName != null) 'organization_name': organizationName,
    if (organizationType != null) 'organization_type': organizationType!.toJson(),
    if (organizationCity != null) 'organization_city': organizationCity,
    if (organizationWebsite != null) 'organization_website': organizationWebsite,
    'is_verified': isVerified,
    if (verificationStatus != null)
      'verification_status': verificationStatus!.toJson(),
  };

  static String? _str(dynamic v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static bool _bool(dynamic v) => switch (v) {
    bool b   => b,
    num n    => n != 0,
    String s => s == '1' || s.toLowerCase() == 'true',
    _        => false,
  };

  UserModel copyWith({
    String? id, String? displayName, String? email, String? phone,
    String? phoneCountry, bool? isPhoneVerified,
    String? avatarUrl, String? country, UserRole? role, bool? isEmailVerified,
    int? testimonyCount, int? likeCount, int? prayerCount,
    int? followerCount, int? followingCount,
    String? createdAt, String? updatedAt,
    AccountType? accountType, String? organizationName,
    OrganizationType? organizationType, String? organizationCity,
    String? organizationWebsite, bool? isVerified,
    VerificationStatus? verificationStatus,
    String? coverUrl, bool clearCoverUrl = false,
  }) => UserModel(
    id:              id              ?? this.id,
    displayName:     displayName     ?? this.displayName,
    email:           email           ?? this.email,
    phone:           phone           ?? this.phone,
    phoneCountry:    phoneCountry    ?? this.phoneCountry,
    isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
    avatarUrl:       avatarUrl       ?? this.avatarUrl,
    coverUrl:        clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
    country:         country         ?? this.country,
    role:            role            ?? this.role,
    isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    testimonyCount:  testimonyCount  ?? this.testimonyCount,
    likeCount:       likeCount       ?? this.likeCount,
    prayerCount:     prayerCount     ?? this.prayerCount,
    followerCount:   followerCount   ?? this.followerCount,
    followingCount:  followingCount  ?? this.followingCount,
    createdAt:       createdAt       ?? this.createdAt,
    updatedAt:       updatedAt       ?? this.updatedAt,
    accountType:         accountType         ?? this.accountType,
    organizationName:    organizationName    ?? this.organizationName,
    organizationType:    organizationType    ?? this.organizationType,
    organizationCity:    organizationCity    ?? this.organizationCity,
    organizationWebsite: organizationWebsite ?? this.organizationWebsite,
    isVerified:          isVerified          ?? this.isVerified,
    verificationStatus:  verificationStatus  ?? this.verificationStatus,
  );

  @override bool operator ==(Object other) =>
      other is UserModel && other.id == id;

  @override int get hashCode => id.hashCode;

  @override String toString() => 'UserModel($id, $displayName)';

  // ── Helpers ───────────────────────────────────────────────────────────────────

  bool get canPublish  => role != UserRole.visiteur;
  bool get canModerate => role == UserRole.moderateur || role == UserRole.administrateur;
  bool get isAdmin     => role == UserRole.administrateur;
  bool get isOrganization => accountType == AccountType.organization;

  /// Statut effectif : `verified` si le badge est accordé, sinon le statut
  /// renvoyé par le serveur, `pending` par défaut pour une organisation.
  VerificationStatus? get effectiveVerificationStatus {
    if (isVerified) return VerificationStatus.verified;
    if (verificationStatus != null) return verificationStatus;
    return isOrganization ? VerificationStatus.pending : null;
  }

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}
