import '../../../core/data/countries.dart';
import '../../../shared/widgets/country_picker.dart';
import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_notifier.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/profile/providers/profile_provider.dart'
    show profileExtrasProvider;
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart' show LaravelApiException;
import '../../../shared/models/user_model.dart'
    show AccountType, OrganizationType;
import '../../../shared/widgets/app_button.dart';
import '../widgets/auth_widgets.dart';

// =============================================================================
// REGISTER SCREEN
// =============================================================================
// Layout (top → bottom, scrollable):
//   1. Purple wave header  — logo + "Créer un compte" title
//   2. White card body     — rounded top corners (28 px)
//      0. Choix du type de compte — « Je suis une personne » /
//         « Je représente une organisation » (grandes cartes).
//         Organisation : Nom, Type, Ville, Site web (optionnel) remplacent
//         Prénom / Nom ; l'avatar devient « Logo » ; note de vérification.
//      a. Avatar picker    — centered circle, gold camera FAB overlay (optional)
//      b. Two-col row      — Prénom | Nom
//      c. Email field
//      d. Pays dropdown    — African + diaspora countries
//      e. Mot de passe     — show/hide toggle, 4-segment strength bar
//      f. Confirmer MDP    — must match password
//      g. Terms checkbox   — CGU + Politique de confidentialité
//      h. S'inscrire       — full-width FilledButton, loading state
//      i. Login link       — "Déjà inscrit ? Se connecter"
//
// Validation (triggered per-field on submit + onFieldSubmitted):
//   Prénom / Nom  : non-empty, min 2 chars
//   Email         : RFC pattern
//   Pays          : must select a value
//   Mot de passe  : min 8 chars, 1 uppercase, 1 digit
//   Confirmer     : must equal password
//   Terms         : must be checked before submit
// =============================================================================

// ── Screen-local providers ────────────────────────────────────────────────────

// ── Countries list ────────────────────────────────────────────────────────────

// Pays : liste partagée avec le site (lib/core/data/countries.dart).

