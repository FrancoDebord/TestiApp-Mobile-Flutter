import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/media/playback_preferences.dart' show FeedLayout;
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/events/providers/events_providers.dart';
import 'package:testi_app/features/events/data/events_repository.dart';
import 'package:testi_app/features/events/models/event_models.dart';
import 'package:testi_app/features/events/screens/event_detail_screen.dart';
import 'package:testi_app/features/events/screens/event_form_screen.dart';
import 'package:testi_app/features/events/screens/events_screen.dart';
import 'package:testi_app/features/events/widgets/event_widgets.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/notifications/models/notification_models.dart' show NotificationType;
import 'package:testi_app/features/notifications/providers/notifications_provider.dart' show notificationFromJson;

/// Réponse de l'API (EventResource) — docs serveur fonctionnalites/evenements.md
Map<String, dynamic> _json({bool manage = false, String status = 'published', bool live = false}) => {
      'id': 'e1',
      'title': 'Grande croisade de guérison et de délivrance de Cotonou 2026',
      'description': 'Trois soirées de louange, de prière et de témoignages. ' * 8,
      'type': 'crusade',
      'typeLabel': "Croisade d'évangélisation",
      'status': status,
      'phase': 'upcoming',
      'startsAt': '2026-10-12T17:00:00+00:00',
      'endsAt': '2026-10-14T21:00:00+00:00',
      'location': "Stade de l'Amitié Général Mathieu Kérékou",
      'city': 'Cotonou',
      'country': 'Bénin',
      'guests': [
        {'name': 'Pasteur Jean-Baptiste Mukendi', 'role': 'Orateur principal'},
        {'name': 'Chorale Gloire', 'role': null},
      ],
      'commentsEnabled': true,
      'images': [
        {'id': 'i1', 'url': 'https://example.org/1.jpg'},
        {'id': 'i2', 'url': 'https://example.org/2.jpg'},
      ],
      'coverUrl': 'https://example.org/1.jpg',
      'organizer': {
        'id': 'o1',
        'displayName': 'Église de la Grâce de Cotonou',
        'initials': 'EG',
        'avatarUrl': null,
        'isOrganization': true,
        'isVerified': true,
      },
      'stats': {'going': 1234, 'notGoing': 3, 'comments': 12, 'testimonies': 4},
      'myParticipation': 'going',
      'acceptsParticipation': true,
      'canManage': manage,
      'live': live ? {'id': 'l1', 'status': 'live', 'title': 'Soirée 1'} : null,
      'webUrl': 'https://example.org/evenements/e1',
    };

/// Événement terminé, reporté une fois, avec résultats du sondage et ma réponse.
Map<String, dynamic> _pastJson({bool canAnswer = true, bool mine = false}) => {
      ..._json(),
      'phase': 'past',
      'acceptsParticipation': false,
      'myParticipation': 'going',
      'isPostponed': true,
      'originalStartsAt': '2026-09-01T17:00:00+00:00',
      'originalEndsAt': '2026-09-01T21:00:00+00:00',
      'statusReason': 'Travaux au stade',
      'isUnconfirmed': true,
      'canReport': true,
      'organizer': {..._json()['organizer'] as Map<String, dynamic>, 'isReliable': true},
      'survey': {
        'open': true,
        'canAnswer': canAnswer,
        'yes': 20,
        'no': 3,
        'absent': 2,
        'total': 25,
        'confirmedPercent': 87,
        'ratingAverage': 4.6,
        'ratingCount': 18,
        'mine': mine
            ? {'attended': 'yes', 'rating': 5, 'body': 'Béni', 'editableUntil': '2026-11-05T10:00:00+00:00', 'canEdit': true}
            : null,
      },
    };

/// Affichage compact forcé (sans stockage).
class _CompactLayout extends EventLayoutNotifier {
  @override
  FeedLayout build() => FeedLayout.compact;
}

class _FakeRepo implements EventsRepository {
  _FakeRepo(this.event);
  final ChristianEvent event;

  @override
  Future<ChristianEvent> show(String id) async => event;

  @override
  Future<EventPage<ChristianEvent>> list({
    EventScope scope = EventScope.upcoming,
    EventType? type,
    String? query,
    int page = 1,
    String? organizerId,
    int? limit,
  }) async =>
      EventPage(items: [event, event], canCreate: true);

