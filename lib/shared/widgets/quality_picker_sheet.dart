// lib/shared/widgets/quality_picker_sheet.dart
//
// Feuille « Qualité » façon YouTube, commune aux lecteurs vidéo et audio.

import 'package:flutter/material.dart';

class QualityOption<T> {
  const QualityOption({
    required this.value,
    required this.label,
    this.hint,
  });

  final T value;
  final String label;
  final String? hint;
}

/// Affiche la liste des qualités et renvoie la valeur choisie (ou `null` si
/// l'utilisateur ferme la feuille).
///
/// [currentLabel] est affiché à côté d'« Auto » (ex. « Auto (360p) »).
Future<T?> showQualityPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<QualityOption<T>> options,
  required T selected,
  String? currentLabel,
  String? footer,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            for (final o in options)
              ListTile(
                leading: Icon(
                  o.value == selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: o.value == selected ? cs.primary : cs.outline,
                ),
                title: Text(
                  o.label == 'Auto' && currentLabel != null
                      ? 'Auto ($currentLabel)'
                      : o.label,
                  style: TextStyle(
                    fontWeight: o.value == selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                subtitle: o.hint == null ? null : Text(o.hint!),
                onTap: () => Navigator.of(ctx).pop(o.value),
              ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(footer,
                    style: Theme.of(ctx)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ),
          ],
        ),
      );
    },
  );
}
