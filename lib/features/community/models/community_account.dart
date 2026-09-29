// Compte affiché dans « Communauté » et sur le profil d'un auteur (UserResource du serveur).
// Backend : docs/fonctionnalites/abonnements.md

import 'package:flutter/widgets.dart' show StringCharacters;

import '../../../shared/models/user_model.dart' show OrganizationType;

class CommunityAccount {
  const CommunityAccount({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.coverUrl,
    this.isOrganization = false,
    this.isVerified = false,
    this.organizationType,
    this.city,
    this.country,
    this.bio,
    this.followerCount = 0,
    this.followingCount = 0,
    this.testimonyCount = 0,
    this.isFollowing,
  });

  factory CommunityAccount.fromJson(Map<String, dynamic> m) {
    String? str(Object? v) {
      final s = v is String ? v.trim() : null;
      return (s == null || s.isEmpty) ? null : s;
    }

    int number(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return CommunityAccount(
      id: '${m['id'] ?? ''}',
      displayName: str(m['display_name']) ?? str(m['displayName']) ?? 'Anonyme',
      avatarUrl: str(m['avatar_url']) ?? str(m['avatarUrl']),
      coverUrl: str(m['cover_url']) ?? str(m['coverUrl']),
      isOrganization: (m['account_type'] ?? m['accountType']) == 'organization',
      isVerified: m['is_verified'] == true || m['verification_status'] == 'verified',
      organizationType: OrganizationType.fromJson(m['organization_type'] as String?),
      city: str(m['organization_city']),
      country: str(m['country']),
      bio: str(m['bio']),
      followerCount: number(m['follower_count']),
      followingCount: number(m['following_count']),
      testimonyCount: number(m['testimony_count']),
      isFollowing: m['is_following'] is bool ? m['is_following'] as bool : null,
    );
  }

  final String id;
  final String displayName;
  final String? avatarUrl;

  /// Photo de couverture (bandeau du profil), null si aucune.
  final String? coverUrl;
  final bool isOrganization;
  final bool isVerified;
  final OrganizationType? organizationType;
  final String? city;
  final String? country;
  final String? bio;
  final int followerCount;
  final int followingCount;
  final int testimonyCount;

  /// État fourni par le serveur (null si inconnu : personne non connectée).
  final bool? isFollowing;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }

  /// « Église · Cotonou · Bénin » ou « Bénin ».
  String get subtitle => [
        if (isOrganization) organizationType?.label,
        if (isOrganization) city,
        country,
      ].whereType<String>().join(' · ');

  CommunityAccount copyWith({int? followerCount}) => CommunityAccount(
        id: id,
        displayName: displayName,
        avatarUrl: avatarUrl,
        coverUrl: coverUrl,
        isOrganization: isOrganization,
        isVerified: isVerified,
        organizationType: organizationType,
        city: city,
        country: country,
        bio: bio,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount,
        testimonyCount: testimonyCount,
        isFollowing: isFollowing,
      );
}

/// Onglets de « Communauté » (paramètre `tab` de l'API).
enum CommunityTab {
  organizations('organizations', 'Organisations'),
  people('people', 'Personnes');

  const CommunityTab(this.apiValue, this.label);
  final String apiValue;
  final String label;
}
