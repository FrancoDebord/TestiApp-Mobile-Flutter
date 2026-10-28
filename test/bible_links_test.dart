// Liens vers un passage de la Bible (lib/features/bible/bible_links.dart), alignés
// sur le serveur (BibleReference, tests/Feature/BibleLinksTest.php).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/core/local_db/daos/bible_dao.dart';
import 'package:testi_app/core/local_db/daos/bible_highlight_dao.dart';
import 'package:testi_app/features/bible/bible_links.dart';
import 'package:testi_app/features/bible/models/bible_models.dart';
import 'package:testi_app/features/bible/providers/bible_providers.dart';
import 'package:testi_app/features/bible/screens/bible_reader_screen.dart';

class _Dao implements BibleDao {
  @override
  Future<List<BibleBook>> getBooks(String code) async => const [
        BibleBook(translationCode: 'LSG', bookNumber: 1, name: 'Genèse', chaptersCount: 50),
        BibleBook(translationCode: 'LSG', bookNumber: 43, name: 'Jean', chaptersCount: 21),
      ];

  @override
  Future<List<BibleVerse>> getVerses(String code, int book, int chapter) async => [
        for (var v = 1; v <= 36; v++) BibleVerse(verseNumber: v, text: 'Jean $chapter verset $v '),
      ];

  @override
  Future<int> getChapterCount(String code, int book) async => book == 43 ? 21 : 50;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

class _Highlights implements BibleHighlightDao {
  @override
  Future<Map<int, String>> getChapterHighlights(String code, int book, int chapter) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

class _Translations extends BibleTranslationsNotifier {
  @override
  Future<List<BibleTranslation>> build() async => const [
        BibleTranslation(code: 'LSG', name: 'Louis Segond', language: 'fr', downloadStatus: DownloadStatus.downloaded),
      ];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('noms de livres (comme le serveur)', () {
    test('slug : français, anglais pour une traduction anglaise', () {
      expect(BibleLinks.slug(43, 'LSG'), 'jean');
      expect(BibleLinks.slug(46, 'LSG'), '1-corinthiens');
      expect(BibleLinks.slug(23, 'LSG'), 'esaie');
      expect(BibleLinks.slug(22, 'LSG'), 'cantique-des-cantiques');
      expect(BibleLinks.slug(43, 'KJV'), 'john');
      expect(BibleLinks.slug(22, 'WEB'), 'song-of-solomon');
      // Langue connue sur le téléphone : elle l'emporte.
      expect(BibleLinks.slug(43, 'XYZ', language: 'en'), 'john');
      expect(BibleLinks.slug(43, 'YCB', language: 'yo'), 'jean');
    });

    test('livre lu dans un lien : numéro, nom, abréviation, accents, tirets', () {
      expect(BibleLinks.bookFromSegment('43'), 43);
      expect(BibleLinks.bookFromSegment('jean'), 43);
      expect(BibleLinks.bookFromSegment('john'), 43);
      expect(BibleLinks.bookFromSegment('jn'), 43);
      expect(BibleLinks.bookFromSegment('1-co'), 46);
      expect(BibleLinks.bookFromSegment('1-corinthiens'), 46);
      expect(BibleLinks.bookFromSegment('j%C3%A9r%C3%A9mie'), 24);
      expect(BibleLinks.bookFromSegment('ps'), 19);
      expect(BibleLinks.bookFromSegment('67'), isNull);
      expect(BibleLinks.bookFromSegment('inconnu'), isNull);
    });
  });

  group('versets', () {
    test('plages triées et fusionnées', () {
      expect(BibleLinks.formatVerses(BibleLinks.parseVerses('17,16')!), '16-17');
      expect(BibleLinks.formatVerses(BibleLinks.parseVerses('1,4-6')!), '1,4-6');
      expect(BibleLinks.formatVerses(BibleLinks.parseVerses('20,16-18,17')!), '16-18,20');
      expect(BibleLinks.parseVerses('18-16'), isNull);
      expect(BibleLinks.parseVerses('0'), isNull);
      expect(BibleLinks.parseVerses('a'), isNull);
      expect(BibleLinks.parseVerses(List.generate(11, (i) => '${i * 2 + 1}').join(',')), isNull);
    });

    test('versets choisis dans le lecteur → lien canonique', () {
      expect(BibleLinks.formatVerses(BibleLinks.rangesOf([18, 16, 17, 20])), '16-18,20');
      expect(BibleLinks.passagePath('lsg', 43, 3, ranges: BibleLinks.rangesOf([16, 17, 18])), '/bible/LSG/jean/3/16-18');
      expect(BibleLinks.passagePath('LSG', 46, 13), '/bible/LSG/1-corinthiens/13');
      expect(BibleLinks.passageUrl('KJV', 43, 3, ranges: BibleLinks.rangesOf([16])),
          '${AppConstants.webBaseUrl}/bible/KJV/john/3/16');
      expect(BibleLinks.passageLabel('Jean', 3, BibleLinks.rangesOf([16, 17, 18, 20])), 'Jean 3:16-18, 20');
    });
  });

  testWidgets('lien ouvert : chapitre affiché, versets mis en avant, page placée sur le premier', (tester) async {
    tester.view.physicalSize = const Size(780, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        bibleDaoProvider.overrideWithValue(_Dao()),
        bibleHighlightDaoProvider.overrideWithValue(_Highlights()),
        bibleTranslationsProvider.overrideWith(_Translations.new),
      ],
      child: const MaterialApp(
        home: BibleReaderScreen(translationCode: 'LSG', book: 'jn', chapter: 3, verses: '30-31'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Jean  3'), findsOneWidget);
    // Verset 30 visible sans défiler à la main.
    expect(find.textContaining('Jean 3 verset 30', findRichText: true).hitTestable(), findsOneWidget);
    // Sans lien, le verset 1 serait en haut : la page a bien défilé.
    expect(find.textContaining('Jean 3 verset 1 ', findRichText: true).hitTestable(), findsNothing);
    final container = ProviderScope.containerOf(tester.element(find.byType(BibleReaderScreen)));
    expect(container.read(bibleReaderPositionProvider)['LSG'], (43, 3));
    expect(tester.takeException(), isNull);
  });

  test('livre du lien retrouvé parmi ceux de la traduction', () {
    const books = [
      BibleBook(translationCode: 'FON', bookNumber: 43, name: 'Jaan'),
    ];
    expect(BibleReaderScreen.resolveBook('43', books), 43);
    expect(BibleReaderScreen.resolveBook('jean', books), 43);
    expect(BibleReaderScreen.resolveBook('jaan', books), 43);
    expect(BibleReaderScreen.resolveBook('genese', books), isNull);
  });
}
