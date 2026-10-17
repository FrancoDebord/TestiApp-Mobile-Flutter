// Témoignage de conversion (docs serveur fonctionnalites/temoignage-de-conversion.md)
// et direct YouTube d'un événement (docs serveur fonctionnalites/evenements.md).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart' show currentUserProvider;
import 'package:testi_app/features/conversion/data/conversion_repository.dart';
import 'package:testi_app/features/conversion/providers/conversion_providers.dart';
import 'package:testi_app/features/conversion/screens/conversion_testimonies_screen.dart';
import 'package:testi_app/features/conversion/widgets/conversion_widgets.dart';
import 'package:testi_app/features/events/models/event_models.dart';
import 'package:testi_app/features/home/providers/home_providers.dart' show testimonyFromApiJson;
import 'package:testi_app/features/publish/providers/publish_provider.dart' show ConversionFields;
import 'package:testi_app/shared/models/user_model.dart';

Map<String, dynamic> _testimony({bool conversion = true, Map<String, dynamic>? details}) => {
      'id': 't1',
      'title': "Comment j'ai rencontré Jésus",
      'type': 'text',
      'bodyText': "J'avais 17 ans, à une croisade sur la plage de Fidjrossè…",
      'category': 'conversion',
      'createdAt': '2026-10-15T10:00:00+00:00',
      'status': 'approved',
      'kind': conversion ? 'conversion' : 'standard',
      'isConversion': conversion,
      'conversion': conversion ? (details ?? {'year': 2012, 'place': 'Cotonou', 'verse': 'Jean 3:16'}) : null,
      'user': {'id': 'u1', 'displayName': 'Afi Mensah'},
      'stats': {'viewsCount': 3},
    };

Map<String, dynamic> _event({Map<String, dynamic>? youtubeLive, String phase = 'upcoming'}) => {
      'id': 'e1',
      'title': 'Croisade de Cotonou',
      'type': 'crusade',
      'status': 'published',
      'phase': phase,
      'startsAt': '2026-10-12T17:00:00+00:00',
      'endsAt': '2026-10-14T21:00:00+00:00',
      'organizer': {'id': 'o1', 'displayName': 'Église de la Grâce'},
      'youtubeLive': youtubeLive,
    };

void main() {
  group('Témoignage de conversion', () {
    test('lit kind, isConversion et conversion { year, place, verse }', () {
      final t = testimonyFromApiJson(_testimony())!;
      expect(t.isConversion, isTrue);
      expect(t.conversion!.year, 2012);
      expect(t.conversion!.place, 'Cotonou');
      expect(t.conversion!.verse, 'Jean 3:16');
      expect(t.conversion!.summary, '2012 · Cotonou · Jean 3:16');
    });

    test('témoignage standard : pas de détails de conversion', () {
      final t = testimonyFromApiJson(_testimony(conversion: false))!;
      expect(t.isConversion, isFalse);
      expect(t.conversion, isNull);
    });

    test('conversion sans détails : reconnue, détails vides', () {
      final t = testimonyFromApiJson(_testimony(details: {'year': null, 'place': null, 'verse': null}))!;
      expect(t.isConversion, isTrue);
      expect(t.conversion!.hasDetails, isFalse);
    });

    test('champs envoyés à la publication et à la modification', () {
      expect(const ConversionFields(year: 2012, place: ' Cotonou ', verse: '').toJson(), {
        'kind': 'conversion',
        'conversion_year': 2012,
        'conversion_place': 'Cotonou',
        'conversion_verse': null,
      });
      expect(
        const ConversionEdit(title: ' Ma conversion ', bodyText: 'Texte', place: '').toJson(),
        {
          'title': 'Ma conversion',
          'body_text': 'Texte',
          'kind': 'conversion',
          'conversion_year': null,
          'conversion_place': null,
          'conversion_verse': null,
        },
      );
    });

    test('année de conversion : de 1900 à l’année en cours', () {
      expect(isValidConversionYear(1899), isFalse);
      expect(isValidConversionYear(1900), isTrue);
      expect(isValidConversionYear(DateTime.now().year), isTrue);
      expect(isValidConversionYear(DateTime.now().year + 1), isFalse);
    });

    testWidgets('bandeau de la page du témoignage', (tester) async {
      final t = testimonyFromApiJson(_testimony())!;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ConversionBanner(details: t.conversion!, onEdit: () {})),
      ));
      expect(find.text('Témoignage de conversion'), findsOneWidget);
      expect(find.textContaining('2012'), findsOneWidget);
      expect(find.textContaining('Jean 3:16'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
    });

    testWidgets('section : liste et invitation à raconter sa conversion', (tester) async {
      final t = testimonyFromApiJson(_testimony())!;
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const ConversionTestimoniesScreen()),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          conversionListProvider.overrideWith(_FakeList.new),
          myConversionProvider.overrideWith((ref) async => const MyConversion(canCreate: true)),
          currentUserProvider.overrideWithValue(
              const UserModel(id: 'u1', displayName: 'Afi Mensah')),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Témoignages de conversion'), findsWidgets);
      expect(find.text('Racontez comment vous avez rencontré Jésus'), findsOneWidget);
      expect(find.text(t.title), findsOneWidget);
      expect(find.text('Conversion'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Direct YouTube d’un événement', () {
    test('youtubeLive → identifiant, lien et « en direct » pendant l’événement', () {
      final e = ChristianEvent.fromJson(_event(
        phase: 'ongoing',
        youtubeLive: {'id': 'dQw4w9WgXcQ', 'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
      ));
      expect(e.youtubeLiveId, 'dQw4w9WgXcQ');
      expect(e.youtubeLiveUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(e.isLiveNow, isTrue);
    });

    test('sans lien : rien ; à venir : pas encore en direct', () {
      expect(ChristianEvent.fromJson(_event()).youtubeLiveId, isNull);
      final upcoming = ChristianEvent.fromJson(_event(youtubeLive: {'id': 'dQw4w9WgXcQ'}));
      expect(upcoming.isLiveNow, isFalse);
    });

    test('formulaire : lien envoyé, vide = effacé', () {
      final e = ChristianEvent.fromJson(_event(youtubeLive: {'id': 'dQw4w9WgXcQ'}));
      final draft = EventDraft.fromEvent(e);
      expect(draft.toJson()['youtube_live_url'], 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      draft.youtubeLiveUrl = '  ';
      expect(draft.toJson().containsKey('youtube_live_url'), isTrue);
      expect(draft.toJson()['youtube_live_url'], isNull);
    });
  });
}

class _FakeList extends ConversionListNotifier {
  @override
  Future<ConversionListState> build() async =>
      ConversionListState(items: [testimonyFromApiJson(_testimony())!]);
}
