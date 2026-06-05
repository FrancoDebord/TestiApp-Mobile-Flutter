import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography system for Témoignages.
/// Headings: Poppins SemiBold
/// Body: Inter Regular
/// Verses/Quotes: Playfair Display Italic
///
/// Fonts are served by the google_fonts package (network + cache on first run,
/// bundled fallback glyphs while loading).
abstract final class AppTextStyles {
  // ── Headings (Poppins SemiBold) ──────────────────────────────────────────
  static TextStyle get h1 => GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 28,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get h2 => GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: AppColors.textPrimary,
        height: 1.35,
      );

  static TextStyle get h3 => GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get h4 => GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  // ── Body (Inter Regular) ─────────────────────────────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        color: AppColors.textPrimary,
        height: 1.7,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.6,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
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
