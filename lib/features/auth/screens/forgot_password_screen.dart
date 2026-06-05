import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../widgets/auth_widgets.dart';

// =============================================================================
// FORGOT PASSWORD SCREEN
// =============================================================================
// Two states driven by [_ForgotPasswordState]:
//
//  INPUT STATE (default)
//   • Back arrow AppBar (transparent, no elevation)
//   • Purple wave header — lock icon + "Mot de passe oublié" title + subtitle
//   • White card body:
//       - Instructional paragraph
//       - Email field with validation
//       - "Envoyer le lien" FilledButton with loading state
//       - "Retour à la connexion" ghost TextButton
//
//  SUCCESS STATE (after API call resolves)
//   • Same AppBar
//   • Full-height center column:
//       - Large success illustration (envelope + checkmark, CustomPaint)
//       - "E-mail envoyé !" headline
//       - Body copy with masked email address
//       - "Retour à la connexion" primary button
//       - "Renvoyer" outlined button (re-enters input state)
//
// Validation:
//   Email: non-empty + RFC pattern → inline error below field
// =============================================================================

// ── Screen-local providers ────────────────────────────────────────────────────

// ── Screen ────────────────────────────────────────────────────────────────────

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ── Validator ───────────────────────────────────────────────────────────────

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez saisir votre adresse e-mail';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Adresse e-mail invalide';
    return null;
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _isSent = true);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            "Impossible d'envoyer l'e-mail. Vérifiez l'adresse saisie.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSent = _isSent;

    return Scaffold(
      backgroundColor: const Color(0xFF6B21A8),
      // Transparent AppBar with back arrow.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(AppRoutes.login),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: isSent
          ? _SuccessBody(
              email: _emailController.text.trim(),
              onResend: () => setState(() => _isSent = false),
            )
          : _InputBody(
              formKey: _formKey,
              emailController: _emailController,
              validateEmail: _validateEmail,
              onSubmit: _submit,
              isLoading: _isLoading,
              errorMessage: _errorMessage,
            ),
    );
  }
}

// ── Input body ────────────────────────────────────────────────────────────────

class _InputBody extends StatelessWidget {
  const _InputBody({
    required this.formKey,
    required this.emailController,
    required this.validateEmail,
    required this.onSubmit,
    required this.isLoading,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final FormFieldValidator<String> validateEmail;
  final VoidCallback onSubmit;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {

    return Column(
      children: [
        // Purple header.
        AuthWaveHeader(
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(26),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withAlpha(77), width: 1.5),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nous vous enverrons un lien de réinitialisation',
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

        // White card.
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Instructional text.
                    const Text(
                      'Saisissez l\'adresse e-mail associée à votre compte. '
                      'Vous recevrez un lien pour créer un nouveau mot de passe.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (errorMessage != null) ...[
                      AuthErrorBanner(message: errorMessage!),
                      const SizedBox(height: 20),
                    ],

                    // Email field.
                    AuthTextField(
                      controller: emailController,
                      label: 'Adresse e-mail',
                      hint: 'exemple@email.com',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      validator: validateEmail,
                      enabled: !isLoading,
                      onFieldSubmitted: (_) => onSubmit(),
                    ),

                    const SizedBox(height: 28),

                    // Submit button.
                    AuthPrimaryButton(
                      label: 'Envoyer le lien',
                      isLoading: isLoading,
                      onPressed: isLoading ? null : onSubmit,
                    ),

                    const SizedBox(height: 16),

                    // Back to login.
                    Center(
                      child: TextButton(
                        onPressed: () => context.goNamed(AppRoutes.login),
                        child: const Text(
                          'Retour à la connexion',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Color(0xFF6B21A8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Success body ──────────────────────────────────────────────────────────────

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.email, required this.onResend});

  final String email;
  final VoidCallback onResend;

  // Mask email: jean@email.com → j***@email.com
  String _maskEmail(String raw) {
    final parts = raw.split('@');
    if (parts.length != 2) return raw;
    final local = parts[0];
    final masked = local.length <= 1
        ? local
        : '${local[0]}${'*' * (local.length - 1)}';
    return '$masked@${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Illustration.
            const SizedBox(
              height: 180,
              child: _EmailSentIllustration(),
            ),

            const SizedBox(height: 32),

            const Text(
              'E-mail envoyé !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 26,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Nous avons envoyé un lien de réinitialisation à\n'
              '${_maskEmail(email)}\n\n'
              'Vérifiez également vos courriers indésirables.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.6,
              ),
            ),

            const SizedBox(height: 36),

            // Back to login — primary.
            AuthPrimaryButton(
              label: 'Retour à la connexion',
              isLoading: false,
              onPressed: () => context.goNamed(AppRoutes.login),
            ),

            const SizedBox(height: 12),

            // Resend — outlined.
            OutlinedButton(
              onPressed: onResend,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: Color(0xFF6B21A8), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Renvoyer l\'e-mail',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFF6B21A8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Email-sent illustration (envelope + green checkmark, CustomPaint) ─────────

class _EmailSentIllustration extends StatelessWidget {
  const _EmailSentIllustration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EnvelopePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _EnvelopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background circle.
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.38,
      Paint()..color = const Color(0xFFEDE9FE),
    );

    // Envelope body.
    final env = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 4), width: 96, height: 68),
      const Radius.circular(6),
    );
    canvas.drawRRect(env, Paint()..color = const Color(0xFF6B21A8));

    // Envelope flap (inverted V).
    final flapPaint = Paint()
      ..color = const Color(0xFF9333EA)
      ..style = PaintingStyle.fill;
    final flap = Path()
      ..moveTo(cx - 48, cy - 30)
      ..lineTo(cx, cy + 4)
      ..lineTo(cx + 48, cy - 30)
      ..close();
    canvas.drawPath(flap, flapPaint);

    // Envelope bottom-left and bottom-right fold lines.
    final linePaint = Paint()
      ..color = const Color(0xFF9333EA)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 48, cy + 38), Offset(cx - 10, cy + 10), linePaint);
    canvas.drawLine(Offset(cx + 48, cy + 38), Offset(cx + 10, cy + 10), linePaint);

    // Green checkmark circle.
    canvas.drawCircle(
      Offset(cx + 38, cy - 36),
      18,
      Paint()..color = const Color(0xFF22C55E),
    );

    // Checkmark tick.
    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final tick = Path()
      ..moveTo(cx + 29, cy - 36)
      ..lineTo(cx + 37, cy - 28)
      ..lineTo(cx + 48, cy - 44);
    canvas.drawPath(tick, tickPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
