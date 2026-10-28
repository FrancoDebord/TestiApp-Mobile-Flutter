// Prier plusieurs fois (docs serveur fonctionnalites/prier-plusieurs-fois.md) : quand la
// personne prie déjà, « Je prie » propose « Prier encore » (nouveau temps de prière, puis
// `again: true`) ou « Retirer ma dernière prière » (`last`). Le compteur de la publication
// reste le nombre de personnes ; le nombre de fois est propre à chacun (`myPrayerTimes`).

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';

enum PrayAgainChoice { again, removeLast }

/// Feuille « Vous avez prié N fois » : prier encore ou retirer sa dernière prière.
Future<PrayAgainChoice?> askPrayAgain(BuildContext context, {required int times}) {
  return showModalBottomSheet<PrayAgainChoice>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (sheet) {
      final l10n = sheet.l10n;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.volunteer_activism, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.prayTimesYou(times < 1 ? 1 : times), style: AppTextStyles.h4)),
              ]),
              const SizedBox(height: 6),
              Text(l10n.prayAgainHint, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(sheet).pop(PrayAgainChoice.again),
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: Text(l10n.prayAgain),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(sheet).pop(PrayAgainChoice.removeLast),
                child: Text(l10n.prayRemoveLast),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// « Vous avez prié 3 fois » (rien si la personne ne prie pas).
class MyPrayerTimesLine extends StatelessWidget {
  const MyPrayerTimesLine({required this.times, this.padding = EdgeInsets.zero, super.key});

  final int times;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (times < 1) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volunteer_activism, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.l10n.prayTimesYou(times),
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
