import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/events/models/event_models.dart';
import 'package:testi_app/features/events/widgets/event_location_widgets.dart';

/// Lieu des événements : adresse, repère GPS, itinéraire — docs serveur fonctionnalites/evenements.md
Map<String, dynamic> _json({Object? lat = 6.3702928, Object? lng = 2.391236, String? directions}) => {
      'id': 'e1',
      'title': 'Grande croisade',
      'type': 'crusade',
      'status': 'published',
      'phase': 'upcoming',
      'location': "Stade de l'Amitié",
      'address': 'Boulevard de la Marina',
      'city': 'Cotonou',
      'country': 'Bénin',
      'latitude': lat,
      'longitude': lng,
      'directionsUrl': directions,
      'organizer': {'id': 'o1', 'displayName': 'Église'},
    };

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  setUp(() => debugDisableEventMapTiles = true);

  group('JSON', () {
    test('adresse et coordonnées (nombres ou chaînes)', () {
      final e = ChristianEvent.fromJson(_json(
          directions: 'https://www.google.com/maps/dir/?api=1&destination=6.3702928,2.391236'));
      expect(e.address, 'Boulevard de la Marina');
      expect(e.latitude, 6.3702928);
      expect(e.longitude, 2.391236);
      expect(e.hasCoordinates, isTrue);
      expect(e.fullAddress, "Stade de l'Amitié, Boulevard de la Marina, Cotonou, Bénin");
      expect(e.directionsUrl, contains('destination=6.3702928,2.391236'));

      final s = ChristianEvent.fromJson(_json(lat: '6.5', lng: '2.25'));
      expect(s.latitude, 6.5);
      expect(s.longitude, 2.25);
    });

    test('sans repère : itinéraire par adresse', () {
      final e = ChristianEvent.fromJson(_json(lat: null, lng: null));
      expect(e.hasCoordinates, isFalse);
      expect(e.hasPlace, isTrue);
      final web = EventDirections.googleMapsUrl(e)!;
      expect(web.host, 'www.google.com');
      expect(web.queryParameters['destination'], e.fullAddress);
    });

    test('brouillon : coordonnées envoyées ensemble, null pour effacer', () {
      final d = EventDraft.fromEvent(ChristianEvent.fromJson(_json()));
      expect(d.address, 'Boulevard de la Marina');
      expect(d.toJson()['latitude'], 6.3702928);
      d.latitude = 6.123456789;
      expect(d.toJson()['latitude'], 6.1234568);
      d.longitude = null;
      expect(d.toJson()['latitude'], isNull);
      expect(d.toJson()['longitude'], isNull);
      expect(d.toJson().containsKey('latitude'), isTrue);
    });
  });

  group('Itinéraire selon la plateforme', () {
    final e = ChristianEvent.fromJson(_json());

    test('Android : geo: puis Google Maps', () {
      final uris = EventDirections.candidates(e, platform: TargetPlatform.android);
      expect(uris.first.scheme, 'geo');
      expect(uris.first.toString(), startsWith('geo:6.3702928,2.391236?q=6.3702928,2.391236('));
      expect(uris.last.host, 'www.google.com');
    });

    test('iOS : Plans puis Google Maps', () {
      final uris = EventDirections.candidates(e, platform: TargetPlatform.iOS);
      expect(uris.first.host, 'maps.apple.com');
      expect(uris.first.queryParameters['daddr'], '6.3702928,2.391236');
      expect(uris.last.host, 'www.google.com');
    });

    test('web : Google Maps seulement', () {
      final uris = EventDirections.candidates(e, platform: TargetPlatform.android, isWeb: true);
      expect(uris, hasLength(1));
      expect(uris.single.queryParameters['destination'], '6.3702928,2.391236');
    });

    test('aucun lieu : aucun lien', () {
      final none = ChristianEvent.fromJson({
        'id': 'x', 'title': 'T', 'organizer': {'id': 'o'},
      });
      expect(none.hasPlace, isFalse);
      expect(EventDirections.candidates(none, platform: TargetPlatform.android), isEmpty);
    });
  });

  group('Widgets', () {
    testWidgets('bloc « Lieu » : adresse, carte, Itinéraire, Copier', (tester) async {
      await tester.pumpWidget(_wrap(EventPlaceCard(event: ChristianEvent.fromJson(_json()))));
      expect(find.text('Lieu'), findsOneWidget);
      expect(find.text('Boulevard de la Marina'), findsOneWidget);
      expect(find.text('Cotonou, Bénin'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('© contributeurs OpenStreetMap'), findsOneWidget);
      expect(find.text('Itinéraire'), findsOneWidget);
      expect(find.text("Copier l'adresse"), findsOneWidget);
    });

    testWidgets('bloc « Lieu » sans repère : pas de carte', (tester) async {
      await tester.pumpWidget(
          _wrap(EventPlaceCard(event: ChristianEvent.fromJson(_json(lat: null, lng: null)))));
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Itinéraire'), findsOneWidget);
    });

    testWidgets('sélecteur : toucher place le repère, Effacer le retire', (tester) async {
      double? lat;
      double? lng = 0;
      await tester.pumpWidget(_wrap(EventMapPicker(
        latitude: null,
        longitude: null,
        addressQuery: () => 'Cotonou',
        onChanged: (a, b) {
          lat = a;
          lng = b;
        },
      )));
      expect(find.text('Ma position'), findsOneWidget);
      expect(find.text("Chercher l'adresse"), findsOneWidget);
      expect(find.text('Effacer le repère'), findsNothing);

      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      // flutter_map attend la fin du délai de double-toucher avant d'appeler onTap.
      await tester.pump(const Duration(milliseconds: 600));
      expect(lat, isNotNull);
      expect(lng, isNotNull);
      expect(find.text('Effacer le repère'), findsOneWidget);

      await tester.tap(find.text('Effacer le repère'));
      await tester.pump();
      expect(lat, isNull);
      expect(lng, isNull);
      expect(find.textContaining('Aucun repère placé'), findsOneWidget);
    });
  });
}
