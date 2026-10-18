// Temps de prière immersif : 5 minutes avant de pouvoir valider « J'ai prié ».

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/prayer/models/prayer_models.dart';
import 'package:testi_app/features/prayer/screens/prayer_focus_screen.dart';

final _request = PrayerRequest.fromJson({
  'id': 'r1',
  'body': 'Priez pour la guérison de ma mère, hospitalisée depuis deux semaines à Cotonou.',
  'author': {'id': 'u1', 'displayName': 'Afi Mensah'},
  'prayerCount': 4,
});

Future<bool?> _open(WidgetTester tester, {Size size = const Size(390, 844), double scale = 1}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  bool? result;
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery.withClampedTextScaling(
      minScaleFactor: scale,
      maxScaleFactor: scale,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => PrayerFocusScreen(request: _request, keepScreenOn: false),
                ));
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ouvrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return result;
}

FilledButton _validate(WidgetTester tester) =>
    tester.widget<FilledButton>(find.ancestor(of: find.text('Valider ma prière'), matching: find.byWidgetPredicate((w) => w is FilledButton)));

void main() {
  testWidgets('sujet affiché, compte à rebours lancé, validation impossible avant 5 min', (tester) async {
    await _open(tester);
    expect(find.text('Temps de prière'), findsOneWidget);
    expect(find.textContaining('guérison de ma mère'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text("J'ai prié pour cette requête"), findsNothing);
    expect(_validate(tester).onPressed, isNull);

    await tester.pump(const Duration(minutes: 2));
    expect(find.text('03:00'), findsOneWidget);
    expect(_validate(tester).onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('après 5 min : cocher « J\'ai prié » puis valider', (tester) async {
    bool? result;
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => PrayerFocusScreen(request: _request, keepScreenOn: false),
          )),
          child: const Text('ouvrir'),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 5, seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text("J'ai prié pour cette requête"), findsOneWidget);
    // Pas encore coché : bouton inactif.
    expect(_validate(tester).onPressed, isNull);

    await tester.tap(find.text("J'ai prié pour cette requête"));
    await tester.pump();
    expect(_validate(tester).onPressed, isNotNull);
    await tester.tap(find.text('Valider ma prière'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('quitter sans valider : rien n\'est enregistré', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => PrayerFocusScreen(request: _request, keepScreenOn: false),
          )),
          child: const Text('ouvrir'),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Quitter sans valider'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('le temps ne court pas quand l\'application est en arrière-plan', (tester) async {
    await _open(tester);
    await tester.pump(const Duration(minutes: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('04:00'), findsOneWidget);
    expect(_validate(tester).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in const [Size(320, 568), Size(390, 844)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('sans débordement (${size.width.toInt()} px, ×$scale)', (tester) async {
        await _open(tester, size: size, scale: scale);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(minutes: 5, seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
