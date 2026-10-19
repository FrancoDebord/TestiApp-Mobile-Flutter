// Directs diffusés sur YouTube (source youtube, sans LiveKit) : lecture de l'API,
// vue YouTube (discussion, « je regarde », fin), mise en page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/live/models/live_models.dart';
import 'package:testi_app/features/live/widgets/live_youtube_view.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/shared/models/user_model.dart';

Map<String, dynamic> _live({String status = 'live', bool host = false}) => {
      'id': 'l1',
      'title': 'Soirée de louange et de témoignages — Cotonou',
      'status': status,
      'source': 'youtube',
      'youtube': {
        'id': 'dQw4w9WgXcQ',
        'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'embedUrl': 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
      },
      'host': {'id': 'h1', 'displayName': 'Pasteur Eli'},
      'commentsEnabled': true,
      'isHost': host,
      'canEnd': host,
      'canModerate': host,
      'stats': {'peakViewers': 4, 'commentCount': 2},
    };

Map<String, dynamic> _comment(String id, String body) => {
      'id': id,
      'body': body,
      'user': {'id': 'u$id', 'displayName': 'Fidèle $id'},
      'createdAt': DateTime.now().toIso8601String(),
    };

class _Api implements ApiService {
  final calls = <String>[];
  String status = 'live';
  final comments = [_comment('1', 'Gloire à Dieu !'), _comment('2', 'Bonsoir depuis Parakou 🙏')];

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET $path');
    expect(path, AppConstants.liveComments('l1'));
    return LaravelResponse<T>(success: true, data: List.of(comments) as T);
  }

  @override
  Future<LaravelResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query}) async {
    calls.add('POST $path');
    if (path == AppConstants.liveHeartbeat('l1')) {
      expect((data as Map)['viewer_id'], isA<String>());
      return LaravelResponse<T>(success: true, data: {'status': status, 'viewers': 37, 'peakViewers': 40} as T);
    }
    if (path == AppConstants.liveComments('l1')) {
      final c = _comment('3', (data as Map)['body'] as String);
      comments.add(c);
      return LaravelResponse<T>(success: true, data: c as T);
    }
    if (path == AppConstants.liveEnd('l1')) {
      status = 'ended';
      return LaravelResponse<T>(success: true, data: _live(status: 'ended', host: true) as T);
    }
    if (path == AppConstants.liveReactions('l1')) {
      return LaravelResponse<T>(success: true, data: {'reactions': {'like': 1}} as T);
    }
    throw UnimplementedError(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

class _FakeAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthStateAuthenticated(UserModel(id: 'me', displayName: 'Awa'));
}

Future<({_Api api, List<int> ended})> _pump(WidgetTester tester,
    {bool host = false, Size size = const Size(390, 844), double scale = 1, _Api? api}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 24 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
  final a = api ?? _Api();
  final ended = <int>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiServiceProvider.overrideWithValue(a),
      authStateProvider.overrideWith(_FakeAuth.new),
    ],
    child: MaterialApp(
      builder: (context, child) =>
          MediaQuery.withClampedTextScaling(minScaleFactor: scale, maxScaleFactor: scale, child: child!),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: LiveYoutubeView(
          live: LiveSession.fromJson(_live(host: host)),
          onClose: () {},
          onEnded: () => ended.add(1),
          playerBuilder: (_) => const AspectRatio(aspectRatio: 16 / 9, child: ColoredBox(color: Colors.red)),
        ),
      ),
    ),
  ));
  await tester.pump();
  // Session connectée chargée avant d'écrire.
  await tester.runAsync(() => ProviderScope.containerOf(tester.element(find.byType(LiveYoutubeView)))
      .read(authStateProvider.future));
  await tester.pump(const Duration(milliseconds: 50));
  return (api: a, ended: ended);
}

void main() {
  test('source youtube : identifiant, lien, index youtubeEnabled', () {
    final l = LiveSession.fromJson(_live());
    expect(l.source, LiveSource.youtube);
    expect(l.source.isExternal, isTrue);
    expect(l.isYoutube, isTrue);
    expect(l.youtubeId, 'dQw4w9WgXcQ');
    expect(l.youtubeUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    expect(LiveSession.fromJson({..._live(), 'source': 'browser', 'youtube': null}).isYoutube, isFalse);
    final index = LivesIndex.fromJson({'configured': false, 'youtubeEnabled': true, 'canGoLive': true});
    expect(index.canStart, isTrue);
    expect(LivesIndex.fromJson({'configured': false}).canStart, isFalse);
  });

  testWidgets('spectateur : discussion, spectateurs, message, J\'aime', (tester) async {
    final r = await _pump(tester);
    expect(find.textContaining('Gloire à Dieu', findRichText: true), findsWidgets);
    expect(find.text('37'), findsWidgets); // « je regarde » → spectateurs
    expect(r.api.calls, contains('POST ${AppConstants.liveHeartbeat('l1')}'));
    // Pas de bouton « Terminer » pour un spectateur.
    expect(find.byKey(const ValueKey('youtube-live-end')), findsNothing);

    await tester.enterText(find.byType(TextField), 'Amen !');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(r.api.calls, contains('POST ${AppConstants.liveComments('l1')}'));

    await tester.tap(find.byKey(const ValueKey('youtube-live-like')));
    await tester.pump();
    expect(r.api.calls, contains('POST ${AppConstants.liveReactions('l1')}'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('diffuseur : terminer le direct', (tester) async {
    final r = await _pump(tester, host: true);
    await tester.tap(find.byKey(const ValueKey('youtube-live-end')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('youtube-live-end-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(r.api.calls, contains('POST ${AppConstants.liveEnd('l1')}'));
    expect(r.ended, [1]);
  });

  testWidgets('direct coupé ailleurs : « je regarde » renvoie ended → écran de fin', (tester) async {
    final api = _Api()..status = 'ended';
    final r = await _pump(tester, api: api);
    expect(r.ended, [1]);
  });

  for (final size in const [Size(320, 568), Size(360, 720), Size(412, 915)]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('sans débordement ${size.width.toInt()}×${size.height.toInt()} ×$scale', (tester) async {
        await _pump(tester, host: true, size: size, scale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
