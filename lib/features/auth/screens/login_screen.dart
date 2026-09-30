import 'package:flutter/material.dart';
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

// =============================================================================
// CONNEXION / INSCRIPTION (maquette, écran 3)
// =============================================================================
// Vue d'accueil (colonne centrée, défilante) :
//   1. Logo « Témoignages de Gloire » + « Rejoignez une communauté… »
//   2. « Se connecter avec numéro »  — bleu, icône téléphone → OTP SMS
//   3. « Se connecter avec Google »  — contour, logo G
//   4. « Se connecter avec Email »   — contour, icône enveloppe → sous-vue
//      e-mail / mot de passe (+ mot de passe oublié)
//   5. Lien discret « Continuer avec Facebook »
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
      return 'Veuillez saisir votre adresse e-mail';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Adresse e-mail invalide';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez saisir votre mot de passe';
    }
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
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
            : 'Identifiants incorrects. Vérifiez votre e-mail et mot de passe.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authStateProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithFacebook() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authStateProvider.notifier).signInWithFacebook();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
          'Rejoignez une communauté qui partage la gloire de Dieu.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        _errorBanner(),
        AppButton(
          label: 'Se connecter avec numéro',
          leadingIcon: Icons.phone_rounded,
          fullWidth: true,
          onPressed: isLoading ? null : _openPhoneAuth,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Se connecter avec Google',
          variant: AppButtonVariant.outline,
          leading: const GoogleGMark(size: 20),
          fullWidth: true,
          onPressed: isLoading ? null : _signInWithGoogle,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Se connecter avec Email',
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
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: TextButton.icon(
            onPressed: isLoading ? null : _signInWithFacebook,
            icon: const Icon(Icons.facebook_rounded,
                size: 18, color: AppColors.primary),
            label: Text(
              'Continuer avec Facebook',
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AuthOrDivider(label: 'Ou continuer sans compte'),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Mode invité',
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
            title: 'Connexion par e-mail',
            subtitle: 'Connectez-vous à votre compte',
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
            label: 'Adresse e-mail',
            hint: 'exemple@email.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validateEmail,
            enabled: !isLoading,
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthTextField(
            controller: _passwordController,
            label: 'Mot de passe',
            hint: '••••••••',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            validator: _validatePassword,
            enabled: !isLoading,
            suffixIcon: IconButton(
              tooltip: _obscurePassword
                  ? 'Afficher le mot de passe'
                  : 'Masquer le mot de passe',
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
                'Mot de passe oublié ?',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Se connecter',
            fullWidth: true,
            isLoading: isLoading,
            onPressed: isLoading ? null : _submit,
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
        Text('Pas encore de compte ? ',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Text(
              "S'inscrire",
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.secondary, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
