// Historique des versets du jour : lecture de l'API et page dédiée.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/daily_verse/providers/verse_history_providers.dart';
import 'package:testi_app/features/daily_verse/screens/verse_history_screen.dart';
import 'package:testi_app/services/api_service.dart';

String _day(int ago) => DateTime.now().subtract(Duration(days: ago)).toIso8601String().substring(0, 10);

Map<String, dynamic> _entry(int ago, {List<String> mine = const []}) => {
      'date': _day(ago),
      'id': 100 - ago,
      'reference': ago == 0 ? 'Jean 3:16' : 'Psaume 23:${ago + 1}',
      'verseText': "Car Dieu a tant aimé le monde qu'il a donné son Fils unique, afin que quiconque croit en lui ne périsse point.",
      'themeLabel': 'Amour',
      'counts': {'likes': 12 + ago, 'prayers': 4, 'comments': 3, 'testimonies': 2, 'prayerRequests': 1},
      'myReactions': mine,
    };

class _Api implements ApiService {
  final queries = <Map<String, dynamic>?>[];

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    expect(path, AppConstants.verseHistory);
    queries.add(query);
    final page = query?['page'] as int? ?? 1;
    return LaravelResponse<T>(
      success: true,
      data: (page == 1
          ? [_entry(0, mine: const ['like']), _entry(1), _entry(2, mine: const ['pray'])]
          : [_entry(3)]) as T,
      meta: {'currentPage': page, 'lastPage': 2},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

Future<_Api> _pump(WidgetTester tester, {double width = 390, double scale = 1}) async {
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final api = _Api();
  await tester.pumpWidget(ProviderScope(
    overrides: [apiServiceProvider.overrideWithValue(api)],
    child: MaterialApp(
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: scale,
        maxScaleFactor: scale,
        child: const VerseHistoryScreen(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  test('jour de l\'historique : compteurs et réactions', () {
    final e = VerseHistoryEntry.fromJson(_entry(2, mine: const ['pray']));
    expect(e.reference, 'Psaume 23:3');
    expect(e.likes, 14);
    expect(e.testimonies, 2);
    expect(e.isPrayed, isTrue);
    expect(e.isLiked, isFalse);
  });

  test('lien de partage du jour : shareUrl, sinon webUrl daté', () {
    expect(VerseHistoryEntry.fromJson(_entry(1)).shareUrl, isNull);
    expect(
      VerseHistoryEntry.fromJson({..._entry(1), 'webUrl': 'https://site.org/verset-du-jour/2026-10-27'}).shareUrl,
      'https://site.org/verset-du-jour/2026-10-27',
    );
    expect(
      VerseHistoryEntry.fromJson({
        ..._entry(1),
        'webUrl': 'https://site.org/verset-du-jour/2026-10-27',
        'shareUrl': 'https://partage.org/verset-du-jour/2026-10-27',
      }).shareUrl,
      'https://partage.org/verset-du-jour/2026-10-27',
    );
  });

  testWidgets('page des versets précédents : jours, compteurs, page suivante', (tester) async {
    final api = await _pump(tester);
    expect(find.text('Versets précédents'), findsOneWidget);
    expect(find.textContaining("AUJOURD'HUI"), findsOneWidget);
    expect(find.text('Jean 3:16'), findsOneWidget);
    expect(find.text('12 j\'aime'), findsOneWidget);
    expect(find.text('2 témoignages'), findsWidgets);
    // Chaque jour se partage sans l'ouvrir.
    expect(find.byKey(const ValueKey('verse-history-share-99')), findsOneWidget);
    expect(find.byTooltip('Partager le verset'), findsWidgets);
    // Défilement : page 2.
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(api.queries.map((q) => q?['page']), containsAll([1, 2]));
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('sans débordement (320 px, ×$scale)', (tester) async {
      await _pump(tester, width: 320, scale: scale);
      expect(tester.takeException(), isNull);
    });
  }
}
