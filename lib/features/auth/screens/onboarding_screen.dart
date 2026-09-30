import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_logo.dart';

// =============================================================================
// ONBOARDING — Tutoriel / premier lancement (maquette, écran 2)
// =============================================================================
// 4 diapositives (PageView) illustrées en style plat, arrondi et chaleureux
// (CustomPainter : personnages qui louent / partagent, soleil, étoiles) :
//   1. « Bienvenue sur Témoignages de Gloire » (« Gloire » en orange)
//   2. « Partagez ce que Dieu a fait »
//   3. « Inspirez d'autres croyants »
//   4. « Commencez votre voyage » (logo)
// Bas d'écran : points de pagination (actif = pilule bleue), grand bouton
// « Suivant » (bleu) — « Commencer » (orange) sur la dernière — puis le lien
// « Passer » (saut à la dernière diapositive).
// « Commencer » ouvre l'écran Connexion / Inscription (/login), qui mène à
// l'inscription, aux connexions téléphone / Google / e-mail et au mode invité.
// =============================================================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_SlideData> _slides = [
    _SlideData(
      illustration: _Illustration.welcome,
      title: 'Bienvenue sur',
      highlightTitle: true,
      body: 'Découvrez, partagez et vivez des témoignages qui édifient et '
          'changent des vies.',
    ),
    _SlideData(
      illustration: _Illustration.share,
      title: 'Partagez ce que Dieu a fait',
      body: 'Votre témoignage est une arme puissante : chaque histoire de '
          'grâce mérite d\'être racontée et peut changer une vie.',
    ),
    _SlideData(
      illustration: _Illustration.inspire,
      title: 'Inspirez d\'autres croyants',
      body: 'Des milliers de frères et sœurs attendent d\'être encouragés '
          'par ce que Dieu a accompli dans votre vie.',
    ),
    _SlideData(
      illustration: _Illustration.start,
      title: 'Commencez votre voyage',
      body: 'Rejoignez la communauté et soyez une lumière dans la vie de '
          'quelqu\'un aujourd\'hui.',
    ),
  ];

  int get _pageCount => _slides.length;

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
      context.goNamed(AppRoutes.login);
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
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: _pageCount,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) =>
                    _SlidePage(data: _slides[index]),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _DotIndicator(count: _pageCount, current: _currentPage),
            const SizedBox(height: AppSpacing.xxl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: AppButton(
                key: const ValueKey('onboarding-next'),
                label: isLastPage ? 'Commencer' : 'Suivant',
                variant: isLastPage
                    ? AppButtonVariant.orange
                    : AppButtonVariant.primary,
                size: AppButtonSize.large,
                fullWidth: true,
                onPressed: _advance,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Hauteur réservée : pas de saut de mise en page sur la dernière.
            SizedBox(
              height: 44,
              child: isLastPage
                  ? null
                  : TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Passer',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

// ── Diapositive ──────────────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.data});

  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTextStyles.h2.copyWith(fontSize: 24, height: 1.25);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.1,
                child: _OnboardingIllustration(kind: data.illustration),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Flexible(
            flex: 4,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: data.highlightTitle
                        ? titleStyle.copyWith(
                            fontSize: 18, fontWeight: FontWeight.w600)
                        : titleStyle,
                  ),
                  if (data.highlightTitle) ...[
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Témoignages de '),
                        TextSpan(
                          text: 'Gloire',
                          style: titleStyle.copyWith(
                              color: AppColors.secondary),
                        ),
                      ]),
                      textAlign: TextAlign.center,
                      style: titleStyle.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    data.body,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.55,
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

// ── Illustrations ────────────────────────────────────────────────────────────

enum _Illustration { welcome, share, inspire, start }

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({required this.kind});

  final _Illustration kind;

  @override
  Widget build(BuildContext context) {
    final painted = CustomPaint(
      painter: _IllustrationPainter(kind),
      child: const SizedBox.expand(),
    );
    if (kind != _Illustration.start) return painted;
    // Dernière diapositive : le logo de l'application au centre.
    return LayoutBuilder(
      builder: (context, c) => Stack(
        alignment: Alignment.center,
        children: [
          painted,
          Align(
            alignment: const Alignment(0, -0.05),
            child: AppLogoMark(size: c.maxHeight * 0.46),
          ),
        ],
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter(this.kind);

  final _Illustration kind;

  // Palette des personnages (tons de peau et cheveux : pas d'équivalent
  // dans la charte, réservés aux illustrations).
  static const _skinDark = Color(0xFF8A5A3C);
  static const _skinLight = Color(0xFFB57C55);
  static const _hair = Color(0xFF2B2A33);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fond : grand disque doux + sol arrondi.
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      math.min(w, h) * 0.46,
      Paint()
        ..color = kind == _Illustration.inspire
            ? AppColors.sunSoft
            : AppColors.primarySoft,
    );

    switch (kind) {
      case _Illustration.welcome:
        _sun(canvas, Offset(w * 0.72, h * 0.22), h * 0.1);
        _stars(canvas, size, const [
          Offset(0.16, 0.2),
          Offset(0.3, 0.1),
          Offset(0.9, 0.44),
        ]);
        // Homme qui lève la main (louange) et femme au téléphone.
        _person(canvas, Offset(w * 0.36, h * 0.93), h * 0.62,
            skin: _skinDark,
            shirt: AppColors.primary,
            armUp: true,
            longHair: false);
        _person(canvas, Offset(w * 0.66, h * 0.93), h * 0.56,
            skin: _skinLight,
            shirt: AppColors.sun,
            armUp: false,
            longHair: true,
            phone: true);
      case _Illustration.share:
        _sun(canvas, Offset(w * 0.25, h * 0.24), h * 0.08);
        _stars(canvas, size, const [Offset(0.82, 0.18), Offset(0.12, 0.52)]);
        _person(canvas, Offset(w * 0.5, h * 0.95), h * 0.64,
            skin: _skinLight,
            shirt: AppColors.primary,
            armUp: false,
            longHair: true,
            phone: true);
        // Bulles de partage (cœur, lecture, message).
        _bubble(canvas, Offset(w * 0.8, h * 0.36), h * 0.09,
            AppColors.secondary, _heart);
        _bubble(canvas, Offset(w * 0.2, h * 0.4), h * 0.08, AppColors.primary,
            _play);
        _bubble(canvas, Offset(w * 0.74, h * 0.62), h * 0.07, AppColors.sun,
            _lines);
      case _Illustration.inspire:
        _sun(canvas, Offset(w * 0.5, h * 0.2), h * 0.1);
        _stars(canvas, size, const [
          Offset(0.18, 0.24),
          Offset(0.84, 0.26),
          Offset(0.9, 0.56),
        ]);
        // Trois croyants, bras levés.
        _person(canvas, Offset(w * 0.24, h * 0.95), h * 0.5,
            skin: _skinLight,
            shirt: AppColors.secondary,
            armUp: true,
            longHair: true);
        _person(canvas, Offset(w * 0.76, h * 0.95), h * 0.5,
            skin: _skinDark,
            shirt: AppColors.primaryLight,
            armUp: true,
            longHair: false);
        _person(canvas, Offset(w * 0.5, h * 0.97), h * 0.6,
            skin: _skinDark,
            shirt: AppColors.primary,
            armUp: true,
            longHair: false);
      case _Illustration.start:
        // Colline + rayons discrets ; le logo est posé par-dessus.
        final hill = Path()
          ..moveTo(w * 0.08, h * 0.86)
          ..quadraticBezierTo(w * 0.5, h * 0.62, w * 0.92, h * 0.86)
          ..quadraticBezierTo(w * 0.5, h * 0.96, w * 0.08, h * 0.86)
          ..close();
        canvas.drawPath(hill, Paint()..color = AppColors.primary.withAlpha(40));
        _stars(canvas, size, const [
          Offset(0.18, 0.2),
          Offset(0.82, 0.18),
          Offset(0.12, 0.62),
          Offset(0.88, 0.6),
        ]);
    }
  }

  // ── Éléments ─────────────────────────────────────────────────────────────

  void _sun(Canvas canvas, Offset c, double r) {
    final ray = Paint()
      ..color = AppColors.sun
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r * 1.3), c + d * (r * 1.75), ray);
    }
    canvas.drawCircle(c, r, Paint()..color = AppColors.sun);
    canvas.drawCircle(c, r * 0.72, Paint()..color = AppColors.secondary);
  }

  void _stars(Canvas canvas, Size size, List<Offset> rel) {
    final paint = Paint()..color = AppColors.sun;
    for (var i = 0; i < rel.length; i++) {
      final r = size.height * (i.isEven ? 0.035 : 0.025);
      _star(canvas, Offset(rel[i].dx * size.width, rel[i].dy * size.height),
          r, paint);
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    // Étoile à 4 branches arrondie (scintillement).
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  /// Personnage plat : [feet] = milieu du bas, [height] = taille totale.
  void _person(
    Canvas canvas,
    Offset feet,
    double height, {
    required Color skin,
    required Color shirt,
    required bool armUp,
    required bool longHair,
    bool phone = false,
  }) {
    final u = height / 10; // unité
    final headC = Offset(feet.dx, feet.dy - height + u * 1.3);
    final shoulderY = headC.dy + u * 2.0;
    final skinPaint = Paint()..color = skin;
    final hairPaint = Paint()..color = _hair;

    // Cheveux longs derrière la tête.
    if (longHair) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: headC.translate(0, u * 0.6),
              width: u * 2.7,
              height: u * 3.0),
          Radius.circular(u * 1.3),
        ),
        hairPaint,
      );
    }

    // Buste (forme arrondie).
    final body = RRect.fromRectAndCorners(
      Rect.fromLTRB(feet.dx - u * 2.1, shoulderY, feet.dx + u * 2.1, feet.dy),
      topLeft: Radius.circular(u * 1.6),
      topRight: Radius.circular(u * 1.6),
    );
    canvas.drawRRect(body, Paint()..color = shirt);

    // Cou + tête.
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(headC.dx, shoulderY - u * 0.2),
            width: u * 0.8,
            height: u * 0.9),
        skinPaint);
    canvas.drawCircle(headC, u * 1.15, skinPaint);

    // Cheveux courts / frange.
    canvas.drawArc(
      Rect.fromCircle(center: headC.translate(0, -u * 0.15), radius: u * 1.2),
      math.pi,
      math.pi,
      true,
      hairPaint,
    );

    // Sourire.
    canvas.drawArc(
      Rect.fromCenter(
          center: headC.translate(0, u * 0.35), width: u * 0.9, height: u * 0.6),
      0.2,
      math.pi - 0.4,
      false,
      Paint()
        ..color = _hair
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.14
        ..strokeCap = StrokeCap.round,
    );

    final arm = Paint()
      ..color = shirt
      ..strokeWidth = u * 0.95
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final hand = Paint()..color = skin;

    if (armUp) {
      // Bras droit levé vers le ciel.
      final s = Offset(feet.dx + u * 1.6, shoulderY + u * 0.7);
      final e = Offset(feet.dx + u * 2.6, shoulderY - u * 1.2);
      final hnd = Offset(feet.dx + u * 2.9, shoulderY - u * 3.0);
      canvas.drawPath(
          Path()
            ..moveTo(s.dx, s.dy)
            ..lineTo(e.dx, e.dy)
            ..lineTo(hnd.dx, hnd.dy + u * 0.4),
          arm);
      canvas.drawCircle(hnd, u * 0.5, hand);
    }
    if (phone) {
      // Main tenant un téléphone devant la poitrine.
      final p = Offset(feet.dx - u * 0.9, shoulderY + u * 1.9);
      canvas.drawPath(
          Path()
            ..moveTo(feet.dx - u * 1.7, shoulderY + u * 0.8)
            ..lineTo(feet.dx - u * 1.8, shoulderY + u * 2.4)
            ..lineTo(p.dx, p.dy + u * 0.3),
          arm);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: u * 1.0, height: u * 1.7),
          Radius.circular(u * 0.2),
        ),
        Paint()..color = AppColors.primaryDark,
      );
      canvas.drawCircle(p.translate(-u * 0.35, u * 0.6), u * 0.42, hand);
    }
  }

  void _bubble(Canvas canvas, Offset c, double r, Color color,
      void Function(Canvas, Offset, double) icon) {
    canvas.drawCircle(c, r, Paint()..color = AppColors.surface);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withAlpha(90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08);
    icon(canvas, c, r * 0.5);
  }

  static void _heart(Canvas canvas, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.8)
      ..cubicTo(c.dx - r * 1.4, c.dy - r * 0.1, c.dx - r * 0.7, c.dy - r * 1.1,
          c.dx, c.dy - r * 0.35)
      ..cubicTo(c.dx + r * 0.7, c.dy - r * 1.1, c.dx + r * 1.4, c.dy - r * 0.1,
          c.dx, c.dy + r * 0.8)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.secondary);
  }

  static void _play(Canvas canvas, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx - r * 0.5, c.dy - r * 0.8)
      ..lineTo(c.dx + r * 0.85, c.dy)
      ..lineTo(c.dx - r * 0.5, c.dy + r * 0.8)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.primary
          ..strokeJoin = StrokeJoin.round);
  }

  static void _lines(Canvas canvas, Offset c, double r) {
    final p = Paint()
      ..color = AppColors.sunText
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-r * 0.8, -r * 0.4), c.translate(r * 0.8, -r * 0.4), p);
    canvas.drawLine(c.translate(-r * 0.8, r * 0.3), c.translate(r * 0.3, r * 0.3), p);
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter old) => old.kind != kind;
}

// ── Points de pagination ─────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${current + 1} sur $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final isActive = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          );
        }),
      ),
    );
  }
}

// ── Données ──────────────────────────────────────────────────────────────────

class _SlideData {
  const _SlideData({
    required this.illustration,
    required this.title,
    required this.body,
    this.highlightTitle = false,
  });

  final _Illustration illustration;
  final String title;
  final String body;

  /// Ajoute « Témoignages de Gloire » (« Gloire » en orange) sous le titre.
  final bool highlightTitle;
}
