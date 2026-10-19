// Direct YouTube d'un événement : pas de débordement (petits écrans, texte agrandi, clavier).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/events/screens/event_live_screen.dart';
import 'package:testi_app/services/api_service.dart';

Map<String, dynamic> _event({bool comments = true}) => {
      'id': 'e1',
      'title': 'Grande croisade de réveil et de guérison de Cotonou — édition 2026',
      'type': 'crusade',
      'status': 'published',
      'phase': 'ongoing',
      'startsAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'endsAt': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
      'organizer': {'id': 'o1', 'displayName': 'Église de la Grâce'},
      'youtubeLive': {'id': 'dQw4w9WgXcQ', 'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
      'commentsEnabled': comments,
      'goingCount': 1240,
    };

class _Api implements ApiService {
  _Api({this.comments = true, this.withMessages = true});
  final bool comments;
  final bool withMessages;

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    if (path == AppConstants.eventComments('e1')) {
      return LaravelResponse<T>(
        success: true,
        data: [
          if (withMessages)
            for (var i = 0; i < 30; i++)
              {
                'id': 'c$i',
                'body': i.isEven ? 'Gloire à Dieu ! 🙏' : 'Je suis connecté depuis Parakou, que Dieu bénisse ce moment de louange.',
                'user': {'id': 'u$i', 'displayName': 'Fidèle $i'},
                'createdAt': DateTime.now().subtract(Duration(minutes: i)).toIso8601String(),
              },
        ] as T,
        meta: {'currentPage': 1, 'lastPage': 1},
      );
    }
    return LaravelResponse<T>(success: true, data: _event(comments: comments) as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

Future<void> _pump(WidgetTester tester,
    {required Size size, double scale = 1, double keyboard = 0, double bottomInset = 0, _Api? api}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  tester.view.padding = FakeViewPadding(top: 24 * 3, bottom: bottomInset * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiServiceProvider.overrideWithValue(api ?? _Api())],
    child: MaterialApp(
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: scale,
        maxScaleFactor: scale,
        child: child!,
      ),
      home: EventLiveScreen(
        eventId: 'e1',
        keepScreenOn: false,
        playerBuilder: (_) => const AspectRatio(aspectRatio: 16 / 9, child: ColoredBox(color: Colors.red)),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  const sizes = [Size(320, 568), Size(360, 640), Size(360, 720), Size(360, 780), Size(390, 844), Size(412, 915)];
  for (final size in sizes) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('sans débordement ${size.width.toInt()}×${size.height.toInt()} ×$scale', (tester) async {
        await _pump(tester, size: size, scale: scale, bottomInset: 34);
        expect(find.byKey(const ValueKey('event-live')), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Clavier ouvert.
        await _pump(tester, size: size, scale: scale, keyboard: 300);
        expect(tester.takeException(), isNull);
        // Clavier ouvert, barre système conservée (iOS).
        await _pump(tester, size: size, scale: scale, keyboard: 300, bottomInset: 34);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets("carte de bienvenue : affichée s'il reste de la place, sinon masquée", (tester) async {
    await _pump(tester, size: const Size(390, 844), bottomInset: 34);
    expect(find.byKey(const ValueKey('live-chat-welcome')), findsOneWidget);
    await _pump(tester, size: const Size(360, 720), scale: 1.6, bottomInset: 34);
    expect(find.byKey(const ValueKey('live-chat-welcome')), findsNothing);
  });

  testWidgets('discussion fermée, sans message (360×640 ×1.3)', (tester) async {
    await _pump(tester, size: const Size(360, 640), scale: 1.3, api: _Api(comments: false, withMessages: false));
    expect(tester.takeException(), isNull);
  });
}
