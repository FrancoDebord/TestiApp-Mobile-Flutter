// lib/features/daily_verse/design/verse_layout.dart
//
// Mise en page commune du verset (carte de l'accueil, plein écran, image de
// partage, vignettes du sélecteur) :
//   • taille du texte adaptée à sa longueur et à la place disponible, jamais
//     sous 18 (carte) / 22 (plein écran), interligne 1,4 ;
//   • réglage de taille du texte du téléphone respecté, plafonné à × 1,3 ;
//   • couleurs issues du design résolu (contraste ≥ 4,5:1).

import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../models/daily_verse_models.dart' show VerseLine, VerseVersion;
import 'verse_background_painter.dart';
import 'verse_design.dart';
import 'verse_style_prefs.dart';

/// Contexte d'affichage : bornes de taille du texte.
enum VerseSurface {
  card(min: 18, max: 24),
  fullscreen(min: 22, max: 34),
  share(min: 18, max: 30);

  const VerseSurface({required this.min, required this.max});

  final double min;
  final double max;
}

/// Interligne du texte du verset.
const double kVerseLineHeight = 1.4;

/// Bornes du réglage de taille du texte du téléphone pour le verset.
const double kVerseMinTextScale = 0.85;
const double kVerseMaxTextScale = 1.3;

/// Facteur de taille du texte du téléphone, borné (0,85 à 1,3).
double verseTextScale(BuildContext context) =>
    (MediaQuery.textScalerOf(context).scale(100) / 100)
        .clamp(kVerseMinTextScale, kVerseMaxTextScale);

/// Style du texte du verset (taille en pixels logiques, déjà mise à l'échelle).
TextStyle verseTextStyle(VerseStylePrefs prefs, double fontSize, Color color) => TextStyle(
      fontFamily: prefs.font.family,
      fontSize: fontSize,
      height: kVerseLineHeight,
      fontWeight: FontWeight.w400,
      color: color,
      letterSpacing: prefs.font.serif ? 0 : -0.1,
    );

/// Style des libellés (« Verset du jour ») : police de l'interface (taille
/// mise à l'échelle par le MediaQuery borné de [VerseCanvas]).
TextStyle verseLabelStyle(Color color) => TextStyle(
      fontFamily: AppFonts.family,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: color,
      height: 1.3,
    );

/// Style de la référence (« Jérémie 17:7 ») : police de l'interface.
TextStyle verseReferenceStyle(Color color, {double size = 15}) => TextStyle(
      fontFamily: AppFonts.family,
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.35,
    );

/// Taille du texte du verset.
///
/// Sans [maxHeight] : selon la longueur (court → grand, long → petit).
/// Avec [maxHeight] : la plus grande taille qui tient dans la place disponible.
/// Le résultat (× [scale] et × facteur de taille choisi) ne descend jamais sous
/// [VerseSurface.min].
double fitVerseFontSize({
  required String text,
  required VerseSurface surface,
  required VerseStylePrefs prefs,
  required double maxWidth,
  double? maxHeight,
  double scale = 1,
}) {
  final min = surface.min;
  final len = text.trim().length;
  // Courbe selon la longueur : 80 caractères → max, 320 et plus → min.
  final t = ((len - 80) / 240).clamp(0.0, 1.0);
  var size = (surface.max - (surface.max - min) * t) * prefs.size.factor * scale;
  if (size < min) size = min;
  if (maxHeight == null || maxWidth <= 0) return size;

  // Réduction par pas de 1 jusqu'à ce que le texte tienne.
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: prefs.align.textAlign,
  );
  try {
    for (var s = size; s >= min; s -= 1) {
      painter
        ..text = TextSpan(text: text, style: verseTextStyle(prefs, s, const Color(0xFF000000)))
        ..layout(maxWidth: maxWidth);
      if (painter.height <= maxHeight) return s;
    }
  } finally {
    painter.dispose();
  }
  return min;
}

