// Vidéos Bunny Stream : choix de la source (HLS / MP4), lecture de l'objet
// « video » d'un témoignage, préférences de qualité et tâche d'envoi.

import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/media/media_quality.dart';
import 'package:testi_app/core/media/playback_preferences.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/profile/models/user_testimony_model.dart';
import 'package:testi_app/features/publish/upload/video_upload_models.dart';

const _hls = 'https://cdn.test/v/playlist.m3u8';
const _mp4 = [
  MediaRendition(url: 'm240', label: '240p', height: 240),
  MediaRendition(url: 'm360', label: '360p', height: 360),
  MediaRendition(url: 'm720', label: '720p', height: 720),
];
const _prefs = PlaybackPreferences();

Map<String, dynamic> _testimony(Map<String, dynamic>? video) => {
      'id': 't1',
      'title': 'Guérie',
      'type': 'video',
      'user': {'id': 'u1', 'displayName': 'Marie'},
      'stats': <String, dynamic>{},
      'createdAt': '2026-10-01T10:00:00Z',
      'video': video,
    };

void main() {
  group('resolveVideo (Bunny)', () {
    ResolvedMedia? pick({
      required bool metered,
      PlaybackPreferences prefs = _prefs,
      VideoQuality? override,
      List<MediaRendition> mp4 = _mp4,
    }) =>
        resolveVideo(
          original: null,
          renditions: mp4,
          hlsUrl: _hls,
          prefs: prefs,
          metered: metered,
          override: override,
        );

    test('Wi-Fi, Auto par défaut → flux HLS', () {
      final m = pick(metered: false);
      expect(m?.url, _hls);
      expect(m?.label, kAdaptiveLabel);
      expect(m?.rendition, isNull);
    });

    test('Données mobiles, Standard par défaut → MP4 360p', () {
      expect(pick(metered: true)?.url, 'm360');
    });

    test('Économie choisie sur données mobiles → MP4 240p', () {
      const p = PlaybackPreferences(videoQualityMobile: VideoQuality.p240);
      expect(pick(metered: true, prefs: p)?.url, 'm240');
    });

    test('Choix forcé dans le lecteur → MP4 correspondant', () {
      expect(pick(metered: false, override: VideoQuality.p720)?.url, 'm720');
      expect(pick(metered: true, override: VideoQuality.auto)?.url, _hls);
    });

    test('Qualité absente → la plus haute en dessous, sinon HLS', () {
      const only240 = [MediaRendition(url: 'm240', label: '240p', height: 240)];
      expect(
          pick(metered: false, override: VideoQuality.p720, mp4: only240)?.url,
          'm240');
      expect(pick(metered: true, mp4: const [])?.url, _hls);
    });

    test('Menu : Auto + qualités présentes seulement (480p jamais proposé)', () {
      const r = [
        MediaRendition(url: 'a', label: '240p', height: 240),
        MediaRendition(url: 'b', label: '480p', height: 480),
        MediaRendition(url: 'c', label: '720p', height: 720),
      ];
      expect(availableVideoQualities(r),
          [VideoQuality.auto, VideoQuality.p720, VideoQuality.p240]);
    });
  });

  group('Préférences de qualité vidéo', () {
    test('Défauts : Standard (360p) sur mobile, Auto en Wi-Fi', () {
      expect(_prefs.videoQualityMobile, VideoQuality.p360);
      expect(_prefs.videoQualityWifi, VideoQuality.auto);
    });

    test('Aller-retour JSON ; ancienne clé ignorée ; Auto refusé sur mobile', () {
      const p = PlaybackPreferences(
        videoQualityMobile: VideoQuality.p240,
        videoQualityWifi: VideoQuality.p720,
      );
      final back = PlaybackPreferences.fromJson(p.toJson());
      expect(back.videoQualityMobile, VideoQuality.p240);
      expect(back.videoQualityWifi, VideoQuality.p720);

      final legacy = PlaybackPreferences.fromJson({
        'video_quality': 'p1080',
        'video_quality_mobile': 'auto',
      });
      expect(legacy.videoQualityMobile, VideoQuality.p360);
      expect(legacy.videoQualityWifi, VideoQuality.auto);
    });

    test('Libellés du menu', () {
      expect(VideoQuality.p240.fullLabel, 'Économie (240p)');
      expect(VideoQuality.p360.fullLabel, 'Standard (360p)');
      expect(VideoQuality.p720.fullLabel, 'HD (720p)');
      expect(VideoQuality.auto.fullLabel, 'Auto');
    });
  });

  group('Témoignage vidéo (objet « video »)', () {
    test('Vidéo prête : HLS, miniature, MP4 triés, durée', () {
      final t = testimonyFromApiJson(_testimony({
        'status': 'ready',
        'hls_url': _hls,
        'thumbnail_url': 'https://cdn.test/v/thumb.jpg',
        'mp4_urls': {'720': 'u720', '240': 'u240', '360': 'u360'},
        'duration': 245,
      })) as VideoTestimony;
      expect(t.hlsUrl, _hls);
      expect(t.thumbnailUrl, 'https://cdn.test/v/thumb.jpg');
      expect(t.renditions.map((r) => r.height), [240, 360, 720]);
      expect(t.renditions.first.label, '240p');
      expect(t.durationSeconds, 245);
      expect(t.isReady, isTrue);
    });

    test('Vidéo pas prête : gardée, son état est affiché', () {
      final raw = _testimony({'status': 'processing', 'hls_url': _hls});
      final t = testimonyFromApiJson(raw) as VideoTestimony;
      expect(t.isReady, isFalse);
      expect(t.isProcessing, isTrue);
      expect(t.videoStatus, 'processing');
    });

    test('Ancien format à plat lu en secours', () {
      final raw = _testimony(null)
        ..remove('video')
        ..addAll({
          'video_status': 'ready',
          'hls_url': _hls,
          'mp4_urls': {'360': 'https://cdn.test/360.mp4'},
          'thumbnail_url': 'https://cdn.test/t.jpg',
        });
      final t = testimonyFromApiJson(raw) as VideoTestimony;
      expect(t.hlsUrl, _hls);
      expect(t.renditions.single.url, 'https://cdn.test/360.mp4');
      expect(t.thumbnailUrl, 'https://cdn.test/t.jpg');
    });

    test('video = null : ancienne vidéo, toujours lisible', () {
      final raw = _testimony(null)..['mediaUrl'] = 'https://x.test/v.mp4';
      final t = testimonyFromApiJson(raw) as VideoTestimony;
      expect(t.hlsUrl, isNull);
      expect(t.isReady, isTrue);
      expect(t.mediaPath, 'https://x.test/v.mp4');
    });

    test('Mes publications : badges « En traitement » / « Échec »', () {
      final processing = UserTestimony.fromJson(
          _testimony({'status': 'uploading', 'thumbnail_url': 'th'}));
      expect(processing.isVideoProcessing, isTrue);
      expect(processing.thumbnailUrl, 'th');
      final failed = UserTestimony.fromJson(_testimony({'status': 'failed'}));
      expect(failed.isVideoFailed, isTrue);
      final ready = UserTestimony.fromJson(_testimony({'status': 'ready'}));
      expect(ready.isVideoProcessing || ready.isVideoFailed, isFalse);
    });
  });

  group('Tâche d’envoi', () {
    VideoUploadJob job() => VideoUploadJob(
          sourcePath: '/tmp/v.mov',
          title: 'Mon témoignage',
          body: const {'title': 'Mon témoignage', 'type': 'video'},
          proofs: const [(position: 1, path: '/tmp/p.jpg')],
        );

    test('Réponse de upload-init → en-têtes TUS Bunny', () {
      final j = job()
        ..applyInit({
          'video_id': 'v1',
          'testimony_id': 't1',
          'library_id': 42,
          'bunny_video_id': 'b-guid',
          'signature': 'sig',
          'expiration': 1893456000,
          'tus_endpoint': 'https://video.bunnycdn.com/tusupload',
        });
      expect(j.isInitialized, isTrue);
      expect(j.tusHeaders, {
        'AuthorizationSignature': 'sig',
        'AuthorizationExpire': '1893456000',
        'VideoId': 'b-guid',
        'LibraryId': '42',
      });
      expect(j.fileType, 'video/quicktime');
      j.compressedPath = '/tmp/out.mp4';
      expect(j.fileType, 'video/mp4');
    });

    test('Signature à renouveler moins de 5 minutes avant expiration', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final j = job()..expiration = now + 4 * 60;
      expect(j.signatureExpiresSoon, isTrue);
      j.applySignature({'signature': 's2', 'expiration': '${now + 3600}'});
      expect(j.signatureExpiresSoon, isFalse);
      expect(j.tusHeaders['AuthorizationSignature'], 's2');
    });

    test('Expiration en date ISO 8601', () {
      expect(VideoUploadJob.parseExpiration('2030-01-01T00:00:00Z'), 1893456000);
    });

    test('Enregistrement / restauration (reprise après redémarrage)', () {
      final j = job()
        ..compressedPath = '/tmp/out.mp4'
        ..applyInit({
          'video_id': 'v1',
          'testimony_id': 't1',
          'library_id': '42',
          'bunny_video_id': 'b',
          'signature': 's',
          'expiration': 1,
          'tus_endpoint': 'https://e',
        });
      final back = VideoUploadJob.fromJson(j.toJson());
      expect(back.uploadPath, '/tmp/out.mp4');
      expect(back.testimonyId, 't1');
      expect(back.isInitialized, isTrue);
      expect(back.proofs.single.position, 1);
      expect(back.body['type'], 'video');
    });
  });
}
