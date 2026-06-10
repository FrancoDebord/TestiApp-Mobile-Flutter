import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_notifier.dart';
import '../../../core/router/app_routes.dart';
import '../../../services/api_service.dart' show LaravelApiException;
import '../widgets/auth_widgets.dart';

// =============================================================================
// REGISTER SCREEN
// =============================================================================
// Layout (top → bottom, scrollable):
//   1. Purple wave header  — logo + "Créer un compte" title
//   2. White card body     — rounded top corners (28 px)
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

const List<String> _countries = [
  'Bénin', 'Burkina Faso', 'Burundi', 'Cameroun', 'Cap-Vert',
  'Comores', 'Congo (Brazzaville)', 'Congo (RDC)', "Côte d'Ivoire",
  'Djibouti', 'Égypte', 'Érythrée', 'Éthiopie', 'Gabon',
  'Gambie', 'Ghana', 'Guinée', 'Guinée-Bissau', 'Guinée équatoriale',
  'Kenya', 'Lesotho', 'Libéria', 'Libye', 'Madagascar',
  'Malawi', 'Mali', 'Maroc', 'Maurice', 'Mauritanie',
  'Mozambique', 'Namibie', 'Niger', 'Nigeria', 'Ouganda',
  'Rwanda', 'São Tomé-et-Príncipe', 'Sénégal', 'Seychelles',
  'Sierra Leone', 'Somalie', 'Soudan', 'Soudan du Sud',
  'Swaziland', 'Tanzanie', 'Tchad', 'Togo', 'Tunisie',
  'Zambie', 'Zimbabwe',
  'France', 'Belgique', 'Canada', 'États-Unis', 'Royaume-Uni',
  'Autre',
];

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

  String? _selectedCountry;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  int _passwordStrength = 0;
  bool _isLoading = false;
  String? _errorMessage;

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

    if (_selectedCountry == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner votre pays');
      return;
    }

    if (!_acceptedTerms) {
      setState(() =>
          _errorMessage = 'Vous devez accepter les CGU pour continuer');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authStateProvider.notifier).register(
            firstName: _firstNameController.text.trim(),
            lastName:  _lastNameController.text.trim(),
            email:     _emailController.text.trim(),
            password:  _passwordController.text,
            country:   _selectedCountry,
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
      backgroundColor: const Color(0xFF6B21A8),
      body: Column(
        children: [
          // ── Purple wave header ─────────────────────────────────────────────
          AuthWaveHeader(
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(26),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withAlpha(77), width: 1.5),
                    ),
                    child: const Center(
                      child: Text(
                        '✝',
                        style: TextStyle(
                            color: Colors.white, fontSize: 24, height: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Créer un compte',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rejoignez la communauté Témoignages',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Colors.white.withAlpha(204),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // ── White scrollable body ──────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Avatar picker.
                      const _AvatarPicker(),

                      const SizedBox(height: 24),

                      if (errorMessage != null) ...[
                        AuthErrorBanner(message: errorMessage),
                        const SizedBox(height: 20),
                      ],

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
                      _CountryDropdown(
                        value: _selectedCountry,
                        enabled: !isLoading,
                        onChanged: (v) => setState(() => _selectedCountry = v),
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
                            color: const Color(0xFF64748B),
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
                            color: const Color(0xFF64748B),
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
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(
                              color: Color(0xFFDB4437), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          backgroundColor:
                              const Color(0xFFDB4437).withAlpha(12),
                          foregroundColor: const Color(0xFFDB4437),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Icon(Icons.g_mobiledata_rounded,
                            size: 22, color: Color(0xFFDB4437)),
                        label: const Text(
                          'Continuer avec Google',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFFDB4437),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Login link.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Déjà inscrit ? ',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.goNamed(AppRoutes.login),
                            child: const Text(
                              'Se connecter',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B21A8),
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
        ],
      ),
    );
  }
}

// ── Avatar picker ─────────────────────────────────────────────────────────────

class _AvatarPicker extends StatefulWidget {
  const _AvatarPicker();

  @override
  State<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<_AvatarPicker> {
  bool _hasAvatar = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEDE9FE),
              border: Border.all(
                  color: const Color(0xFF6B21A8).withAlpha(60), width: 2),
            ),
            child: _hasAvatar
                ? const ClipOval(
                    child: Icon(Icons.person_rounded,
                        size: 48, color: Color(0xFF6B21A8)),
                  )
                : const Icon(Icons.person_rounded,
                    size: 48, color: Color(0xFF6B21A8)),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                // Wire image_picker package here
                setState(() => _hasAvatar = !_hasAvatar);
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Country dropdown ──────────────────────────────────────────────────────────

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  static final _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pays',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          hint: const Text(
            'Sélectionnez votre pays',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFFCBD5E1),
              fontSize: 15,
            ),
          ),
          onChanged: enabled ? onChanged : null,
          validator: (v) =>
              v == null ? 'Veuillez sélectionner votre pays' : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF94A3B8)),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.public_rounded,
                color: Color(0xFF94A3B8), size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: _fieldBorder,
            enabledBorder: _fieldBorder,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF6B21A8), width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.8),
            ),
            errorStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFFEF4444),
            ),
          ),
          items: _countries
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
        ),
      ],
    );
  }
}

// ── Password strength bar ─────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.strength});

  final int strength; // 0–4

  static const _labels = [
    'Très faible', 'Faible', 'Moyen', 'Fort', 'Très fort'
  ];
  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFF16A34A),
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
                  color: i < strength ? color : const Color(0xFFE2E8F0),
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
            fontFamily: 'Inter',
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
            activeColor: const Color(0xFF6B21A8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              children: [
                TextSpan(text: "J'accepte les "),
                TextSpan(
                  text: "Conditions Générales d'Utilisation",
                  style: TextStyle(
                    color: Color(0xFF6B21A8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(text: ' et la '),
                TextSpan(
                  text: 'Politique de confidentialité',
                  style: TextStyle(
                    color: Color(0xFF6B21A8),
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
