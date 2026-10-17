// =============================================================================
// Profile feature — domain models
// =============================================================================

import '../../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Profil étendu (champs complémentaires stockés localement)
// ---------------------------------------------------------------------------

class ProfileExtras {
  const ProfileExtras({
    this.firstName  = '',
    this.lastName   = '',
    this.gender     = '',   // 'Homme' | 'Femme'
    this.phone      = '',   // numéro national (sans indicatif)
    this.phoneCountry = '', // code ISO de l'indicatif (« bj »)
    this.email      = '',
    this.country    = '',
    this.bio        = '',
    this.title      = '',   // titre ecclésiastique ou personnalisé
    this.avatarPath,        // local file path (null = not set)
  });

  final String  firstName;
  final String  lastName;
  final String  gender;
  final String  phone;
  final String  phoneCountry;
  final String  email;
  final String  country;
  final String  bio;
  final String  title;
  final String? avatarPath;

  String get displayName {
    final name = '${firstName.trim()} ${lastName.trim()}'.trim();
    return name.isEmpty ? L10n.current.profileFallbackUser : name;
  }

  bool get hasPersonalInfo =>
      gender.isNotEmpty || phone.isNotEmpty ||
      email.isNotEmpty || country.isNotEmpty;

  ProfileExtras copyWith({
    String? firstName,
    String? lastName,
    String? gender,
    String? phone,
    String? phoneCountry,
    String? email,
    String? country,
    String? bio,
    String? title,
    String? avatarPath,
    bool    clearAvatarPath = false,
  }) => ProfileExtras(
    firstName:  firstName  ?? this.firstName,
    lastName:   lastName   ?? this.lastName,
    gender:     gender     ?? this.gender,
    phone:      phone      ?? this.phone,
    phoneCountry: phoneCountry ?? this.phoneCountry,
    email:      email      ?? this.email,
    country:    country    ?? this.country,
    bio:        bio        ?? this.bio,
    title:      title      ?? this.title,
    avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
  );
}

// ---------------------------------------------------------------------------
// Profil complet
// ---------------------------------------------------------------------------

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.country,
    required this.memberSince,
    required this.testimonyCount,
    required this.likeCount,
    required this.prayerCount,
    this.followersCount = 0,
    this.followingCount = 0,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.isPrivate = false,
    this.extras = const ProfileExtras(),
  });

  final String       uid;
  final String       displayName;
  final String       country;
  final DateTime     memberSince;
  final int          testimonyCount;
  final int          likeCount;
  final int          prayerCount;
  final int          followersCount;
  final int          followingCount;
  final String?      bio;
  final String?      avatarUrl;
  /// Photo de couverture (bandeau du profil).
  final String?      coverUrl;
  final bool         isPrivate;
  final ProfileExtras extras;

  String get memberSinceLabel => L10n.current.profileMemberSinceMonthYear(
        '${memberSince.month}',
        '${memberSince.year}',
      );

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2 && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }
}

// ---------------------------------------------------------------------------
// Carte témoignage compacte pour la grille profil
// ---------------------------------------------------------------------------

class ProfileTestimonyCard {
  const ProfileTestimonyCard({
    required this.id,
    required this.title,
    required this.category,
    required this.likeCount,
    required this.prayerCount,
    this.coverUrl,
    this.isDraft = false,
  });

  final String  id;
  final String  title;
  final String  category;
  final int     likeCount;
  final int     prayerCount;
  final String? coverUrl;
  final bool    isDraft;
}

// ---------------------------------------------------------------------------
// Paramètres
// ---------------------------------------------------------------------------

// Pas de réglage Clair / Sombre / Système : l'application n'a pas de palette
// sombre (couleurs fixes AppColors). À réintroduire avec un vrai mode sombre.

/// « Qui peut commenter mes témoignages » (`user_settings.comment_permission`,
/// appliqué par le serveur : 403 pour les autres).
enum CommentPermission {
  everyone,
  followers,
  nobody;

  static CommentPermission fromJson(String? v) => switch (v) {
    'followers' => CommentPermission.followers,
    'nobody'    => CommentPermission.nobody,
    _           => CommentPermission.everyone,
  };

  String toJson() => name;
}

extension CommentPermissionLabel on CommentPermission {
  String get label => switch (this) {
    CommentPermission.everyone  => L10n.current.settingsCommentEveryone,
    CommentPermission.followers => L10n.current.settingsCommentFollowers,
    CommentPermission.nobody    => L10n.current.settingsCommentNobody,
  };
}

class UserSettings {
  const UserSettings({
    this.pushComments    = true,
    this.pushLikes       = true,
    this.pushPrayers     = true,
    this.pushApproval    = true,
    this.commentPermission = CommentPermission.everyone,
  });

  final bool               pushComments;
  final bool               pushLikes;
  final bool               pushPrayers;
  final bool               pushApproval;
  final CommentPermission  commentPermission;

  /// GET / PUT /users/me/settings (clés snake_case du serveur).
  factory UserSettings.fromJson(Map<String, dynamic> j) {
    bool b(String k) {
      final v = j[k];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return true; // non enregistré : envoyé par défaut (comme le serveur)
    }

    return UserSettings(
      pushComments: b('push_comments'),
      pushLikes: b('push_likes'),
      pushPrayers: b('push_prayers'),
      pushApproval: b('push_approval'),
      commentPermission:
          CommentPermission.fromJson(j['comment_permission'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'push_comments': pushComments,
    'push_likes': pushLikes,
    'push_prayers': pushPrayers,
    'push_approval': pushApproval,
    'comment_permission': commentPermission.toJson(),
  };

  UserSettings copyWith({
    bool? pushComments,
    bool? pushLikes,
    bool? pushPrayers,
    bool? pushApproval,
    CommentPermission? commentPermission,
  }) => UserSettings(
    pushComments:      pushComments      ?? this.pushComments,
    pushLikes:         pushLikes         ?? this.pushLikes,
    pushPrayers:       pushPrayers       ?? this.pushPrayers,
    pushApproval:      pushApproval      ?? this.pushApproval,
    commentPermission: commentPermission ?? this.commentPermission,
  );
}
