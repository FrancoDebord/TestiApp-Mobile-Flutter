import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_logo.dart';

// =============================================================================
// Composants communs des écrans d'authentification (charte ARISE & SHINE)
// Utilisés par : LoginScreen, RegisterScreen, ForgotPasswordScreen,
// VerifyEmailScreen, PhoneAuthScreen.
// Style : fond clair, logo dessiné, titres bleus, champs blancs bordure fine,
// boutons 48 px radius 10.
// =============================================================================

// ── En-tête clair (logo + titre + sous-titre) ────────────────────────────────

class AuthScreenHeader extends StatelessWidget {
  const AuthScreenHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.markSize = 64,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Affiche une flèche retour en haut à gauche si non nul.
  final VoidCallback? onBack;
  final double markSize;

  /// Icône à la place du logo (ex. enveloppe pour « vérifier l'e-mail »).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: onBack == null
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Retour',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.primary),
                  ),
                ),
        ),
        Center(
          child: icon == null
              ? AppLogoMark(size: markSize)
              : Container(
                  width: markSize,
                  height: markSize,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      color: AppColors.primary, size: markSize * 0.46),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.h2,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ],
    );
  }
}

// ── En-tête historique ───────────────────────────────────────────────────────
// Conservé pour compatibilité : désormais un simple bandeau clair.

class AuthWaveHeader extends StatelessWidget {
  const AuthWaveHeader({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.surface, child: child);
  }
}

// ── Champ de saisie avec libellé ─────────────────────────────────────────────

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.enabled = true,
    this.suffixIcon,
    this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;

  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelMedium.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          enabled: enabled,
          onFieldSubmitted: onFieldSubmitted,
          style: AppTextStyles.bodyMedium.copyWith(fontSize: 15, height: 1.3),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: AppFonts.family,
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
            prefixIcon:
                Icon(prefixIcon, color: AppColors.textSecondary, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surface,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: _border(AppColors.inputBorder),
            enabledBorder: _border(AppColors.inputBorder),
            disabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.primary, 1.6),
            errorBorder: _border(AppColors.danger),
            focusedErrorBorder: _border(AppColors.danger, 1.6),
            errorMaxLines: 3,
            errorStyle: const TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 12,
              color: AppColors.danger,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bouton principal pleine largeur ──────────────────────────────────────────

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.color = AppColors.primary,
    super.key,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withAlpha(128),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button)),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            )
          : Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.family,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
    );
  }
}

// ── Bandeau d'erreur ─────────────────────────────────────────────────────────

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 13,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Séparateur « ou continuer avec » ─────────────────────────────────────────

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({this.label = 'ou continuer avec', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppTextStyles.bodySmall,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

// ── Bouton social (contour gris) ─────────────────────────────────────────────

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: AppColors.textPrimary),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppFonts.family,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.inputBorder),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button)),
        backgroundColor: AppColors.surface,
      ),
    );
  }
}

// ── Logo « G » de Google (dessiné, couleurs de la marque) ────────────────────

class GoogleGMark extends StatelessWidget {
  const GoogleGMark({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  // Couleurs officielles de la marque Google (exception à la charte).
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final rect = Rect.fromCircle(
        center: Offset(s / 2, s / 2), radius: (s - stroke) / 2);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const d = 3.14159265 / 180;
    // Angles dans le sens horaire depuis l'axe +x ; ouverture en haut à droite.
    canvas.drawArc(rect, 0, 45 * d, false, arc(_blue));
    canvas.drawArc(rect, 45 * d, 95 * d, false, arc(_green));
    canvas.drawArc(rect, 140 * d, 80 * d, false, arc(_yellow));
    canvas.drawArc(rect, 220 * d, 95 * d, false, arc(_red));
    // Barre horizontale du G.
    canvas.drawRect(
      Rect.fromLTWH(s / 2, s / 2 - stroke / 2, s / 2 - stroke / 2 + 0.5,
          stroke),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
