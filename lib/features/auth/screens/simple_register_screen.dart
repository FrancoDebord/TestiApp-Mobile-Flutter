// lib/features/auth/screens/simple_register_screen.dart
//
// Inscription simplifiée : prénom + nom, aucun mot de passe.
// Flux : Onboarding → CetEcran → Home

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/auth_notifier.dart';
import '../../../l10n/app_localizations.dart';

const _kPrimary = AppColors.primary;
const _kGold   = AppColors.secondary;

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
      setState(() => _error = context.l10n.authEnterFullName);
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
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // ── Header (bleu Krea) ─────────────────────────────────────────────
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
                    Text(
                      context.l10n.authWelcomeNew,
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.authTagline,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 14,
                        color: AppColors.textSecondary,
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
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.authCreateMyAccount,
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.authSimpleRegisterIntro,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
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
                      label: context.l10n.authFirstNameLabel,
                      controller: _firstNameCtrl,
                      focusNode: _firstFocus,
                      hint: context.l10n.authFirstNameHintFemale,
                      nextFocus: _lastFocus,
                    ),
                    const SizedBox(height: 16),

                    // Nom
                    _buildField(
                      label: context.l10n.authLastNameLabel,
                      controller: _lastNameCtrl,
                      focusNode: _lastFocus,
                      hint: context.l10n.authLastNameHint,
                      isLast: true,
                      onSubmit: _submit,
                    ),

                    const SizedBox(height: 32),

                    // Bouton
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPrimary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              context.l10n.authLetsGo,
                              style: const TextStyle(
                                fontFamily: AppFonts.family,
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
                        context.l10n.authCompleteProfileLater,
                        style: TextStyle(
                          fontFamily: AppFonts.family,
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
            fontFamily: AppFonts.family,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: AppColors.textPrimary,
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
          style: const TextStyle(fontFamily: AppFonts.family, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: _kPrimary, width: 1.5),
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
