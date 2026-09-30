import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Arrondis de la charte ARISE & SHINE Krea (formes arrondies du logo).
///
/// Cartes 16 · boutons et champs 10 · badges en pilule.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999;

  static const double button = 10;
  static const double field = 10;
  static const double card = lg;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(button));
}

/// Espacements (grille de 4 px). Marge d'écran mobile : 16–20 px.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const double screen = 16;
}

/// Ombres : très légères, jamais de grosse ombre.
abstract final class AppShadows {
  /// 0 4px 20px rgba(16, 54, 117, 0.08)
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14103675),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  /// Décoration standard d'une carte blanche.
  static const BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppRadius.cardRadius,
    border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
    boxShadow: card,
  );
}
