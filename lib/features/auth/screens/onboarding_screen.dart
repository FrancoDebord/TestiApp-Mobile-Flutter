import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

// =============================================================================
// ONBOARDING SCREEN — 3 slides with PageView
// =============================================================================
// Slide 1 : "Partagez ce que Dieu a fait"
//           Illustration: hands raised toward light rays (CustomPaint)
//           Copy: invite users to share their personal testimonies
//           Actions: Skip (top-right TextButton) | Suivant (primary button)
//
// Slide 2 : "Inspirez d'autres croyants"
//           Illustration: connected hearts / community circle (CustomPaint)
//           Copy: testimonies encourage the wider body of Christ
//           Actions: Retour (secondary) | Suivant (primary)
//
// Slide 3 : "Commencez votre voyage"
//           Illustration: open Bible with a rising sun (CustomPaint)
//           Copy: CTA to register or sign in
//           Actions: S'inscrire (primary filled) | Se connecter (outlined)
//
// Interaction: PageView.builder (physics: BouncingScrollPhysics)
//              Dot indicator updates on page change
//              Skip always jumps to slide 3
//              Suivant advances by one page with animated scroll
// =============================================================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _pageCount = 3;

  // Slide data ────────────────────────────────────────────────────────────────
  static const List<_SlideData> _slides = [
    _SlideData(
      illustrationIndex: 0,
      title: 'Partagez ce que\nDieu a fait',
      body:
          'Votre témoignage est une arme puissante. '
          'Chaque histoire de grâce mérite d\'être racontée '
          'et peut changer une vie.',
      primaryLabel: 'Suivant',
      secondaryLabel: null,
    ),
    _SlideData(
      illustrationIndex: 1,
      title: 'Inspirez d\'autres\ncroyants',
      body:
          'Des milliers de frères et sœurs attendent '
          'd\'être encouragés par ce que Dieu a accompli '
          'dans votre vie.',
      primaryLabel: 'Suivant',
      secondaryLabel: 'Retour',
    ),
    _SlideData(
      illustrationIndex: 2,
      title: 'Commencez votre\nvoyage',
      body:
          'Rejoignez la communauté Témoignages et '
          'soyez une lumière dans la vie de quelqu\'un aujourd\'hui.',
      primaryLabel: "S'inscrire",
      secondaryLabel: 'Se connecter',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _advance() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      context.goNamed(AppRoutes.register);
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() {
    _pageController.animateToPage(
      _pageCount - 1,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pageCount - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: Skip button (hidden on last slide) ─────────────────
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isLastPage)
                      TextButton(
                        onPressed: _skip,
                        child: const Text(
                          'Passer',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Page view ───────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: _pageCount,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  return _SlidePage(data: _slides[index]);
                },
              ),
            ),

            // ── Dot indicator ───────────────────────────────────────────────
            _DotIndicator(
              count: _pageCount,
              current: _currentPage,
            ),

            const SizedBox(height: 32),

            // ── Action buttons ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ActionButtons(
                slide: _slides[_currentPage],
                isLastPage: isLastPage,
                onPrimary: _advance,
                onSecondary: isLastPage
                    ? () => context.goNamed(AppRoutes.login)
                    : _back,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Single slide page ─────────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.data});

  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration — custom painted, 260 × 220 canvas.
          SizedBox(
            height: 220,
            child: _OnboardingIllustration(
              index: data.illustrationIndex,
            ),
          ),

          const SizedBox(height: 40),

          // Title.
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 26,
              color: Color(0xFF0F172A),
              height: 1.3,
            ),
          ),

          const SizedBox(height: 16),

          // Body.
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Illustration widget (CustomPaint; swap with Lottie/SVG asset) ─────────────

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _IllustrationPainter(index),
      child: const SizedBox.expand(),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter(this.index);

  final int index;

  // ── Slide 0 : Raised hands + light rays ──────────────────────────────────

  void _paintSlide0(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Soft purple circle background.
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.38,
      Paint()..color = const Color(0xFFEDE9FE),
    );

    // Light rays emanating from top-center.
    final rayPaint = Paint()
      ..color = const Color(0xFFF59E0B).withAlpha(180)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Rays radiate upward; angle sweeps left-to-right across the top arc.
    for (int i = -2; i <= 2; i++) {
      final angle = -math.pi / 2 + i * 0.25;
      final originX = cx + 20 * i.toDouble();
      final originY = cy - size.height * 0.20;
      canvas.drawLine(
        Offset(originX, originY),
        Offset(originX + 50 * math.cos(angle), originY + 50 * math.sin(angle)),
        rayPaint,
      );
    }

    // Two simplified hands reaching up.
    final handPaint = Paint()
      ..color = const Color(0xFF6B21A8)
      ..style = PaintingStyle.fill;

    // Left hand.
    final leftHand = Path()
      ..moveTo(cx - 35, cy + 40)
      ..lineTo(cx - 55, cy - 20)
      ..quadraticBezierTo(cx - 60, cy - 40, cx - 45, cy - 50)
      ..quadraticBezierTo(cx - 30, cy - 60, cx - 20, cy - 30)
      ..lineTo(cx - 20, cy + 40)
      ..close();
    canvas.drawPath(leftHand, handPaint);

    // Right hand.
    final rightHand = Path()
      ..moveTo(cx + 35, cy + 40)
      ..lineTo(cx + 55, cy - 20)
      ..quadraticBezierTo(cx + 60, cy - 40, cx + 45, cy - 50)
      ..quadraticBezierTo(cx + 30, cy - 60, cx + 20, cy - 30)
      ..lineTo(cx + 20, cy + 40)
      ..close();
    canvas.drawPath(rightHand, handPaint);

    // Gold star / sparkle above.
    _drawStar(canvas, Offset(cx, cy - size.height * 0.38), 12, rayPaint..color = const Color(0xFFF59E0B));
  }

  // ── Slide 1 : Community hearts circle ────────────────────────────────────

  void _paintSlide1(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Light gold circle.
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.38,
      Paint()..color = const Color(0xFFFEF3C7),
    );

    // Three hearts positioned in a triangle.
    const heartPositions = [
      Offset(0, -0.28),
      Offset(-0.24, 0.18),
      Offset(0.24, 0.18),
    ];

    for (final pos in heartPositions) {
      _drawHeart(
        canvas,
        Offset(cx + pos.dx * size.width, cy + pos.dy * size.height),
        24,
        const Color(0xFF6B21A8),
      );
    }

    // Connecting lines.
    final linePaint = Paint()
      ..color = const Color(0xFFA855F7).withAlpha(120)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final pts = heartPositions
        .map((p) => Offset(cx + p.dx * size.width, cy + p.dy * size.height))
        .toList();
    for (int i = 0; i < pts.length; i++) {
      canvas.drawLine(pts[i], pts[(i + 1) % pts.length], linePaint);
    }

    // Small gold stars.
    final starPaint = Paint()..color = const Color(0xFFF59E0B);
    _drawStar(canvas, Offset(cx + 60, cy - 60), 8, starPaint);
    _drawStar(canvas, Offset(cx - 65, cy - 45), 6, starPaint);
  }

  // ── Slide 2 : Open Bible + rising sun ────────────────────────────────────

  void _paintSlide2(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Sky circle.
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.38,
      Paint()..color = const Color(0xFFEDE9FE),
    );

    // Sun.
    canvas.drawCircle(
      Offset(cx, cy - 30),
      26,
      Paint()..color = const Color(0xFFF59E0B),
    );

    // Sun rays.
    final rayPaint = Paint()
      ..color = const Color(0xFFF59E0B).withAlpha(160)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        Offset(cx + 32 * math.cos(angle), (cy - 30) + 32 * math.sin(angle)),
        Offset(cx + 46 * math.cos(angle), (cy - 30) + 46 * math.sin(angle)),
        rayPaint,
      );
    }

    // Open Bible (two rectangles tilted).
    final biblePaint = Paint()..color = const Color(0xFF6B21A8);
    canvas.save();
    canvas.translate(cx, cy + 40);

    // Left page.
    canvas.save();
    canvas.rotate(-0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-68, -32, 66, 46),
        const Radius.circular(4),
      ),
      biblePaint,
    );
    // Lines on page.
    final linePaint = Paint()
      ..color = Colors.white.withAlpha(120)
      ..strokeWidth = 1.5;
    for (int l = 0; l < 4; l++) {
      canvas.drawLine(
        Offset(-60, -20 + l * 10.0),
        Offset(-12, -20 + l * 10.0),
        linePaint,
      );
    }
    canvas.restore();

    // Right page.
    canvas.save();
    canvas.rotate(0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, -32, 66, 46),
        const Radius.circular(4),
      ),
      biblePaint,
    );
    for (int l = 0; l < 4; l++) {
      canvas.drawLine(
        Offset(10, -20 + l * 10.0),
        Offset(58, -20 + l * 10.0),
        linePaint,
      );
    }
    canvas.restore();

    canvas.restore();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.3);
    path.cubicTo(
      center.dx - size * 1.2, center.dy - size * 0.5,
      center.dx - size * 2.0, center.dy + size * 0.5,
      center.dx, center.dy + size * 1.4,
    );
    path.cubicTo(
      center.dx + size * 2.0, center.dy + size * 0.5,
      center.dx + size * 1.2, center.dy - size * 0.5,
      center.dx, center.dy + size * 0.3,
    );
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outer = i * (2 * math.pi / 5) - math.pi / 2;
      final inner = outer + math.pi / 5;
      final p1 = Offset(
        center.dx + r * math.cos(outer),
        center.dy + r * math.sin(outer),
      );
      final p2 = Offset(
        center.dx + r * 0.4 * math.cos(inner),
        center.dy + r * 0.4 * math.sin(inner),
      );
      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.lineTo(p2.dx, p2.dy);
    }
    path.close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (index) {
      case 0:
        _paintSlide0(canvas, size);
      case 1:
        _paintSlide1(canvas, size);
      case 2:
        _paintSlide2(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter old) =>
      old.index != index;
}

// ── Dot indicator ─────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6B21A8)
                : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.slide,
    required this.isLastPage,
    required this.onPrimary,
    required this.onSecondary,
  });

  final _SlideData slide;
  final bool isLastPage;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary button — filled purple.
        FilledButton(
          onPressed: onPrimary,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6B21A8),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            slide.primaryLabel,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),

        if (slide.secondaryLabel != null) ...[
          const SizedBox(height: 12),

          // Secondary button — outlined purple on last slide, ghost on others.
          OutlinedButton(
            onPressed: onSecondary,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: BorderSide(
                color: isLastPage
                    ? const Color(0xFF6B21A8)
                    : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              slide.secondaryLabel!,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isLastPage
                    ? const Color(0xFF6B21A8)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _SlideData {
  const _SlideData({
    required this.illustrationIndex,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.secondaryLabel,
  });

  final int illustrationIndex;
  final String title;
  final String body;
  final String primaryLabel;
  final String? secondaryLabel;
}
