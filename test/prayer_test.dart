import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/auth/guest_access.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart' show currentUserProvider;
import 'package:testi_app/features/prayer/data/prayer_repository.dart';
import 'package:testi_app/features/prayer/models/prayer_models.dart';
import 'package:testi_app/features/prayer/screens/create_prayer_session_screen.dart';
import 'package:testi_app/features/prayer/screens/group_prayer_sessions_screen.dart';
import 'package:testi_app/features/prayer/screens/prayer_request_detail_screen.dart';
import 'package:testi_app/features/prayer/screens/prayer_requests_screen.dart';
import 'package:testi_app/features/prayer/screens/prayer_session_detail_screen.dart';
import 'package:testi_app/features/prayer/screens/submit_prayer_request_screen.dart';
import 'package:testi_app/features/prayer/widgets/prayer_widgets.dart';

/// Réponse de l'API (PrayerRequestResource) — docs serveur fonctionnalites/requetes-de-priere.md
Map<String, dynamic> _requestJson({bool anonymous = false, bool answered = false, bool mine = false}) => {
      'type': 'prayer_request',
      'id': 'r1',
      'body': 'Priez pour la guérison de ma mère, hospitalisée depuis lundi à Cotonou. '
          'Les médecins attendent les résultats des examens de cette semaine.',
      'visibility': 'public',
      'isAnonymous': anonymous,
      'author': anonymous && !mine
          ? null
          : {'id': 'u1', 'displayName': 'Marie-Claire Ahouansou', 'avatarUrl': null, 'isVerified': false},
      'status': answered ? 'answered' : 'open',
      'isAnswered': answered,
      'answeredAt': answered ? '2026-10-04T10:00:00Z' : null,
      'answerNote': answered ? "Elle est sortie de l'hôpital !" : null,
      'testimonyId': null,
      'prayerCount': 12,
      'messageCount': 3,
      'hasPrayed': false,
      'event': {'id': 'e1', 'title': 'Grande croisade de Cotonou'},
      'isMine': mine,
      'isHidden': false,
      'canEdit': mine,
      'canDelete': mine,
      'canReport': !mine,
      'canModerate': false,
      'canMessage': true,
      'webUrl': 'https://exemple.org/priere/requetes/r1',
      'createdAt': DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
    };

/// Réponse de l'API (PrayerSessionResource) — docs serveur fonctionnalites/sessions-de-priere.md
Map<String, dynamic> _sessionJson({bool host = false, String phase = 'upcoming', bool room = false}) => {
      'type': 'prayer_session',
      'id': 's1',
      'title': 'Veillée de prière pour les familles et la paix dans le pays',
      'description': 'Une heure pour présenter nos familles au Seigneur.',
      'topics': ['Les couples en crise', 'Les enfants', 'La paix'],
      'startsAt': '2026-10-07T19:00:00Z',
      'endsAt': '2026-10-07T20:30:00Z',
      'durationMinutes': 90,
      'visibility': 'followers',
      'status': 'scheduled',
      'phase': phase,
      'phaseLabel': 'À venir',
      'host': {'id': 'h1', 'displayName': 'Pasteur Jean-Baptiste Mukendi', 'avatarUrl': null, 'isVerified': true},
      'event': null,
      'participantCount': 24,
      'isRegistered': false,
      'isHost': host,
      'canEdit': host,
      'canDelete': host,
      'canStart': host && phase != 'ended',
      'opensAt': '2026-10-07T18:30:00Z',
      'live': room ? {'id': 'l1', 'status': 'live'} : null,
      'webUrl': 'https://exemple.org/priere/sessions/s1',
    };

class _FakeRepo implements PrayerRepository {
  _FakeRepo({required this.req, required this.sess});
  final PrayerRequest req;
  final PrayerSession sess;

  @override
  Future<PrayerPage<PrayerRequest>> requests({
    PrayerRequestScope scope = PrayerRequestScope.all,
    String? eventId,
    bool answeredOnly = false,
    int page = 1,
    int limit = 20,
    bool near = false,
  }) async =>
      PrayerPage(items: [req], total: 1);

  @override
  Future<PrayerRequest> request(String id) async => req;

  @override
  Future<List<PrayerMessage>> messages(String id) async => [
        PrayerMessage.fromJson({
          'id': 'm1',
          'body': 'Je prie avec vous, courage ! Le Seigneur est fidèle.',
          'bibleReference': 'Philippiens 4:6-7',
          'author': {'id': 'u2', 'displayName': 'Paul'},
          'canDelete': false,
        }),
      ];

