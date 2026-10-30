// « Qui a réagi ? » et « Prier plusieurs fois », alignés sur le serveur.
// Docs serveur : fonctionnalites/qui-a-reagi.md, prier-plusieurs-fois.md

import 'package:dio/dio.dart' show Options;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/prayer/models/prayer_models.dart';
import 'package:testi_app/features/prayer/widgets/prayer_widgets.dart';
import 'package:testi_app/features/reactions/reaction_people.dart';
import 'package:testi_app/features/repost/content_interactions.dart';
import 'package:testi_app/l10n/app_localizations.dart';
import 'package:testi_app/services/api_service.dart';

typedef _Call = ({String method, String path, Object? data, Map<String, dynamic>? query});

class _Api implements ApiService {
  final calls = <_Call>[];

  /// Réponse de GET …/reactions/people selon le filtre.
  Map<String, dynamic> Function(Map<String, dynamic>? query) people = (_) => const {};

  /// Réponse des POST / DELETE.
  Map<String, dynamic> reply = const {};

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    calls.add((method: 'GET', path: path, data: null, query: query));
    return LaravelResponse<T>(success: true, data: people(query) as T, meta: const {'currentPage': 1, 'lastPage': 1});
  }

  @override
  Future<LaravelResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query, Options? options}) async {
    calls.add((method: 'POST', path: path, data: data, query: query));
    return LaravelResponse<T>(success: true, data: reply as T);
  }

  @override
  Future<LaravelResponse<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? query, Options? options}) async {
    calls.add((method: 'DELETE', path: path, data: data, query: query));
    return LaravelResponse<T>(success: true, data: reply as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

const _summary = {
  'total': 3,
  'likesCount': 2,
  'prayersCount': 2,
  'types': [
    {'type': 'like', 'group': 'appreciation', 'label': "J'aime", 'emoji': '👍', 'icon': 'fa-thumbs-up', 'count': 2},
    {'type': 'pray', 'group': 'prayer', 'label': 'Je prie', 'emoji': '🙏', 'icon': 'fa-hands-praying', 'count': 2},
  ],
};

Map<String, dynamic> _person(String id, String name, List<String> reactions, {int prayerTimes = 0}) => {
      'id': id,
      'displayName': name,
      'initials': name[0],
      'avatarUrl': null,
      'isVerified': id == 'u1',
      'reactions': reactions,
      'prayerTimes': prayerTimes,
      'reactedAt': '2026-10-26T10:00:00+00:00',
    };

Testimony _testimony({String id = 't1', bool prayed = false, int times = 0, int prayers = 2}) => testimonyFromApiJson({
      'id': id,
      'user': {'id': 'u9', 'display_name': 'Awa'},
      'title': 'Guérison',
      'type': 'text',
      'bodyText': 'Texte',
      'stats': {'likesCount': 0, 'prayersCount': prayers, 'commentsCount': 0},
      'isPrayedByMe': prayed,
      'myPrayerTimes': times,
    })!;

void main() {
  group('qui a réagi', () {
    test('effectifs et personnes lus comme le serveur les renvoie', () async {
      final api = _Api()
        ..people = (_) => {
              'summary': _summary,
              'people': [
                _person('u1', 'Afi', ['like', 'pray'], prayerTimes: 3),
                _person('u2', 'Koffi', ['like']),
              ],
            };
      final page = await fetchReactionPeople(api, ReactionSubject.testimony.peoplePath('t1'), type: 'prayer');
      expect(api.calls.single.path, '/testimonies/t1/reactions/people');
      expect(api.calls.single.query, {'type': 'prayer', 'page': 1});
      expect(page.summary.total, 3);
      expect(page.summary.types.map((t) => '${t.type}:${t.count}'), ['like:2', 'pray:2']);
      expect(page.people.first.prayerTimes, 3);
      expect(page.people.first.isVerified, isTrue);
      expect(page.people.last.reactions, ['like']);
      expect(ReactionSubject.dailyVerse.peoplePath('12'), '/daily-verse/12/reactions/people');
      expect(ContentKind.prayerRequest.reactionSubject.peoplePath('r1'), '/prayer/requests/r1/reactions/people');
    });

    testWidgets('feuille : onglets par réaction, personnes, « a prié 3 fois », filtre', (tester) async {
      final api = _Api()
        ..people = (q) => {
              'summary': _summary,
              'people': [
                if (q?['type'] != 'like') _person('u1', 'Afi', ['pray'], prayerTimes: 3),
                if (!{'pray', 'prayer'}.contains(q?['type'])) _person('u2', 'Koffi', ['like']),
              ],
            };
      await tester.pumpWidget(ProviderScope(
        overrides: [apiServiceProvider.overrideWithValue(api)],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ReactionPeopleSheet(path: '/testimonies/t1/reactions/people', initialType: 'prayer')),
        ),
      ));
      await tester.pumpAndSettle();

      // Ouvert sur « Je prie » : seule réaction de prière présente → son onglet.
      expect(find.text('Toutes  3'), findsOneWidget);
      expect(find.text("👍 J'aime  2"), findsOneWidget);
      final pray = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '🙏 Je prie  2'));
      expect(pray.selected, isTrue);
      expect(find.text('Afi'), findsOneWidget);
      expect(find.text('A prié 3 fois'), findsOneWidget);
      expect(find.text('Koffi'), findsNothing);

      await tester.tap(find.text("👍 J'aime  2"));
      await tester.pumpAndSettle();
      expect(api.calls.last.query, {'type': 'like', 'page': 1});
      expect(find.text('Koffi'), findsOneWidget);
      expect(find.text('Afi'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('prier plusieurs fois', () {
    test('témoignage : prier encore, retirer la dernière prière ; compteur = personnes', () async {
      final api = _Api();
      final c = ProviderContainer(overrides: [apiServiceProvider.overrideWithValue(api)]);
      addTearDown(c.dispose);
      final n = c.read(interactionProvider.notifier);
      final t = _testimony(prayed: true, times: 2);
      expect(c.read(interactionProvider).prayerTimesOf(t), 2);

      api.reply = {'isPrayedByMe': true, 'myPrayerTimes': 3, 'prayersCount': 2};
      await n.pray(t);
      expect(api.calls.last.data, {'type': 'pray', 'again': true});
      expect(c.read(interactionProvider).prayerTimesOf(t), 3);
      expect(c.read(interactionProvider).prayersOf(t), 2);

      api.reply = {'isPrayedByMe': true, 'myPrayerTimes': 2, 'prayersCount': 2};
      await n.removeLastPrayer(t);
      expect(api.calls.last.method, 'DELETE');
      expect(api.calls.last.query, {'group': 'prayer', 'last': 1});
      expect(c.read(interactionProvider).prayerTimesOf(t), 2);

      // Première prière d'une autre personne : le compteur monte d'un.
      final other = _testimony(id: 't2');
      api.reply = const {};
      await n.pray(other);
      expect(c.read(interactionProvider).prayedOf(other), isTrue);
      expect(c.read(interactionProvider).prayerTimesOf(other), 1);
      expect(c.read(interactionProvider).prayersOf(other), 3);
      // Dernière prière retirée : ne prie plus, le compteur redescend.
      await n.removeLastPrayer(other);
      expect(c.read(interactionProvider).prayedOf(other), isFalse);
      expect(c.read(interactionProvider).prayersOf(other), 2);
    });

    test('événement : again et last envoyés, myPrayerTimes lu', () async {
      final api = _Api()..reply = const {};
      final c = ProviderContainer(overrides: [apiServiceProvider.overrideWithValue(api)]);
      addTearDown(c.dispose);
      final n = c.read(contentInteractionsProvider.notifier);
      final start = ContentReactions.fromJson({'prayersCount': 4, 'myPrayerReaction': 'amen', 'myPrayerTimes': 2});
      expect(start.myPrayerTimes, 2);

      await n.pray(ContentKind.event, 'e1', start);
      expect(api.calls.last.path, '/events/e1/reactions');
      expect(api.calls.last.data, {'type': 'pray', 'again': true});
      var now = n.of(ContentKind.event, 'e1', start);
      expect((now.myPrayerTimes, now.prayersCount, now.myPrayerReaction), (3, 4, 'amen'));

      await n.removeLastPrayer(ContentKind.event, 'e1', now);
      expect(api.calls.last.query, {'group': 'prayer', 'last': 1});
      now = n.of(ContentKind.event, 'e1', start);
      expect((now.myPrayerTimes, now.isPrayed), (2, true));

      final once = ContentReactions.fromJson({'prayersCount': 1, 'myPrayerReaction': 'pray', 'myPrayerTimes': 1});
      await n.removeLastPrayer(ContentKind.prayerSession, 's1', once);
      now = n.of(ContentKind.prayerSession, 's1', once);
      expect((now.isPrayed, now.prayersCount), (false, 0));
    });

    test('requête de prière et verset : nombre de fois, compteur de personnes', () {
      final r = PrayerRequest.fromJson({'id': 'q1', 'body': 'Priez', 'prayerCount': 5, 'hasPrayed': true, 'myPrayerTimes': 2});
      expect(r.prayerTimes, 2);
      expect((r.withPrayerTimes(3).prayerCount, r.withPrayerTimes(3).myPrayerTimes), (5, 3));
      expect((r.withPrayerTimes(0).prayerCount, r.withPrayerTimes(0).hasPrayed), (4, false));
      final fresh = PrayerRequest.fromJson({'id': 'q2', 'body': 'Priez', 'prayerCount': 0});
      expect((fresh.withPrayerTimes(1).prayerCount, fresh.withPrayerTimes(1).prayerTimes), (1, 1));

      const v = DailyVerse(id: 3, text: 'Car Dieu…', reference: 'Jean 3:16', prayerCount: 4, isPrayed: true, myPrayerTimes: 1);
      final again = verseWithPrayer(v, again: true);
      expect((again.prayerTimes, again.prayerCount), (2, 4));
      final removed = verseWithPrayer(v, again: false);
      expect((removed.isPrayed, removed.prayerCount), (false, 3));
      expect(versePrayBody(again: false), {'type': 'pray', 'active': false, 'last': true});
      expect(DailyVerse.fromJson({'text': 'x', 'reference': 'y', 'myReactions': ['pray'], 'myPrayerTimes': 4}).prayerTimes, 4);
    });
  });

  testWidgets('carte de sujet de prière : prier encore, N prient, retirer sa dernière prière', (tester) async {
    final api = _Api()..reply = {'id': 'q1', 'body': 'Priez pour ma famille', 'prayerCount': 12, 'hasPrayed': true, 'myPrayerTimes': 1};
    await tester.pumpWidget(ProviderScope(
      overrides: [apiServiceProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PrayerRequestFeedCard(
              request: PrayerRequest.fromJson(
                  {'id': 'q1', 'body': 'Priez pour ma famille', 'prayerCount': 12, 'hasPrayed': true, 'myPrayerTimes': 2}),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Prier encore'), findsOneWidget);
    expect(find.text('12 personnes prient'), findsOneWidget);
    expect(find.text('Vous avez prié 2 fois'), findsOneWidget);

    await tester.tap(find.byTooltip('Retirer ma dernière prière'));
    await tester.pumpAndSettle();
    expect(api.calls.last.path, '/prayer/requests/q1/pray');
    expect(api.calls.last.data, {'prayed': false, 'last': true});
    expect(find.text('Vous avez prié 1 fois'), findsOneWidget);
    expect(find.text('12 personnes prient'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onglet « Encouragements » : qui a commenté, et quoi', (tester) async {
    final api = _Api()
      ..people = (q) => {
            'summary': {..._summary, 'commentsCount': 2},
            if (q?['type'] == 'comments')
              'comments': [
                {'id': 'c1', 'body': 'Je prie pour toi, courage !', 'createdAt': '2026-10-26T09:00:00+00:00',
                 'user': {'id': 'u3', 'displayName': 'Mariam', 'initials': 'M', 'isVerified': false}},
              ]
            else
              'people': [_person('u1', 'Afi', ['pray'])],
          };
    await tester.pumpWidget(ProviderScope(
      overrides: [apiServiceProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReactionPeopleSheet(
            path: ReactionSubject.prayerRequest.peoplePath('q1'),
            commentsLabel: 'Encouragements',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Afi'), findsOneWidget);

    await tester.tap(find.text('💬 Encouragements  2'));
    await tester.pumpAndSettle();
    expect(api.calls.last.query, {'type': 'comments', 'page': 1});
    expect(find.text('Mariam'), findsOneWidget);
    expect(find.text('Je prie pour toi, courage !'), findsOneWidget);
    expect(find.text('Afi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Affichage bord à bord : la barre de navigation du téléphone (48 px ici) ne
  // doit cacher ni les noms ni le titre ; la feuille ne reste pas collée en bas.
  testWidgets('feuille au-dessus de la barre de navigation du téléphone', (tester) async {
    tester.view.physicalSize = const Size(780, 1600);
    tester.view.devicePixelRatio = 2;
    tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 96); // 24 / 48 px logiques
    addTearDown(tester.view.reset);
    final api = _Api()
      ..people = (_) => {
            'summary': _summary,
            'people': [for (var i = 0; i < 12; i++) _person('u$i', 'Personne $i', ['like'])],
          };
    await tester.pumpWidget(ProviderScope(
      overrides: [apiServiceProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showReactionPeople(context, subject: ReactionSubject.testimony, id: 't1'),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    const screenHeight = 800.0;
    const navBar = 48.0;
    final sheet = tester.getRect(find.byType(ReactionPeopleSheet));
    expect(sheet.bottom, lessThanOrEqualTo(screenHeight - navBar), reason: 'contenu sous la barre système');
    expect(sheet.height, greaterThanOrEqualTo(screenHeight * 0.4 - 1));
    // Dernier nom visible une fois la liste défilée jusqu'en bas : au-dessus de la barre.
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Personne 11')).bottom, lessThanOrEqualTo(screenHeight - navBar));
    expect(tester.takeException(), isNull);
  });

  testWidgets('témoignage : onglet « Commentaires » toujours là, juste après « Toutes »', (tester) async {
    final api = _Api()
      ..people = (q) => {
            'summary': {..._summary, 'commentsCount': 0},
            if (q?['type'] == 'comments') 'comments': const [] else 'people': [_person('u1', 'Afi', ['like'])],
          };
    await tester.pumpWidget(ProviderScope(
      overrides: [apiServiceProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReactionPeopleSheet(path: ReactionSubject.testimony.peoplePath('t1'))),
      ),
    ));
    await tester.pumpAndSettle();
    final labels = [for (final c in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) (c.label as Text).data];
    expect(labels.take(2), ['Toutes  3', '💬 Commentaires  0']);

    await tester.tap(find.text('💬 Commentaires  0'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun commentaire pour le moment.'), findsOneWidget);

    // Session de prière : pas de commentaires, pas d'onglet.
    await tester.pumpWidget(ProviderScope(
      overrides: [apiServiceProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReactionPeopleSheet(path: ReactionSubject.prayerSession.peoplePath('s1'), hasComments: false),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Commentaires'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
