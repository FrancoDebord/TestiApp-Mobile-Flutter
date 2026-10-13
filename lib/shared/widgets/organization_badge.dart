// lib/shared/widgets/organization_badge.dart
//
// Petit badge affiché après le nom d'un auteur :
//   • organisation vérifiée → coche bleue « Organisation vérifiée »
//   • personne vérifiée → même coche, « Compte vérifié »
//     (docs/fonctionnalites/verification-des-comptes.md)
//   • organisation non vérifiée → icône bâtiment discrète

import 'package:flutter/material.dart';

class OrganizationBadge extends StatelessWidget {
  const OrganizationBadge({
    super.key,
    required this.isOrganization,
    required this.isVerified,
    this.size = 14,
  });

  final bool isOrganization;
  final bool isVerified;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!isOrganization && !isVerified) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final verified = isVerified;
    final label = verified
        ? (isOrganization ? 'Organisation vérifiée' : 'Compte vérifié')
        : 'Organisation';
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(
          verified ? Icons.verified_rounded : Icons.apartment_rounded,
          size: size,
          color: verified ? const Color(0xFF1D9BF0) : cs.onSurfaceVariant,
          semanticLabel: label,
        ),
      ),
    );
  }
}
