import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/journal/data/journal_repository.dart';
import 'package:testi_app/features/journal/models/journal_entry.dart';
import 'package:testi_app/features/journal/screens/journal_entry_screen.dart';

/// Renvoie l'entrée demandée, au format exact de l'API (TestimonyResource).
class _FakeJournal implements JournalRepository {
  _FakeJournal(this.json);
  final Map<String, dynamic> json;

  @override
  Future<JournalEntry> show(String id) async => JournalEntry.fromJson(json);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Comme l'ancien serveur : GET /testimonies/{id} répond 403 pour une entrée privée.
class _RefusingJournal implements JournalRepository {
  @override
  Future<JournalEntry> show(String id) async =>
      throw const JournalFailure('Accès refusé', statusCode: 403);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Map<String, dynamic> _api(String type, {String? media, String body = 'Merci **Seigneur** !'}) => {
      'id': 'id-$type',
      'userId': 'u1',
      'title': 'Mon témoignage $type',
      'type': type,
      'category': 'autre',
      'bodyText': body,
      'mediaUrl': media,
      'coverUrl': null,
      'shareUrl': 'https://testi.airid-africa.com/testimonies/id-$type',
      'duration': 42,
      'bibleVerse': null,
      'verseReference': null,
      'tags': <String>[],
      'visibility': 'private',
      'status': 'draft',
      'createdAt': '2026-09-26T08:30:00+00:00',
      'updatedAt': '2026-09-26T08:30:00+00:00',
    };

Future<void> _open(WidgetTester tester, Map<String, dynamic> json) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [journalRepositoryProvider.overrideWithValue(_FakeJournal(json))],
    child: MaterialApp(home: JournalEntryScreen(entryId: json['id'] as String)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('entrée texte : s\'affiche sans erreur', (tester) async {
    await _open(tester, _api('text'));
    expect(tester.takeException(), isNull);
    expect(find.text('Mon témoignage text'), findsOneWidget);
    expect(find.text('Partager ce témoignage'), findsOneWidget);
  });

  testWidgets('entrée audio : s\'affiche sans erreur', (tester) async {
    await _open(tester, _api('audio', media: 'https://x.test/a.m4a', body: ''));
    expect(tester.takeException(), isNull);
    expect(find.text('Mon témoignage audio'), findsOneWidget);
  });

  testWidgets('entrée vidéo : s\'affiche sans erreur', (tester) async {
    await _open(tester, _api('video', media: 'https://x.test/v.mp4', body: ''));
    expect(tester.takeException(), isNull);
    expect(find.text('Mon témoignage video'), findsOneWidget);
  });

  testWidgets(
      'serveur qui refuse la lecture (403) : l\'entrée venue de la liste s\'affiche quand même',
      (tester) async {
    for (final type in ['text', 'audio', 'video']) {
      final entry = JournalEntry.fromJson(
          _api(type, media: type == 'text' ? null : 'https://x.test/f'));
      await tester.pumpWidget(ProviderScope(
        overrides: [journalRepositoryProvider.overrideWithValue(_RefusingJournal())],
        child: MaterialApp(
            home: JournalEntryScreen(entryId: entry.id, initialEntry: entry)),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: type);
      expect(find.text('Mon témoignage $type'), findsOneWidget, reason: type);
      expect(find.text('Accès refusé'), findsNothing, reason: type);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
