// lib/features/daily_verse/design/verse_background_painter.dart
//
// Peinture du fond d'un design de verset (CustomPainter) et texture de grain
// partagée : générée une seule fois (bruit déterministe 128 × 128), puis
// répétée par un ImageShader. Aucun recalcul à chaque frame : le fond n'est
// repeint que si le design, le thème ou la taille changent, ou une seule fois
// quand le grain devient disponible.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'verse_design.dart';

/// Texture de grain commune à tous les fonds.
abstract final class VerseGrain {
  static const int _size = 128;

  /// Image du grain (null tant qu'elle n'est pas prête).
  static final ValueNotifier<ui.Image?> image = ValueNotifier(null);
  static Future<ui.Image>? _pending;

  /// Lance la génération (une seule fois) et renvoie l'image.
  static Future<ui.Image> ensure() {
    final ready = image.value;
    if (ready != null) return Future.value(ready);
    return _pending ??= _generate().then((img) => image.value = img);
  }

  static Future<ui.Image> _generate() {
    final rnd = math.Random(20261013);
    final px = Uint8List(_size * _size * 4);
    for (var i = 0; i < _size * _size; i++) {
      final v = rnd.nextInt(256);
      px[i * 4] = v;
      px[i * 4 + 1] = v;
      px[i * 4 + 2] = v;
      px[i * 4 + 3] = 255;
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, _size, _size, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }
}

/// Peint les couches d'un [ResolvedVerseDesign].
class VerseBackgroundPainter extends CustomPainter {
  VerseBackgroundPainter(this.design, this.scheme) : super(repaint: VerseGrain.image);

  final VerseDesign design;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final resolved = design.resolve(scheme, size);
    final grain = VerseGrain.image.value;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final layer in resolved.layers) {
      layer.paint(canvas, size, grain);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(VerseBackgroundPainter old) =>
      old.design.id != design.id || old.scheme != scheme;
}

/// Fond d'un design : remplit son parent. [child] est posé par-dessus.
class VerseBackground extends StatelessWidget {
  const VerseBackground({required this.design, this.child, super.key});

  final VerseDesign design;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    unawaited(VerseGrain.ensure());
    return RepaintBoundary(
      child: CustomPaint(
        painter: VerseBackgroundPainter(design, Theme.of(context).colorScheme),
        child: child,
      ),
    );
  }
}
