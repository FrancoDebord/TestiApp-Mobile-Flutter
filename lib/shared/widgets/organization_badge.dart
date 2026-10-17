// lib/shared/widgets/organization_badge.dart
//
// Petit badge affiché après le nom d'un compte :
//   • compte approuvé (approval_badge, docs serveur fonctionnalites/badge-approuve.md)
//     → pastille [AccountApprovalIcon] : coche bleue (personne) ou écusson
//       orange (organisation) ;
//   • organisation non approuvée → icône bâtiment discrète.
// Sans approval_badge fourni, il est déduit de (isOrganization, isVerified) :
// côté serveur, le badge est la vérification du compte.

import 'package:flutter/material.dart';

import '../models/account_approval.dart';
import 'approval_badges.dart';
import '../../l10n/app_localizations.dart';

class OrganizationBadge extends StatelessWidget {
  const OrganizationBadge({
    super.key,
    required this.isOrganization,
    required this.isVerified,
    this.approvalBadge,
    this.size = 14,
  });

  final bool isOrganization;
  final bool isVerified;

  /// Style donné par le serveur (prioritaire sur isVerified).
  final AccountApprovalBadge? approvalBadge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final badge = approvalBadge ??
        AccountApprovalBadge.fromLegacy(isOrganization: isOrganization, isVerified: isVerified);
    if (badge != null) return AccountApprovalIcon(badge: badge, size: size);
    if (!isOrganization) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.sharedOrganization,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(
          Icons.apartment_rounded,
          size: size,
          color: cs.onSurfaceVariant,
          semanticLabel: context.l10n.sharedOrganization,
        ),
      ),
    );
  }
}
