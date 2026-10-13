// Autocomplétion des barres de recherche (docs/fonctionnalites/recherche.md, dépôt du serveur) :
// anti-rebond, requêtes obsolètes ignorées, sélection, flèche « Compléter », recherches récentes,
// hors ligne, clavier, et mise en page sur un petit écran avec une grande taille de police.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/shared/search/search_suggestions.dart';
import 'package:testi_app/shared/widgets/search_autocomplete_field.dart';

class _FakeServer {
  final calls = <String>[];
  final tokens = <CancelToken?>[];
  final pending = <String, Completer<SearchSuggestResponse>>{};
  bool manual = false;
  final logged = <String>[];

  Future<SearchSuggestResponse> fetch(String q, SearchScope scope, {int limit = 6, CancelToken? cancelToken}) {
    calls.add(q);
    tokens.add(cancelToken);
    if (manual) return (pending[q] = Completer<SearchSuggestResponse>()).future;
    return Future.value(response(q));
  }

  static SearchSuggestResponse response(String q) => SearchSuggestResponse.fromJson({
        'suggestions': [
          {'text': 'Guérison miraculeuse de ma mère', 'source': 'testimony', 'highlight': [0, q.length]},
          {'text': 'guéri mon fils', 'source': 'testimony'},
        ],
        'results': [
          {
            'type': 'user',
            'id': 'u1',
            'label': 'Guérison et Délivrance — Ministère International de la Restauration',
            'sublabel': 'Organisation · Cotonou',
            'verified': true,
            'route': '/users/u1',
          },
          {'type': 'category', 'id': 'guerison', 'label': 'Guérison', 'route': '/explore/category/guerison'},
        ],
      });
}