/// Hauteur du texte à cette taille (mise en page de la carte).
double measureVerseHeight(String text, VerseStylePrefs prefs, double fontSize, double maxWidth,
    {int? maxLines}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: verseTextStyle(prefs, fontSize, const Color(0xFF000000))),
    textDirection: TextDirection.ltr,
    textAlign: prefs.align.textAlign,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '…',
  )..layout(maxWidth: maxWidth);
  final h = painter.height;
  painter.dispose();
  return h;
}

/// Fond du design à la taille [size], avec [builder] posé dessus (couleurs du
/// design résolu). Un changement de design se fait en fondu de 250 ms.
class VerseCanvas extends StatelessWidget {
  const VerseCanvas({
    required this.design,
    required this.size,
    required this.builder,
    this.borderRadius,
    this.animate = true,
    super.key,
  });

  final VerseDesign design;
  final Size size;
  final Widget Function(BuildContext context, ResolvedVerseDesign resolved) builder;
  final BorderRadius? borderRadius;

  /// Fondu lors d'un changement de design (désactivé pour les vignettes).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = design.resolve(scheme, size);
    Widget canvas = SizedBox.fromSize(
      key: ValueKey(design.id),
      size: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VerseBackground(design: design),
          // Sous l'en-tête (carte) ou la barre du haut (plein écran).
          if (design.accent == VerseAccent.quote)
            Positioned(
              top: (size.height * 0.14).clamp(36.0, 130.0),
              left: size.width * 0.03,
              child: ExcludeSemantics(
                child: Text(
                  '“',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: (size.shortestSide * 0.42).clamp(60, 220),
                    height: 1,
                    color: resolved.decoration.withValues(alpha: 0.13),
                  ),
                ),
              ),
            ),
          // Réglage de taille du texte du téléphone respecté, mais borné.
          MediaQuery.withClampedTextScaling(
            minScaleFactor: kVerseMinTextScale,
            maxScaleFactor: kVerseMaxTextScale,
            child: Builder(builder: (context) => builder(context, resolved)),
          ),
        ],
      ),
    );
    if (animate) {
      canvas = AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, ?current],
        ),
        child: canvas,
      );
    }
    if (borderRadius != null) {
      canvas = ClipRRect(borderRadius: borderRadius!, child: canvas);
    }
    return canvas;
  }
}

/// Filet d'accent au-dessus du verset (designs « line »).
class VerseAccentLine extends StatelessWidget {
  const VerseAccentLine({required this.resolved, required this.align, super.key});

  final ResolvedVerseDesign resolved;
  final VerseAlign align;

  @override
  Widget build(BuildContext context) {
    if (resolved.design.accent != VerseAccent.line) return const SizedBox.shrink();
    return Align(
      alignment: align == VerseAlign.center ? Alignment.center : Alignment.centerLeft,
      child: Container(
        width: 40,
        height: 3,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: resolved.decoration,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Texte du passage ; numéros de versets (couleur d'accent) si la version
/// affichée en contient plusieurs.
class VersePassageText extends StatelessWidget {
  const VersePassageText({
    required this.text,
    required this.style,
    required this.accent,
    this.version,
    this.textAlign,
    this.maxLines,
    super.key,
  });

  final String text;
  final TextStyle style;
  final Color accent;
  final VerseVersion? version;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final lines = version?.lines ?? const <VerseLine>[];
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    // Les tailles sont déjà mises à l'échelle (verseTextScale) : pas de seconde mise à l'échelle.
    if (lines.length < 2) {
      final t = version == null ? text : '« ${text.trim()} »';
      return Text(t,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          textScaler: TextScaler.noScaling);
    }
    return Text.rich(
      TextSpan(style: style, children: [
        for (final l in lines) ...[
          TextSpan(
            text: '${l.verse} ',
            style: style.copyWith(
              fontSize: (style.fontSize ?? 20) * 0.6,
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: '${l.text} '),
        ],
      ]),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      textScaler: TextScaler.noScaling,
    );
  }
}
