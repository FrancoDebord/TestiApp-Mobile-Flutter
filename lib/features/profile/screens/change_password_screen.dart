import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Sécurité : changement du mot de passe (POST /auth/change-password).
/// Un compte créé par téléphone, Google ou Facebook n'a pas de mot de passe :
/// l'écran l'explique au lieu d'afficher le formulaire.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  String? _currentError;
  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    final l10n = context.l10n;
    String? current, next, confirm;
    if (_currentCtrl.text.isEmpty) current = l10n.profilePwdEnterCurrent;
    if (_newCtrl.text.length < AppConstants.minPasswordLength) {
      next = l10n.profilePwdMinLengthError(AppConstants.minPasswordLength);
    } else if (_newCtrl.text == _currentCtrl.text) {
      next = l10n.profilePwdMustDiffer;
    }
    if (_confirmCtrl.text != _newCtrl.text) {
      confirm = l10n.profilePwdMismatch;
    }
    setState(() {
      _currentError = current;
      _newError = next;
      _confirmError = confirm;
      _error = null;
    });
    return current == null && next == null && confirm == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiServiceProvider).post<dynamic>(
        AppConstants.authChangePassword,
        data: {
          'current_password': _currentCtrl.text,
          'new_password': _newCtrl.text,
          'new_password_confirmation': _confirmCtrl.text,
        },
      );
    } on LaravelApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e.statusCode == 403) {
          _currentError = context.l10n.profilePwdCurrentWrong;
        } else {
          _newError = e.fieldError('new_password');
          _error = _newError == null ? e.displayMessage : null;
        }
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.profileServerUnreachable;
      });
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.profilePwdChanged),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasPassword =
        ref.watch(currentUserProvider.select((u) => u?.hasPassword ?? true));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.l10n.profileSecurity,
          style: const TextStyle(
            fontFamily: AppFonts.family,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: hasPassword ? _form() : _noPassword(context),
    );
  }

  Widget _form() {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.profileChangePassword,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.profilePwdOtherDevices,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          AppTextField(
            label: l10n.profilePwdCurrent,
            controller: _currentCtrl,
            isPassword: true,
            errorText: _currentError,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.profilePwdNew,
            helperText: l10n.profilePwdMinLengthHelper(AppConstants.minPasswordLength),
            controller: _newCtrl,
            isPassword: true,
            errorText: _newError,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.profilePwdConfirmNew,
            controller: _confirmCtrl,
            isPassword: true,
            errorText: _confirmError,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 13,
                color: AppColors.danger,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 28),
          AppButton(
            label: l10n.commonSave,
            size: AppButtonSize.large,
            fullWidth: true,
            isLoading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _noPassword(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withAlpha(60),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.profileNoPassword,
              style: const TextStyle(
                fontFamily: AppFonts.family,
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.profileNoPasswordBody,
              style: const TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AppButton(
              label: l10n.commonBack,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
