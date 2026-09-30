import 'package:flutter/material.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/core/theme/app_text_styles.dart';

// ── Enums ──────────────────────────────────────────────────────────────────────

/// Variantes de la charte ARISE & SHINE Krea :
/// - [primary]   : Krea Blue, texte blanc (action principale)
/// - [orange]    : Krea Orange, texte blanc (action très importante : Publier…)
/// - [accent]    : Krea Sun, texte bleu foncé (jamais de texte blanc sur jaune)
/// - [secondary] : fond blanc, bordure et texte bleus
/// - [outline]   : fond blanc, bordure grise, texte sombre (Google, e-mail…)
/// - [ghost]     : sans fond
/// - [danger]    : rouge (déconnexion, suppression)
enum AppButtonVariant { primary, orange, accent, secondary, outline, ghost, danger }

enum AppButtonSize { small, medium, large }

// ── Size configuration ─────────────────────────────────────────────────────────

class _SizeConfig {
  const _SizeConfig({
    required this.height,
    required this.horizontalPadding,
    required this.iconSize,
    required this.textStyle,
    required this.spinnerSize,
  });

  final double height;
  final double horizontalPadding;
  final double iconSize;
  final TextStyle textStyle;
  final double spinnerSize;
}

const _sizeConfigs = <AppButtonSize, _SizeConfig>{
  AppButtonSize.small: _SizeConfig(
    height: 36,
    horizontalPadding: 14,
    iconSize: 16,
    textStyle: TextStyle(
      fontFamily: AppFonts.family,
      fontWeight: FontWeight.w600,
      fontSize: 13,
      height: 1.1,
    ),
    spinnerSize: 16,
  ),
  AppButtonSize.medium: _SizeConfig(
    height: 48,
    horizontalPadding: 20,
    iconSize: 20,
    textStyle: TextStyle(
      fontFamily: AppFonts.family,
      fontWeight: FontWeight.w600,
      fontSize: 15,
      height: 1.1,
    ),
    spinnerSize: 20,
  ),
  AppButtonSize.large: _SizeConfig(
    height: 52,
    horizontalPadding: 24,
    iconSize: 22,
    textStyle: TextStyle(
      fontFamily: AppFonts.family,
      fontWeight: FontWeight.w600,
      fontSize: 16,
      height: 1.1,
    ),
    spinnerSize: 22,
  ),
};

/// Arrondi des boutons de la charte : 10 px.
const double _radius = 10;

// ── Variant configuration ──────────────────────────────────────────────────────

class _VariantConfig {
  const _VariantConfig({
    required this.background,
    required this.foreground,
    this.border,
    this.splash,
  });

  final Color background;
  final Color foreground;
  final Color? border;
  final Color? splash;
}

const _disabledBackground = Color(0xFFE4E7EC);
const _disabledForeground = Color(0xFF98A2B3);

const _variantConfigs = <AppButtonVariant, _VariantConfig>{
  AppButtonVariant.primary: _VariantConfig(
    background: AppColors.primary,
    foreground: Colors.white,
  ),
  AppButtonVariant.orange: _VariantConfig(
    background: AppColors.secondary,
    foreground: Colors.white,
  ),
  AppButtonVariant.accent: _VariantConfig(
    background: AppColors.sun,
    foreground: AppColors.primaryDark,
  ),
  AppButtonVariant.secondary: _VariantConfig(
    background: AppColors.surface,
    foreground: AppColors.primary,
    border: AppColors.primary,
    splash: AppColors.primarySoft,
  ),
  AppButtonVariant.outline: _VariantConfig(
    background: AppColors.surface,
    foreground: AppColors.textPrimary,
    border: AppColors.inputBorder,
    splash: AppColors.primarySoft,
  ),
  AppButtonVariant.ghost: _VariantConfig(
    background: Colors.transparent,
    foreground: AppColors.primary,
    splash: AppColors.primarySoft,
  ),
  AppButtonVariant.danger: _VariantConfig(
    background: AppColors.danger,
    foreground: Colors.white,
  ),
};

// ── Main widget ────────────────────────────────────────────────────────────────

/// Bouton de la charte : 7 variantes, 3 tailles, état de chargement et état
/// désactivé. Hauteur 48 px (medium), arrondi 10 px, texte 15 px / 600.
///
/// Example:
/// ```dart
/// AppButton(
///   label: 'Se connecter',
///   variant: AppButtonVariant.primary,
///   isLoading: _isLoading,
///   onPressed: _handleLogin,
///   leadingIcon: Icons.login_rounded,
///   fullWidth: true,
/// )
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.leadingIcon,
    this.leading,
    this.trailingIcon,
    this.fullWidth = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final IconData? leadingIcon;

  /// Élément de tête personnalisé (ex. logo Google) ; prioritaire sur
  /// [leadingIcon].
  final Widget? leading;
  final IconData? trailingIcon;
  final bool fullWidth;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final sc = _sizeConfigs[size]!;
    final vc = _variantConfigs[variant]!;

    final hasFill = vc.background != Colors.transparent &&
        vc.background != AppColors.surface;
    final background = _isDisabled && hasFill
        ? _disabledBackground
        : vc.background;
    final foreground = _isDisabled ? _disabledForeground : vc.foreground;
    final borderColor =
        vc.border == null ? null : (_isDisabled ? _disabledBackground : vc.border);

    final content = isLoading
        ? SizedBox(
            width: sc.spinnerSize,
            height: sc.spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                  hasFill ? vc.foreground : AppColors.primary),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ] else if (leadingIcon != null) ...[
                Icon(leadingIcon, size: sc.iconSize, color: foreground),
                const SizedBox(width: 8),
              ],
              // Flexible : un libellé long se coupe au lieu de déborder.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sc.textStyle.copyWith(color: foreground),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: sc.iconSize, color: foreground),
              ],
            ],
          );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor, width: 1.2),
    );

    return Semantics(
      button: true,
      enabled: !_isDisabled,
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        child: Material(
          color: background,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _isDisabled ? null : onPressed,
            splashColor: (vc.splash ?? Colors.white).withAlpha(90),
            highlightColor: (vc.splash ?? Colors.white).withAlpha(40),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: sc.height),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: sc.horizontalPadding, vertical: 8),
                child: Center(widthFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
