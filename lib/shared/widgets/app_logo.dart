// lib/shared/widgets/app_logo.dart
//
// Logo « Témoignages de Gloire » : rayons, soleil, croix et colline, dessinés
// (net à toutes les tailles, sans image), plus le nom de l'application.
//
//   AppLogoMark(size: 64)          → le dessin seul
//   AppLogo(markSize: 96)          → dessin + nom sur deux lignes (connexion…)
//   AppLogo.horizontal()           → dessin + nom en ligne (en-tête d'accueil)

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Le dessin du logo. [size] = hauteur ; la largeur vaut 1,25 × la hauteur.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size * 1.25,
        height: size,
        child: const CustomPaint(painter: AppLogoPainter()),
      );
}

/// Dessin + nom « Témoignages de Gloire » (« Gloire » en orange).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.markSize = 96,
    this.titleSize = 34,
  }) : horizontal = false;

  /// Version compacte en ligne, pour les en-têtes.
  const AppLogo.horizontal({
    super.key,
    this.markSize = 34,
    this.titleSize = 15,
  }) : horizontal = true;

  final double markSize;
  final double titleSize;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppFonts.family,
      fontWeight: FontWeight.w800,
      fontSize: titleSize,
      height: 1.05,
      letterSpacing: horizontal ? -0.2 : -0.5,
      color: AppColors.primary,
    );
    final name = Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'Témoignages\n'),
        const TextSpan(text: 'de '),
        TextSpan(
            text: 'Gloire',
            style: style.copyWith(color: AppColors.secondary)),
      ]),
      style: style,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      maxLines: 2,
    );

    return Semantics(
      label: 'Témoignages de Gloire',
      excludeSemantics: true,
      child: horizontal
          ? LayoutBuilder(builder: (context, constraints) {
              // Trop étroit pour le nom : on ne garde que le dessin, réduit
              // si besoin, plutôt que de déborder.
              if (constraints.maxWidth < markSize + 48) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppLogoMark(size: markSize),
                );
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLogoMark(size: markSize),
                  const SizedBox(width: 8),
                  Flexible(
                      child: FittedBox(fit: BoxFit.scaleDown, child: name)),
                ],
              );
            })
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLogoMark(size: markSize),
                SizedBox(height: markSize * 0.12),
                FittedBox(fit: BoxFit.scaleDown, child: name),
              ],
            ),
    );
  }
}

/// Peintre du logo (public pour pouvoir être réutilisé dans d'autres dessins).
class AppLogoPainter extends CustomPainter {
  const AppLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h * 0.62);
    final sunR = h * 0.34;

    // Rayons en éventail au-dessus du soleil.
    final rayPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h * 0.055;
    const rays = 9;
    for (var i = 0; i < rays; i++) {
      final a = math.pi + math.pi * (i + 0.5) / rays; // de gauche à droite
      final dir = Offset(math.cos(a), math.sin(a));
      final long = i.isEven;
      rayPaint.color = long ? AppColors.sun : AppColors.secondary;
      canvas.drawLine(
        center + dir * (sunR * 1.25),
        center + dir * (sunR * (long ? 1.78 : 1.6)),
        rayPaint,
      );
    }

    // Soleil (demi-disque dégradé orange → jaune).
    final sunRect = Rect.fromCircle(center: center, radius: sunR);
    canvas.drawArc(
      sunRect,
      math.pi,
      math.pi,
      true,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.sun, AppColors.secondary],
        ).createShader(sunRect),
    );

    // Colline bleue (arc large sous le soleil).
    final hill = Path()
      ..moveTo(w * 0.02, h * 0.98)
      ..quadraticBezierTo(w * 0.5, h * 0.42, w * 0.98, h * 0.98)
      ..close();
    canvas.drawPath(
      hill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryLight, AppColors.primary],
        ).createShader(Rect.fromLTWH(0, h * 0.5, w, h * 0.5)),
    );

    // Croix blanche bordée de bleu, posée sur la colline.
    final cw = h * 0.105; // épaisseur
    final crossTop = h * 0.16;
    final crossBottom = h * 0.80;
    final armY = h * 0.33;
    final armHalf = h * 0.17;
    final cross = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(w / 2 - cw / 2, crossTop, w / 2 + cw / 2, crossBottom),
        Radius.circular(cw * 0.2),
      ))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(w / 2 - armHalf, armY, w / 2 + armHalf, armY + cw),
        Radius.circular(cw * 0.2),
      ));
    canvas.drawPath(
      cross,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = cw * 0.45
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(cross, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