Widget _app({
  required _FakeServer server,
  required MemoryRecentSearchStore store,
  bool online = true,
  ValueChanged<String>? onSubmitted,
  void Function(SearchDirectResult)? onResult,
  TextEditingController? controller,
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      searchSuggestFetcherProvider.overrideWithValue(server.fetch),
      searchLoggerProvider.overrideWithValue(server.logged.add),
      recentSearchStoreProvider.overrideWithValue(store),
      searchOnlineProvider.overrideWithValue(online),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                SearchAutocompleteField(
                  controller: controller,
                  onSubmitted: onSubmitted ?? (_) {},
                  onResultSelected: onResult,
                  hintText: 'Rechercher un témoignage',
                ),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _type(WidgetTester tester, String text, {Duration wait = Duration.zero}) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(wait);
}

void main() {
  testWidgets('anti-rebond : une seule requête pour une saisie rapide, puis suggestions surlignées', (tester) async {
    final server = _FakeServer();
    await tester.pumpWidget(_app(server: server, store: MemoryRecentSearchStore()));
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await _type(tester, 'g', wait: const Duration(milliseconds: 100));
    await _type(tester, 'gu', wait: const Duration(milliseconds: 100));
    await _type(tester, 'gue', wait: const Duration(milliseconds: 100));
    await _type(tester, 'guer', wait: const Duration(milliseconds: 100));
    expect(server.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(server.calls, ['guer']);

    expect(find.text('Guérison miraculeuse de ma mère', findRichText: true), findsOneWidget);
    expect(find.text('SUGGESTIONS'), findsOneWidget);
    expect(find.text('ACCÈS DIRECT'), findsOneWidget);
    // Surlignage : « Guér » en gras.
    final rich = tester.widget<RichText>(find.text('Guérison miraculeuse de ma mère', findRichText: true));
    final spans = <TextSpan>[];
    rich.text.visitChildren((s) {
      if (s is TextSpan && s.text != null) spans.add(s);
      return true;
    });
    final bold = spans.firstWhere((s) => s.style?.fontWeight == FontWeight.w700);
    expect(bold.text, 'Guér');
  });

  testWidgets('une réponse obsolète est annulée et ignorée', (tester) async {
    final server = _FakeServer()..manual = true;
    await tester.pumpWidget(_app(server: server, store: MemoryRecentSearchStore()));
    await tester.tap(find.byType(TextField));
    await _type(tester, 'gue', wait: const Duration(milliseconds: 300));
    await _type(tester, 'pri', wait: const Duration(milliseconds: 300));
    expect(server.calls, ['gue', 'pri']);
    expect(server.tokens.first!.isCancelled, isTrue);

    server.pending['pri']!.complete(SearchSuggestResponse.fromJson({
      'suggestions': [
        {'text': 'prière du matin'},
      ],
    }));
    await tester.pump();
    server.pending['gue']!.complete(_FakeServer.response('gue'));
    await tester.pump();
    expect(find.text('prière du matin', findRichText: true), findsOneWidget);
    expect(find.text('Guérison miraculeuse de ma mère', findRichText: true), findsNothing);
  });

  testWidgets('toucher une suggestion lance la recherche et l’ajoute aux récentes', (tester) async {
    final server = _FakeServer();
    final store = MemoryRecentSearchStore();
    String? submitted;
    await tester.pumpWidget(_app(server: server, store: store, onSubmitted: (q) => submitted = q));
    await tester.tap(find.byType(TextField));
    await _type(tester, 'guer', wait: const Duration(milliseconds: 300));
    await tester.pump();

    await tester.tap(find.text('Guérison miraculeuse de ma mère', findRichText: true));
    await tester.pumpAndSettle();
    expect(submitted, 'Guérison miraculeuse de ma mère');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Guérison miraculeuse de ma mère');
    expect(store.data['all'], ['Guérison miraculeuse de ma mère']);
    expect(server.logged, ['Guérison miraculeuse de ma mère']);
    expect(find.text('SUGGESTIONS'), findsNothing); // liste fermée
  });

  testWidgets('la flèche « Compléter » remplit le champ sans lancer la recherche', (tester) async {
    final server = _FakeServer();
    final controller = TextEditingController();
    var submits = 0;
    await tester.pumpWidget(_app(server: server, store: MemoryRecentSearchStore(), controller: controller, onSubmitted: (_) => submits++));
    await tester.tap(find.byType(TextField));
    await _type(tester, 'guer', wait: const Duration(milliseconds: 300));
    await tester.pump();

    await tester.tap(find.byTooltip('Compléter avec « guéri mon fils »'));
    await tester.pump();
    expect(controller.text, 'guéri mon fils ');
    expect(submits, 0);
  });

  testWidgets('un résultat direct ouvre sa page', (tester) async {
    final server = _FakeServer();
    SearchDirectResult? opened;
    await tester.pumpWidget(_app(server: server, store: MemoryRecentSearchStore(), onResult: (r) => opened = r));
    await tester.tap(find.byType(TextField));
    await _type(tester, 'guer', wait: const Duration(milliseconds: 300));
    await tester.pump();

    await tester.tap(find.text('Guérison', findRichText: true));
    await tester.pumpAndSettle();
    expect(opened?.type, SearchResultType.category);
    expect(opened?.route, '/explore/category/guerison');
  });

  testWidgets('champ vide : recherches récentes, effaçables une à une ou toutes', (tester) async {
    final store = MemoryRecentSearchStore()..data['all'] = ['prière', 'jeûne'];
    await tester.pumpWidget(_app(server: _FakeServer(), store: store));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('RECHERCHES RÉCENTES'), findsOneWidget);
    expect(find.text('prière', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('Retirer « prière » des recherches récentes'));
    await tester.pumpAndSettle();
    expect(store.data['all'], ['jeûne']);
    expect(find.text('prière', findRichText: true), findsNothing);

    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();
    expect(store.data['all'], isEmpty);
    expect(find.text('RECHERCHES RÉCENTES'), findsNothing);
  });

  testWidgets('hors ligne : aucune requête, récentes correspondantes seulement', (tester) async {
    final server = _FakeServer();
    final store = MemoryRecentSearchStore()..data['all'] = ['Guérison divine', 'prière'];
    await tester.pumpWidget(_app(server: server, store: store, online: false));
    await tester.tap(find.byType(TextField));
    await _type(tester, 'guer', wait: const Duration(milliseconds: 300));
    await tester.pump();
    expect(server.calls, isEmpty);
    expect(find.text('Guérison divine', findRichText: true), findsOneWidget);
    expect(find.text('prière', findRichText: true), findsNothing);
  });

  testWidgets('clavier : ↓ puis Entrée choisit, Échap ferme', (tester) async {
    final server = _FakeServer();
    String? submitted;
    await tester.pumpWidget(_app(server: server, store: MemoryRecentSearchStore(), onSubmitted: (q) => submitted = q));
    await tester.tap(find.byType(TextField));
    await _type(tester, 'guer', wait: const Duration(milliseconds: 300));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('SUGGESTIONS'), findsNothing);

    await _type(tester, 'gueri', wait: const Duration(milliseconds: 300));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(submitted, 'guéri mon fils');
  });

  testWidgets('320 px et police ×1,3 : aucun débordement', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryRecentSearchStore()..data['all'] = ['Une très longue recherche récente qui ne tient pas sur une ligne'];
    await tester.pumpWidget(_app(server: _FakeServer(), store: store, textScale: 1.3));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _type(tester, 'guer', wait: const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('ACCÈS DIRECT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('pliage, correspondance et récentes', () {
    expect(foldForSearch('Cœur ÉGLISE'), 'coeur eglise');
    expect(findSearchMatch('Dieu a guéri mon fils', 'GUERI'), (7, 5));
    expect(findSearchMatch('Guérison', 'gué'), (0, 3));
    expect(findSearchMatch('Prière', 'xyz'), isNull);
    final list = addRecentSearch(['Prière', 'jeûne'], 'priere');
    expect(list, ['priere', 'jeûne']);
    expect(addRecentSearch(List.generate(10, (i) => 'r$i'), 'nouveau').length, maxRecentSearches);
  });
}
