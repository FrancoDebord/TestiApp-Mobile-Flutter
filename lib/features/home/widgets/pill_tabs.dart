// lib/features/home/widgets/pill_tabs.dart
//
// Rangée d'onglets en pilule (maquette : « Tous · Vidéos · Audios · Textes »).
// Sélectionné : fond bleu primaire + texte blanc ; sinon fond blanc, bordure fine.

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/testimony_model.dart';

class PillTab<T> {
  const PillTab(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Onglets « type de témoignage » (null = Tous). Pas d'onglet « Images » :
/// l'application ne publie pas de témoignage image.
const List<PillTab<TestimonyType?>> kTestimonyTypeTabs = [
  PillTab(null, 'Tous'),
  PillTab(TestimonyType.video, 'Vidéos'),
  PillTab(TestimonyType.audio, 'Audios'),
  PillTab(TestimonyType.text, 'Textes'),
];

class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
    super.key,
  });

  final List<PillTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            PillChip(
              label: tabs[i].label,
              icon: tabs[i].icon,
              selected: tabs[i].value == selected,
              onTap: () => onSelected(tabs[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

/// Puce en pilule (onglet ou catégorie).
class PillChip extends StatelessWidget {
  const PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.soft = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Variante douce : sélection = fond primarySoft + texte primary.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (soft ? AppColors.primarySoft : AppColors.primary)
        : AppColors.surface;
    final fg = selected
        ? (soft ? AppColors.primary : Colors.white)
        : AppColors.textSecondary;
    final border = selected
        ? (soft ? AppColors.primary.withAlpha(60) : AppColors.primary)
        : AppColors.border;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  maxLines: 1,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: fg,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
