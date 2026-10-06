// « Comptes à suivre » (GET /users/suggestions) : profil public + raison de la suggestion.
// Backend : docs/fonctionnalites/abonnements.md (App\Services\AccountSuggestions)

import 'community_account.dart';

class SuggestedAccount {
  const SuggestedAccount({required this.account, this.reason = ''});

  factory SuggestedAccount.fromJson(Map<String, dynamic> m) {
    // Le serveur fournit les champs du profil (snake_case) et ceux de l'écran (camelCase).
    final merged = <String, dynamic>{
      ...m,
      'testimony_count': m['testimony_count'] ?? m['testimonyCount'],
      'follower_count': m['follower_count'] ?? m['followersCount'],
      'is_verified': m['is_verified'] ?? m['isVerified'],
      'is_following': m['is_following'] ?? m['isFollowing'],
      if (m['account_type'] == null && m['isOrganization'] == true) 'account_type': 'organization',
    };
    final reason = m['reason'];
    return SuggestedAccount(
      account: CommunityAccount.fromJson(merged),
      reason: reason is String ? reason.trim() : '',
    );
  }

  final CommunityAccount account;

  /// « Organisation vérifiée », « Publie souvent des témoignages », « Suivi par X que vous suivez »…
  final String reason;

  String get id => account.id;
}
