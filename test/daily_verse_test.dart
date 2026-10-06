// Verset du jour en plein écran : analyse des références, lecture des
// réponses de l'API, et écran (versions, « Comparer », onglets, hors
// connexion, mise en page 320 / 390 px × 1,3 sans débordement).
// Docs serveur : fonctionnalites/verset-du-jour.md

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/daily_verse/data/daily_verse_repository.dart';
import 'package:testi_app/features/daily_verse/models/daily_verse_models.dart';
import 'package:testi_app/features/daily_verse/models/verse_reference.dart';
import 'package:testi_app/features/daily_verse/screens/daily_verse_screen.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/prayer/models/prayer_models.dart';

const _longText = 'Car Dieu a tant aimé le monde qu’il a donné son Fils unique, '
    'afin que quiconque croit en lui ne périsse point, mais qu’il ait la vie éternelle.';

class _FakeVerse extends DailyVerseNotifier {
  _FakeVerse([this.id = 7]);
  final int id;
  @override
  Future<DailyVerse> build() async => DailyVerse(
        id: id,
        text: '« $_longText »',
        reference: 'Jean 3 : 16-17',
        likeCount: 1234,
        prayerCount: 56,
      );
}

Map<String, dynamic> _versionsJson() => {
      'reference': 'Jean 3 : 16-17',
      'parsed': {'book': 43, 'chapter': 3, 'verseStart': 16, 'verseEnd': 17, 'bookName': 'Jean', 'label': 'Jean 3:16-17'},
      'original': {'code': null, 'name': 'Texte du jour', 'text': _longText},
      'versions': [
        {
          'code': 'LSG', 'name': 'Louis Segond 1910', 'language': 'fr', 'available': true,
          'verses': [
            {'verse': 16, 'text': 'Car Dieu a tant aimé le monde qu’il a donné son Fils unique.'},
            {'verse': 17, 'text': 'Dieu, en effet, n’a pas envoyé son Fils dans le monde pour qu’il juge le monde.'},
          ],
        },
        {
          'code': 'KJV', 'name': 'King James Version', 'language': 'en', 'available': true,
          'verses': [
            {'verse': 16, 'text': 'For God so loved the world, that he gave his only begotten Son.'},
          ],
        },
        {'code': 'BBE', 'name': 'Bible in Basic English', 'language': 'en', 'available': false, 'verses': []},
      ],
    };

class _FakeRepo implements DailyVerseRepository {
  _FakeRepo({this.offline = false});
  final bool offline;

  @override
  Future<DailyVerseVersions> versions(DailyVerse verse) async => offline
      ? DailyVerseVersions(
          reference: verse.reference,
          originalText: verse.text,
          parsed: VerseReference.parse(verse.reference),
          offline: true,
        )
      : DailyVerseVersions.fromJson(_versionsJson(), fallbackText: verse.text);

  @override
  Future<List<VerseComment>> comments(int verseId) async => offline
      ? throw const DailyVerseFailure('Pas de connexion. Réessayez une fois en ligne.', offline: true)
      : [
          VerseComment.fromJson({
            'id': 'c1',
            'body': 'Ce verset me rappelle que je suis aimé, même dans les jours les plus difficiles de ma vie.',
            'user': {'id': 'u1', 'displayName': 'Ministère International Lumière du Monde pour la Restauration'},
            'isMine': false,
            'canDelete': false,
            'canReport': true,
            'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
          }),
        ];

  @override
  Future<List<PrayerRequest>> prayerRequests(int verseId) async => offline
      ? throw const DailyVerseFailure('Pas de connexion. Réessayez une fois en ligne.', offline: true)
      : [
          PrayerRequest.fromJson({
            'id': 'r1',
            'body': 'Que je comprenne cet amour chaque jour et que ma famille le découvre aussi.',
            'visibility': 'public',
            'isAnonymous': false,
            'author': {'id': 'u2', 'displayName': 'Marie-Claire Ahouansou'},
            'status': 'open',
            'isAnswered': false,
            'prayerCount': 3,
            'messageCount': 0,
            'hasPrayed': false,
            'dailyVerseId': 7,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          }),
        ];

