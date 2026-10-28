// « Je prie » sur un témoignage : temps de prière de 5 minutes avant la prière,
// début signalé au serveur (POST /testimonies/{id}/pray/start) ; ensuite prier encore
// ou retirer sa dernière prière (docs serveur prier-plusieurs-fois.md).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart' show Options;
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart' show interactionProvider;
import 'package:testi_app/features/testimony/prayer/pray_for_testimony.dart';
import 'package:testi_app/services/api_service.dart';

class _Api implements ApiService {
  final posts = <String>[];
  final deletes = <String>[];

  @override
  Future<LaravelResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query, Options? options}) async {
    posts.add(path);
    return LaravelResponse<T>(
      success: true,
      data: <String, dynamic>{'isPrayedByMe': true, 'prayersCount': 1} as T,
    );
  }

  @override
  Future<LaravelResponse<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? query, Options? options}) async {
    deletes.add(path);
    return LaravelResponse<T>(
      success: true,
      data: <String, dynamic>{'isPrayedByMe': false, 'prayersCount': 0} as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

final _t = TextTestimony(
  id: 't1',
  author: const TestimonyAuthor(uid: 'u1', displayName: 'Afi Mensah'),
  title: 'Guérie après dix ans de maladie',
  category: TestimonyCategory.guerison,
  createdAt: DateTime(2026),
  stats: const TestimonyStats(views: 0, comments: 0, likes: 0, prayers: 0),
  preview: 'Après des années de souffrance, Dieu a **touché** mon corps.',
);

void main() {
  testWidgets('prier pour un témoignage : 5 minutes, puis validation', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = _Api();
    late WidgetRef widgetRef;
    await tester.pumpWidget(ProviderScope(
      overrides: [apiServiceProvider.overrideWithValue(api)],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          widgetRef = ref;
          return Scaffold(
            body: TextButton(
              onPressed: () => prayForTestimony(context, ref, _t),
              child: const Text('Je prie'),
            ),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Je prie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Écran immersif : témoignage affiché, début signalé, rien de posé.
    expect(find.text('Temps de prière'), findsOneWidget);
    expect(find.text(_t.title), findsOneWidget);
    expect(find.textContaining('Dieu a touché mon corps'), findsOneWidget);
    expect(api.posts, [AppConstants.testimonyPrayStart('t1')]);
    expect(widgetRef.read(interactionProvider.notifier).isPrayed(_t), isFalse);

    await tester.pump(const Duration(minutes: 5, seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text("J'ai prié pour ce témoignage"));
    await tester.pump();
    await tester.tap(find.text('Valider ma prière'));
    await tester.pumpAndSettle();

    expect(api.posts.last, AppConstants.testimonyReactions('t1'));
    expect(widgetRef.read(interactionProvider.notifier).isPrayed(_t), isTrue);

    // Déjà en prière : « Prier encore » ou « Retirer ma dernière prière » (immédiat).
    await tester.tap(find.text('Je prie'));
    await tester.pumpAndSettle();
    expect(find.text('Vous avez prié 1 fois'), findsOneWidget);
    expect(find.text('Prier encore'), findsOneWidget);
    await tester.tap(find.text('Retirer ma dernière prière'));
    await tester.pumpAndSettle();
    expect(find.text('Temps de prière'), findsNothing);
    expect(api.deletes, [AppConstants.testimonyReactions('t1')]);
    expect(widgetRef.read(interactionProvider.notifier).isPrayed(_t), isFalse);
  });

  test('extrait montré pendant la prière : texte sans mise en forme', () {
    expect(prayerSubjectText(_t), 'Après des années de souffrance, Dieu a touché mon corps.');
  });
}
