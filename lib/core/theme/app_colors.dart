import 'package:flutter/material.dart';

/// Central color palette for Témoignages.
abstract final class AppColors {
  static const Color primary = Color(0xFF6B21A8);
  static const Color primaryLight = Color(0xFFA855F7);
  static const Color secondary = Color(0xFFF59E0B);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color border = Color(0xFFE2E8F0);

  // Category gradient stops
  static const List<Color> guerisonGradient = [Color(0xFF6B21A8), Color(0xFFA855F7)];
  static const List<Color> delivranceGradient = [Color(0xFF1E3A8A), Color(0xFF3B82F6)];
  static const List<Color> conversionGradient = [Color(0xFF065F46), Color(0xFF10B981)];
  static const List<Color> mariageGradient = [Color(0xFF9D174D), Color(0xFFF43F5E)];
  static const List<Color> familleGradient = [Color(0xFF92400E), Color(0xFFF59E0B)];
  static const List<Color> financesGradient = [Color(0xFF14532D), Color(0xFF22C55E)];
  static const List<Color> miraclesGradient = [Color(0xFF7C2D12), Color(0xFFF97316)];
  static const List<Color> protectionGradient = [Color(0xFF1E3A5F), Color(0xFF0EA5E9)];
  static const List<Color> ministereGradient = [Color(0xFF4A1D96), Color(0xFF8B5CF6)];
  static const List<Color> salutGradient = [Color(0xFF7F1D1D), Color(0xFFEF4444)];
}
