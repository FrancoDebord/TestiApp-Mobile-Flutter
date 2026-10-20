// lib/shared/models/user_model.dart — Dart pur, sans génération de code.

import '../../l10n/app_localizations.dart';
import 'account_approval.dart';

export 'account_approval.dart' show AccountApprovalBadge;

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
  church('church'),
  ministry('ministry'),
  association('association'),
  ngo('ngo'),
  media('media'),
  other('other');

  const OrganizationType(this.apiValue);

  final String apiValue;

  /// Libellé dans la langue affichée.
  String get label => switch (this) {
        church => L10n.current.sharedOrgTypeChurch,
        ministry => L10n.current.sharedOrgTypeMinistry,
        association => L10n.current.sharedOrgTypeAssociation,
        ngo => L10n.current.sharedOrgTypeNgo,
        media => L10n.current.sharedOrgTypeMedia,
        other => L10n.current.sharedOrgTypeOther,
      };

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
    this.hasConversionTestimony = false,
    this.allowedTestimonyTypes,
    this.avatarUrl,
    this.coverUrl,
    this.country = '',
    this.bio = '',
    this.hasPassword = true,
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
    this.approvalBadge,
    this.approvedAt,
  });

  final String  id;
  final String  displayName;
  final String  email;
  final String  phone;

  /// Code ISO du pays de l'indicatif (« bj »), pour réafficher le numéro.
  final String? phoneCountry;

  /// Numéro confirmé par SMS (connexion par téléphone) : non modifiable dans le profil.
  final bool isPhoneVerified;

  /// Témoignage de conversion publié (`has_conversion_testimony` de GET /me et
  /// GET /users/{id} ; docs serveur fonctionnalites/temoignage-de-conversion.md).
  final bool hasConversionTestimony;

  /// Types de témoignages que ce compte peut publier (`allowed_testimony_types` :
  /// text, audio, video, youtube) — réglages de l'administrateur, globaux ou propres
  /// au profil (docs serveur fonctionnalites/types-de-temoignages.md). null : serveur
  /// plus ancien, règles d'avant (tout sauf YouTube, réservé aux administrateurs).
  final List<String>? allowedTestimonyTypes;

  /// Ce compte peut-il publier un témoignage de ce type ?
  bool canPublishType(String type) {
    final allowed = allowedTestimonyTypes;
    if (allowed != null) return allowed.contains(type);
    return type == 'youtube' ? isAdmin : true;
  }
  final String? avatarUrl;

  /// Photo de couverture du profil (bandeau), null si aucune.
  final String? coverUrl;
  final String  country;
  /// Présentation du profil (`bio` de UserResource).
  final String  bio;
  /// Compte avec mot de passe (e-mail). Faux pour un compte téléphone / Google /
  /// Facebook : suppression par simple confirmation, pas de changement de mot de passe.
  final bool    hasPassword;
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

  /// Badge « Approuvé » (`approval_badge`, docs serveur fonctionnalites/badge-approuve.md) :
  /// style de la pastille ; null sans badge.
  final AccountApprovalBadge? approvalBadge;

  /// Compte approuvé (pastille à côté du nom).
  bool get isApproved => approvalBadge != null;

  /// Date d'attribution du badge (`approved_at`) ; null sans badge.
  final DateTime? approvedAt;

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
      hasConversionTestimony: _bool(j['has_conversion_testimony']),
      allowedTestimonyTypes: j['allowed_testimony_types'] is List
          ? [for (final t in j['allowed_testimony_types'] as List) '$t']
          : null,
      avatarUrl:        j['avatar_url']       as String?,
      coverUrl:         _str(j['cover_url']),
      country:          j['country']          as String? ?? '',
      bio:              j['bio']              as String? ?? '',
      // Absent (ancien serveur) : on suppose un mot de passe.
      hasPassword:      j['has_password'] == null || _bool(j['has_password']),
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
      approvalBadge: AccountApprovalBadge.parse(j),
      approvedAt: DateTime.tryParse('${j['approved_at'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'display_name': displayName, 'email': email, 'phone': phone,
    if (phoneCountry != null) 'phone_country': phoneCountry,
    'is_phone_verified': isPhoneVerified,
    'has_conversion_testimony': hasConversionTestimony,
    'allowed_testimony_types': ?allowedTestimonyTypes,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    if (coverUrl != null) 'cover_url': coverUrl,
    'country': country, 'bio': bio, 'has_password': hasPassword, 'role': role.toJson(), 'is_email_verified': isEmailVerified,
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
    'is_approved': approvalBadge != null,
    'approval_badge': approvalBadge?.apiValue,
    if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
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
    String? avatarUrl, bool clearAvatarUrl = false, String? country, String? bio, bool? hasPassword, UserRole? role, bool? isEmailVerified,
    int? testimonyCount, int? likeCount, int? prayerCount,
    int? followerCount, int? followingCount,
    String? createdAt, String? updatedAt,
    AccountType? accountType, String? organizationName,
    OrganizationType? organizationType, String? organizationCity,
    String? organizationWebsite, bool? isVerified,
    VerificationStatus? verificationStatus,
    String? coverUrl, bool clearCoverUrl = false,
    AccountApprovalBadge? approvalBadge, bool clearApprovalBadge = false,
  }) => UserModel(
    id:              id              ?? this.id,
    displayName:     displayName     ?? this.displayName,
    email:           email           ?? this.email,
    phone:           phone           ?? this.phone,
    phoneCountry:    phoneCountry    ?? this.phoneCountry,
    isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
    hasConversionTestimony: hasConversionTestimony,
    allowedTestimonyTypes: allowedTestimonyTypes,
    avatarUrl:       clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
    coverUrl:        clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
    country:         country         ?? this.country,
    bio:             bio             ?? this.bio,
    hasPassword:     hasPassword     ?? this.hasPassword,
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
    approvalBadge:       clearApprovalBadge ? null : (approvalBadge ?? this.approvalBadge),
    approvedAt:          clearApprovalBadge ? null : approvedAt,
  );

  @override bool operator ==(Object other) =>
      other is UserModel && other.id == id;

  @override int get hashCode => id.hashCode;

  @override String toString() => 'UserModel($id, $displayName)'; // i18n-ignore

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
