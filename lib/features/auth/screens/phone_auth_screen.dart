// lib/features/auth/screens/phone_auth_screen.dart
//
// Écran d'authentification par numéro de téléphone + OTP (style WhatsApp).
// 3 étapes gérées dans le même écran :
//   Étape 1 : Saisie du numéro de téléphone avec indicatif pays
//   Étape 2 : Saisie du code OTP (6 chiffres)
//   Étape 3 : Completion du profil (prénom, nom, pays) — nouveaux utilisateurs

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_notifier.dart';

// ── Constantes ─────────────────────────────────────────────────────────────────

const _kPurple = Color(0xFF6B21A8);
const _kGold   = Color(0xFFF59E0B);

// ── Indicatifs pays ─────────────────────────────────────────────────────────────

class _Country {
  const _Country(this.name, this.flag, this.code);
  final String name, flag, code;
}

const _countries = [
  _Country('Bénin',           '🇧🇯', '+229'),
  _Country("Côte d'Ivoire",   '🇨🇮', '+225'),
  _Country('Cameroun',        '🇨🇲', '+237'),
  _Country('Sénégal',         '🇸🇳', '+221'),
  _Country('Mali',            '🇲🇱', '+223'),
  _Country('Burkina Faso',    '🇧🇫', '+226'),
  _Country('Guinée',          '🇬🇳', '+224'),
  _Country('Togo',            '🇹🇬', '+228'),
  _Country('RDC',             '🇨🇩', '+243'),
  _Country('Congo',           '🇨🇬', '+242'),
  _Country('Gabon',           '🇬🇦', '+241'),
  _Country('Nigeria',         '🇳🇬', '+234'),
  _Country('Ghana',           '🇬🇭', '+233'),
  _Country('Rwanda',          '🇷🇼', '+250'),
  _Country('Kenya',           '🇰🇪', '+254'),
  _Country('Éthiopie',        '🇪🇹', '+251'),
  _Country('Madagascar',      '🇲🇬', '+261'),
  _Country('France',          '🇫🇷', '+33'),
  _Country('Belgique',        '🇧🇪', '+32'),
  _Country('Canada',          '🇨🇦', '+1'),
  _Country('États-Unis',      '🇺🇸', '+1'),
  _Country('Autre',           '🌍', '+'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneCtrl = TextEditingController();
  _Country _selectedCountry = _countries.first;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _fullPhone =>
      '${_selectedCountry.code}${_phoneCtrl.text.replaceAll(' ', '')}';

  Future<void> _sendOtp() async {
    final number = _phoneCtrl.text.trim();
    if (number.isEmpty) {
      setState(() => _error = 'Entrez votre numéro de téléphone');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await ref.read(authStateProvider.notifier).sendOtp(phoneNumber: _fullPhone);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écouter le changement d'état pour naviguer vers OTP
    ref.listen(authStateProvider, (prev, next) {
      final state = next.value;
      if (state is AuthStateOtpSent) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _OtpScreen(
              phoneNumber: state.phoneNumber,
              verificationId: state.verificationId,
              resendToken: state.resendToken,
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: _kPurple,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(77), width: 1.5),
                      ),
                      child: const Center(
                        child: Text('✝', style: TextStyle(color: Colors.white, fontSize: 32)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Témoignages',
                      style: TextStyle(
                        fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                        fontSize: 28, color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Partagez les œuvres de Dieu',
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 14,
                        color: Colors.white.withAlpha(204),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Card blanche ──────────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Entrez votre numéro',
                      style: TextStyle(
                        fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                        fontSize: 20, color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nous vous enverrons un code de vérification par SMS.',
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 14,
                        color: Colors.grey.shade600, height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.danger.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Sélecteur pays + numéro ──────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          // Indicatif
                          GestureDetector(
                            onTap: _showCountryPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: const BoxDecoration(
                                border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              child: Row(
                                children: [
                                  Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedCountry.code,
                                    style: const TextStyle(
                                      fontFamily: 'Inter', fontWeight: FontWeight.w600,
                                      fontSize: 15, color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 20, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                          // Numéro
                          Expanded(
                            child: TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              enabled: !_isLoading,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 16),
                              decoration: const InputDecoration(
                                hintText: '07 12 34 56 78',
                                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 14),
                              ),
                              onSubmitted: (_) => _sendOtp(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Bouton Continuer ──────────────────────────────────────
                    FilledButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPurple,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Continuer', style: TextStyle(
                              fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                              fontSize: 16, color: Colors.white)),
                    ),

                    const SizedBox(height: 24),
                    const _OrDivider(),
                    const SizedBox(height: 20),

                    // ── Social ────────────────────────────────────────────────
                    Row(children: [
                      Expanded(child: _SocialBtn(
                        label: 'Google', color: const Color(0xFFDB4437),
                        icon: Icons.g_mobiledata_rounded,
                        onPressed: _isLoading ? null : () =>
                            ref.read(authStateProvider.notifier).signInWithGoogle(),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _SocialBtn(
                        label: 'Facebook', color: const Color(0xFF1877F2),
                        icon: Icons.facebook_rounded,
                        onPressed: _isLoading ? null : () =>
                            ref.read(authStateProvider.notifier).signInWithFacebook(),
                      )),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Choisir un pays', style: TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _countries.length,
                itemBuilder: (_, i) {
                  final c = _countries[i];
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(c.name, style: const TextStyle(fontFamily: 'Inter')),
                    trailing: Text(c.code, style: const TextStyle(
                        color: Color(0xFF6B21A8), fontWeight: FontWeight.w600)),
                    onTap: () {
                      setState(() => _selectedCountry = c);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Écran OTP ──────────────────────────────────────────────────────────────────

class _OtpScreen extends ConsumerStatefulWidget {
  const _OtpScreen({
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  final String phoneNumber;
  final String verificationId;
  final int? resendToken;

  @override
  ConsumerState<_OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<_OtpScreen> {
  static const _cellCount = 6;
  static const _countdown = 60;

  final _controllers = List.generate(_cellCount, (_) => TextEditingController());
  final _focusNodes  = List.generate(_cellCount, (_) => FocusNode());

  bool _isLoading = false;
  String? _error;
  int _secondsLeft = _countdown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Listen for auto-verification
    ref.listenManual(authStateProvider, (_, next) {
      _handleAuthState(next.value);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _countdown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft <= 0) { t.cancel(); return; }
      setState(() => _secondsLeft--);
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _isComplete => _otp.length == _cellCount;

  void _handleAuthState(AuthState? state) {
    if (state is AuthStateAuthenticated) {
      // Connecté — GoRouter redirige automatiquement vers /home
    } else if (state is AuthStateNeedsProfile) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => _ProfileScreen(
          firebaseToken: state.firebaseToken,
          phoneNumber: state.phoneNumber,
        )),
      );
    }
  }

  Future<void> _verify() async {
    if (!_isComplete) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      await ref.read(authStateProvider.notifier).verifyOtp(
        verificationId: widget.verificationId,
        otp: _otp,
        phoneNumber: widget.phoneNumber,
      );
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Code incorrect. Réessayez.'; _isLoading = false; });
        for (final c in _controllers) { c.clear(); }
        _focusNodes.first.requestFocus();
      }
    }
  }

  Future<void> _resend() async {
    await ref.read(authStateProvider.notifier).resendOtp(
      phoneNumber: widget.phoneNumber,
      resendToken: widget.resendToken,
    );
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPurple,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // Header
          const Expanded(
            child: Center(
              child: Text('Vérification', style: TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                fontSize: 26, color: Colors.white,
              )),
            ),
          ),

          // Card
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Code envoyé au ${widget.phoneNumber}',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
                        color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withAlpha(80)),
                      ),
                      child: Text(_error!, textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // OTP cells
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_cellCount, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: SizedBox(
                        width: 46, height: 56,
                        child: KeyboardListener(
                          focusNode: FocusNode(),
                          onKeyEvent: (event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.backspace &&
                                _controllers[i].text.isEmpty && i > 0) {
                              _focusNodes[i - 1].requestFocus();
                              _controllers[i - 1].clear();
                            }
                          },
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            enabled: !_isLoading,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(
                              fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                              fontSize: 22, color: Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _kPurple, width: 2),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) {
                              if (v.isNotEmpty && i < _cellCount - 1) {
                                _focusNodes[i + 1].requestFocus();
                              }
                              setState(() {});
                              if (_isComplete) _verify();
                            },
                          ),
                        ),
                      ),
                    )),
                  ),

                  const SizedBox(height: 32),

                  FilledButton(
                    onPressed: (_isComplete && !_isLoading) ? _verify : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPurple,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Confirmer', style: TextStyle(
                            fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                            fontSize: 16, color: Colors.white)),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: TextButton(
                      onPressed: _secondsLeft == 0 ? _resend : null,
                      child: Text(
                        _secondsLeft > 0
                            ? 'Renvoyer dans 0:${_secondsLeft.toString().padLeft(2, '0')}'
                            : 'Renvoyer le code',
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 14,
                          color: _secondsLeft > 0 ? const Color(0xFF94A3B8) : _kPurple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Complétion du profil ────────────────────────────────────────────────────────

class _ProfileScreen extends ConsumerStatefulWidget {
  const _ProfileScreen({
    required this.firebaseToken,
    required this.phoneNumber,
  });

  final String firebaseToken;
  final String phoneNumber;

  @override
  ConsumerState<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<_ProfileScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  String _country = "Côte d'Ivoire";
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Entrez votre prénom et votre nom');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await ref.read(authStateProvider.notifier).completeProfile(
        firebaseToken: widget.firebaseToken,
        phoneNumber: widget.phoneNumber,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        country: _country,
      );
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPurple,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: _kGold.withAlpha(50),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _kGold.withAlpha(180), width: 2),
                      ),
                      child: const Center(child: Text('🙏', style: TextStyle(fontSize: 28))),
                    ),
                    const SizedBox(height: 12),
                    const Text('Bienvenue !', style: TextStyle(
                        fontFamily: 'Poppins', fontWeight: FontWeight.w700,
                        fontSize: 24, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Complétez votre profil pour commencer',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                            color: Colors.white.withAlpha(200))),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.danger.withAlpha(80)),
                        ),
                        child: Text(_error!, style: const TextStyle(
                            color: AppColors.danger, fontSize: 13)),
                      ),
                    ],

                    _buildField('Prénom', _firstNameCtrl, 'Marie'),
                    const SizedBox(height: 16),
                    _buildField('Nom', _lastNameCtrl, 'Dupont'),
                    const SizedBox(height: 16),

                    // Pays
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pays', style: TextStyle(
                            fontFamily: 'Inter', fontWeight: FontWeight.w500,
                            fontSize: 14, color: Color(0xFF0F172A))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _country, // ignore: deprecated_member_use
                          decoration: InputDecoration(
                            filled: true, fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          items: _countries.map((c) => DropdownMenuItem(
                            value: c.name,
                            child: Text('${c.flag}  ${c.name}'),
                          )).toList(),
                          onChanged: (v) => setState(() => _country = v!),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPurple,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text("C'est parti !", style: TextStyle(
                              fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                              fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Inter',
            fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, enabled: !_isLoading,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPurple, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ── Widgets helpers ────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(children: [
    const Expanded(child: Divider()),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text('ou continuer avec', style: TextStyle(
          color: Colors.grey.shade500, fontSize: 13, fontFamily: 'Inter')),
    ),
    const Expanded(child: Divider()),
  ]);
}

class _SocialBtn extends StatelessWidget {
  const _SocialBtn({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      side: BorderSide(color: color.withAlpha(100), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: color.withAlpha(12),
      foregroundColor: color,
    ),
    icon: Icon(icon, size: 22, color: color),
    label: Text(label, style: TextStyle(fontFamily: 'Inter',
        fontWeight: FontWeight.w600, fontSize: 14, color: color)),
  );
}