  @override
  Future<PrayerPage<PrayerSession>> sessions({
    PrayerSessionScope scope = PrayerSessionScope.upcoming,
    String? eventId,
    int page = 1,
  }) async =>
      PrayerPage(items: [sess], total: 1);

  @override
  Future<PrayerSession> session(String id) async => sess;

  @override
  Future<PrayerRequest> pray(String id, {required bool prayed}) async => req.withPrayed(prayed);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(UnimplementedError(invocation.memberName.toString()));
}

void main() {
  group('modèles', () {
    test('lit une requête de l\'API', () {
      final r = PrayerRequest.fromJson(_requestJson());
      expect(r.authorName, 'Marie-Claire Ahouansou');
      expect(r.author?.initials, 'MA');
      expect(r.prayerCount, 12);
      expect(r.messageCount, 3);
      expect(r.event?.title, 'Grande croisade de Cotonou');
      expect(r.isAnswered, isFalse);
      expect(r.canReport, isTrue);
    });

    test('requête anonyme : auteur masqué', () {
      final r = PrayerRequest.fromJson(_requestJson(anonymous: true));
      expect(r.author, isNull);
      expect(r.authorName, 'Anonyme');
      expect(r.isAnonymous, isTrue);
    });

    test('« Je prie » localement', () {
      final r = PrayerRequest.fromJson(_requestJson());
      final prayed = r.withPrayed(true);
      expect(prayed.hasPrayed, isTrue);
      expect(prayed.prayerCount, 13);
      expect(prayed.withPrayed(false).prayerCount, 12);
      expect(r.withPrayed(false), same(r));
    });

    test('exaucée', () {
      final r = PrayerRequest.fromJson(_requestJson(answered: true));
      expect(r.isAnswered, isTrue);
      expect(r.answerNote, "Elle est sortie de l'hôpital !");
    });

    test('lit une session et sa salle', () {
      final s = PrayerSession.fromJson(_sessionJson(phase: 'live', room: true));
      expect(s.isLive, isTrue);
      expect(s.hasRoom, isTrue);
      expect(s.liveId, 'l1');
      expect(s.topics, hasLength(3));
      expect(s.visibility, PrayerVisibility.followers);
      expect(s.host.isVerified, isTrue);
      expect(s.endsAt.difference(s.startsAt).inMinutes, 90);
    });

    test('brouillons envoyés au serveur', () {
      final r = PrayerRequestDraft(body: '  Pour mon examen  ', visibility: PrayerVisibility.private, isAnonymous: true, eventId: 'e1');
      expect(r.toJson(), {'body': 'Pour mon examen', 'visibility': 'private', 'is_anonymous': true, 'event_id': 'e1'});

      final s = PrayerSessionDraft(
        title: ' Veillée ',
        topics: ['La paix', '  ', 'Les malades'],
        startsAt: DateTime.utc(2026, 10, 7, 19),
        visibility: PrayerVisibility.private, // pas de session privée : publique
      ).toJson();
      expect(s['title'], 'Veillée');
      expect(s['topics'], ['La paix', 'Les malades']);
      expect(s['starts_at'], '2026-10-07T19:00:00.000Z');
      expect(s['visibility'], 'public');
      expect(s['description'], isNull);
      expect(s.containsKey('event_id'), isFalse);
    });

    test('requête confiée depuis un témoignage', () {
      final r = PrayerRequest.fromJson({..._requestJson(), 'sourceTestimony': {'id': 't1', 'title': 'Guérie du paludisme'}});
      expect(r.sourceTestimony?.id, 't1');
      expect(r.sourceTestimony?.title, 'Guérie du paludisme');
      expect(r.withPrayed(!r.hasPrayed).sourceTestimony?.id, 't1');
      expect(PrayerRequest.fromJson(_requestJson()).sourceTestimony, isNull);

      final d = PrayerRequestDraft(body: 'Moi aussi, priez pour moi', sourceTestimonyId: 't1');
      expect(d.toJson()['source_testimony_id'], 't1');
      expect(PrayerRequestDraft(body: 'x').toJson().containsKey('source_testimony_id'), isFalse);
    });

    test('date et ancienneté', () {
      expect(formatPrayerDate(DateTime(2026, 10, 7, 20, 5)), 'mer. 7 oct., 20:05');
      final now = DateTime(2026, 10, 5, 12);
      expect(prayerTimeAgo(now.subtract(const Duration(minutes: 5)), now: now), 'il y a 5 min');
      expect(prayerTimeAgo(now.subtract(const Duration(days: 2)), now: now), 'il y a 2 j');
    });
  });

  group('accès invité', () {
    test('lecture libre, création réservée', () {
      expect(guestCanAccess('/prayer-requests'), isTrue);
      expect(guestCanAccess('/prayer-requests/r1'), isTrue);
      expect(guestCanAccess('/prayer-sessions/s1'), isTrue);
      expect(guestCanAccess('/prayer-requests/new'), isFalse);
      expect(guestCanAccess('/prayer-sessions/new'), isFalse);
      expect(guestCanAccess('/prayer-sessions/s1/edit'), isFalse);
    });
  });

  group('mise en page', () {
    Future<void> pump(WidgetTester tester, Widget screen,
        {required Size size, double scale = 1.0, bool host = false, bool room = false}) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          prayerRepositoryProvider.overrideWithValue(_FakeRepo(
            req: PrayerRequest.fromJson(_requestJson()),
            sess: PrayerSession.fromJson(_sessionJson(host: host, room: room, phase: room ? 'live' : 'upcoming')),
          )),
          currentUserProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          home: MediaQuery.withClampedTextScaling(minScaleFactor: scale, maxScaleFactor: scale, child: screen),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final size in const [Size(320, 568), Size(390, 844)]) {
      for (final scale in const [1.0, 1.3]) {
        final label = '${size.width.toInt()} px, ×$scale';

        testWidgets('liste des requêtes ($label)', (tester) async {
          await pump(tester, const PrayerRequestsScreen(), size: size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.text('Marie-Claire Ahouansou'), findsOneWidget);
          expect(find.textContaining('Je prie'), findsWidgets);
        });

        testWidgets('détail d\'une requête ($label)', (tester) async {
          await pump(tester, const PrayerRequestDetailScreen(requestId: 'r1'), size: size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.textContaining("Priez pour la gu"), findsOneWidget);
          await tester.scrollUntilVisible(find.text('Philippiens 4:6-7'), 200, scrollable: find.byType(Scrollable).first);
          expect(find.text('Philippiens 4:6-7'), findsOneWidget);
        });

        testWidgets('confier une requête ($label)', (tester) async {
          await pump(tester, const SubmitPrayerRequestScreen(eventId: 'e1'), size: size, scale: scale);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.text('Publier anonymement'), 200, scrollable: find.byType(Scrollable).first);
          expect(find.text('Publier anonymement'), findsOneWidget);
        });

        testWidgets('sessions ($label)', (tester) async {
          await pump(tester, const GroupPrayerSessionsScreen(), size: size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.textContaining('Veillée de prière'), findsOneWidget);
        });

        testWidgets('session : visiteur, salle ouverte ($label)', (tester) async {
          await pump(tester, const PrayerSessionDetailScreen(sessionId: 's1'), size: size, scale: scale, room: true);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.text('Je serai là'), 200, scrollable: find.byType(Scrollable).first);
          expect(find.text('Rejoindre la salle'), findsOneWidget);
          expect(find.text('Je serai là'), findsOneWidget);
        });

        testWidgets('session : hôte ($label)', (tester) async {
          await pump(tester, const PrayerSessionDetailScreen(sessionId: 's1'), size: size, scale: scale, host: true);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.text('Ouvrir la salle'), 200, scrollable: find.byType(Scrollable).first);
          expect(find.text('Ouvrir la salle'), findsOneWidget);
        });

        testWidgets('programmer une session ($label)', (tester) async {
          await pump(tester, const CreatePrayerSessionScreen(), size: size, scale: scale);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.text('Programmer la session'), 200, scrollable: find.byType(Scrollable).first);
          expect(find.text('Programmer la session'), findsOneWidget);
        });
      }
    }

    testWidgets('carte : compteurs et bouton « Je prie »', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PrayerRequestFeedCard(request: PrayerRequest.fromJson(_requestJson())),
            ),
          ),
        ),
      ));
      // « Je prie » et, à côté, « N personnes prient » (ouvre qui a prié).
      expect(find.text('Je prie'), findsOneWidget);
      expect(find.text('12 personnes prient'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // encouragements
      expect(find.byType(OutlinedButton), findsOneWidget); // pas encore prié

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PrayButton(prayed: true, count: 13)),
      ));
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Je prie · 13'), findsOneWidget);
    });

    testWidgets('carte anonyme', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: PrayerRequestFeedCard(request: PrayerRequest.fromJson(_requestJson(anonymous: true)))),
        ),
      ));
      expect(find.text('Anonyme'), findsOneWidget);
      expect(find.text('Grande croisade de Cotonou'), findsOneWidget);
    });
  });
}
