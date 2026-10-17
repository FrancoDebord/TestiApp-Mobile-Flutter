import 'package:flutter/material.dart';
import '../services/social_auth_service.dart' show googleSignInErrorMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/api_service.dart' show LaravelApiException;
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_logo.dart';
import '../providers/auth_notifier.dart';
import '../widgets/auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'phone_auth_screen.dart';
import '../../../l10n/app_localizations.dart';

// =============================================================================
// CONNEXION / INSCRIPTION (maquette, écran 3)
// =============================================================================
// Vue d'accueil (colonne centrée, défilante) :
//   1. Logo « Témoignages de Gloire » + « Rejoignez une communauté… »
//   2. « Se connecter avec numéro »  — bleu, icône téléphone → OTP SMS
//   3. « Se connecter avec Google »  — contour, logo G
//   4. « Se connecter avec Email »   — contour, icône enveloppe → sous-vue
//      e-mail / mot de passe (+ mot de passe oublié)
//   5. (Lien « Continuer avec Facebook » désactivé)
//   6. « Ou continuer sans compte » puis « Mode invité » (jaune, texte bleu)
//   7. « Pas encore de compte ? S'inscrire »
//
// La redirection vers /home après connexion est gérée par le routeur
// (changement de l'état d'authentification). Le mode invité est persisté
// par AuthNotifier.continueAsGuest().
// =============================================================================

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  /// Connexion Google en cours (indicateur sur le bouton Google).
  bool _googleLoading = false;
  bool _showEmailForm = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────────────────────────

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.authValidateEmail;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) return context.l10n.authInvalidEmail;
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.authValidatePwd;
    }
    if (value.length < 8) {
      return context.l10n.authPwdMin8;
    }
    return null;
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authStateProvider.notifier).loginWithEmail(
            email:    _emailController.text.trim(),
            password: _passwordController.text,
          );
      // La redirection vers /home est gérée par le router (auth state change)
    } catch (e) {
      if (mounted) {
        final msg = e is LaravelApiException
            ? e.displayMessage
            : e.toString().contains('): ')
                ? e.toString().substring(e.toString().indexOf('): ') + 3)
                : e.toString();
        setState(() => _errorMessage = msg.isNotEmpty
            ? msg
            : context.l10n.authWrongCredentials);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Connexion Google : bouton désactivé avec indicateur pendant l'opération ; annulation
  /// silencieuse ; erreur Google ou API (401, 5xx…) → SnackBar. La redirection après
  /// connexion est faite par le routeur (changement de l'état d'authentification).
  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _googleLoading = true; _errorMessage = null; });
    try {
      await ref.read(authStateProvider.notifier).signInWithGoogle();
    } catch (e, stack) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(googleSignInErrorMessage(e, stack)),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; _googleLoading = false; });
    }
  }

  // Connexion Facebook désactivée (retirée de l'application) : à réactiver si besoin.
  // Future<void> _signInWithFacebook() async {
  //   setState(() { _isLoading = true; _errorMessage = null; });
  //   try {
  //     await ref.read(authStateProvider.notifier).signInWithFacebook();
  //   } catch (e) {
  //     if (mounted) setState(() => _errorMessage = e.toString());
  //   } finally {
  //     if (mounted) setState(() => _isLoading = false);
  //   }
  // }

  /// Connexion par numéro : flux OTP SMS (PhoneAuthScreen).
  void _openPhoneAuth() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PhoneAuthScreen()),
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  Future<void> _continueAsGuest() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authStateProvider.notifier).continueAsGuest();
      if (mounted) context.goNamed(AppRoutes.home);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Retour système dans la sous-vue e-mail : revenir aux choix.
      canPop: !_showEmailForm,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showEmailForm) {
          setState(() => _showEmailForm = false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.xl * 2),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _showEmailForm
                          ? _buildEmailForm()
                          : _buildChoices(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    final message = _errorMessage;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AuthErrorBanner(message: message),
    );
  }

  Widget _buildChoices() {
    final isLoading = _isLoading;
    return Column(
      key: const ValueKey('login-choices'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AppLogo(markSize: 90, titleSize: 30)),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.l10n.authJoinTagline,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        _errorBanner(),
        AppButton(
          label: context.l10n.authSignInWithPhone,
          leadingIcon: Icons.phone_rounded,
          fullWidth: true,
          onPressed: isLoading ? null : _openPhoneAuth,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: context.l10n.authSignInWithGoogle,
          variant: AppButtonVariant.outline,
          leading: const GoogleGMark(size: 20),
          fullWidth: true,
          isLoading: _googleLoading,
          onPressed: isLoading ? null : _signInWithGoogle,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: context.l10n.authSignInWithEmail,
          variant: AppButtonVariant.outline,
          leadingIcon: Icons.mail_outline_rounded,
          fullWidth: true,
          onPressed: isLoading
              ? null
              : () => setState(() {
                    _showEmailForm = true;
                    _errorMessage = null;
                  }),
        ),
        // Connexion Facebook désactivée (retirée de l'application) : à réactiver si besoin.
        // const SizedBox(height: AppSpacing.xs),
        // Center(
        //   child: TextButton.icon(
        //     onPressed: isLoading ? null : _signInWithFacebook,
        //     icon: const Icon(Icons.facebook_rounded,
        //         size: 18, color: AppColors.primary),
        //     label: Text(
        //       'Continuer avec Facebook',
        //       style: AppTextStyles.labelSmall.copyWith(
        //           color: AppColors.primary, fontWeight: FontWeight.w600),
        //     ),
        //   ),
        // ),
        const SizedBox(height: AppSpacing.md),
        AuthOrDivider(label: context.l10n.authOrContinueWithoutAccount),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: context.l10n.authGuestMode,
          variant: AppButtonVariant.accent,
          leadingIcon: Icons.explore_outlined,
          fullWidth: true,
          onPressed: isLoading ? null : _continueAsGuest,
        ),
        const SizedBox(height: AppSpacing.xl),
        _RegisterLink(
          onTap: isLoading ? null : () => context.goNamed(AppRoutes.register),
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    final isLoading = _isLoading;
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('login-email'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthScreenHeader(
            title: context.l10n.authEmailSignInTitle,
            subtitle: context.l10n.authSignInSubtitle,
            onBack: isLoading
                ? null
                : () => setState(() {
                      _showEmailForm = false;
                      _errorMessage = null;
                    }),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _errorBanner(),
          AuthTextField(
            controller: _emailController,
            label: context.l10n.authEmailLabel,
            hint: context.l10n.authEmailHint,
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validateEmail,
            enabled: !isLoading,
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthTextField(
            controller: _passwordController,
            label: context.l10n.authPasswordLabel,
            hint: '••••••••',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            validator: _validatePassword,
            enabled: !isLoading,
            suffixIcon: IconButton(
              tooltip: _obscurePassword
                  ? context.l10n.authShowPassword
                  : context.l10n.authHidePassword,
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : _openForgotPassword,
              child: Text(
                context.l10n.authForgotPassword,
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: context.l10n.authSignIn,
            fullWidth: true,
            isLoading: isLoading && !_googleLoading,
            onPressed: isLoading ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthOrDivider(label: context.l10n.authOr),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: context.l10n.authContinueWithGoogle,
            variant: AppButtonVariant.outline,
            leading: const GoogleGMark(size: 20),
            fullWidth: true,
            isLoading: _googleLoading,
            onPressed: isLoading ? null : _signInWithGoogle,
          ),
          const SizedBox(height: AppSpacing.xl),
          _RegisterLink(
            onTap:
                isLoading ? null : () => context.goNamed(AppRoutes.register),
          ),
        ],
      ),
    );
  }
}

// ── « Pas encore de compte ? S'inscrire » ────────────────────────────────────

class _RegisterLink extends StatelessWidget {
  const _RegisterLink({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${context.l10n.authNoAccount} ',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Text(
              context.l10n.authSignUp,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.secondary, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
