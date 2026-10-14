// Vidéos Bunny Stream (API du 2026-10-14) : objet « video » { status,
// playback_url, mp4_url, thumbnail_url, duration } + anciens champs ; choix
// de la source de lecture (HLS → MP4 → ancien mediaUrl) ; états affichés ;
// notifications video_ready / video_failed ; re-vérification du détail.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:testi_app/core/media/video_source.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/home/widgets/video_testimony_card.dart';
import 'package:testi_app/features/moderation/providers/moderation_provider.dart'
    show moderationItemFromJson;
import 'package:testi_app/features/notifications/models/notification_models.dart';
import 'package:testi_app/features/notifications/providers/notifications_provider.dart';
import 'package:testi_app/features/profile/models/user_testimony_model.dart';
import 'package:testi_app/features/publish/upload/video_resend.dart';
import 'package:testi_app/features/publish/upload/video_upload_models.dart';
import 'package:testi_app/features/testimony/providers/testimony_refresh.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/services/push_service.dart';
import 'package:testi_app/shared/models/user_model.dart';
import 'package:testi_app/shared/widgets/video_status_views.dart';

// ── Données : réponses réelles de GET /testimonies/{id} (2026-10-14) ─────────

const _cdn = 'https://vz-5fc8c5f9-0fc.b-cdn.net/92bf3ac6';
const _hls = '$_cdn/playlist.m3u8';
const _mp4 = '$_cdn/play_360p.mp4';
const _thumb = '$_cdn/thumbnail.jpg';
const _legacy =
    'https://temoignage.as-krea.com/storage/media/S0cD6ZvZYYn84qDofaox5wj5PJW5ol2ug9rZhBY5.mp4';

Map<String, dynamic> _testimony({
  String id = 't1',
  Object? video,
  Object? mediaUrl,
  String userId = 'u1',
  bool withVideoKey = true,
}) =>
    {
      'id': id,
      'userId': userId,
      'user': {'id': userId, 'display_name': 'Marie'},
      'title': 'Mon autre témoignage',
      'type': 'video',
      'category': 'emploi',
      'bodyText': 'Dieu a pourvu.',
      'mediaUrl': mediaUrl,
      'coverUrl': null,
      'renditions': const [],
      'stats': const {'viewsCount': 2},
      'status': 'approved',
      'visibility': 'public',
      'createdAt': '2026-10-14T16:34:01+00:00',
      if (withVideoKey) 'video': video,
    };

/// Vidéo prête, telle que renvoyée par l'API.
Map<String, dynamic> get _readyJson => _testimony(
      mediaUrl: _hls,
      video: {
        'status': 'ready',
        'playback_url': _hls,
        'mp4_url': _mp4,
        'thumbnail_url': _thumb,
        'duration': 127,
        'hls_url': _hls,
        'mp4_urls': {'240': '$_cdn/play_240p.mp4', '360': _mp4},
      },
    );

/// Aucune URL tant que la vidéo n'est pas prête.
Map<String, dynamic> _pendingJson(String status, {String id = 't1'}) =>
    _testimony(
      id: id,
      mediaUrl: null,
      video: {
        'status': status,
        'playback_url': null,
        'mp4_url': null,
        'thumbnail_url': null,
        'duration': null,
        'hls_url': null,
        'mp4_urls': const <String, dynamic>{},
      },
    );

VideoTestimony _parse(Map<String, dynamic> json) =>
    testimonyFromApiJson(json)! as VideoTestimony;

// ── Faux services ────────────────────────────────────────────────────────────

class _FakeApi implements ApiService {
  _FakeApi(this.byId);

  /// Réponse de GET /testimonies/{id}, par identifiant.
  final Map<String, Map<String, dynamic>> byId;
  final calls = <String>[];

