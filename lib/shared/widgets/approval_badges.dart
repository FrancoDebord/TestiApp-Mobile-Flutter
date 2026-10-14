// lib/shared/widgets/approval_badges.dart
//
// Badges de confiance (charte Krea) — trois notions distinctes :
//   • [AccountApprovalIcon] : pastille « Approuvé » d'un compte, à côté du nom
//     (approval_badge : personnel = coche bleue, organisation = écusson orange) ;
//   • [TestimonyApprovedLabel] : label « Témoignage approuvé » (badges contient
//     "verified"), attribué par un administrateur ;
//   • [FeaturedLabel] : « À la une » (badges contient "featured", mise à la une
//     manuelle ; jamais pour le complément automatique « recent »).
// Le statut de modération (approved = publié) n'a pas de badge public.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../models/account_approval.dart';

/// Pastille « Approuvé » à côté du nom d'un compte.
class AccountApprovalIcon extends StatelessWidget {
  const AccountApprovalIcon({required this.badge, this.size = 14, super.key});

  final AccountApprovalBadge badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final personal = badge == AccountApprovalBadge.personal;
    return Tooltip(
      message: badge.label,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(
          // Personne : coche ronde bleue ; organisation : écusson orange.
          personal ? Icons.verified_rounded : Icons.verified_user_rounded,
          key: ValueKey('approval-${badge.name}'),
          size: size,
          color: personal ? AppColors.primary : AppColors.secondaryDark,
          semanticLabel: badge.label,
        ),
      ),
    );
  }
}

/// Label « Témoignage approuvé » (icône + libellé).
class TestimonyApprovedLabel extends StatelessWidget {
  const TestimonyApprovedLabel({this.compact = false, super.key});

  /// Version réduite (cartes du fil).
  final bool compact;

  static const tooltip = 'Vérifié par l\'équipe de modération';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Témoignage approuvé. $tooltip',
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        triggerMode: TooltipTriggerMode.tap,
        child: _Pill(
          icon: Icons.verified_rounded,
          label: 'Témoignage approuvé',
          background: AppColors.primarySoft,
          foreground: AppColors.primary,
          compact: compact,
        ),
      ),
    );
  }
}

/// Label « À la une ».
class FeaturedLabel extends StatelessWidget {
  const FeaturedLabel({this.compact = false, this.onDark = false, super.key});

  final bool compact;

  /// Sur une image (carrousel) : fond jaune plein.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'À la une',
      excludeSemantics: true,
      child: _Pill(
        icon: Icons.star_rounded,
        label: 'À la une',
        // Jaune Krea : toujours du texte foncé dessus (charte).
        background: onDark ? AppColors.sun : AppColors.sunSoft,
        foreground: onDark ? AppColors.primaryDark : AppColors.sunText,
        compact: compact,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: foreground,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
