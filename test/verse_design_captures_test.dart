// Captures des designs du verset du jour (avec les vraies polices) :
//   VERSE_CAPTURES=<dossier> flutter test test/verse_design_captures_test.dart
// Sans la variable, le test est ignoré.
//
// Produit : cartes (thème clair / sombre), plein écran, défilement (cartes
// blanches), sélecteur et images de partage.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/core/theme/app_text_styles.dart';
import 'package:testi_app/features/daily_verse/design/verse_background_painter.dart';
import 'package:testi_app/features/daily_verse/design/verse_design.dart';
import 'package:testi_app/features/daily_verse/design/verse_share_image.dart';
import 'package:testi_app/features/daily_verse/design/verse_style_prefs.dart';
import 'package:testi_app/features/daily_verse/screens/daily_verse_screen.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/home/widgets/daily_verse_banner.dart';

final _out = Platform.environment['VERSE_CAPTURES'];

const _verse = DailyVerse(
  id: 0,
  text: 'Béni soit l’homme qui se confie dans l’Éternel, et dont l’Éternel est l’espérance !',
  reference: 'Jérémie 17:7',
  likeCount: 128,
  prayerCount: 42,
);

class _Verse extends DailyVerseNotifier {
  @override
  Future<DailyVerse> build() async => _verse;
}

Future<void> _loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final f in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(f['asset'] as String));
    }
    await loader.load();
  }
}

ThemeData _theme(Brightness b) => ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.family,
      colorScheme: appColorScheme(brightness: b),
      scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF111318) : AppColors.background,
    );

Future<void> _save(WidgetTester tester, GlobalKey key, String name, {double ratio = 2}) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_out${Platform.pathSeparator}$name.png').writeAsBytes(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async => null);
  });

  final skip = _out == null ? 'VERSE_CAPTURES non défini' : null;

  for (final b in Brightness.values) {
    final mode = b == Brightness.dark ? 'sombre' : 'clair';
    testWidgets('cartes de l’accueil — thème $mode', (tester) async {
      await tester.runAsync(VerseGrain.ensure);
      await tester.binding.setSurfaceSize(const Size(1180, 1500));
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: _theme(b),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: _theme(b).scaffoldBackgroundColor,
              child: Wrap(
                children: [
                  for (final d in kVerseDesigns)
                    SizedBox(
                      width: 390,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ProviderScope(
                            overrides: [
                              dailyVerseProvider.overrideWith(_Verse.new),
                              currentVerseDesignProvider.overrideWithValue(d),
                            ],
                            child: const DailyVerseBanner(),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 20, bottom: 6),
                            child: Text('${d.name} · ${d.mood.label}',
                                style: TextStyle(fontSize: 12, color: _theme(b).colorScheme.onSurface)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _save(tester, key, 'cartes_$mode');
      await tester.binding.setSurfaceSize(null);
    }, skip: skip != null);
  }

  for (final id in ['aube', 'nuit', 'or', 'ocean', 'minimal', 'braise']) {
    testWidgets('plein écran — $id', (tester) async {
      await tester.runAsync(VerseGrain.ensure);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            dailyVerseProvider.overrideWith(_Verse.new),
            currentVerseDesignProvider.overrideWithValue(verseDesignById(id)!),
          ],
          child: MaterialApp(
            theme: _theme(Brightness.light),
            debugShowCheckedModeBanner: false,
            home: const DailyVerseScreen(),
          ),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _save(tester, key, 'plein_ecran_$id');

      if (id == 'aube') {
        // Défilement : versions et participation sur cartes blanches.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
        await tester.pumpAndSettle();
        await _save(tester, key, 'plein_ecran_defilement');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
        await tester.pumpAndSettle();
        // Sélecteur de designs.
        await tester.tap(find.bySemanticsLabel(RegExp('Changer le design')));
        await tester.pumpAndSettle();
        await _save(tester, key, 'selecteur_fonds');
        await tester.tap(find.text('Texte'));
        await tester.pumpAndSettle();
        await _save(tester, key, 'selecteur_texte');
      }
      await tester.binding.setSurfaceSize(null);
    }, skip: skip != null);
  }

  testWidgets('images de partage', (tester) async {
    await tester.runAsync(VerseGrain.ensure);
    for (final (id, font, align) in [
      ('aube', VerseFont.lora, VerseAlign.start),
      ('nuit', VerseFont.sourceSerif, VerseAlign.center),
      ('braise', VerseFont.nunitoSans, VerseAlign.start),
      ('or', VerseFont.inter, VerseAlign.center),
    ]) {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: _theme(Brightness.light),
        debugShowCheckedModeBanner: false,
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: VerseShareCard(
              design: verseDesignById(id)!,
              prefs: VerseStylePrefs(font: font, align: align),
              text: _verse.text,
              reference: _verse.reference,
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await _save(tester, key, 'partage_$id', ratio: 3);
    }
  }, skip: skip != null);
}