// ── Screen ────────────────────────────────────────────────────────────────────

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _orgCityController = TextEditingController();
  final _orgWebsiteController = TextEditingController();
  final _phoneController = TextEditingController();

  AccountType _accountType = AccountType.individual;
  OrganizationType? _orgType;
  Country? _country;
  /// Indicatif du téléphone : suit le pays choisi, reste modifiable.
  Country? _phoneDial;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  int _passwordStrength = 0;
  bool _isLoading = false;
  String? _errorMessage;

  /// Photo de profil / logo choisi (envoyé après la création du compte).
  String? _avatarPath;

  // ── Photo / logo ──────────────────────────────────────────────────────────

  /// Même sélecteur que l'écran « Modifier le profil » (galerie / caméra).
  Future<void> _pickAvatar() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(Icons.photo_library_rounded,
                      color: AppColors.primary)),
              title: Text(l10n.editGallery,
                  style: const TextStyle(fontFamily: AppFonts.family)),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(Icons.camera_alt_rounded,
                      color: AppColors.primary)),
              title: Text(l10n.editCamera,
                  style: const TextStyle(fontFamily: AppFonts.family)),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            if (_avatarPath != null)
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: AppColors.dangerSoft,
                    child: Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger)),
                title: const Text('Retirer',
                    style: TextStyle(fontFamily: AppFonts.family)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _avatarPath = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(
        source: source, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (file != null && mounted) {
      setState(() => _avatarPath = file.path);
    }
  }

  /// Envoi de la photo / du logo après l'inscription. Un échec ne bloque pas
  /// l'inscription : simple message, l'image pourra être ajoutée plus tard.
  /// [container] et [messenger] sont capturés avant l'inscription car l'écran
  /// peut être fermé par la redirection du router entre-temps.
  static Future<void> _uploadAvatarAfterSignUp(
    String path,
    ProviderContainer container,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      await container.read(profileExtrasProvider.notifier).uploadAvatar(path);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            "Logo non envoyé, vous pourrez l'ajouter depuis votre profil"),
        behavior: SnackBarBehavior.floating,
      ));
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _orgNameController.dispose();
    _orgCityController.dispose();
    _orgWebsiteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Password strength ───────────────────────────────────────────────────────

  void _onPasswordChanged(String value) {
    int score = 0;
    if (value.length >= 8) score++;
    if (value.contains(RegExp(r'[A-Z]'))) score++;
    if (value.contains(RegExp(r'[0-9]'))) score++;
    if (value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score++;
    setState(() => _passwordStrength = score);
  }

  // ── Validators ──────────────────────────────────────────────────────────────

  String? _validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez saisir votre $fieldName';
    }
    if (value.trim().length < 2) {
      return 'Le $fieldName doit contenir au moins 2 caractères';
    }
    return null;
  }

  String? _validateRequired(String? value, String message) {
    if (value == null || value.trim().length < 2) return message;
    return null;
  }

  String? _validateWebsite(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // optionnel
    final uri = Uri.tryParse(v.contains('://') ? v : 'https://$v');
    final ok = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.') &&
        !v.contains(' ');
    return ok ? null : 'Adresse du site web invalide';
  }

  static String? _normalizeWebsite(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    return v.contains('://') ? v : 'https://$v';
  }

  bool get _isOrg => _accountType == AccountType.organization;

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez saisir votre adresse e-mail';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Adresse e-mail invalide';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Veuillez saisir un mot de passe';
    if (value.length < 8) return 'Minimum 8 caractères';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Au moins une majuscule requise';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Au moins un chiffre requis';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer votre mot de passe';
    }
    if (value != _passwordController.text) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_country == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner votre pays');
      return;
    }

    if (!_acceptedTerms) {
      setState(() =>
          _errorMessage = 'Vous devez accepter les CGU pour continuer');
      return;
    }

    setState(() => _isLoading = true);
    final avatarPath = _avatarPath;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final notifier = ref.read(authStateProvider.notifier);
      if (_isOrg) {
        await notifier.register(
          firstName: '',
          lastName:  '',
          email:     _emailController.text.trim(),
          password:  _passwordController.text,
          country:   _country!.name,
          phoneCountry: _phoneDial?.code,
          phone:        _phoneController.text.trim(),
          accountType:         AccountType.organization,
          organizationName:    _orgNameController.text.trim(),
          organizationType:    _orgType,
          organizationCity:    _orgCityController.text.trim(),
          organizationWebsite: _normalizeWebsite(_orgWebsiteController.text),
        );
      } else {
        await notifier.register(
          firstName: _firstNameController.text.trim(),
          lastName:  _lastNameController.text.trim(),
          email:     _emailController.text.trim(),
          password:  _passwordController.text,
          country:   _country!.name,
          phoneCountry: _phoneDial?.code,
          phone:        _phoneController.text.trim(),
        );
      }
      // La redirection vers /home est gérée par le router (auth state change)
      if (avatarPath != null &&
          container.read(authStateProvider).value is AuthStateAuthenticated) {
        unawaited(_uploadAvatarAfterSignUp(avatarPath, container, messenger));
      }
    } catch (e) {
      if (mounted) {
        final msg = e is LaravelApiException
            ? e.displayMessage
            : e.toString().contains('): ')
                ? e.toString().substring(e.toString().indexOf('): ') + 3)
                : e.toString();
        setState(() => _errorMessage = msg.isNotEmpty
            ? msg
            : 'Impossible de créer le compte. Vérifiez vos informations.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isLoading;
    final errorMessage = _errorMessage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl, 0, AppSpacing.xxl, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthScreenHeader(
                        title: 'Créer un compte',
                        subtitle: 'Rejoignez une communauté qui partage la '
                            'gloire de Dieu.',
                        onBack: () => context.canPop()
                            ? context.pop()
                            : context.goNamed(AppRoutes.login),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      // Choix du type de compte.
                      _AccountTypeSelector(
                        value: _accountType,
                        enabled: !isLoading,
                        onChanged: (t) => setState(() {
                          _accountType = t;
                          _errorMessage = null;
                        }),
                      ),

                      const SizedBox(height: 24),

                      // Avatar / logo picker.
                      _AvatarPicker(
                        isOrganization: _isOrg,
                        imagePath: _avatarPath,
                        onPick: isLoading ? null : _pickAvatar,
                      ),

                      const SizedBox(height: 24),

                      if (errorMessage != null) ...[
                        AuthErrorBanner(message: errorMessage),
                        const SizedBox(height: 20),
                      ],

                      if (_isOrg) ...[
                        const _VerificationNote(),
                        const SizedBox(height: 20),
                        AuthTextField(
                          controller: _orgNameController,
                          label: "Nom de l'organisation",
                          hint: 'Église de la Grâce',
                          prefixIcon: Icons.church_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (v) => _validateRequired(
                              v, "Veuillez saisir le nom de l'organisation"),
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),
                        _OrganizationTypeDropdown(
                          value: _orgType,
                          enabled: !isLoading,
                          onChanged: (v) => setState(() => _orgType = v),
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _orgCityController,
                          label: 'Ville',
                          hint: 'Cotonou',
                          prefixIcon: Icons.location_city_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              _validateRequired(v, 'Veuillez saisir la ville'),
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _orgWebsiteController,
                          label: 'Site web (optionnel)',
                          hint: 'www.exemple.org',
                          prefixIcon: Icons.language_rounded,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          validator: _validateWebsite,
                          enabled: !isLoading,
                        ),
                      ] else
                      // Prénom + Nom.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AuthTextField(
                              controller: _firstNameController,
                              label: 'Prénom',
                              hint: 'Jean',
                              prefixIcon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next,
                              validator: (v) => _validateName(v, 'prénom'),
                              enabled: !isLoading,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AuthTextField(
                              controller: _lastNameController,
                              label: 'Nom',
                              hint: 'Dupont',
                              prefixIcon: Icons.badge_outlined,
                              textInputAction: TextInputAction.next,
                              validator: (v) => _validateName(v, 'nom'),
                              enabled: !isLoading,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Email.
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

                      const SizedBox(height: 16),

                      // Pays dropdown.
                      CountryPickerField(
                        initialValue: _country,
                        enabled: !isLoading,
                        onChanged: (c) => setState(() {
                          _country = c;
                          if (c != null) _phoneDial = c; // l'indicatif suit le pays
                        }),
                      ),

                      const SizedBox(height: 16),

                      // Téléphone : obligatoire pour une organisation (vérification du compte).
                      PhoneNumberField(
                        dial: _phoneDial,
                        onDialChanged: (c) => setState(() => _phoneDial = c),
                        controller: _phoneController,
                        required: _isOrg,
                        requiredNote: _isOrg ? null : '(facultatif)',
                        enabled: !isLoading,
                      ),

                      const SizedBox(height: 16),

                      // Password.
                      AuthTextField(
                        controller: _passwordController,
                        label: 'Mot de passe',
                        hint: '••••••••',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        validator: _validatePassword,
                        enabled: !isLoading,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        onFieldSubmitted: (v) => _onPasswordChanged(v),
                      ),

                      // Strength bar — shown only once user starts typing.
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _PasswordStrengthBar(strength: _passwordStrength),
                      ],

                      const SizedBox(height: 16),

                      // Confirm password.
                      AuthTextField(
                        controller: _confirmController,
                        label: 'Confirmer le mot de passe',
                        hint: '••••••••',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        validator: _validateConfirm,
                        enabled: !isLoading,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                      ),

                      const SizedBox(height: 20),

                      // Terms checkbox.
                      _TermsCheckbox(
                        checked: _acceptedTerms,
                        onChanged: (v) =>
                            setState(() => _acceptedTerms = v ?? false),
                      ),

                      const SizedBox(height: 24),

                      // S'inscrire.
                      AuthPrimaryButton(
                        label: "S'inscrire",
                        isLoading: isLoading,
                        onPressed: isLoading ? null : _submit,
                      ),

                      const SizedBox(height: 20),

                      // Divider "ou".
                      const AuthOrDivider(),

                      const SizedBox(height: 16),

                      // Google sign-in.
                      AppButton(
                        label: 'Continuer avec Google',
                        variant: AppButtonVariant.outline,
                        leading: const GoogleGMark(size: 20),
                        fullWidth: true,
                        onPressed: isLoading ? null : _signInWithGoogle,
                      ),

                      const SizedBox(height: 28),

                      // Login link.
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Déjà inscrit ? ',
                            style: TextStyle(
                              fontFamily: AppFonts.family,
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.goNamed(AppRoutes.login),
                            child: const Text(
                              'Se connecter',
                              style: TextStyle(
                                fontFamily: AppFonts.family,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ),
        ),
      ),
    );
  }
}

// ── Avatar picker ─────────────────────────────────────────────────────────────

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    this.isOrganization = false,
    this.imagePath,
    this.onPick,
  });

  /// En mode organisation, le même sélecteur sert de « Logo ».
  final bool isOrganization;

  /// Image choisie (chemin local, ou URL blob sur le web).
  final String? imagePath;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final icon =
        isOrganization ? Icons.church_rounded : Icons.person_rounded;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: isOrganization
                ? "Choisir le logo de l'organisation"
                : 'Choisir une photo de profil',
            child: GestureDetector(onTap: onPick, child: _buildCircle(icon)),
          ),
          const SizedBox(height: 6),
          Text(
            isOrganization ? 'Logo' : 'Photo de profil',
            style: const TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircle(IconData icon) {
    final path = imagePath;
    final ImageProvider? image = path == null
        ? null
        : kIsWeb
            ? NetworkImage(path)
            : FileImage(File(path));
    return Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primarySoft,
              border: Border.all(
                  color: AppColors.primary.withAlpha(60), width: 2),
              image: image == null
                  ? null
                  : DecorationImage(image: image, fit: BoxFit.cover),
            ),
            child: image == null
                ? Icon(icon, size: 48, color: AppColors.primary)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                  image == null ? Icons.camera_alt_rounded : Icons.edit_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
    );
  }
}

