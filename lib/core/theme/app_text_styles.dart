import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typographie de la charte ARISE & SHINE Krea : Plus Jakarta Sans (embarquée,
/// assets/fonts), titres gras en Krea Blue ; versets en Playfair Display italique
/// (google_fonts).
/// Nom de la police de l'application (déclarée dans pubspec.yaml).
abstract final class AppFonts {
  static const String family = 'Plus Jakarta Sans';
}

abstract final class AppTextStyles {
  // ── Headings (Poppins SemiBold) ──────────────────────────────────────────
  static TextStyle get h1 => TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        color: AppColors.primary,
        height: 1.3,
      );

  static TextStyle get h2 => TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: AppColors.primary,
        height: 1.35,
      );

  static TextStyle get h3 => TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: AppColors.primary,
        height: 1.4,
      );

  static TextStyle get h4 => TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  // ── Body (Inter Regular) ─────────────────────────────────────────────────
  static TextStyle get bodyLarge => TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 16,
        color: AppColors.textPrimary,
        height: 1.7,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.6,
      );

  static TextStyle get bodySmall => TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get labelMedium => TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get labelSmall => TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // ── Verse / Quotes (Playfair Display Italic) ─────────────────────────────
  static TextStyle get verseQuote => GoogleFonts.playfairDisplay(
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        fontSize: 17,
        color: AppColors.textPrimary,
        height: 1.8,
      );

  static TextStyle get verseReference => GoogleFonts.playfairDisplay(
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: AppColors.primary,
        height: 1.5,
      );
}
