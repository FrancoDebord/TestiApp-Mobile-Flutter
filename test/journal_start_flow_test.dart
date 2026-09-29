import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/journal/data/journal_repository.dart';
import 'package:testi_app/features/journal/models/journal_entry.dart';
import 'package:testi_app/features/journal/screens/journal_screen.dart';
import 'package:testi_app/features/publish/providers/publish_provider.dart';

/// Carnet sans réseau : une entrée de chaque type, filtrées comme le serveur.
class _EmptyJournal implements JournalRepository {
  final requestedTypes = <JournalEntryType?>[];

  static final _all = [
    for (final t in JournalEntryType.values)
      JournalEntry.fromJson({
        'id': 'id-${t.name}', 'title': 'Entrée ${t.label}', 'type': t.name,
        'bodyText': '', 'visibility': 'private', 'status': 'draft',
        'createdAt': '2026-09-26T08:30:00+00:00',
      }),
  ];

  @override
  Future<JournalPage> list({int page = 1, JournalEntryType? type, String? query}) async {
    requestedTypes.add(type);
    final entries = _all.where((e) => type == null || e.type == type).toList();
    return JournalPage(entries: entries, currentPage: 1, lastPage: 1, total: entries.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Remplace l'écran de publication : affiche le brouillon reçu.
class _DraftProbe extends ConsumerWidget {
  const _DraftProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(publishProvider);
    return Scaffold(body: Text('draft:${d.format?.name}:${d.visibility.name}'));
  }
}

Future<void> _pumpJournal(WidgetTester tester, JournalRepository repo) async {
  final router = GoRouter(
    initialLocation: '/journal',
    routes: [
      GoRoute(path: '/journal', builder: (_, _) => const JournalScreen()),
      GoRoute(path: '/journal/:id', builder: (_, s) => Text('entry:${s.pathParameters['id']}')),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [journalRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openFlow(WidgetTester tester, String option) async {
  final router = GoRouter(
    initialLocation: '/journal',
    routes: [
      GoRoute(path: '/journal', builder: (_, _) => const JournalScreen()),
      GoRoute(path: '/journal/new', builder: (_, _) => const _DraftProbe()),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [journalRepositoryProvider.overrideWithValue(_EmptyJournal())],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Nouveau témoignage'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final (option, format) in [
    ('Filmer', 'video'),
    ('Enregistrer ma voix', 'audio'),
    ('Écrire', 'text'),
  ]) {
    testWidgets('« $option » ouvre le parcours en $format, en privé', (tester) async {
      await _openFlow(tester, option);
      expect(find.text('draft:$format:private'), findsOneWidget);
    });
  }

  testWidgets('filtres Texte / Audio / Vidéo : bonne requête, bonnes entrées', (tester) async {
    final repo = _EmptyJournal();
    await _pumpJournal(tester, repo);
    expect(find.text('Entrée Vidéo'), findsOneWidget);
    expect(find.text('Entrée Texte'), findsOneWidget);

    for (final t in JournalEntryType.values) {
      await tester.tap(find.widgetWithText(ChoiceChip, t.label));
      await tester.pumpAndSettle();
      expect(repo.requestedTypes.last, t);
      for (final other in JournalEntryType.values) {
        expect(find.text('Entrée ${other.label}'), other == t ? findsOneWidget : findsNothing,
            reason: 'filtre ${t.label}');
      }
    }

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tous'));
    await tester.pumpAndSettle();
    expect(repo.requestedTypes.last, isNull);
    expect(find.text('Entrée Audio'), findsOneWidget);

    // Ouvrir une entrée vidéo mène à son détail.
    await tester.tap(find.text('Entrée Vidéo'));
    await tester.pumpAndSettle();
    expect(find.text('entry:id-video'), findsOneWidget);
  });
}