// ── Account type selector ─────────────────────────────────────────────────────

class _AccountTypeSelector extends StatelessWidget {
  const _AccountTypeSelector({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final AccountType value;
  final ValueChanged<AccountType> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Type de compte',
          style: TextStyle(
            fontFamily: AppFonts.family,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _AccountTypeCard(
          icon: Icons.person_rounded,
          title: 'Je suis une personne',
          subtitle: 'Partagez vos témoignages personnels',
          selected: value == AccountType.individual,
          onTap: enabled ? () => onChanged(AccountType.individual) : null,
        ),
        const SizedBox(height: 10),
        _AccountTypeCard(
          icon: Icons.church_rounded,
          title: 'Je représente une organisation',
          subtitle: 'Église, ministère, association…',
          selected: value == AccountType.organization,
          onTap: enabled ? () => onChanged(AccountType.organization) : null,
        ),
      ],
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  static const _purple = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _purple : AppColors.border,
                width: selected ? 2 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? _purple : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon,
                      size: 26, color: selected ? Colors.white : _purple),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? _purple : AppColors.inputBorder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Verification note ─────────────────────────────────────────────────────────

class _VerificationNote extends StatelessWidget {
  const _VerificationNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Votre organisation sera vérifiée par notre équipe. Le badge '
              'vérifié apparaîtra ensuite sur votre profil et vos témoignages.',
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 13,
                height: 1.4,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Organisation type dropdown ────────────────────────────────────────────────

class _OrganizationTypeDropdown extends StatelessWidget {
  const _OrganizationTypeDropdown({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final OrganizationType? value;
  final ValueChanged<OrganizationType?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Type d'organisation",
          style: TextStyle(
            fontFamily: AppFonts.family,
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<OrganizationType>(
          initialValue: value,
          hint: const Text(
            'Sélectionnez le type',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          onChanged: enabled ? onChanged : null,
          validator: (v) => v == null ? 'Veuillez choisir un type' : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          style: const TextStyle(
            fontFamily: AppFonts.family,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          decoration: countryFieldDecoration(prefix: Icons.category_outlined),
          items: OrganizationType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
              .toList(),
        ),
      ],
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.strength});

  final int strength; // 0–4

  static const _labels = [
    'Très faible', 'Faible', 'Moyen', 'Fort', 'Très fort'
  ];
  static const _colors = [
    AppColors.danger,
    AppColors.secondary,
    AppColors.secondary,
    AppColors.success,
    AppColors.success,
  ];

  @override
  Widget build(BuildContext context) {
    final idx = strength.clamp(0, 4);
    final color = _colors[idx];
    final label = _labels[idx];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength ? color : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.family,
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Terms checkbox ────────────────────────────────────────────────────────────

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.checked,
    required this.onChanged,
  });

  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: checked,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: const BorderSide(color: AppColors.border, width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              children: [
                TextSpan(text: "J'accepte les "),
                TextSpan(
                  text: "Conditions Générales d'Utilisation",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(text: ' et la '),
                TextSpan(
                  text: 'Politique de confidentialité',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
