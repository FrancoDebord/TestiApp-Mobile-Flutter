// Écran de lancement : textes affichés, barre de chargement, et aucun
// débordement sur petit écran avec une grande taille de police.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/auth/screens/splash_screen.dart';

/// Session jamais résolue : le splash reste affiché, sans navigation.
class _PendingAuth extends AuthNotifier {
  @override
  Future<AuthState> build() => Completer<AuthState>().future;
}

void main() {
  for (final (w, h, scale) in [
    (320.0, 568.0, 1.3),
    (390.0, 844.0, 1.0),
    (768.0, 1024.0, 1.0),
  ]) {
    testWidgets('splash ${w.toInt()}×${h.toInt()} (×$scale) sans débordement',
        (tester) async {
      tester.view.physicalSize = Size(w * 2, h * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        overrides: [authStateProvider.overrideWith(_PendingAuth.new)],
        child: MaterialApp(
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: c!,
          ),
          home: const SplashScreen(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1200));

      expect(tester.takeException(), isNull);
      expect(find.text('Chargement…'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Témoignages de Gloire')),
          findsOneWidget);
    });
  }
}
