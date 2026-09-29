import 'package:flutter/material.dart';

/// Charte ARISE & SHINE Krea (même palette que le site : resources/css/theme.css du serveur).
///
/// BLEU = confiance, structure (~25 %) · ORANGE = action (~10 %) ·
/// JAUNE = lumière, inspiration (~5 %, jamais de texte blanc dessus) · BLANC = espace (~60 %).
abstract final class AppColors {
  // ── Marque ───────────────────────────────────────────────────────────────
  /// Krea Blue : navigation, titres, action principale.
  static const Color primary = Color(0xFF184797);
  /// Blue Dark : survol, texte très important, texte sur le jaune.
  static const Color primaryDark = Color(0xFF103675);
  /// Bleu intermédiaire (dégradés bleu → bleu, icônes).
  static const Color primaryLight = Color(0xFF4B7ACB);
  /// Blue Light : fonds bleus très légers (élément actif, sélection).
  static const Color primarySoft = Color(0xFFEAF1FC);

  /// Krea Orange : appel à l'action très important.
  static const Color secondary = Color(0xFFF18717);
  static const Color secondaryDark = Color(0xFFD96F0B);
  static const Color secondarySoft = Color(0xFFFFF1E2);

  /// Krea Sun : accents, nouveautés, encouragements.
  static const Color sun = Color(0xFFFCC11D);
  static const Color sunSoft = Color(0xFFFFF8D9);
  static const Color sunBorder = Color(0xFFFDE7A0);
  static const Color sunText = Color(0xFF8A6500);

  // ── Neutres ──────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF667085);
  static const Color border = Color(0xFFE4E7EC);
  static const Color inputBorder = Color(0xFFD0D5DD);

  // ── Messages (distincts de la marque) ────────────────────────────────────
  static const Color success = Color(0xFF12B76A);
  static const Color successSoft = Color(0xFFECFDF3);
  static const Color warning = Color(0xFFF79009);
  static const Color warningSoft = Color(0xFFFFFAEB);
  static const Color danger = Color(0xFFD92D20);
  static const Color dangerSoft = Color(0xFFFEF3F2);
  static const Color info = primary;
  static const Color infoSoft = primarySoft;

  // ── Dégradés autorisés (bandeaux, illustrations ; jamais sur les boutons) ──
  static const List<Color> blueGradient = [primary, primaryDark];
  static const List<Color> sunGradient = [secondary, sun];

  // ── Catégories : bleu, orange et jaune de la marque, en alternance ───────
  static const List<Color> guerisonGradient = [primary, primaryLight];
  static const List<Color> delivranceGradient = [primaryDark, primary];
  static const List<Color> conversionGradient = [secondaryDark, secondary];
  static const List<Color> mariageGradient = [secondary, sun];
  static const List<Color> familleGradient = [Color(0xFFC48A06), sun];
  static const List<Color> financesGradient = [primary, Color(0xFF2B5DB0)];
  static const List<Color> miraclesGradient = [secondaryDark, sun];
  static const List<Color> protectionGradient = [primaryDark, primaryLight];
  static const List<Color> ministereGradient = [primary, secondary];
  static const List<Color> salutGradient = [secondary, secondaryDark];
}
