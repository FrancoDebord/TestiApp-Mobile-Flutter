import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/live/data/live_repository.dart';
import 'package:testi_app/features/live/models/live_models.dart';
import 'package:testi_app/features/live/screens/live_studio_screen.dart';
import 'package:testi_app/features/live/screens/live_viewer_screen.dart';

/// Faux dépôt : `show` répond, le reste échoue (la salle s'affiche en erreur,
/// ce qui suffit pour vérifier la mise en page).
class _FakeRepo implements LiveRepository {
  _FakeRepo(this.live);
  final LiveSession live;

  @override
  Future<LiveSession> show(String id) async => live;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(UnimplementedError(invocation.memberName.toString()));
}

LiveSession _live({required bool host, String status = 'live'}) =>
    LiveSession.fromJson({
      'id': 'l1',
      'title': 'Guéri par la grâce : un témoignage très long pour tester',
      'description': null,
      'category': 'guerison',
      'status': status,
      'statusLabel': 'En direct',
      'commentsEnabled': true,
      'host': {
        'id': 'h1',
        'displayName': 'Pasteur Jean-Baptiste Mukendi',
        'initials': 'PJ',
        'avatarUrl': null,
      },
      'stats': {
        'peakViewers': 12,
        'commentCount': 3,
        'reactions': {'like': 1234, 'pray': 567, 'amen': 89, 'fire': 10},
      },
      'isHost': host,
      'canModerate': host,
      'webUrl': 'https://example.org/lives/l1',
      'startedAt': '2026-09-25T10:00:00+00:00',
      'endedAt': null,
      'endReason': null,
      'createdAt': '2026-09-25T09:55:00+00:00',
    });

void main() {
  setUp(() {
    // WakelockPlus (pigeon) : répondre « ok » sans plateforme.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (message) async => const StandardMessageCodec().encodeMessage(<Object?>[]),
    );
  });

  Future<void> pump(WidgetTester tester, Widget screen, LiveSession live,
      {required Size size, double scale = 1.0, double keyboard = 0}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [liveRepositoryProvider.overrideWithValue(_FakeRepo(live))],
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
      for (final keyboard in const [0.0, 300.0]) {
        final label = '${size.width.toInt()} px, ×$scale, clavier $keyboard';

        testWidgets('studio ($label)', (tester) async {
          final live = _live(host: true);
          await pump(
            tester,
            LiveStudioScreen(
              args: LiveStudioArgs(
                live: live,
                credentials:
                    const LiveCredentials(url: '', token: '', identity: ''),
              ),
            ),
            live,
            size: size,
            scale: scale,
            keyboard: keyboard,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('spectateur ($label)', (tester) async {
          final live = _live(host: false);
          await pump(tester, const LiveViewerScreen(liveId: 'l1'), live,
              size: size, scale: scale, keyboard: keyboard);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