  @override
  Future<EventPage<EventComment>> comments(String id, {int page = 1}) async =>
      EventPage(items: [
        EventComment.fromJson({
          'id': 'c1',
          'body': "J'ai été guéri pendant la prière du deuxième soir, gloire à Dieu !",
          'user': {'id': 'u1', 'displayName': 'Marie Kossou', 'initials': 'MK'},
          'testimonyId': null,
          'isMine': false,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      ]);

  @override
  Future<EventPage<Testimony>> testimonies(String id, {int page = 1}) async =>
      const EventPage(items: []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(UnimplementedError(invocation.memberName.toString()));
}

void main() {
  group('modèle', () {
    test('lit un événement de l\'API', () {
      final e = ChristianEvent.fromJson(_json(manage: true, live: true));
      expect(e.type, EventType.crusade);
      expect(e.guests, hasLength(2));
      expect(e.guests[1].role, isNull);
      expect(e.images.first.id, 'i1');
      expect(e.coverUrl, 'https://example.org/1.jpg');
      expect(e.organizer.isVerified, isTrue);
      expect(e.goingCount, 1234);
      expect(e.myParticipation, EventParticipation.going);
      expect(e.canManage, isTrue);
      expect(e.live?.isOnAir, isTrue);
      expect(e.place, "Stade de l'Amitié Général Mathieu Kérékou · Cotonou, Bénin");
      expect(e.phaseLabel, 'À venir');
    });

    test('report, signalement, sondage et modération', () {
      final e = ChristianEvent.fromJson(_pastJson(mine: true));
      expect(e.isPostponed, isTrue);
      expect(e.dateTbd, isFalse);
      expect(e.originalStartsAt, isNotNull);
      expect(e.statusReason, 'Travaux au stade');
      expect(e.isUnconfirmed, isTrue);
      expect(e.canReport, isTrue);
      expect(e.organizer.isReliable, isTrue);
      expect(e.survey.open, isTrue);
      expect(e.survey.confirmedPercent, 87);
      expect(e.survey.ratingAverage, 4.6);
      expect(e.survey.summary, "87 % confirment qu'il a eu lieu · ★ 4,6 · 25 avis");
      expect(e.survey.mine?.attended, EventAttendance.yes);
      expect(e.survey.mine?.rating, 5);
      expect(e.moderation, isNull);
      expect(e.canChangeSchedule, isFalse); // terminé

      final tbd = ChristianEvent.fromJson({..._json(), 'status': 'postponed', 'isPostponed': true, 'dateTbd': true});
      expect(tbd.status, EventStatus.postponed);
      expect(tbd.phaseLabel, 'Reporté — date à confirmer');
      expect(eventScheduleText(tbd), 'Date à confirmer');
      expect(tbd.canChangeSchedule, isTrue);

      final mod = ChristianEvent.fromJson({
        ..._json(),
        'isHidden': true,
        'moderation': {
          'reportCount': 3,
          'pendingReports': 2,
          'reliability': {'confirmed': 4, 'unconfirmed': 1, 'reported': 2, 'total': 7, 'reliable': false},
        },
      });
      expect(mod.isHidden, isTrue);
      expect(mod.moderation?.pendingReports, 2);
      expect(mod.moderation?.unconfirmed, 1);
      // Ancienne API (sans les nouveaux champs) : valeurs par défaut.
      final old = ChristianEvent.fromJson(_json());
      expect(old.survey.total, 0);
      expect(old.survey.summary, '0 avis');
      expect(old.isPostponed, isFalse);
    });

    test('commentaire avec mentions', () {
      final c = EventComment.fromJson({
        'id': 'c9',
        'body': 'Merci @Paul Mbeki pour la louange !',
        'mentions': [
          {'id': 'u9', 'displayName': 'Paul Mbeki'},
        ],
        'user': {'id': 'u1', 'displayName': 'Marie'},
      });
      expect(c.mentions.single.displayName, 'Paul Mbeki');
      expect(c.copyWith(testimonyId: 't1').mentions, hasLength(1));
      expect(EventComment.fromJson({'id': 'c1', 'body': 'Amen', 'user': const {}}).mentions, isEmpty);
    });

    test('notification d\'événement (sondage, report)', () {
      final n = notificationFromJson({
        'id': 'n1',
        'type': 'event_survey',
        'actorName': null,
        'message': "L'événement « Croisade » est terminé. A-t-il bien eu lieu ? Donnez votre avis.",
        'eventId': 'e1',
        'createdAt': '2026-10-06T10:00:00+00:00',
      });
      expect(n?.type, NotificationType.event);
      expect(n?.eventId, 'e1');
      expect(n?.title, 'Événement');
      expect(n?.body, contains('A-t-il bien eu lieu'));
    });

    test('libellé annulé prioritaire', () {
      expect(ChristianEvent.fromJson(_json(status: 'cancelled')).phaseLabel, 'Annulé');
    });

    test('brouillon envoyé au serveur', () {
      final d = EventDraft(
        title: '  Camp de jeunes ',
        type: EventType.camp,
        startsAt: DateTime.utc(2026, 7, 1, 8),
        endsAt: DateTime.utc(2026, 7, 5, 18),
        guests: [const EventGuest(name: ' Frère Paul ', role: ' '), const EventGuest(name: '')],
      );
      final j = d.toJson();
      expect(j['title'], 'Camp de jeunes');
      expect(j['type'], 'camp');
      expect(j['description'], isNull);
      expect(j['guests'], [
        {'name': 'Frère Paul'},
      ]);
      expect(j['starts_at'], '2026-07-01T08:00:00.000Z');
    });
  });

  group('dates', () {
    test('même jour', () {
      expect(formatEventRange(DateTime(2026, 10, 10, 18), DateTime(2026, 10, 10, 21, 30)),
          'sam. 10 oct. 2026 · 18:00 – 21:30');
    });
    test('plusieurs jours du même mois', () {
      expect(formatEventRange(DateTime(2026, 10, 12, 18), DateTime(2026, 10, 14, 21)),
          '12 → 14 oct. 2026');
    });
    test('sur deux mois', () {
      expect(formatEventRange(DateTime(2026, 10, 30), DateTime(2026, 11, 2)),
          '30 oct. → 2 nov. 2026');
    });
    test('sans date', () {
      expect(formatEventRange(null, null), 'Date à préciser');
    });
  });

  group('mise en page', () {
    Future<void> pump(WidgetTester tester, Widget screen, ChristianEvent e,
        {required Size size, double scale = 1.0, bool compact = false}) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          eventsRepositoryProvider.overrideWithValue(_FakeRepo(e)),
          currentUserProvider.overrideWithValue(null),
          if (compact) eventLayoutProvider.overrideWith(_CompactLayout.new),
        ],
        child: MaterialApp(
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: scale,
            maxScaleFactor: scale,
            child: screen,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final size in const [Size(320, 568), Size(390, 844)]) {
      for (final scale in const [1.0, 1.3]) {
        final label = '${size.width.toInt()} px, ×$scale';

        testWidgets('liste ($label)', (tester) async {
          await pump(tester, const EventsScreen(), ChristianEvent.fromJson(_json()),
              size: size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.byType(EventCard), findsWidgets);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('liste compacte ($label)', (tester) async {
          final tbd = ChristianEvent.fromJson({
            ..._json(live: true),
            'status': 'postponed',
            'isPostponed': true,
            'dateTbd': true,
            'isUnconfirmed': true,
          });
          await pump(tester, const EventsScreen(), tbd, size: size, scale: scale, compact: true);
          expect(tester.takeException(), isNull);
          expect(find.byType(EventCompactTile), findsWidgets);
          expect(find.byType(EventCard), findsNothing);
          expect(find.text('Reporté — date à confirmer'), findsWidgets);
          expect(find.byTooltip('Affichage : cartes'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('détail terminé : bloc « Votre avis » ($label)', (tester) async {
          await pump(tester, const EventDetailScreen(eventId: 'e1'), ChristianEvent.fromJson(_pastJson()),
              size: size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.text('Événement reporté'), findsOneWidget);
          expect(find.text('Non confirmé'), findsWidgets);
          await tester.scrollUntilVisible(find.text("L'événement a-t-il eu lieu ?"), 200,
              scrollable: find.byType(Scrollable).first);
          expect(find.textContaining('87 % confirment'), findsOneWidget);
          // « Oui » : la note apparaît.
          await tester.ensureVisible(find.text('Oui, il a eu lieu'));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Oui, il a eu lieu'));
          await tester.pump();
          expect(find.text('Votre note'), findsOneWidget);
          expect(find.byTooltip('5 sur 5'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('détail : ma réponse déjà donnée ($label)', (tester) async {
          await pump(tester, const EventDetailScreen(eventId: 'e1'),
              ChristianEvent.fromJson(_pastJson(mine: true)),
              size: size, scale: scale);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.textContaining('Votre réponse : Oui'), 200,
              scrollable: find.byType(Scrollable).first);
          expect(find.textContaining('Modifier'), findsWidgets);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('détail visiteur ($label)', (tester) async {
          await pump(tester, const EventDetailScreen(eventId: 'e1'),
              ChristianEvent.fromJson(_json(live: true)),
              size: size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.text('Je participe'), findsOneWidget);
          expect(find.textContaining('Gestion'), findsNothing);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('détail gestionnaire ($label)', (tester) async {
          await pump(tester, const EventDetailScreen(eventId: 'e1'),
              ChristianEvent.fromJson(_json(manage: true)),
              size: size, scale: scale);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.text('Gestion de la page'), 200,
              scrollable: find.byType(Scrollable).first);
          expect(find.text('Lancer un direct'), findsOneWidget);
          expect(find.text('Reporter'), findsOneWidget);
          expect(find.text("Annuler l'événement"), findsOneWidget);
          // Pas de « Signaler » pour les gestionnaires.
          expect(find.byTooltip("Plus d'options"), findsNothing);
          // Commentaires : bouton « Enregistrer comme témoignage » pour le gestionnaire.
          await tester.ensureVisible(find.textContaining('Commentaires ('));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.textContaining('Commentaires ('), warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.scrollUntilVisible(find.text('Enregistrer comme témoignage'), 200,
              scrollable: find.byType(Scrollable).first);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('formulaire de création ($label)', (tester) async {
          await pump(tester, const EventFormScreen(), ChristianEvent.fromJson(_json()),
              size: size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.text("Publier l'événement"), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });
}
