// Nouveautés serveur : fil « Pour vous » paginé, suggestions, vidéos YouTube,
// preuves privées et directs par caméra IP / encodeur.

import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/core/media/youtube.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/live/controllers/live_room_controller.dart';
import 'package:testi_app/features/live/models/live_models.dart';
import 'package:testi_app/features/publish/models/publish_models.dart';
import 'package:testi_app/features/testimony/providers/recommendations_provider.dart';

Map<String, dynamic> _testimonyJson({
  String id = 't1',
  String type = 'video',
  Object? youtubeId,
  Object? proofs,
  String? coverUrl,
}) => {
  'id': id,
  'title': 'Guéri par la grâce',
  'type': type,
  'category': 'guerison',
  'createdAt': '2026-09-30T10:00:00Z',
  'user': {'id': 'u1', 'displayName': 'Marie'},
  'stats': {'viewsCount': 3},
  'mediaUrl': null,
  'coverUrl': ?coverUrl,
  'youtubeId': ?youtubeId,
  'proofs': ?proofs,
};

void main() {
  test('preuves : accord de publication conservé par copyWith, désactivé par défaut', () {
    final draft = PublishDraft();
    expect(draft.proofsPublic, isFalse);
    expect(draft.copyWith(proofsPublic: true).proofsPublic, isTrue);
    expect(draft.copyWith(proofsPublic: true).copyWith(title: 'T').proofsPublic, isTrue);
  });

  group('Fil « Pour vous »', () {
    test('paramètres de la requête', () {
      expect(AppConstants.forYouFeedQuery(page: 3), {
        'sort': 'for_you',
        'limit': 20,
        'page': 3,
      });
    });

    test('pagination camelCase', () {
      final m = parsePageMeta({
        'currentPage': 2,
        'lastPage': 5,
        'total': 90,
        'perPage': 20,
      });
      expect(m.currentPage, 2);
      expect(m.lastPage, 5);
    });

    test('pagination snake_case et valeurs en texte', () {
      final m = parsePageMeta({'current_page': '1', 'last_page': '4'});
      expect(m.currentPage, 1);
      expect(m.lastPage, 4);
    });

    test('sans meta : une seule page', () {
      final m = parsePageMeta(null);
      expect(m.currentPage, 1);
      expect(m.lastPage, 1);
    });

    test('lastPage incohérent ramené à la page courante', () {
      final m = parsePageMeta({'currentPage': 3, 'lastPage': 0});
      expect(m.lastPage, 3);
    });
  });

  group('Suggestions', () {
    test('témoignage courant et éléments invalides retirés', () {
      final list = parseRecommendations([
        _testimonyJson(id: 'a', type: 'text'),
        _testimonyJson(id: 'current', type: 'text'),
        'invalide',
        _testimonyJson(id: 'b', type: 'audio'),
      ], excludeId: 'current');
      expect(list.map((t) => t.id), ['a', 'b']);
    });

    test('réponse inattendue : liste vide', () {
      expect(parseRecommendations({'data': []}, excludeId: 'x'), isEmpty);
    });
  });

  group('YouTube', () {
    const id = 'dQw4w9WgXcQ';
    for (final link in [
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/watch?feature=share&v=$id',
      'https://m.youtube.com/watch?v=$id&t=42',
      'youtu.be/$id',
      'https://youtu.be/$id?si=abc',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/live/$id?feature=share',
      'https://www.youtube-nocookie.com/embed/$id',
      id,
      '  $id  ',
    ]) {
      test('reconnaît $link', () => expect(extractYouTubeId(link), id));
    }

    for (final link in [
      '',
      'https://vimeo.com/123456',
      'https://www.youtube.com/watch?v=court',
      'https://www.youtube.com/channel/UC1234567890',
      'https://evil.example/watch?v=$id',
      'pas un lien',
    ]) {
      test('refuse « $link »', () => expect(extractYouTubeId(link), isNull));
    }

    test('témoignage YouTube : identifiant et miniature', () {
      final t = testimonyFromApiJson(_testimonyJson(youtubeId: id));
      expect(t, isA<VideoTestimony>());
      final v = t as VideoTestimony;
      expect(v.youtubeId, id);
      expect(v.isYouTube, isTrue);
      expect(v.mediaPath, isNull);
      // Pas de coverUrl : miniature YouTube par défaut.
      expect(v.thumbnailUrl, youTubeThumbnailUrl(id));
    });

    test('coverUrl du serveur conservée', () {
      final v =
          testimonyFromApiJson(
                _testimonyJson(
                  youtubeId: id,
                  coverUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                ),
              )
              as VideoTestimony;
      expect(v.thumbnailUrl, 'https://i.ytimg.com/vi/$id/hqdefault.jpg');
    });

    test('identifiant invalide ignoré', () {
      final v =
          testimonyFromApiJson(_testimonyJson(youtubeId: 'abc'))
              as VideoTestimony;
      expect(v.youtubeId, isNull);
      expect(v.isYouTube, isFalse);
    });

    test('identifiant présent : toujours une vidéo', () {
      expect(
        testimonyFromApiJson(_testimonyJson(type: 'text', youtubeId: id)),
        isA<VideoTestimony>(),
      );
    });
  });

  group('Preuves', () {
    test('absentes pour le public', () {
      final t = testimonyFromApiJson(_testimonyJson(type: 'text'));
      expect(t!.proofs, isEmpty);
    });

    test('lues, triées par position, URL absolue', () {
      final t = testimonyFromApiJson(
        _testimonyJson(
          type: 'text',
          proofs: [
            {
              'id': 'p2',
              'position': 2,
              'name': 'certificat.pdf',
              'mimeType': 'application/pdf',
              'size': 1572864,
              'isPdf': true,
              'url':
                  'https://testi.airid-africa.com/api/v1/testimonies/t1/proofs/p2',
            },
            {
              'id': 'p1',
              'position': 1,
              'name': 'radio.jpg',
              'mimeType': 'image/jpeg',
              'size': 2048,
              'isPdf': false,
              'url': '/api/v1/testimonies/t1/proofs/p1',
            },
            {'id': '', 'url': ''}, // inexploitable
          ],
        ),
      )!;
      expect(t.proofs.map((p) => p.id), ['p1', 'p2']);
      expect(t.proofs.first.isPdf, isFalse);
      expect(t.proofs.first.url, startsWith('http'));
      expect(t.proofs.first.formattedSize, '2 Ko');
      expect(t.proofs.last.isPdf, isTrue);
      expect(t.proofs.last.formattedSize, '1,5 Mo');
    });

    test('isPdf déduit du type quand absent', () {
      final p = TestimonyProof.fromJson({
        'id': 'x',
        'url': 'https://a/b',
        'mimeType': 'application/pdf',
        'name': 'doc',
      });
      expect(p!.isPdf, isTrue);
      expect(p.position, 1);
    });

    test('contrôle du fichier choisi', () {
      expect(proofRejectionReason(name: 'photo.JPG', size: 1000), isNull);
      expect(
        proofRejectionReason(name: 'scan.pdf', size: kMaxProofBytes),
        isNull,
      );
      expect(
        proofRejectionReason(name: 'scan.pdf', size: kMaxProofBytes + 1),
        contains('10 Mo'),
      );
      expect(
        proofRejectionReason(name: 'video.mp4', size: 10),
        contains('Format'),
      );
      expect(proofRejectionReason(name: 'sans_extension', size: 10), isNotNull);
    });

    test('pièce jointe locale', () {
      const f = ProofAttachment(path: '/tmp/a.PDF', name: 'a.PDF', size: 3);
      expect(f.isPdf, isTrue);
      expect(f.extension, 'pdf');
    });

    test('brouillon : emplacements indépendants', () {
      final d = PublishDraft().copyWith(
        proofs: {
          2: const ProofAttachment(path: '/b.png', name: 'b.png', size: 1),
        },
      );
      expect(d.proofs.keys, [2]);
      expect(d.copyWith(title: 'x').proofs.keys, [2]);
    });
  });

  group('Direct par caméra IP', () {
    Map<String, dynamic> live({Object? source, Object? camera}) => {
      'id': 'l1',
      'title': 'Culte',
      'status': 'preparing',
      'host': {'id': 'u1', 'displayName': 'Pasteur'},
      'source': ?source,
      'camera': ?camera,
    };

    test('source absente : caméra de l\'appareil', () {
      final s = LiveSession.fromJson(live());
      expect(s.source, LiveSource.browser);
      expect(s.source.isExternal, isFalse);
      expect(s.camera, isNull);
    });

    test('RTMP : adresse et clé pour le diffuseur', () {
      final s = LiveSession.fromJson(
        live(
          source: 'rtmp',
          camera: {
            'url': 'rtmps://ingress.example/x',
            'streamKey': 'cle-secrete',
            'sourceUrl': null,
          },
        ),
      );
      expect(s.source, LiveSource.rtmp);
      expect(s.source.isExternal, isTrue);
      expect(s.camera!.url, 'rtmps://ingress.example/x');
      expect(s.camera!.streamKey, 'cle-secrete');
      expect(s.camera!.sourceUrl, isNull);
    });

    test('adresse de flux', () {
      final s = LiveSession.fromJson(
        live(source: 'url', camera: {'sourceUrl': 'rtsp://cam.example/stream'}),
      );
      expect(s.source, LiveSource.url);
      expect(s.camera!.sourceUrl, 'rtsp://cam.example/stream');
    });

    test('adresses acceptées pour camera_url', () {
      for (final ok in [
        'rtsp://user:pass@1.2.3.4:554/s1',
        'RTMPS://a/b',
        'https://cdn.example/live.m3u8',
        'srt://host:9000',
      ]) {
        expect(liveCameraUrlPattern.hasMatch(ok), isTrue, reason: ok);
      }
      for (final ko in [
        'ftp://a/b',
        'rtsp://',
        'cam.example/stream',
        'http://a b',
      ]) {
        expect(liveCameraUrlPattern.hasMatch(ko), isFalse, reason: ko);
      }
    });

    test('identité du flux de la caméra', () {
      expect(LiveRoomController.isCameraIdentity('host-camera-l1'), isTrue);
      expect(LiveRoomController.isHostIdentity('host-camera-l1'), isTrue);
      expect(LiveRoomController.isCameraIdentity('host-u1'), isFalse);
      expect(LiveRoomController.isCameraIdentity('user-u2-abc'), isFalse);
    });
  });
}
