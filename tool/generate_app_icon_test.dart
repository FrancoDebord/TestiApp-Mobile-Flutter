// Génère les images de l'icône de l'application à partir du logo dessiné dans
// l'app (AppLogoPainter : rayons, soleil, croix, colline), puis :
//   flutter test tool/generate_app_icon_test.dart
//   dart run flutter_launcher_icons
//
//   assets/icon/app_icon.png            1024 × 1024, fond blanc (iOS, web, Android ancien)
//   assets/icon/app_icon_foreground.png 1024 × 1024, fond transparent, logo dans la
//                                       zone sûre des icônes adaptatives Android (66 %)

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/shared/widgets/app_logo.dart';

const double _size = 1024;

/// Dessine le logo centré, sur [width] pixels de large (hauteur = largeur / 1,25).
Future<void> _render(String path, {required double width, Color? background}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, _size, _size));
  if (background != null) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, _size, _size), Paint()..color = background);
  }
  final height = width / 1.25;
  // Le haut du cadre du dessin reste vide (au-dessus des rayons) : léger
  // décalage vers le bas pour un centrage visuel.
  final dx = (_size - width) / 2;
  final dy = (_size - height) / 2 + height * 0.02;
  canvas.translate(dx, dy);
  const AppLogoPainter().paint(canvas, Size(width, height));
  final image = await recorder.endRecording().toImage(_size.toInt(), _size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  test('icône de l’application depuis le logo actuel', () async {
    await _render('assets/icon/app_icon.png', width: _size * 0.80, background: Colors.white);
    // Icône adaptative : seul le disque central (≈ 66 %) est toujours visible.
    await _render('assets/icon/app_icon_foreground.png', width: _size * 0.50);
    expect(File('assets/icon/app_icon.png').lengthSync(), greaterThan(1000));
  });
}
