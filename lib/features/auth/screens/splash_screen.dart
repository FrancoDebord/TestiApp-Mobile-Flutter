import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../providers/auth_notifier.dart'
    show
        AuthState,
        AuthStateAuthenticated,
        AuthStateLoading,
        AuthStateNeedsProfile,
        AuthStateOtpSent,
        AuthStateUnauthenticated,
        authStateProvider;

// =============================================================================
// SPLASH SCREEN
// =============================================================================
// Layout   : Full-screen purple gradient, centered logo block, loading dots
// Duration : Driven by authProvider — navigates once auth state resolves
// Branding : Vertical gradient #6B21A8 → #A855F7, white cross + dove glyph,
//            app name in Poppins SemiBold, tagline in Playfair Display Italic
// =============================================================================

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();

    // Logo entrance animation (scale + fade, 800 ms).
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );

    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    );

    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  // Navigate once auth resolves.
  void _handleAuthState(AuthState authState) {
    if (!mounted) return;
    switch (authState) {
      case AuthStateAuthenticated():
        context.goNamed(AppRoutes.home);
      case AuthStateUnauthenticated():
        context.goNamed(AppRoutes.onboarding);
      case AuthStateOtpSent():
      case AuthStateNeedsProfile():
        context.goNamed(AppRoutes.phoneAuth);
      case AuthStateLoading():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      next.whenData(_handleAuthState);
    });

    return Scaffold(
      body: Container(
        // ── Purple vertical gradient background ──────────────────────────────
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B21A8), // Primary
              Color(0xFF4C1D95), // deeper indigo at bottom
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Logo area — vertically centered in remaining space ──────────
              Expanded(
                child: Center(
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoOpacity,
                      child: const _LogoBlock(),
                    ),
                  ),
                ),
              ),

              // ── Loading indicator + version at bottom ──────────────────────
              const _BottomBlock(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logo block ────────────────────────────────────────────────────────────────
// White cross overlaid with a dove silhouette, app name, tagline.

class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App icon container (cross + dove symbol).
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(26), // 10% white overlay
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withAlpha(77), // 30% white
              width: 1.5,
            ),
          ),
          child: const Center(
            child: _CrossDoveIcon(),
          ),
        ),

        const SizedBox(height: 24),

        // App name.
        const Text(
          'Témoignages',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 32,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 8),

        // Tagline in Playfair Display Italic.
        const Text(
          '"Ce que Dieu a fait pour moi"',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontStyle: FontStyle.italic,
            fontSize: 16,
            color: Color(0xFFE9D5FF), // light purple-white
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Cross + Dove composite icon (drawn with Widgets; swap for SVG asset) ──────

class _CrossDoveIcon extends StatelessWidget {
  const _CrossDoveIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Cross — two overlapping white rectangles.
        const SizedBox(
          width: 48,
          height: 48,
          child: _CrossPainter(),
        ),
        // Dove glyph rendered with a Unicode char (swap for custom SVG).
        const Positioned(
          top: 6,
          child: Text(
            '🕊',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }
}

class _CrossPainter extends StatelessWidget {
  const _CrossPainter();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CrossCustomPainter());
  }
}

class _CrossCustomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Vertical bar.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.44, size.height * 0.10,
            size.width * 0.12, size.height * 0.80),
        const Radius.circular(2),
      ),
      paint,
    );

    // Horizontal bar.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12, size.height * 0.30,
            size.width * 0.76, size.height * 0.12),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Bottom block: animated dots + version ─────────────────────────────────────

class _BottomBlock extends StatelessWidget {
  const _BottomBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Three-dot pulse indicator.
        const _PulsingDots(),
        const SizedBox(height: 16),
        Text(
          'v1.0.0',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Colors.white.withAlpha(128),
          ),
        ),
      ],
    );
  }
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final delay = i * 0.3;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            final t = (((_ctrl.value - delay) % 1.0 + 1.0) % 1.0);
            final opacity = (0.3 + 0.7 * (1 - (2 * t - 1).abs())).clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
