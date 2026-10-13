import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/prophecies/data/prophecies_repository.dart';
import 'package:testi_app/features/prophecies/data/prophecy_reminders.dart';
import 'package:testi_app/features/prophecies/models/prophecy.dart';
import 'package:testi_app/features/prophecies/screens/prophecies_screen.dart';
import 'package:testi_app/features/prophecies/screens/prophecy_detail_screen.dart';
import 'package:testi_app/features/prophecies/screens/prophecy_form_screen.dart';
import 'package:testi_app/features/prophecies/widgets/prophecy_widgets.dart' show prophecyReceived;
import 'package:testi_app/shared/content/encouragements.dart';

/// Réponse de l'API (ProphecyResource) — docs serveur fonctionnalites/paroles-prophetiques.md
Map<String, dynamic> _json({String status = 'waiting', String? due, bool audio = false}) => {
      'id': 'p1',
      'title': null,
      'receivedOn': '2026-03-12',
      'bodyText': "Je t'ouvrirai des portes que personne ne pourra fermer, et tu verras ma gloire dans ta maison "
          'et dans ta famille. Ne crains rien, car je suis avec toi.',
      'audioUrl': audio ? 'https://example.org/a.m4a' : null,
      'audioDuration': audio ? 42 : 0,
      'givenBy': 'Pasteur Jean-Baptiste Mukendi, lors du culte de jeudi soir',
      'dueOn': due,
      'status': status,
      'fulfilledOn': status == 'fulfilled' ? '2026-09-30' : null,
      'testimonyId': null,
      'isPublic': false,
      'reminder': {'frequency': 'weekly', 'time': '06:30', 'weekday': 7},
      'prayerCount': 12,
      'lastPrayedAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    };

class _FakeRepo implements PropheciesRepository {
  _FakeRepo(this.items);
  final List<Prophecy> items;

  @override
  Future<List<Prophecy>> list() async => items;

  @override
  Future<Prophecy> show(String id) async => items.first;

  @override
  Future<List<ProphecyPrayer>> prayers(String id) async => [
        ProphecyPrayer(id: 1, prayedAt: DateTime(2026, 9, 1, 6, 30), note: 'Proclamée avec ma famille ce matin'),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(UnimplementedError(invocation.memberName.toString()));
}

void main() {
  group('modèle', () {
    test('lit une parole de l\'API', () {
      final p = Prophecy.fromJson(_json());
      expect(p.receivedOn, DateTime(2026, 3, 12));
      expect(p.fulfilled, isFalse);
      expect(p.reminder?.label, 'Chaque dimanche à 06:30');
      expect(p.prayerCount, 12);
      expect(p.displayTitle((d) => '${d.day}'), startsWith("Je t'ouvrirai des portes"));
      expect(p.displayTitle((d) => '').length, lessThanOrEqualTo(61));
    });

    test('échéance passée seulement si en attente', () {
      expect(Prophecy.fromJson(_json(due: '2020-01-01')).isOverdue, isTrue);
      expect(Prophecy.fromJson(_json(due: '2020-01-01', status: 'fulfilled')).isOverdue, isFalse);
      expect(Prophecy.fromJson(_json(due: '2999-01-01')).isOverdue, isFalse);
    });

    test('brouillon envoyé au serveur', () {
      final d = ProphecyDraft(receivedOn: DateTime(2026, 10, 5), bodyText: '  Parole  ', givenBy: ' ')
        ..reminder = const ProphecyReminder(frequency: ReminderFrequency.daily, hour: 7, minute: 5, weekday: 3);
      final j = d.toJson();
      expect(j['received_on'], '2026-10-05');
      expect(j['body_text'], 'Parole');
      expect(j['given_by'], isNull);
      expect(j['title'], isNull);
      expect(j['reminder_frequency'], 'daily');
      expect(j['reminder_time'], '07:05');
      expect(j['reminder_weekday'], isNull); // quotidien : pas de jour
    });
  });

  group('rappels', () {
    final now = DateTime(2026, 10, 5, 12); // lundi midi
    test('quotidien : aujourd\'hui si l\'heure n\'est pas passée, sinon demain', () {
      const later = ProphecyReminder(frequency: ReminderFrequency.daily, hour: 18, minute: 0);
      const earlier = ProphecyReminder(frequency: ReminderFrequency.daily, hour: 6, minute: 0);
      expect(ProphecyReminders.nextOccurrence(later, now), DateTime(2026, 10, 5, 18));
      expect(ProphecyReminders.nextOccurrence(earlier, now), DateTime(2026, 10, 6, 6));
    });
    test('hebdomadaire : le prochain jour choisi', () {
      const sunday = ProphecyReminder(frequency: ReminderFrequency.weekly, hour: 6, minute: 30, weekday: 7);
      const mondayMorning = ProphecyReminder(frequency: ReminderFrequency.weekly, hour: 6, minute: 0, weekday: 1);
      expect(ProphecyReminders.nextOccurrence(sunday, now), DateTime(2026, 10, 11, 6, 30));
      expect(ProphecyReminders.nextOccurrence(mondayMorning, now), DateTime(2026, 10, 12, 6));
    });
  });

  // Message silencieux du serveur (Laravel SyncProphecyReminderJob::payload) : valeurs en chaînes.
  group('message silencieux', () {
    test('réglage hebdomadaire reconstruit', () {
      final p = ProphecyReminders.fromPush({
        'type': 'prophecy_sync', 'prophecy_id': 'p1', 'deleted': 'false', 'status': 'waiting',
        'display_title': 'Portes ouvertes',
        'reminder_frequency': 'weekly', 'reminder_time': '06:30', 'reminder_weekday': '7',
      })!;
      expect(p.id, 'p1');
      expect(p.fulfilled, isFalse);
      expect(p.displayTitle((d) => ''), 'Portes ouvertes');
      expect(p.reminder!.frequency, ReminderFrequency.weekly);
      expect(p.reminder!.time, '06:30');
      expect(p.reminder!.weekday, 7);
    });

    test('sans rappel, accomplie ou supprimée', () {
      final none = ProphecyReminders.fromPush({'type': 'prophecy_sync', 'prophecy_id': 'p1', 'deleted': 'false', 'status': 'waiting'})!;
      expect(none.reminder, isNull);
      final done = ProphecyReminders.fromPush({
        'type': 'prophecy_sync', 'prophecy_id': 'p1', 'deleted': 'false', 'status': 'fulfilled',
        'reminder_frequency': 'daily', 'reminder_time': '07:00',
      })!;
      expect(done.fulfilled, isTrue);
      expect(ProphecyReminders.fromPush({'type': 'prophecy_sync', 'prophecy_id': 'p1', 'deleted': 'true'}), isNull);
    });

    test('autres messages ignorés', () async {
      expect(await ProphecyReminders.handlePush({'type': 'comment', 'testimony_id': 't1'}), isFalse);
    });
  });

  group('messages pour témoigner', () {
    test('un message tous les 8 témoignages', () {
      expect(feedLengthWithEncouragements(7), 7);
      expect(feedLengthWithEncouragements(8), 9);
      expect(feedLengthWithEncouragements(20), 22);
      expect(testimonyIndexAt(7), 7);
      expect(testimonyIndexAt(8), isNull);
      expect(testimonyIndexAt(9), 8);
      expect(testimonyIndexAt(17), isNull);
      // Tous les témoignages apparaissent une fois, dans l'ordre.
      final indexes = [for (var i = 0; i < feedLengthWithEncouragements(30); i++) testimonyIndexAt(i)]
          .whereType<int>()
          .toList();
      expect(indexes, List.generate(30, (i) => i));
    });

    test('versets et invitations en alternance', () {
      expect(encouragementAt(0).isVerse, isTrue);
      expect(encouragementAt(1).isVerse, isTrue);
      expect(encouragementAt(2).isVerse, isFalse);
      expect(encouragementVerses.first.reference, 'Apocalypse 12:11');
      expect(encouragementVerses.any((v) => v.reference!.startsWith('Psaume 78')), isTrue);
    });
  });

  group('mise en page', () {
    Future<void> pump(WidgetTester tester, Widget screen, List<Prophecy> items,
        {required Size size, double scale = 1.0}) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [propheciesRepositoryProvider.overrideWithValue(_FakeRepo(items))],
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

        testWidgets('liste ($label)', (tester) async {
          await pump(tester, const PropheciesScreen(),
              [Prophecy.fromJson(_json(due: '2020-01-01')), Prophecy.fromJson(_json())],
              size: size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.text('Échéance passée'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('détail ($label)', (tester) async {
          await pump(tester, const ProphecyDetailScreen(prophecyId: 'p1'), [Prophecy.fromJson(_json())],
              size: size, scale: scale);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.text("Elle s'est accomplie"), 200,
              scrollable: find.byType(Scrollable).first);
          expect(find.text("J'ai prié"), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('formulaire ($label)', (tester) async {
          await pump(tester, const ProphecyFormScreen(), const [], size: size, scale: scale);
          expect(tester.takeException(), isNull);
          expect(find.text('Garder cette parole'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });

  test('heure de réception : lue, envoyée, affichée', () {
    final p = Prophecy.fromJson({'id': 'p9', 'receivedOn': '2026-10-05', 'receivedTime': '14:30:00', 'status': 'waiting'});
    expect(p.receivedTime, '14:30');
    expect(prophecyReceived(p.receivedOn, p.receivedTime), endsWith('à 14:30'));
    expect(prophecyReceived(p.receivedOn, null), isNot(contains(' à ')));
    expect(ProphecyDraft.fromProphecy(p).toJson()['received_time'], '14:30');
    // Nouvelle parole : l'heure actuelle par défaut.
    expect(ProphecyDraft().receivedTime, matches(RegExp(r'^\d\d:\d\d$')));
    expect(parseClockTime('25:00'), isNull);
  });
}
