// lib/features/auth/screens/simple_register_screen.dart
//
// Inscription simplifiée : prénom + nom, aucun mot de passe.
// Flux : Onboarding → CetEcran → Home

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/auth_notifier.dart';

const _kPurple = Color(0xFF6B21A8);
const _kGold   = Color(0xFFF59E0B);

class SimpleRegisterScreen extends ConsumerStatefulWidget {
  const SimpleRegisterScreen({super.key});

  @override
  ConsumerState<SimpleRegisterScreen> createState() =>
      _SimpleRegisterScreenState();
}

class _SimpleRegisterScreenState
    extends ConsumerState<SimpleRegisterScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _firstFocus    = FocusNode();
  final _lastFocus     = FocusNode();

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _firstFocus.dispose();
    _lastFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName  = _lastNameCtrl.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Veuillez entrer votre prénom et votre nom.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await ref.read(authStateProvider.notifier).registerLocally(
        firstName: firstName,
        lastName: lastName,
      );
      // GoRouter's redirect will automatically navigate to /home once
      // the auth state becomes AuthStateAuthenticated.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPurple,
      body: Column(
        children: [
          // ── Header violet ───────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icône
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: _kGold.withAlpha(50),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _kGold.withAlpha(180), width: 2),
                      ),
                      child: const Center(
                        child: Text('🙏',
                            style: TextStyle(fontSize: 32)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Bienvenue !',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Partagez les œuvres de Dieu',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.white.withAlpha(204),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Carte blanche ────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Créer mon compte',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Entrez juste votre prénom et votre nom.\nAucun mot de passe requis.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Erreur
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.danger.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.danger)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Prénom
                    _buildField(
                      label: 'Prénom',
                      controller: _firstNameCtrl,
                      focusNode: _firstFocus,
                      hint: 'Marie',
                      nextFocus: _lastFocus,
                    ),
                    const SizedBox(height: 16),

                    // Nom
                    _buildField(
                      label: 'Nom',
                      controller: _lastNameCtrl,
                      focusNode: _lastFocus,
                      hint: 'Dupont',
                      isLast: true,
                      onSubmit: _submit,
                    ),

                    const SizedBox(height: 32),

                    // Bouton
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPurple,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text(
                              "C'est parti !",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    // Mention légère
                    Center(
                      child: Text(
                        'Vous pouvez compléter votre profil plus tard.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
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

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    FocusNode? nextFocus,
    bool isLast = false,
    VoidCallback? onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: !_isLoading,
          textCapitalization: TextCapitalization.words,
          textInputAction:
              isLast ? TextInputAction.done : TextInputAction.next,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: _kPurple, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
          onSubmitted: (_) {
            if (nextFocus != null) {
              nextFocus.requestFocus();
            } else if (onSubmit != null) {
              onSubmit();
            }
          },
        ),
      ],
    );
  }
}
