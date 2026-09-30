import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_logo.dart';
import '../providers/auth_notifier.dart'
    show
        AuthState,
        AuthStateAuthenticated,
        AuthStateGuest,
        AuthStateLoading,
        AuthStateNeedsProfile,
        AuthStateOtpSent,
        AuthStateUnauthenticated,
        authStateProvider;

// =============================================================================
// SPLASH SCREEN
// =============================================================================
// Layout   : Lever de soleil sur des montagnes, silhouette aux bras levés,
//            logo (croix, soleil, colline), « Témoignages de Gloire », slogan,
//            barre « Chargement… » en bas.
// Rendu    : entièrement dessiné (CustomPainter) — aucune image à charger,
//            net sur toutes les tailles d'écran.
// Duration : Driven by authProvider — navigates once auth state resolves
// Branding : bleu / orange / jaune de la charte (AppColors), Plus Jakarta Sans
// =============================================================================

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  /// Progression de la barre : avance vite puis ralentit (on ne connaît pas
  /// la durée réelle de la restauration de session).
  late final AnimationController _progressController;

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

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..forward();

    // fireImmediately : le routeur lit authStateProvider avant le splash ;
    // si l'état est déjà résolu, un simple ref.listen ne serait jamais appelé
    // et l'utilisateur resterait bloqué ici.
    ref.listenManual<AsyncValue<AuthState>>(
      authStateProvider,
      (_, next) {
        next.when(
          data: (s) => WidgetsBinding.instance
              .addPostFrameCallback((_) => _handleAuthState(s)),
          // Sans ce cas, une erreur de restauration de session laisse
          // l'utilisateur bloqué indéfiniment sur le splash.
          error: (e, _) {
            debugPrint('[Splash] Restauration de session échouée : $e');
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _handleAuthState(const AuthStateUnauthenticated()));
          },
          loading: () {},
        );
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // Navigate once auth resolves.
  void _handleAuthState(AuthState authState) {
    if (!mounted) return;
    // Le routeur a déjà quitté le splash (ex. lien de témoignage rejoué par
    // le redirect) : ne pas écraser cette navigation par l'accueil.
    final current =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    if (current != AppPaths.splash) return;
    switch (authState) {
      case AuthStateAuthenticated():
      case AuthStateGuest():
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
    // Haut de l'écran clair : icônes de la barre d'état en sombre.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _SunrisePainter.ground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _SunrisePainter.ground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const RepaintBoundary(
              child: CustomPaint(painter: _SunrisePainter()),
            ),
            SafeArea(
              child: LayoutBuilder(builder: (context, c) {
                // Tailles relatives à la hauteur : tient sur les petits
                // écrans comme sur les grands.
                final logoSize = (c.maxHeight * 0.17).clamp(84.0, 150.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      SizedBox(height: c.maxHeight * 0.07),
                      ScaleTransition(
                        scale: _logoScale,
                        child: FadeTransition(
                          opacity: _logoOpacity,
                          child: _LogoBlock(logoSize: logoSize),
                        ),
                      ),
                      const Spacer(),
                      _LoadingBar(progress: _progressController),
                      SizedBox(height: c.maxHeight * 0.05),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logo block ────────────────────────────────────────────────────────────────
// Logo dessiné, nom de l'application sur deux lignes, slogan.

class _LogoBlock extends StatelessWidget {
  const _LogoBlock({required this.logoSize});

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w800,
      fontSize: 40,
      height: 1.05,
      letterSpacing: -0.5,
      color: AppColors.primary,
      shadows: [Shadow(color: Color(0x66FFFFFF), blurRadius: 12)],
    );

    return Semantics(
      label: 'Témoignages de Gloire. Des vies transformées pour la gloire '
          'de Dieu.',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLogoMark(size: logoSize),
          const SizedBox(height: 14),
          // FittedBox : le titre se réduit plutôt que de déborder (petits
          // écrans, grande taille de police système).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              children: [
                const Text('Témoignages', style: titleStyle),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'de '),
                      TextSpan(
                        text: 'Gloire',
                        style: titleStyle.copyWith(
                            color: AppColors.secondary),
                      ),
                    ],
                  ),
                  style: titleStyle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Des vies transformées\npour la gloire de Dieu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w600,
                fontSize: 17,
                height: 1.35,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading bar ───────────────────────────────────────────────────────────────

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    // 0 → 90 % en ralentissant : la barre ne « finit » jamais avant que la
    // navigation ait lieu.
    final eased = CurvedAnimation(parent: progress, curve: Curves.easeOutCubic);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Chargement…',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.white,
            shadows: [Shadow(color: Color(0x80000000), blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedBuilder(
              animation: eased,
              builder: (_, _) => Semantics(
                label: 'Chargement',
                value: '${(eased.value * 90).round()} %',
                child: Container(
                  height: 8,
                  color: Colors.white.withAlpha(60),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.08 + 0.82 * eased.value,
                    heightFactor: 1,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.sun, AppColors.secondary],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Background painter : ciel, soleil levant, montagnes, silhouette ──────────

class _SunrisePainter extends CustomPainter {
  const _SunrisePainter();

  /// Couleur du premier plan (sert aussi de fond du Scaffold et de la barre
  /// de navigation Android).
  static const ground = Color(0xFF1A2138);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final full = Offset.zero & size;

    // Ciel : bleu clair en haut (lisibilité du titre) → doré → orangé.
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFB9D7EF),
            Color(0xFFE6F0F7),
            Color(0xFFFFF1CF),
            Color(0xFFFFC56B),
            Color(0xFFF08A3C),
          ],
          stops: [0.0, 0.30, 0.52, 0.70, 0.86],
        ).createShader(full),
    );

    // Halo du soleil levant, derrière la silhouette.
    final sunCenter = Offset(w * 0.5, h * 0.72);
    canvas.drawCircle(
      sunCenter,
      h * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            const Color(0xFFFFF4C2).withAlpha(230),
            const Color(0xFFFFD27A).withAlpha(90),
            const Color(0x00FFC56B),
          ],
          stops: const [0.0, 0.10, 0.35, 1.0],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: h * 0.45)),
    );

    // Rayons de lumière très doux.
    final rayPaint = Paint()..color = Colors.white.withAlpha(22);
    for (var i = 0; i < 12; i++) {
      final a = -math.pi + math.pi * (i + 0.5) / 12;
      final spread = 0.035;
      final p = Path()
        ..moveTo(sunCenter.dx, sunCenter.dy)
        ..lineTo(sunCenter.dx + math.cos(a - spread) * h,
            sunCenter.dy + math.sin(a - spread) * h)
        ..lineTo(sunCenter.dx + math.cos(a + spread) * h,
            sunCenter.dy + math.sin(a + spread) * h)
        ..close();
      canvas.drawPath(p, rayPaint);
    }

    // Chaînes de montagnes, de la plus lointaine (brumeuse) à la plus proche.
    _ridge(canvas, size, baseY: 0.74, amp: 0.035, seed: 1,
        color: const Color(0xFFC08A7A).withAlpha(150));
    _ridge(canvas, size, baseY: 0.79, amp: 0.045, seed: 2,
        color: const Color(0xFF7C6E86).withAlpha(200));
    _ridge(canvas, size, baseY: 0.85, amp: 0.05, seed: 3,
        color: const Color(0xFF454A68));

    // Premier plan : sommet sur lequel se tient la silhouette.
    final peakX = w * 0.5;
    final peakY = h * 0.86;
    final fore = Path()
      ..moveTo(0, h * 0.93)
      ..quadraticBezierTo(w * 0.22, h * 0.90, w * 0.40, peakY + h * 0.012)
      ..lineTo(peakX, peakY)
      ..lineTo(w * 0.60, peakY + h * 0.012)
      ..quadraticBezierTo(w * 0.80, h * 0.90, w, h * 0.92)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(fore, Paint()..color = ground);

    _person(canvas, Offset(peakX, peakY), h * 0.20);
  }

  /// Ligne de crête irrégulière (somme de sinusoïdes, déterministe).
  void _ridge(Canvas canvas, Size size,
      {required double baseY,
      required double amp,
      required int seed,
      required Color color}) {
    final w = size.width;
    final h = size.height;
    final path = Path()..moveTo(0, h);
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final x = i / steps;
      final y = baseY +
          amp *
              (0.55 * math.sin(x * 7.0 + seed * 1.7) +
                  0.30 * math.sin(x * 15.0 + seed * 2.9) +
                  0.15 * math.sin(x * 31.0 + seed));
      path.lineTo(x * w, y * h);
    }
    path
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Silhouette debout, bras levés en V. [feet] = point d'appui, [height] =
  /// taille totale (tête comprise, bras non compris).
  void _person(Canvas canvas, Offset feet, double height) {
    final u = height / 10; // unité
    final paint = Paint()..color = ground;
    final limb = Paint()
      ..color = ground
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final hip = feet.translate(0, -4.6 * u);
    final neck = feet.translate(0, -8.4 * u);

    // Jambes.
    limb.strokeWidth = 1.35 * u;
    canvas.drawPath(
      Path()
        ..moveTo(feet.dx - 0.9 * u, feet.dy)
        ..lineTo(hip.dx - 0.35 * u, hip.dy)
        ..moveTo(feet.dx + 0.9 * u, feet.dy)
        ..lineTo(hip.dx + 0.35 * u, hip.dy),
      limb,
    );

    // Buste.
    canvas.drawPath(
      Path()
        ..moveTo(hip.dx - 1.05 * u, hip.dy + 0.3 * u)
        ..lineTo(neck.dx - 1.6 * u, neck.dy + 0.45 * u)
        ..quadraticBezierTo(neck.dx, neck.dy - 0.35 * u, neck.dx + 1.6 * u,
            neck.dy + 0.45 * u)
        ..lineTo(hip.dx + 1.05 * u, hip.dy + 0.3 * u)
        ..close(),
      paint,
    );

    // Bras levés (épaule → coude → main).
    limb.strokeWidth = 1.05 * u;
    for (final s in [-1.0, 1.0]) {
      final shoulder = neck.translate(s * 1.25 * u, 0.55 * u);
      final elbow = shoulder.translate(s * 1.5 * u, -1.8 * u);
      final hand = elbow.translate(s * 0.9 * u, -1.9 * u);
      canvas.drawPath(
        Path()
          ..moveTo(shoulder.dx, shoulder.dy)
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(hand.dx, hand.dy),
        limb,
      );
      canvas.drawCircle(hand, 0.55 * u, paint);
    }

    // Tête.
    canvas.drawCircle(neck.translate(0, -1.0 * u), 0.95 * u, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
