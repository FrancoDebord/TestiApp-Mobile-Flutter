// Sélecteur de designs du verset (onglets Fonds et Texte) : aucun débordement,
// des petits écrans aux grandes tailles de texte.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testi_app/features/daily_verse/design/verse_design_picker.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async => null);
  });

  for (final width in [320.0, 390.0]) {
    for (final height in [640.0, 844.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('sélecteur sans débordement ($width × $height, ×$scale)', (tester) async {
          tester.view.physicalSize = Size(width * 2, height * 2);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (c) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => showVerseDesignPicker(
                        c,
                        text: 'Béni soit l’homme qui se confie dans l’Éternel, et dont l’Éternel est l’espérance !',
                        reference: 'Jérémie 17:7',
                      ),
                      child: const Text('Ouvrir'),
                    ),
                  ),
                ),
              ),
            ),
          ));
          await tester.tap(find.text('Ouvrir'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'onglet Fonds');
          expect(find.text('Toujours utiliser mon design'), findsOneWidget);

          await tester.tap(find.text('Texte'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'onglet Texte');
        });
      }
    }
  }
}
