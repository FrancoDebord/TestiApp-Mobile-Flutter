// Administrateurs de compte : modèles (GET /users/me/accounts, /users/me/managers,
// /users/me/managers/activity, /users/me/managed-organizations).

import '../../../shared/models/user_model.dart';

String? _str(dynamic v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;

String _initialsOf(String name) => name
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w[0].toUpperCase())
    .join();

/// Rôle de la personne connectée vis-à-vis d'un compte.
enum AccountRole {
  owner,
  manager;

  static AccountRole fromJson(dynamic v) => v == 'owner' ? owner : manager;
  String toJson() => name;
}

/// Un compte : celui de la personne (role owner), un compte qu'elle administre
/// (role manager), ou un de ses administrateurs (liste `managers`).
class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.displayName,
    this.username,
    this.initials = '',
    this.avatarUrl,
    this.isOrganization = false,
    this.isVerified = false,
    this.role = AccountRole.manager,
    this.since,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> m) {
    final name = _str(m['displayName']) ?? _str(m['display_name']) ?? 'Compte';
    return AccountSummary(
      id: '${m['id'] ?? ''}',
      displayName: name,
      username: _str(m['username']),
      initials: _str(m['initials']) ?? _initialsOf(name),
      avatarUrl: _str(m['avatarUrl']) ?? _str(m['avatar_url']),
      isOrganization: m['isOrganization'] == true || m['is_organization'] == true,
      isVerified: m['isVerified'] == true || m['is_verified'] == true,
      role: AccountRole.fromJson(m['role']),
      since: _date(m['since']),
    );
  }

  final String id;
  final String displayName;
  final String? username;
  final String initials;
  final String? avatarUrl;
  final bool isOrganization;
  final bool isVerified;
  final AccountRole role;
  final DateTime? since;

  bool get isOwner => role == AccountRole.owner;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'username': ?username,
        'initials': initials,
        'avatarUrl': ?avatarUrl,
        'isOrganization': isOrganization,
        'isVerified': isVerified,
        'role': role.toJson(),
        if (since != null) 'since': since!.toIso8601String(),
      };

  /// Utilisateur provisoire, le temps que `GET /users/me` réponde.
  UserModel toPlaceholderUser() => UserModel(
        id: id,
        displayName: displayName,
        avatarUrl: avatarUrl,
        accountType: isOrganization ? AccountType.organization : AccountType.individual,
        organizationName: isOrganization ? displayName : null,
        isVerified: isVerified,
        hasPassword: false,
      );
}

/// `GET /users/me/accounts` : le premier compte est celui de la personne.
class AccountsSnapshot {
  const AccountsSnapshot({required this.accounts, this.actingAs});

  factory AccountsSnapshot.fromJson(dynamic data) {
    final m = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    final raw = m['accounts'] is List ? m['accounts'] as List : (data is List ? data : const []);
    return AccountsSnapshot(
      accounts: raw
          .whereType<Map>()
          .map((a) => AccountSummary.fromJson(Map<String, dynamic>.from(a)))
          .where((a) => a.id.isNotEmpty)
          .toList(),
      actingAs: _str(m['actingAs']),
    );
  }

  final List<AccountSummary> accounts;
  final String? actingAs;

  AccountSummary? get owner {
    for (final a in accounts) {
      if (a.isOwner) return a;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  /// Comptes administrés (hors le sien).
  List<AccountSummary> get managed => [
        for (final a in accounts)
          if (!a.isOwner && a.id != owner?.id) a,
      ];

  AccountSummary? byId(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// `GET /users/me/managers` : administrateurs du compte (2 au plus).
class AccountManagers {
  const AccountManagers({required this.managers, this.max = 2});

  factory AccountManagers.fromJson(dynamic data) {
    final m = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    final max = _int(m['max']);
    return AccountManagers(
      max: max <= 0 ? 2 : max,
      managers: (m['managers'] is List ? m['managers'] as List : const [])
          .whereType<Map>()
          .map((p) => AccountSummary.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
    );
  }

  final List<AccountSummary> managers;
  final int max;

  bool get isFull => managers.length >= max;
}

/// Action faite au nom du compte par un administrateur.
class ManagerActivity {
  const ManagerActivity({
    required this.id,
    required this.actorName,
    required this.action,
    this.actorId,
    this.createdAt,
  });

  factory ManagerActivity.fromJson(Map<String, dynamic> m) => ManagerActivity(
        id: '${m['id'] ?? ''}',
        actorId: _str(m['actorId']),
        actorName: _str(m['actorName']) ?? 'Un administrateur',
        action: _str(m['action']) ?? '',
        createdAt: _date(m['createdAt']),
      );

  final String id;
  final String? actorId;
  final String actorName;
  final String action;
  final DateTime? createdAt;
}
