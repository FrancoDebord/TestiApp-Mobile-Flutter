import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';

/// Carte blanche arrondie regroupant des [ProfileMenuTile] séparées par un
/// filet fin (écrans Profil et Paramètres de la maquette).
class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({required this.children, this.title, super.key});

  final List<Widget> children;

  /// Titre de section facultatif, affiché au-dessus de la carte.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(const Divider(
            height: 1, thickness: 1, indent: 60, color: AppColors.border));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
            child: Text(
              title!,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        DecoratedBox(
          decoration: AppShadows.cardDecoration,
          child: ClipRRect(
            borderRadius: AppRadius.cardRadius,
            child: Material(
              color: AppColors.surface,
              child: Column(mainAxisSize: MainAxisSize.min, children: rows),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ligne de menu : icône à gauche, libellé (+ sous-titre), valeur ou
/// interrupteur à droite, chevron par défaut.
class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.color,
    this.showChevron = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Valeur courte affichée à droite (ex. « Français », « 28 Mo »).
  final String? value;

  /// Élément de droite personnalisé (ex. Switch) ; remplace le chevron.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Couleur d'accent (ex. danger) ; par défaut bleu primaire.
  final Color? color;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    final titleColor = color ?? AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color == null
                      ? AppColors.primarySoft
                      : accent.withAlpha(22),
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    value!,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ] else if (showChevron && onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.chevron_right_rounded,
                    size: 20,
                    color: color ?? AppColors.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
