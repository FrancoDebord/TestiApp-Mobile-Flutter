// lib/shared/models/account_approval.dart
//
// Badge « Approuvé » des comptes (docs serveur fonctionnalites/badge-approuve.md).
//
// `approval_badge` (approved_personal | approved_organization | null) décide du
// style de la pastille ; `is_approved` dit s'il y en a une ; `account_type` vaut
// individual | organization ; `approval_source` est informatif (non affiché).
//
// Le badge EST la vérification de compte existante côté serveur
// (verification_status = verified) : pour un objet qui n'expose pas encore
// approval_badge, on retombe sur is_verified / verification_status.

/// Style de la pastille « Approuvé ».
enum AccountApprovalBadge {
  personal,
  organization;

  /// Valeur de l'API ← enum.
  String get apiValue => this == personal ? 'approved_personal' : 'approved_organization';

  /// Libellé de l'info-bulle et de l'accessibilité.
  String get label => this == personal ? 'Compte approuvé' : 'Organisation approuvée';

  static AccountApprovalBadge? fromApi(Object? value) => switch (value) {
        'approved_personal' => personal,
        'approved_organization' => organization,
        _ => null,
      };

  /// Badge depuis un utilisateur ou un auteur (snake_case ou camelCase).
  static AccountApprovalBadge? parse(Map<String, dynamic> m) {
    if (m.containsKey('approval_badge') || m.containsKey('approvalBadge')) {
      return fromApi(m['approval_badge'] ?? m['approvalBadge']);
    }
    final approved = m['is_approved'] == true ||
        m['isApproved'] == true ||
        m['is_verified'] == true ||
        m['isVerified'] == true ||
        m['organization_verified'] == true ||
        m['verification_status'] == 'verified';
    if (!approved) return null;
    final type = m['account_type'] ?? m['accountType'];
    final isOrg = type == 'organization' || m['isOrganization'] == true || m['is_organization'] == true;
    return isOrg ? organization : personal;
  }

  /// Badge déduit de l'ancien couple (organisation ?, vérifié ?).
  static AccountApprovalBadge? fromLegacy({required bool isOrganization, required bool isVerified}) =>
      isVerified ? (isOrganization ? organization : personal) : null;
}
