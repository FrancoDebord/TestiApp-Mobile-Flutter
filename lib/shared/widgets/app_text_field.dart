import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/core/theme/app_text_styles.dart';

// ── Public widget ──────────────────────────────────────────────────────────────

/// A fully-featured text field with label, hint, error/helper text, leading &
/// trailing icon slots, password toggle, and character counter.
///
/// Example — search:
/// ```dart
/// AppTextField(
///   label: 'Rechercher',
///   hint: 'Saisissez un mot-clé…',
///   leadingIcon: Icons.search_rounded,
///   controller: _searchCtrl,
/// )
/// ```
///
/// Example — password:
/// ```dart
/// AppTextField(
///   label: 'Mot de passe',
///   hint: '••••••••',
///   isPassword: true,
///   controller: _passCtrl,
///   errorText: _errors['password'],
/// )
/// ```
///
/// Example — bio with counter:
/// ```dart
/// AppTextField(
///   label: 'Biographie',
///   hint: 'Parlez-nous de vous…',
///   maxLength: 200,
///   maxLines: 4,
///   controller: _bioCtrl,
/// )
/// ```
class AppTextField extends StatefulWidget {
  const AppTextField({
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.inputFormatters,
    this.leadingIcon,
    this.trailingIcon,
    this.onTrailingIconTap,
    this.isPassword = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.fillColor,
    super.key,
  });

  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;

  /// Icon shown at the start of the field.
  final IconData? leadingIcon;

  /// Icon shown at the end of the field (ignored when [isPassword] is true —
  /// the visibility toggle takes that slot).
  final IconData? trailingIcon;
  final VoidCallback? onTrailingIconTap;

  /// When `true`, text is obscured and a visibility toggle is shown.
  final bool isPassword;

  /// Maximum character count; shows a counter below the field when set.
  final int? maxLength;

  final int maxLines;
  final int? minLines;

  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  /// Override the field background (defaults to [AppColors.surface]).
  final Color? fillColor;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _hasFocus = false;
  bool _obscured = true;
  int _charCount = 0;

  bool get _isOwningController => widget.controller == null;
  bool get _isOwningFocusNode => widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();

    _charCount = _controller.text.length;
    _controller.addListener(_onTextChange);
    _focusNode.addListener(_onFocusChange);
  }

  void _onTextChange() {
    if (mounted) setState(() => _charCount = _controller.text.length);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChange);
    _focusNode.removeListener(_onFocusChange);
    if (_isOwningController) _controller.dispose();
    if (_isOwningFocusNode) _focusNode.dispose();
    super.dispose();
  }

  // ── Derived state ──────────────────────────────────────────────────────────

  bool get _hasError => widget.errorText != null && widget.errorText!.isNotEmpty;

  Color get _borderColor {
    if (!widget.enabled) return AppColors.border;
    if (_hasError) return AppColors.danger;
    if (_hasFocus) return AppColors.primary;
    return AppColors.border;
  }

  Color get _labelColor {
    if (_hasError) return AppColors.danger;
    if (_hasFocus) return AppColors.primary;
    return AppColors.textSecondary;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTextStyles.labelMedium.copyWith(color: _labelColor),
          ),
          const SizedBox(height: 6),
        ],

        // Field
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: widget.enabled
                ? (widget.fillColor ?? AppColors.surface)
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1.5),
            boxShadow: _hasFocus && !_hasError
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(30),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            obscureText: widget.isPassword && _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onTap: widget.onTap,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            maxLines: widget.isPassword ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            buildCounter: (_,
                    {required currentLength,
                    required isFocused,
                    required maxLength}) =>
                null, // We draw our own counter below
            inputFormatters: widget.inputFormatters,
            textCapitalization: widget.textCapitalization,
            style: AppTextStyles.bodyMedium,
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary.withAlpha(150)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: widget.maxLines > 1 ? 12 : 0,
              ),
              prefixIcon: widget.leadingIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        widget.leadingIcon,
                        size: 20,
                        color: _hasFocus
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    )
                  : null,
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: _buildSuffixIcon(),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              isCollapsed: widget.maxLines == 1,
            ),
          ),
        ),

        // Bottom row: error/helper + character counter
        if (_hasError || widget.helperText != null || widget.maxLength != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
            child: Row(
              children: [
                // Error or helper
                Expanded(
                  child: _hasError
                      ? Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 13, color: AppColors.danger),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.errorText!,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.danger),
                              ),
                            ),
                          ],
                        )
                      : widget.helperText != null
                          ? Text(
                              widget.helperText!,
                              style: AppTextStyles.bodySmall,
                            )
                          : const SizedBox.shrink(),
                ),

                // Character counter
                if (widget.maxLength != null)
                  Text(
                    '$_charCount / ${widget.maxLength}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _charCount > widget.maxLength!
                          ? AppColors.danger
                          : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.isPassword) {
      return GestureDetector(
        onTap: () => setState(() => _obscured = !_obscured),
        child: Padding(
          padding: const EdgeInsets.only(right: 12, left: 8),
          child: Icon(
            _obscured
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    if (widget.trailingIcon != null) {
      return GestureDetector(
        onTap: widget.onTrailingIconTap,
        child: Padding(
          padding: const EdgeInsets.only(right: 12, left: 8),
          child: Icon(
            widget.trailingIcon,
            size: 20,
            color: _hasFocus ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      );
    }

    // Show a clear button when field has text and is focused
    if (_hasFocus && _charCount > 0 && !widget.readOnly) {
      return GestureDetector(
        onTap: () {
          _controller.clear();
          widget.onChanged?.call('');
        },
        child: const Padding(
          padding: EdgeInsets.only(right: 10, left: 6),
          child: Icon(
            Icons.cancel_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return null;
  }
}
