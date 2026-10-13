// Contraste des designs du verset du jour (WCAG AA, 4,5:1) : chaque design est
// réellement peint (couches, grain, voile), en thème clair et sombre, à
// plusieurs tailles ; on mesure le contraste de l'encre et de l'accent contre
// chaque pixel de la zone de texte.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/features/daily_verse/design/verse_background_painter.dart';
import 'package:testi_app/features/daily_verse/design/verse_design.dart';

const _sizes = {
  'carte': Size(360, 310),
  'plein écran': Size(400, 820),
  'partage': Size(360, 450),
  'vignette': Size(120, 160),
};

Future<ByteData> _render(VerseDesign d, ColorScheme scheme, Size size) async {
  final recorder = ui.PictureRecorder();
  VerseBackgroundPainter(d, scheme).paint(Canvas(recorder), size);
  final image = await recorder
      .endRecording()
      .toImage(size.width.round(), size.height.round());
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  return data;
}

/// Contraste minimal de [ink] sur la zone de texte (un pixel sur 2).
double _minContrast(ByteData px, Size size, Color ink) {
  final w = size.width.round();
  final h = size.height.round();
  final x0 = (w * kVerseTextZoneInset).ceil();
  final y0 = (h * kVerseTextZoneInset).ceil();
  var m = 21.0;
  for (var y = y0; y < h - y0; y += 2) {
    for (var x = x0; x < w - x0; x += 2) {
      final i = (y * w + x) * 4;
      final c = Color.fromARGB(255, px.getUint8(i), px.getUint8(i + 1), px.getUint8(i + 2));
      m = math.min(m, contrastRatio(ink, c));
    }
  }
  return m;
}

void main() {
  test('au moins 10 designs, identifiants uniques', () {
    expect(kVerseDesigns.length, greaterThanOrEqualTo(10));
    expect(kVerseDesigns.map((d) => d.id).toSet().length, kVerseDesigns.length);
    expect(VerseMood.values.every((m) => kVerseDesigns.any((d) => d.mood == m)), isTrue);
  });

  test('design du jour : déterministe, change le lendemain', () {
    final a = dailyVerseDesign(DateTime(2026, 10, 13, 8));
    expect(dailyVerseDesign(DateTime(2026, 10, 13, 23, 59)).id, a.id);
    expect(dailyVerseDesign(DateTime(2026, 10, 14)).id, isNot(a.id));
    final month = {for (var i = 0; i < kVerseDesigns.length; i++) dailyVerseDesign(DateTime(2026, 1, 1 + i)).id};
    expect(month.length, kVerseDesigns.length, reason: 'tous les designs reviennent');
  });

  for (final brightness in Brightness.values) {
    final scheme = appColorScheme(brightness: brightness);
    final mode = brightness == Brightness.dark ? 'sombre' : 'clair';
    testWidgets('contraste ≥ 4,5:1 — thème $mode', (tester) async {
      await tester.runAsync(VerseGrain.ensure);
      final report = StringBuffer('\nContraste mesuré (thème $mode) — encre / accent :\n');
      for (final d in kVerseDesigns) {
        report.write('  ${d.name.padRight(15)}');
        for (final e in _sizes.entries) {
          final r = d.resolve(scheme, e.value);
          final px = (await tester.runAsync(() => _render(d, scheme, e.value)))!;
          final ink = _minContrast(px, e.value, r.ink);
          final accent = _minContrast(px, e.value, r.accent);
          report.write(' | ${e.key} ${ink.toStringAsFixed(1)}/${accent.toStringAsFixed(1)}'
              '${r.scrimOpacity > 0 ? ' voile ${(r.scrimOpacity * 100).round()} %' : ''}');
          expect(ink, greaterThanOrEqualTo(kMinVerseContrast),
              reason: '${d.name} ($mode, ${e.key}) : encre ${ink.toStringAsFixed(2)}');
          expect(accent, greaterThanOrEqualTo(kMinVerseContrast),
              reason: '${d.name} ($mode, ${e.key}) : accent ${accent.toStringAsFixed(2)}');
        }
        report.writeln();
      }
      // ignore: avoid_print
      print(report);
    });
  }
}
