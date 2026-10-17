// lib/features/profile/models/account_verification.dart
//
// Vérification d'un compte personnel (badge « Compte vérifié ») :
// GET/POST /users/me/verification. Voir docs/fonctionnalites/verification-des-comptes.md
// (dépôt Laravel). Les pièces justificatives restent privées : l'API ne renvoie
// que leur nombre.

import 'dart:typed_data';

import '../../../l10n/app_localizations.dart';

enum AccountVerificationStatus {
  none,
  pending,
  verified,
  rejected,
  revoked;

  static AccountVerificationStatus fromJson(Object? v) => switch (v) {
        'pending' => pending,
        'verified' => verified,
        'rejected' => rejected,
        'revoked' => revoked,
        _ => none,
      };
}

/// Fonction déclarée (valeurs de l'API ; libellé du serveur, sinon traduit).
class VerificationRoleOption {
  const VerificationRoleOption(this.value, [this._label]);
  final String value;
  final String? _label;

  String get label {
    if (_label != null) return _label;
    final l = L10n.current;
    return switch (value) {
      'pastor' => l.profileRolePastor,
      'evangelist' => l.profileRoleEvangelist,
      'singer' => l.profileRoleSinger,
      'ministry_leader' => l.profileRoleMinistryLeader,
      'public_figure' => l.profileRolePublicFigure,
      'other' => l.profileRoleOther,
      _ => value,
    };
  }

  static const defaults = <VerificationRoleOption>[
    VerificationRoleOption('pastor'),
    VerificationRoleOption('evangelist'),
    VerificationRoleOption('singer'),
    VerificationRoleOption('ministry_leader'),
    VerificationRoleOption('public_figure'),
    VerificationRoleOption('other'),
  ];
}

/// Demande la plus récente, telle que la voit son auteur.
class AccountVerificationRequest {
  const AccountVerificationRequest({
    required this.id,
    required this.status,
    required this.fullName,
    required this.roleLabel,
    required this.church,
    this.role,
    this.roleOther,
    this.links = const [],
    this.message,
    this.documentCount = 0,
    this.createdAt,
    this.reviewedAt,
  });

  final String id;
  final String status;
  final String fullName;
  final String? role;
  final String roleLabel;
  final String? roleOther;
  final String church;
  final List<String> links;
  final String? message;
  final int documentCount;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  factory AccountVerificationRequest.fromJson(Map<String, dynamic> j) =>
      AccountVerificationRequest(
        id: '${j['id'] ?? ''}',
        status: '${j['status'] ?? ''}',
        fullName: '${j['fullName'] ?? ''}',
        role: j['role'] as String?,
        roleLabel: '${j['roleLabel'] ?? ''}',
        roleOther: j['roleOther'] as String?,
        church: '${j['church'] ?? ''}',
        links: (j['links'] as List? ?? const []).whereType<String>().toList(),
        message: j['message'] as String?,
        documentCount: (j['documentCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}'),
        reviewedAt: DateTime.tryParse('${j['reviewedAt'] ?? ''}'),
      );
}

class AccountVerificationState {
  const AccountVerificationState({
    required this.status,
    required this.canRequest,
    this.blockReason,
    this.retryAt,
    this.reason,
    this.verifiedAt,
    this.request,
    this.roles = VerificationRoleOption.defaults,
    this.maxDocuments = 3,
    this.maxDocumentKb = 8192,
    this.maxLinks = 3,
  });

  final AccountVerificationStatus status;
  final bool canRequest;
  final String? blockReason;
  final DateTime? retryAt;

  /// Motif du refus ou du retrait.
  final String? reason;
  final DateTime? verifiedAt;
  final AccountVerificationRequest? request;
  final List<VerificationRoleOption> roles;
  final int maxDocuments;
  final int maxDocumentKb;
  final int maxLinks;

  factory AccountVerificationState.fromJson(Map<String, dynamic> j) {
    final limits = j['limits'] is Map ? Map<String, dynamic>.from(j['limits'] as Map) : const <String, dynamic>{};
    final roles = (j['roles'] as List? ?? const [])
        .whereType<Map>()
        .map((r) => VerificationRoleOption('${r['value']}', '${r['label']}'))
        .toList();
    return AccountVerificationState(
      status: AccountVerificationStatus.fromJson(j['status']),
      canRequest: j['canRequest'] == true,
      blockReason: j['blockReason'] as String?,
      retryAt: DateTime.tryParse('${j['retryAt'] ?? ''}'),
      reason: j['reason'] as String?,
      verifiedAt: DateTime.tryParse('${j['verifiedAt'] ?? ''}'),
      request: j['request'] is Map
          ? AccountVerificationRequest.fromJson(Map<String, dynamic>.from(j['request'] as Map))
          : null,
      roles: roles.isEmpty ? VerificationRoleOption.defaults : roles,
      maxDocuments: (limits['maxDocuments'] as num?)?.toInt() ?? 3,
      maxDocumentKb: (limits['maxDocumentKb'] as num?)?.toInt() ?? 8192,
      maxLinks: (limits['maxLinks'] as num?)?.toInt() ?? 3,
    );
  }
}

/// Pièce justificative choisie (chemin sur mobile, octets sur le web).
class VerificationDocument {
  const VerificationDocument({required this.name, required this.size, this.path, this.bytes});
  final String name;
  final int size;
  final String? path;
  final Uint8List? bytes;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  bool get isPdf => extension == 'pdf';
}

const kVerificationDocumentExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];

/// Raison de refuser une pièce avant l'envoi (type ou taille), sinon null.
String? verificationDocumentRejection(VerificationDocument doc, {int maxKb = 8192}) {
  if (!kVerificationDocumentExtensions.contains(doc.extension)) {
    return L10n.current.profileVerifDocType;
  }
  if (doc.size > maxKb * 1024) {
    return L10n.current.profileVerifDocTooBig(maxKb ~/ 1024);
  }
  return null;
}

final _url = RegExp(r'^https?://[^\s/$.?#].[^\s]*$', caseSensitive: false);

/// Validation du formulaire (mêmes règles que le serveur). Clés : noms des champs de l'API.
Map<String, String> validateVerificationForm({
  required String fullName,
  required String? role,
  required String roleOther,
  required String church,
  required List<String> links,
  required List<VerificationDocument> documents,
  int maxDocuments = 3,
}) {
  final l10n = L10n.current;
  final errors = <String, String>{};
  if (fullName.trim().length < 3) errors['full_name'] = l10n.profileVerifFullNameRequired;
  if (role == null || role.isEmpty) {
    errors['role'] = l10n.profileVerifRoleRequired;
  } else if (role == 'other' && roleOther.trim().isEmpty) {
    errors['role_other'] = l10n.profileVerifRoleOtherRequired;
  }
  if (church.trim().length < 2) errors['church'] = l10n.profileVerifChurchRequired;
  for (var i = 0; i < links.length; i++) {
    final l = links[i].trim();
    if (l.isNotEmpty && !_url.hasMatch(l)) {
      errors['links.$i'] = l10n.profileVerifLinkInvalid;
    }
  }
  if (documents.isEmpty) {
    errors['documents'] = l10n.profileVerifDocRequired;
  } else if (documents.length > maxDocuments) {
    errors['documents'] = l10n.profileVerifDocMax(maxDocuments);
  }
  return errors;
}
