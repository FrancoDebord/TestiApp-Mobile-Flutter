// lib/shared/widgets/app_badge.dart
//
// Badges de la charte : pilule, 12 px / 600.
//   bleu   : fond #EAF1FC, texte #184797
//   orange : fond #FFF1E2, texte #D96F0B
//   jaune  : fond #FFF8D9, texte #8A6500 (nouveautés, encouragements)

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum AppBadgeTone { blue, orange, yellow, success, danger, neutral }

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.blue,
    this.icon,
    this.dense = false,
  });

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;

  /// Version plus petite (sur les cartes).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      AppBadgeTone.blue => (AppColors.primarySoft, AppColors.primary),
      AppBadgeTone.orange => (AppColors.secondarySoft, AppColors.secondaryDark),
      AppBadgeTone.yellow => (AppColors.sunSoft, AppColors.sunText),
      AppBadgeTone.success => (AppColors.successSoft, AppColors.success),
      AppBadgeTone.danger => (AppColors.dangerSoft, AppColors.danger),
      AppBadgeTone.neutral => (AppColors.background, AppColors.textSecondary),
    };
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10, vertical: dense ? 3 : 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
