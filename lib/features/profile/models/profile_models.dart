// =============================================================================
// Profile feature — domain models
// =============================================================================

// ---------------------------------------------------------------------------
// Profil étendu (champs complémentaires stockés localement)
// ---------------------------------------------------------------------------

class ProfileExtras {
  const ProfileExtras({
    this.firstName  = '',
    this.lastName   = '',
    this.gender     = '',   // 'Homme' | 'Femme' | 'Autre'
    this.phone      = '',
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
  final String  email;
  final String  country;
  final String  bio;
  final String  title;
  final String? avatarPath;

  String get displayName {
    final name = '${firstName.trim()} ${lastName.trim()}'.trim();
    return name.isEmpty ? 'Utilisateur' : name;
  }

  bool get hasPersonalInfo =>
      gender.isNotEmpty || phone.isNotEmpty ||
      email.isNotEmpty || country.isNotEmpty;

  ProfileExtras copyWith({
    String? firstName,
    String? lastName,
    String? gender,
    String? phone,
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
  final bool         isPrivate;
  final ProfileExtras extras;

  String get memberSinceLabel {
    const months = [
      'Janvier','Février','Mars','Avril','Mai','Juin',
      'Juillet','Août','Septembre','Octobre','Novembre','Décembre',
    ];
    return 'Membre depuis ${months[memberSince.month - 1]} ${memberSince.year}';
  }

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

enum AppTheme { light, dark, system }

extension AppThemeLabel on AppTheme {
  String get label => switch (this) {
    AppTheme.light  => 'Clair',
    AppTheme.dark   => 'Sombre',
    AppTheme.system => 'Système',
  };
}

enum CommentPermission { everyone, nobody }

extension CommentPermissionLabel on CommentPermission {
  String get label => switch (this) {
    CommentPermission.everyone => 'Tout le monde',
    CommentPermission.nobody   => 'Personne',
  };
}

class UserSettings {
  const UserSettings({
    this.pushComments    = true,
    this.pushLikes       = true,
    this.pushPrayers     = true,
    this.pushApproval    = true,
    this.commentPermission = CommentPermission.everyone,
    this.appTheme        = AppTheme.system,
  });

  final bool               pushComments;
  final bool               pushLikes;
  final bool               pushPrayers;
  final bool               pushApproval;
  final CommentPermission  commentPermission;
  final AppTheme           appTheme;

  UserSettings copyWith({
    bool? pushComments,
    bool? pushLikes,
    bool? pushPrayers,
    bool? pushApproval,
    CommentPermission? commentPermission,
    AppTheme? appTheme,
  }) => UserSettings(
    pushComments:      pushComments      ?? this.pushComments,
    pushLikes:         pushLikes         ?? this.pushLikes,
    pushPrayers:       pushPrayers       ?? this.pushPrayers,
    pushApproval:      pushApproval      ?? this.pushApproval,
    commentPermission: commentPermission ?? this.commentPermission,
    appTheme:          appTheme          ?? this.appTheme,
  );
}
