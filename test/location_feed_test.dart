// Fils classés par zone : lecture des réponses (réglage, meta.place, meta.nearby), bandeau
// « Près de chez vous · … » et invitation refermable, étiquette des cartes proches, réglage
// « Utiliser ma position… » ; sans débordement à 320 px avec une police ×1,3.
// Doc serveur : docs/fonctionnalites/localisation.md

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart' show currentUserProvider;
import 'package:testi_app/features/location/location_providers.dart';
import 'package:testi_app/features/location/location_settings_screen.dart';
import 'package:testi_app/features/location/nearby_widgets.dart';
import 'package:testi_app/features/location/user_location.dart';
import 'package:testi_app/shared/models/user_model.dart';

const _longCity = 'Abomey-Calavi Akassato Zopah Quartier Résidentiel des Cocotiers';

class _FakeLocation extends UserLocationNotifier {
  _FakeLocation(this.initial);
  final UserLocationSettings initial;
  final calls = <String>[];

  @override
  Future<UserLocationSettings> build() async => initial;

  @override
  Future<void> enableAndLocate() async {
    calls.add('locate');
    state = const AsyncData(UserLocationSettings(
      useGps: true, source: 'gps', label: 'Cotonou', locality: 'Akpakpa', country: 'Bénin', hasCoordinates: true,
    ));
  }

  @override
  Future<void> disable() async {
    calls.add('disable');
    state = const AsyncData(UserLocationSettings(source: 'profile', label: 'Bénin', country: 'Bénin'));
  }

  @override
  Future<void> erase() async {
    calls.add('erase');
    state = const AsyncData(UserLocationSettings());
  }
}

class _Labels extends NearbyLabelsNotifier {
  @override
  Map<String, String> build() => const {'t1': 'À $_longCity'};
}

class _Prompt extends LocationPromptNotifier {
  @override
  bool build() => false;

  @override
  Future<void> dismiss() async => state = true;
}

Widget _app(Widget child, {double textScale = 1.0, List overrides = const [], bool signedIn = true}) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(signedIn ? const UserModel(id: 'me', displayName: 'Moi') : null),
        locationPromptDismissedProvider.overrideWith(_Prompt.new),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: child,
      ),
    );

void _small(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async => null);
  });

  group('lecture des réponses', () {
    test('réglage GET /users/me/location', () {
      final s = UserLocationSettings.fromJson({
        'useGps': true, 'source': 'gps', 'label': 'Cotonou', 'locality': 'Akpakpa', 'city': 'Cotonou',
        'countryCode': 'bj', 'country': 'Bénin', 'latitude': 6.37, 'longitude': 2.43,
        'updatedAt': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      });
      expect(s.usesGps, isTrue);
      expect(s.hasCoordinates, isTrue);
      expect(s.describe(), 'Akpakpa, Cotonou, Bénin (position de l’appareil)');
      expect(s.isStale(DateTime.now()), isTrue);
      expect(UserLocationSettings.fromJson(null).describe(), contains('Aucune zone connue'));
      expect(UserLocationSettings.fromJson({'source': 'profile', 'label': 'Bénin', 'country': 'Bénin'}).describe(),
          'Bénin (ville et pays du profil)');
    });

    test('meta.place et meta.nearby des fils', () {
      final meta = {
        'currentPage': 1,
        'place': {'label': 'Cotonou', 'precision': 'city', 'source': 'gps'},
        'nearby': {'t1': 'À Cotonou', 't2': 'Au Bénin', 't3': ''},
      };
      final place = FeedPlace.fromMeta(meta)!;
      expect(place.label, 'Cotonou');
      expect(place.fromGps, isTrue);
      expect(parseNearbyLabels(meta), {'t1': 'À Cotonou', 't2': 'Au Bénin'});
      expect(FeedPlace.fromMeta({'place': null}), isNull);
      expect(parseNearbyLabels({'nearby': []}), isEmpty); // objet vide encodé en liste par PHP
    });
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('bandeau et étiquette sans débordement (320 px, ×$scale)', (tester) async {
      _small(tester);
      await tester.pumpWidget(_app(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: const [
              NearbyFeedBanner(place: FeedPlace(label: _longCity, source: 'profile')),
              NearbyCardLabel(testimonyId: 't1'),
              NearbyCardLabel(testimonyId: 't2'),
            ]),
          ),
        ),
        textScale: scale,
        overrides: [nearbyLabelsProvider.overrideWith(_Labels.new)],
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Près de chez vous · '), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsOneWidget); // t2 : pas d'étiquette
      expect(find.text('Activez votre position pour des témoignages proches de vous'), findsOneWidget);
      expect(find.text('À $_longCity'), findsOneWidget);

      // Invitation refermable.
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pump();
      expect(find.text('Activez votre position pour des témoignages proches de vous'), findsNothing);
      expect(find.textContaining('Près de chez vous · '), findsOneWidget);
    });
  }

  testWidgets('pas d’invitation avec la position GPS, ni pour un invité', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(
      body: NearbyFeedBanner(place: FeedPlace(label: 'Cotonou', source: 'gps')),
    ), overrides: [userLocationProvider.overrideWith(() => _FakeLocation(const UserLocationSettings()))]));
    await tester.pump();
    expect(find.text('Près de chez vous · Cotonou'), findsOneWidget);
    expect(find.textContaining('Activez votre position'), findsNothing);
  });

  testWidgets('invité sans zone : rien n’est affiché', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: NearbyFeedBanner(place: null)), signedIn: false));
    await tester.pump();
    expect(find.textContaining('Activez votre position'), findsNothing);
    expect(find.textContaining('Près de chez vous'), findsNothing);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('réglage de localisation : activer, désactiver, supprimer (320 px, ×$scale)', (tester) async {
      _small(tester);
      final fake = _FakeLocation(UserLocationSettings(
        source: 'profile', label: _longCity, country: 'Bénin', homeCity: _longCity,
      ));
      await tester.pumpWidget(_app(const LocationSettingsScreen(), textScale: scale, overrides: [
        userLocationProvider.overrideWith(() => fake),
      ]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Utiliser ma position pour personnaliser mes fils'), findsOneWidget);
      expect(find.text('Mettre à jour ma position'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(fake.calls, ['locate']);
      expect(find.text('Akpakpa, Cotonou, Bénin (position de l’appareil)'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(fake.calls, ['locate', 'disable']);

      tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Supprimer ma position'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Supprimer ma position'));
      await tester.pumpAndSettle();
      expect(fake.calls.last, 'erase');
      expect(find.textContaining('Aucune zone connue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
