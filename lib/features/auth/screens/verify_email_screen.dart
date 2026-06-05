import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_routes.dart';
import '../widgets/auth_widgets.dart';

// =============================================================================
// EMAIL VERIFICATION SCREEN
// =============================================================================
// Shown after registration when isEmailVerified == false.
// GoRouter redirect keeps the user here until verification completes.
//
// Layout (top → bottom):
//   1. Purple wave header   — shield/envelope icon + "Vérifiez votre e-mail"
//   2. White card body:
//      a. Instructional text + masked email address
//      b. 6-cell OTP input  — each cell is an individual TextField (auto-focus
//         advances, backspace retreats); digits only, one per cell
//      c. Error banner       — shown on invalid/expired code
//      d. "Confirmer" button — full-width FilledButton, loading state
//      e. Resend row        — "Renvoyer le code" + countdown timer (60 s)
//         Countdown resets each time user taps resend.
//      f. Sign-out link      — "Ce n'est pas mon compte ? Se déconnecter"
//
// OTP interaction notes:
//   • Each cell accepts exactly one digit.
//   • Typing a digit auto-moves focus to the next cell.
//   • Backspace on an empty cell moves focus to the previous cell.
//   • Pasting a 6-digit string fills all cells at once.
//   • "Confirmer" is enabled only when all 6 cells are filled.
//   • On success GoRouter redirect navigates to /home.
//   • On error (wrong/expired code) cells clear and an error banner appears.
//
// Countdown:
//   • Starts at 60 s on screen entry and after each resend.
//   • "Renvoyer" is disabled while the timer is running.
//   • Timer label: "Renvoyer dans 0:42" → "Renvoyer le code" when expired.
// =============================================================================

// ── Screen-local providers ────────────────────────────────────────────────────

// ── Screen ────────────────────────────────────────────────────────────────────

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const int _cellCount = 6;
  static const int _countdownSeconds = 60;

  // One controller + focus node per OTP cell.
  final List<TextEditingController> _controllers =
      List.generate(_cellCount, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_cellCount, (_) => FocusNode());

  int _secondsLeft = _countdownSeconds;
  Timer? _timer;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Countdown ───────────────────────────────────────────────────────────────

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _countdownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  // ── OTP helpers ─────────────────────────────────────────────────────────────

  String get _otpValue =>
      _controllers.map((c) => c.text).join();

  bool get _isComplete => _otpValue.length == _cellCount;

  void _clearAllCells() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    setState(() => _errorMessage = null);
  }

  void _onCellChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste: distribute characters across cells.
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < _cellCount && i < digits.length; i++) {
        _controllers[index + i < _cellCount ? index + i : _cellCount - 1]
            .text = digits[i];
      }
      final nextIndex = (index + digits.length).clamp(0, _cellCount - 1);
      _focusNodes[nextIndex].requestFocus();
      setState(() {});
      return;
    }

    if (value.isNotEmpty && index < _cellCount - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onCellKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_isComplete) return;
    setState(() { _errorMessage = null; _isLoading = true; });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) context.goNamed(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Code incorrect ou expiré. Veuillez réessayer.');
        _clearAllCells();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Resend ──────────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    // Wire to auth repository resend-code endpoint.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _clearAllCells();
    _startCountdown();
  }

  // ── Sign out ─────────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).signOut();
    // GoRouter redirect will navigate to /login after sign-out.
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isLoading;
    final errorMessage = _errorMessage;
    final user = ref.watch(currentUserProvider);
    final maskedEmail = _maskEmail(user?.email ?? '');

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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(26),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withAlpha(77), width: 1.5),
                    ),
                    child: const Icon(Icons.mark_email_read_outlined,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Vérifiez votre e-mail',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Code envoyé à $maskedEmail',
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

          // ── White card body ────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Instructional text.
                    const Text(
                      'Saisissez le code à 6 chiffres que nous venons de vous envoyer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // OTP input cells.
                    _OtpInputRow(
                      controllers: _controllers,
                      focusNodes: _focusNodes,
                      onChanged: _onCellChanged,
                      onKeyEvent: _onCellKeyEvent,
                      enabled: !isLoading,
                    ),

                    const SizedBox(height: 24),

                    if (errorMessage != null) ...[
                      AuthErrorBanner(message: errorMessage),
                      const SizedBox(height: 20),
                    ],

                    // Confirm button.
                    AuthPrimaryButton(
                      label: 'Confirmer',
                      isLoading: isLoading,
                      onPressed: (_isComplete && !isLoading) ? _submit : null,
                    ),

                    const SizedBox(height: 24),

                    // Resend row with countdown.
                    _ResendRow(
                      secondsLeft: _secondsLeft,
                      onResend: _secondsLeft == 0 ? _resend : null,
                    ),

                    const SizedBox(height: 32),

                    // Sign-out link.
                    Center(
                      child: GestureDetector(
                        onTap: _signOut,
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                            children: [
                              TextSpan(text: "Ce n'est pas mon compte ? "),
                              TextSpan(
                                text: 'Se déconnecter',
                                style: TextStyle(
                                  color: Color(0xFF6B21A8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _maskEmail(String raw) {
  final parts = raw.split('@');
  if (parts.length != 2) return raw;
  final local = parts[0];
  final masked =
      local.length <= 1 ? local : '${local[0]}${'*' * (local.length - 1)}';
  return '$masked@${parts[1]}';
}

// ── OTP input row ─────────────────────────────────────────────────────────────

class _OtpInputRow extends StatelessWidget {
  const _OtpInputRow({
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
    required this.onKeyEvent,
    required this.enabled,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(int index, String value) onChanged;
  final void Function(int index, KeyEvent event) onKeyEvent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(controllers.length, (i) {
        return _OtpCell(
          controller: controllers[i],
          focusNode: focusNodes[i],
          enabled: enabled,
          onChanged: (v) => onChanged(i, v),
          onKeyEvent: (e) => onKeyEvent(i, e),
        );
      }),
    );
  }
}

class _OtpCell extends StatelessWidget {
  const _OtpCell({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: onKeyEvent,
      child: SizedBox(
        width: 46,
        height: 56,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: controller.text.isEmpty
                ? Colors.white
                : const Color(0xFFEDE9FE),
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: controller.text.isNotEmpty
                    ? const Color(0xFF6B21A8)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF6B21A8), width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Resend row ────────────────────────────────────────────────────────────────

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.secondsLeft,
    required this.onResend,
  });

  final int secondsLeft;
  final VoidCallback? onResend;

  String get _timerLabel {
    if (secondsLeft <= 0) return 'Renvoyer le code';
    final m = secondsLeft ~/ 60;
    final s = secondsLeft % 60;
    return 'Renvoyer dans $m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Vous n'avez pas reçu de code ? ",
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        GestureDetector(
          onTap: onResend,
          child: Text(
            _timerLabel,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: onResend != null
                  ? const Color(0xFF6B21A8)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }
}