  @override
  Future<LaravelResponse<T>> get<T>(String path,
      {Map<String, dynamic>? query}) async {
    calls.add(path);
    final id = path.split('/').last;
    final data = byId[id];
    if (data == null) throw Exception('404 $path');
    return LaravelResponse<T>(success: true, data: data as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Testimony> _feedItems = const [];

class _FakeFeed extends FeedNotifier {
  @override
  List<Testimony> build() => _feedItems;

  @override
  Future<void> refresh() async {}
}

class _RecordingReloader implements TestimonyReloader {
  final reloaded = <String>[];

  @override
  Future<Testimony?> reload(String id) async {
    reloaded.add(id);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Lecteur factice : [fails] simule un échec d'initialisation.
class _FakeController extends VideoPlayerController {
  _FakeController(String url, {required this.fails})
      : super.networkUrl(Uri.parse(url));
  final bool fails;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    if (fails) throw Exception('format non pris en charge');
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}

void main() {
  // ── Parsing ────────────────────────────────────────────────────────────────

  group('Parsing de l’objet video', () {
    test('ready : playback_url, mp4_url, miniature et durée', () {
      final t = _parse(_readyJson);
      expect(t.processingState, VideoProcessingState.ready);
      expect(t.isReady, isTrue);
      expect(t.hlsUrl, _hls);
      expect(t.mp4Url, _mp4);
      expect(t.thumbnailUrl, _thumb);
      expect(t.durationSeconds, 127);
      expect(t.renditions.map((r) => r.height), [240, 360]);
    });

    test('processing : gardé (badge), aucune URL, rien ne plante', () {
      final t = _parse(_pendingJson('processing'));
      expect(t.isProcessing, isTrue);
      expect(t.isReady, isFalse);
      expect(t.hlsUrl, isNull);
      expect(t.mp4Url, isNull);
      expect(t.thumbnailUrl, '');
      expect(t.durationSeconds, 0);
      expect(t.playbackUrls, isEmpty);
    });

    test('uploading est traité comme « en traitement »', () {
      expect(_parse(_pendingJson('uploading')).isProcessing, isTrue);
    });

    test('failed : état « échec »', () {
      final t = _parse(_pendingJson('failed'));
      expect(t.isFailed, isTrue);
      expect(t.processingState, VideoProcessingState.failed);
    });

    test('Anciens champs seuls (hls_url, mp4_urls) : repli', () {
      final t = _parse(_testimony(mediaUrl: null, video: {
        'status': 'ready',
        'hls_url': _hls,
        'mp4_urls': {'720': '$_cdn/play_720p.mp4', '360': _mp4},
        'thumbnail_url': _thumb,
        'duration': 30,
      }));
      expect(t.hlsUrl, _hls);
      // Pas de mp4_url : la plus haute version de mp4_urls.
      expect(t.mp4Url, '$_cdn/play_720p.mp4');
      expect(t.durationSeconds, 30);
    });

    test('Ancien format à plat (video absent)', () {
      final t = _parse(_testimony(withVideoKey: false, mediaUrl: null)
        ..addAll({'video_status': 'processing', 'hls_url': _hls}));
      expect(t.isProcessing, isTrue);
      expect(t.hlsUrl, _hls);
    });

    test('video = null, mediaUrl HLS : playlist lue depuis mediaUrl', () {
      final t = _parse(_testimony(video: null, mediaUrl: _hls));
      expect(t.hlsUrl, _hls);
      expect(t.isReady, isTrue);
    });

    test('Ancienne vidéo locale /storage/media/…mp4', () {
      final t = _parse(_testimony(mediaUrl: _legacy, video: {
        'status': 'ready',
        'playback_url': null,
        'mp4_url': _legacy,
        'thumbnail_url': null,
        'duration': null,
        'hls_url': null,
        'mp4_urls': const <String, dynamic>{},
      }));
      expect(t.isReady, isTrue);
      expect(t.hlsUrl, isNull);
      expect(t.mediaPath, _legacy);
      expect(t.playbackUrls, [_legacy]);
    });

    test('Ancienne vidéo, chemin relatif : URL absolue', () {
      final t = _parse(_testimony(
          video: null, mediaUrl: '/storage/media/a.mp4'));
      expect(t.mediaPath, endsWith('/storage/media/a.mp4'));
      expect(t.mediaPath, startsWith('http'));
    });

    test('Ni vidéo ni média : lisible mais sans source, sans planter', () {
      final t = _parse(_testimony(video: null, mediaUrl: null));
      expect(t.isReady, isTrue);
      expect(t.playbackUrls, isEmpty);
    });

    test('Types inattendus tolérés (durée texte, statut nombre, listes)', () {
      final t = _parse(_testimony(mediaUrl: 42, video: {
        'status': 3,
        'playback_url': 12,
        'mp4_url': false,
        'thumbnail_url': const [],
        'duration': 'abc',
        'mp4_urls': const ['x'],
      }));
      expect(t.isReady, isTrue);
      expect(t.hlsUrl, isNull);
      expect(t.mp4Url, isNull);
      expect(t.durationSeconds, 0);
    });

    test('VideoProcessingState.parse', () {
      expect(VideoProcessingState.parse(null), VideoProcessingState.ready);
      expect(VideoProcessingState.parse('READY'), VideoProcessingState.ready);
      expect(VideoProcessingState.parse('processing'),
          VideoProcessingState.processing);
      expect(VideoProcessingState.parse('failed'), VideoProcessingState.failed);
      expect(VideoProcessingState.parse('inconnu'), VideoProcessingState.ready);
    });

    test('« Mes témoignages » : trois états, durée et miniature', () {
      final ready = UserTestimony.fromJson(_readyJson);
      expect(ready.videoState, VideoProcessingState.ready);
      expect(ready.durationSeconds, 127);
      expect(ready.thumbnailUrl, _thumb);
      final processing = UserTestimony.fromJson(_pendingJson('processing'));
      expect(processing.isVideoProcessing, isTrue);
      expect(processing.durationSeconds, 0);
      expect(UserTestimony.fromJson(_pendingJson('failed')).isVideoFailed,
          isTrue);
    });

    test('Modération : trois états, durée et miniature', () {
      final ready = moderationItemFromJson(_readyJson)!;
      expect(ready.videoState, VideoProcessingState.ready);
      expect(ready.thumbnailUrl, _thumb);
      expect(ready.durationSeconds, 127);
      expect(moderationItemFromJson(_pendingJson('processing'))!.videoState,
          VideoProcessingState.processing);
      expect(moderationItemFromJson(_pendingJson('failed'))!.videoState,
          VideoProcessingState.failed);
    });
  });

  // ── Choix de la source ─────────────────────────────────────────────────────

  group('Source de lecture', () {
    test('Ordre : HLS, puis MP4, puis ancien mediaUrl ; sans doublon', () {
      expect(
        videoPlaybackChain(
            playbackUrl: _hls, mp4Url: _mp4, legacyUrl: _legacy),
        [_hls, _mp4, _legacy],
      );
      // mediaUrl = playlist HLS (nouveau serveur) : pas de doublon.
      expect(videoPlaybackChain(playbackUrl: _hls, mp4Url: _mp4, legacyUrl: _hls),
          [_hls, _mp4]);
      expect(videoPlaybackChain(mp4Url: null, legacyUrl: _legacy), [_legacy]);
      expect(videoPlaybackChain(playbackUrl: '', mp4Url: '  '), isEmpty);
    });

    test('La version choisie (qualité forcée) passe en premier', () {
      expect(
        videoPlaybackChain(
            primary: '$_cdn/play_240p.mp4', playbackUrl: _hls, mp4Url: _mp4),
        ['$_cdn/play_240p.mp4', _hls, _mp4],
      );
    });

    test('Témoignage prêt : HLS puis MP4 de secours', () {
      expect(_parse(_readyJson).playbackUrls, [_hls, _mp4]);
    });

    test('Repli automatique : HLS en échec → MP4', () async {
      final created = <_FakeController>[];
      final played = await initializeFirstPlayable([_hls, _mp4, _legacy], (u) {
        final c = _FakeController(u, fails: u == _hls);
        created.add(c);
        return c;
      });
      expect(played?.url, _mp4);
      expect(created.first.disposed, isTrue);
      expect(created, hasLength(2));
    });

    test('Repli jusqu’à l’ancien mediaUrl ; null si rien ne se lit', () async {
      final last = await initializeFirstPlayable(
          [_hls, _mp4, _legacy], (u) => _FakeController(u, fails: u != _legacy));
      expect(last?.url, _legacy);
      final none = await initializeFirstPlayable(
          [_hls, _mp4], (u) => _FakeController(u, fails: true));
      expect(none, isNull);
    });

    test('Playlist .m3u8 signalée comme HLS au lecteur', () {
      expect(isHlsUrl(_hls), isTrue);
      expect(isHlsUrl('$_hls?token=1'), isTrue);
      expect(isHlsUrl(_mp4), isFalse);
      expect(networkVideoController(_hls).formatHint, VideoFormat.hls);
      expect(networkVideoController(_mp4).formatHint, isNull);
    });

    // Bunny refuse les requêtes sans Referer (403 vérifié le 2026-10-14 sur la
    // playlist, les variantes, les segments .ts, les MP4 et les miniatures).
    test('Referer envoyé au CDN Bunny (lecteur), pas aux autres hôtes', () {
      expect(isBunnyCdnUrl(_hls), isTrue);
      expect(isBunnyCdnUrl(_legacy), isFalse);
      expect(mediaHttpHeaders(_hls)['Referer'], startsWith('https://'));
      expect(mediaHttpHeaders(_thumb), isNotEmpty);
      expect(mediaHttpHeaders(_legacy), isEmpty);
      expect(mediaHttpHeaders(null), isEmpty);
      expect(networkVideoController(_hls).httpHeaders,
          containsPair('Referer', mediaHttpHeaders(_hls)['Referer']));
      expect(networkVideoController(_mp4).httpHeaders, contains('Referer'));
      expect(networkVideoController(_legacy).httpHeaders, isEmpty);
    });
  });

  // ── Notifications ──────────────────────────────────────────────────────────

  group('Notifications video_ready / video_failed', () {
    test('Intention de navigation : détail du témoignage', () {
      for (final type in ['video_ready', 'video_failed']) {
        final i = FcmNavIntent.fromData({'type': type, 'testimony_id': 't9'})!;
        expect(i.type, type);
        expect(i.testimonyId, 't9');
        // Repli sur `id`.
        expect(FcmNavIntent.fromData({'type': type, 'id': 't8'})!.testimonyId,
            't8');
      }
    });

    test('Liste des notifications : prête = approuvé, échec = refusé', () {
      AppNotification n(String type) => notificationFromJson({
            'id': 'n-$type',
            'type': type,
            'createdAt': '2026-10-14T10:00:00+00:00',
            'testimonyId': 't1',
          })!;
      expect(n('video_ready').type, NotificationType.approved);
      expect(n('video_failed').type, NotificationType.rejected);
    });

    test('Push reçu : le témoignage concerné est rechargé', () {
      final reloader = _RecordingReloader();
      final container = ProviderContainer(overrides: [
        testimonyReloaderProvider.overrideWithValue(reloader),
      ]);
      addTearDown(container.dispose);
      final refProvider = Provider<Ref>((ref) => ref);
      final ref = container.read(refProvider);
      refreshForPush(ref, 'video_ready', testimonyId: 't1');
      refreshForPush(ref, 'video_failed', testimonyId: 't2');
      refreshForPush(ref, 'like', testimonyId: 't3');
      expect(reloader.reloaded, ['t1', 't2']);
    });

    test('Rechargement : fil et dernière version connue mis à jour', () async {
      final processing = _parse(_pendingJson('processing'));
      _feedItems = [processing];
      final api = _FakeApi({'t1': _readyJson});
      final container = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(api),
        feedNotifierProvider.overrideWith(_FakeFeed.new),
      ]);
      addTearDown(container.dispose);
      container.read(feedNotifierProvider);

      await container
          .read(testimonyReloaderProvider)
          .onVideoPush({'type': 'video_ready', 'testimony_id': 't1'});

      final fresh = container.read(freshTestimoniesProvider)['t1']!
          as VideoTestimony;
      expect(fresh.isReady, isTrue);
      expect(fresh.hlsUrl, _hls);
      final inFeed = container.read(feedNotifierProvider).single
          as VideoTestimony;
      expect(inFeed.isReady, isTrue);
      expect(inFeed.durationSeconds, 127);
    });

    test('video_failed : état « échec » propagé ; autres types ignorés',
        () async {
      _feedItems = [_parse(_pendingJson('processing'))];
      final api = _FakeApi({'t1': _pendingJson('failed')});
      final container = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(api),
        feedNotifierProvider.overrideWith(_FakeFeed.new),
      ]);
      addTearDown(container.dispose);
      container.read(feedNotifierProvider);
      final reloader = container.read(testimonyReloaderProvider);

      await reloader.onVideoPush({'type': 'comment', 'testimony_id': 't1'});
      expect(api.calls, isEmpty);

      await reloader.onVideoPush({'type': 'video_failed', 'id': 't1'});
      expect(
          (container.read(feedNotifierProvider).single as VideoTestimony)
              .isFailed,
          isTrue);
    });

    test('Retour au premier plan : vidéos en traitement relues', () async {
      _feedItems = [
        _parse(_pendingJson('processing', id: 't1')),
        _parse(_readyJson..['id'] = 't2'),
      ];
      final api = _FakeApi({'t1': _readyJson});
      final container = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(api),
        feedNotifierProvider.overrideWith(_FakeFeed.new),
      ]);
      addTearDown(container.dispose);
      container.read(feedNotifierProvider);

      await container.read(testimonyReloaderProvider).reloadPending();
      // Seule la vidéo en traitement est relue.
      expect(api.calls, ['/testimonies/t1']);
    });
  });

  // ── Re-vérification (détail d'une vidéo en traitement) ─────────────────────

  group('VideoStatusPoller', () {
    testWidgets('Toutes les 30 s, 10 essais au plus, puis arrêt',
        (tester) async {
      var checks = 0;
      final poller = VideoStatusPoller(check: () async {
        checks++;
        return false;
      })..start();
      await tester.pump(const Duration(seconds: 29));
      expect(checks, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(checks, 1);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(seconds: 30));
      }
      expect(checks, 10);
      expect(poller.isActive, isFalse);
      // Ne redémarre pas après 10 essais.
      poller.start();
      expect(poller.isActive, isFalse);
    });

    testWidgets('S’arrête dès que la vidéo est prête ou en échec',
        (tester) async {
      var checks = 0;
      final poller = VideoStatusPoller(check: () async => ++checks == 3)
        ..start();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 30));
      }
      expect(checks, 3);
      expect(poller.isActive, isFalse);
    });
  });

  // ── Affichage ──────────────────────────────────────────────────────────────

  group('Affichage des états', () {
    testWidgets('En traitement : badge, pas de bouton lecture',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: VideoNotReadySurface(
                state: VideoProcessingState.processing),
          ),
        ),
      ));
      expect(find.text(VideoStatusText.processing), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.text(VideoStatusText.resend), findsNothing);
    });

    testWidgets('Échec : message ; « Renvoyer » seulement avec une action',
        (tester) async {
      var tapped = false;
      Widget surface(VoidCallback? onResend) => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 220,
                child: VideoNotReadySurface(
                  state: VideoProcessingState.failed,
                  onResend: onResend,
                ),
              ),
            ),
          );
      await tester.pumpWidget(surface(null));
      expect(find.text(VideoStatusText.failed), findsOneWidget);
      expect(find.text(VideoStatusText.resend), findsNothing);

      await tester.pumpWidget(surface(() => tapped = true));
      await tester.tap(find.text(VideoStatusText.resend));
      expect(tapped, isTrue);
    });

    testWidgets('« Renvoyer la vidéo » réservé à l’auteur', (tester) async {
      VoidCallback? forAuthor;
      VoidCallback? forOther;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(
              const UserModel(id: 'u1', displayName: 'Marie')),
        ],
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            forAuthor = resendVideoAction(context, ref,
                testimonyId: 't1', authorId: 'u1');
            forOther = resendVideoAction(context, ref,
                testimonyId: 't1', authorId: 'u2');
            return const SizedBox();
          }),
        ),
      ));
      expect(forAuthor, isNotNull);
      expect(forOther, isNull);
    });

    testWidgets('Carte du fil : en traitement, échec (auteur), prête + durée',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      Future<void> pumpCard(VideoTestimony t) => tester.pumpWidget(
            ProviderScope(
              overrides: [
                currentUserProvider.overrideWithValue(
                    const UserModel(id: 'u1', displayName: 'Marie')),
                apiServiceProvider.overrideWithValue(_FakeApi(const {})),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                      child: VideoTestimonyCard(testimony: t)),
                ),
              ),
            ),
          );

      await pumpCard(_parse(_pendingJson('processing')));
      await tester.pump();
      expect(find.text(VideoStatusText.processing), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

      await pumpCard(_parse(_pendingJson('failed')));
      await tester.pump();
      expect(find.text(VideoStatusText.failed), findsOneWidget);
      expect(find.text(VideoStatusText.resend), findsOneWidget);

      await pumpCard(_parse(_readyJson));
      await tester.pump();
      expect(find.text('02:07'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text(VideoStatusText.processing), findsNothing);
    });

    testWidgets('Carte du fil : pas de « Renvoyer » pour un autre compte',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(
              const UserModel(id: 'someone-else', displayName: 'Paul')),
          apiServiceProvider.overrideWithValue(_FakeApi(const {})),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VideoTestimonyCard(
                  testimony: _parse(_pendingJson('failed'))),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text(VideoStatusText.failed), findsOneWidget);
      expect(find.text(VideoStatusText.resend), findsNothing);
    });
  });

  // ── « Renvoyer la vidéo » ──────────────────────────────────────────────────

  group('Renvoyer la vidéo', () {
    test('Corps de upload-init reconstruit depuis le témoignage', () {
      final body = resendBodyFromTestimonyJson({
        ..._pendingJson('failed'),
        'bibleVerse': 'Car je connais les projets…',
        'verseReference': 'Jérémie 29:11',
        'eventId': null,
        'mentions': [
          {'id': 'u7', 'name': 'Awa'},
        ],
        'proofsPublic': false,
        'visibility': 'followers',
      });
      expect(body, {
        'title': 'Mon autre témoignage',
        'type': 'video',
        'category': 'emploi',
        'body_text': 'Dieu a pourvu.',
        'bible_verse': 'Car je connais les projets…',
        'verse_ref': 'Jérémie 29:11',
        'mention_ids': ['u7'],
        'proofs_public': false,
        'visibility': 'followers',
      });
    });

    test('Témoignage remplacé enregistré avec la tâche (reprise)', () {
      final job = VideoUploadJob(
        sourcePath: '/tmp/v.mp4',
        title: 'T',
        body: const {'title': 'T'},
        replacesTestimonyId: 'old',
      );
      expect(VideoUploadJob.fromJson(job.toJson()).replacesTestimonyId, 'old');
    });
  });
}