  @override
  Future<List<Testimony>> testimonies(int verseId) async => [
        TextTestimony(
          id: 't1',
          author: const TestimonyAuthor(uid: 'u3', displayName: 'Paul Mensah'),
          title: 'Un très long titre de témoignage pour vérifier le retour à la ligne dans la liste',
          category: TestimonyCategory.values.first,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          stats: const TestimonyStats(views: 10, comments: 0, likes: 2, prayers: 1),
          preview: 'Texte',
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(UnimplementedError(invocation.memberName.toString()));
}

Widget _app({double textScale = 1.0, bool offline = false, int verseId = 7, List<Override> extra = const []}) =>
    ProviderScope(
      overrides: [
        dailyVerseProvider.overrideWith(() => _FakeVerse(verseId)),
        dailyVerseRepositoryProvider.overrideWithValue(_FakeRepo(offline: offline)),
        ...extra,
      ],
      child: MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: const DailyVerseScreen(),
      ),
    );

Future<void> _setPhone(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * 2, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Fait défiler jusqu'à [f] (listes verticale et horizontale), puis le touche.
Future<void> _tapIn(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _see(WidgetTester tester, Finder f) =>
    tester.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);

Future<void> _scrollAll(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 6; i++) {
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async => null);
  });

  group('VerseReference', () {
    test('noms français, abréviations, anglais et plages', () {
      expect(VerseReference.parse('Jérémie 29 : 11'),
          const VerseReference(book: 24, chapter: 29, verseStart: 11, verseEnd: 11));
      expect(VerseReference.parse('Jean 3:16-18')!.label, 'Jean 3:16-18');
      expect(VerseReference.parse('1 Pierre 5.7')!.book, 60);
      expect(VerseReference.parse('Ps 23,1')!.book, 19);
      expect(VerseReference.parse('Ésaïe 40:31')!.book, 23);
      expect(VerseReference.parse('Cantique des Cantiques 8:6')!.book, 22);
      expect(VerseReference.parse('John 3:16')!.book, 43);
      expect(VerseReference.parse('jean 3,16 à 17')!.verseEnd, 17);
      expect(VerseReference.findAll('Lisez (Jn 3:16) puis Rm 8:28.').map((r) => r.book), [43, 45]);
      expect(VerseReference.parse('Un texte sans référence'), isNull);
      expect(VerseReference.parse('Il est 3:4'), isNull);
    });
  });

  group('Réponses de l’API', () {
    test('versions : passage complet, partiel et absent', () {
      final data = DailyVerseVersions.fromJson(_versionsJson(), fallbackText: 'x');
      expect(data.parsed!.label, 'Jean 3:16-17');
      expect(data.originalText, _longText);
      expect(data.byCode('LSG')!.lines, hasLength(2));
      expect(data.byCode('KJV')!.text, startsWith('For God'));
      expect(data.byCode('BBE')!.available, isFalse);
      expect(data.byCode('XYZ'), isNull);
    });

    test('verset du jour : compteurs et réactions imbriqués', () {
      final v = DailyVerse.fromJson({
        'id': 3,
        'verseText': 'Texte',
        'reference': 'Psaume 23:1',
        'counts': {'likes': 4, 'prayers': 2},
        'myReactions': ['pray'],
      });
      expect(v.likeCount, 4);
      expect(v.prayerCount, 2);
      expect(v.isPrayed, isTrue);
      expect(v.isLiked, isFalse);
    });

    test('commentaire : auteur, mentions et droits', () {
      final c = VerseComment.fromJson({
        'id': 'c9',
        'body': 'Merci @Paul pour ce partage',
        'mentions': [
          {'id': '11111111-1111-1111-1111-111111111111', 'displayName': 'Paul'},
        ],
        'user': {'id': 'u1', 'displayName': 'Marie Koffi'},
        'canDelete': true,
        'canReport': false,
        'isHidden': true,
      });
      expect(c.initials, 'MK');
      expect(c.mentions.single.displayName, 'Paul');
      expect(c.canDelete, isTrue);
      expect(c.isHidden, isTrue);
    });

    test('brouillon de requête rattaché au verset', () {
      expect(PrayerRequestDraft(body: 'Seigneur, aide-moi', dailyVerseId: 7).toJson()['daily_verse_id'], 7);
      expect(PrayerRequestDraft(body: 'x').toJson().containsKey('daily_verse_id'), isFalse);
    });
  });

  group('Écran plein écran', () {
    testWidgets('verset, versions, changement de version et comparaison', (tester) async {
      await _setPhone(tester, 390);
      await tester.pumpWidget(_app());
      await _settle(tester);

      expect(find.text('Jean 3:16-17'), findsOneWidget);
      expect(find.text('Texte du jour'), findsWidgets);
      expect(find.text('LSG'), findsOneWidget);
      expect(find.text('KJV'), findsOneWidget);

      await _tapIn(tester, find.text('KJV'));
      expect(find.textContaining('For God so loved the world', findRichText: true), findsOneWidget);
      expect(find.text('King James Version'), findsOneWidget);

      // Version absente pour ce passage : non sélectionnable.
      await tester.scrollUntilVisible(find.text('BBE'), 150, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('BBE'), warnIfMissed: false);
      await _settle(tester);
      expect(find.text('King James Version'), findsOneWidget);

      await _tapIn(tester, find.text('Comparer'));
      await _see(tester, find.text('LSG · Louis Segond 1910'));
      await _see(tester, find.text("Ce passage n'est pas disponible dans cette version."));
      expect(tester.takeException(), isNull);
    });

    testWidgets('onglets : prière, commentaires, témoignages', (tester) async {
      await _setPhone(tester, 390);
      await tester.pumpWidget(_app());
      await _settle(tester);

      await _see(tester, find.text('Confier un sujet de prière'));
      await _see(tester, find.textContaining('Que je comprenne cet amour'));

      await _tapIn(tester, find.text('Commentaires'));
      await _see(tester, find.textContaining('Ce verset me rappelle'));

      await _tapIn(tester, find.text('Témoignages'));
      await _see(tester, find.text('Témoigner sur ce verset'));
      await _see(tester, find.textContaining('Un très long titre'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('hors connexion : versions et participation indisponibles', (tester) async {
      await _setPhone(tester, 390);
      await tester.pumpWidget(_app(offline: true));
      await _settle(tester);

      expect(find.textContaining('Hors connexion'), findsOneWidget);
      expect(find.textContaining('« $_longText »'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Réessayer'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Pas de connexion'), findsOneWidget);
    });

    testWidgets('verset de secours (id 0) : participation désactivée', (tester) async {
      await _setPhone(tester, 390);
      await tester.pumpWidget(_app(verseId: 0));
      await _settle(tester);
      await tester.scrollUntilVisible(find.textContaining('une fois en ligne'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('une fois en ligne'), findsOneWidget);
    });

    testWidgets('mode lecture', (tester) async {
      await _setPhone(tester, 390);
      await tester.pumpWidget(_app());
      await _settle(tester);
      await tester.tap(find.byTooltip('Mode lecture'));
      await _settle(tester);
      expect(find.text('Comparer'), findsNothing);
      expect(find.text('Jean 3:16-17'), findsOneWidget);
      await tester.tap(find.byTooltip('Quitter le mode lecture'));
      await _settle(tester);
      expect(find.text('Comparer'), findsOneWidget);
    });

    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('sans débordement ($width px, ×$scale)', (tester) async {
          await _setPhone(tester, width);
          await tester.pumpWidget(_app(textScale: scale));
          await _settle(tester);
          expect(tester.takeException(), isNull);

          await _tapIn(tester, find.text('Comparer'));
          await _scrollAll(tester);

          for (final tab in ['Commentaires', 'Témoignages']) {
            await _tapIn(tester, find.text(tab));
            await _scrollAll(tester);
          }

          await tester.tap(find.byTooltip('Mode lecture'));
          await _settle(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
