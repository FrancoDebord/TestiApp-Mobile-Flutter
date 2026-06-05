import 'package:flutter/material.dart';
import 'package:testi_app/core/theme/app_colors.dart';

// ── Enums ──────────────────────────────────────────────────────────────────────

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { small, medium, large }

// ── Size configuration ─────────────────────────────────────────────────────────

class _SizeConfig {
  const _SizeConfig({
    required this.height,
    required this.horizontalPadding,
    required this.iconSize,
    required this.textStyle,
    required this.spinnerSize,
    required this.borderRadius,
  });

  final double height;
  final double horizontalPadding;
  final double iconSize;
  final TextStyle textStyle;
  final double spinnerSize;
  final double borderRadius;
}

const _sizeConfigs = <AppButtonSize, _SizeConfig>{
  AppButtonSize.small: _SizeConfig(
    height: 36,
    horizontalPadding: 14,
    iconSize: 16,
    textStyle: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
      fontSize: 13,
      height: 1,
    ),
    spinnerSize: 16,
    borderRadius: 8,
  ),
  AppButtonSize.medium: _SizeConfig(
    height: 48,
    horizontalPadding: 20,
    iconSize: 20,
    textStyle: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
      fontSize: 15,
      height: 1,
    ),
    spinnerSize: 20,
    borderRadius: 12,
  ),
  AppButtonSize.large: _SizeConfig(
    height: 56,
    horizontalPadding: 28,
    iconSize: 22,
    textStyle: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
      fontSize: 16,
      height: 1,
    ),
    spinnerSize: 22,
    borderRadius: 14,
  ),
};

// ── Variant configuration ──────────────────────────────────────────────────────

class _VariantConfig {
  const _VariantConfig({
    required this.background,
    required this.foreground,
    required this.border,
    required this.disabledBackground,
    required this.disabledForeground,
    this.gradient,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color disabledBackground;
  final Color disabledForeground;
  final List<Color>? gradient;
}

const _variantConfigs = <AppButtonVariant, _VariantConfig>{
  AppButtonVariant.primary: _VariantConfig(
    background: AppColors.primary,
    foreground: Colors.white,
    border: Colors.transparent,
    disabledBackground: Color(0xFFD1D5DB),
    disabledForeground: Color(0xFF9CA3AF),
    gradient: [AppColors.primary, AppColors.primaryLight],
  ),
  AppButtonVariant.secondary: _VariantConfig(
    background: Colors.transparent,
    foreground: AppColors.primary,
    border: AppColors.primary,
    disabledBackground: Colors.transparent,
    disabledForeground: Color(0xFF9CA3AF),
  ),
  AppButtonVariant.ghost: _VariantConfig(
    background: Colors.transparent,
    foreground: AppColors.textPrimary,
    border: Colors.transparent,
    disabledBackground: Colors.transparent,
    disabledForeground: Color(0xFF9CA3AF),
  ),
  AppButtonVariant.danger: _VariantConfig(
    background: AppColors.danger,
    foreground: Colors.white,
    border: Colors.transparent,
    disabledBackground: Color(0xFFD1D5DB),
    disabledForeground: Color(0xFF9CA3AF),
  ),
};

// ── Main widget ────────────────────────────────────────────────────────────────

/// Production-grade button with 4 variants, 3 sizes, loading state, and
/// disabled state.
///
/// Example:
/// ```dart
/// AppButton(
///   label: 'Se connecter',
///   variant: AppButtonVariant.primary,
///   size: AppButtonSize.large,
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
  final IconData? trailingIcon;
  final bool fullWidth;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final sc = _sizeConfigs[size]!;
    final vc = _variantConfigs[variant]!;

    final effectiveBackground =
        _isDisabled ? vc.disabledBackground : vc.background;
    final effectiveForeground =
        _isDisabled ? vc.disabledForeground : vc.foreground;
    final effectiveBorder =
        _isDisabled ? vc.disabledBackground : vc.border;

    Widget content = isLoading
        ? SizedBox(
            width: sc.spinnerSize,
            height: sc.spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveForeground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: sc.iconSize, color: effectiveForeground),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: sc.textStyle.copyWith(color: effectiveForeground),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon,
                    size: sc.iconSize, color: effectiveForeground),
              ],
            ],
          );

    // Build the inner decoration
    final hasGradient =
        vc.gradient != null && !_isDisabled && variant == AppButtonVariant.primary;

    Widget button = GestureDetector(
      onTap: _isDisabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: sc.height,
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: sc.horizontalPadding),
        decoration: BoxDecoration(
          color: hasGradient ? null : effectiveBackground,
          gradient: hasGradient
              ? LinearGradient(
                  colors: vc.gradient!,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: BorderRadius.circular(sc.borderRadius),
          border: effectiveBorder != Colors.transparent
              ? Border.all(color: effectiveBorder, width: 1.5)
              : null,
          boxShadow: hasGradient
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(70),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(child: content),
      ),
    );

    // Ghost / secondary get a ripple via Material
    if (variant == AppButtonVariant.ghost ||
        variant == AppButtonVariant.secondary) {
      button = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(sc.borderRadius),
          splashColor: (variant == AppButtonVariant.secondary
                  ? AppColors.primary
                  : AppColors.textPrimary)
              .withAlpha(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: sc.height,
            width: fullWidth ? double.infinity : null,
            padding:
                EdgeInsets.symmetric(horizontal: sc.horizontalPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(sc.borderRadius),
              border: variant == AppButtonVariant.secondary
                  ? Border.all(
                      color: _isDisabled
                          ? vc.disabledForeground
                          : vc.border,
                      width: 1.5,
                    )
                  : null,
            ),
            child: Center(child: content),
          ),
        ),
      );
    }

    return button;
  }
}
