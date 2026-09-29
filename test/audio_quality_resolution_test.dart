// Tests du choix de qualité (audio / vidéo) et du parsing des versions.

import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/media/media_quality.dart';
import 'package:testi_app/core/media/playback_preferences.dart';
import 'package:testi_app/features/home/models/media_rendition.dart';

const _audio = [
  MediaRendition(url: 'a32', label: '32 kbps', bitrateKbps: 32),
  MediaRendition(url: 'a64', label: '64 kbps', bitrateKbps: 64),
  MediaRendition(url: 'a128', label: '128 kbps', bitrateKbps: 128),
  MediaRendition(url: 'a320', label: '320 kbps', bitrateKbps: 320),
];

const _video = [
  MediaRendition(url: 'v144', label: '144p', height: 144),
  MediaRendition(url: 'v360', label: '360p', height: 360),
  MediaRendition(url: 'v480', label: '480p', height: 480),
  MediaRendition(url: 'v720', label: '720p', height: 720),
  MediaRendition(url: 'v1080', label: '1080p', height: 1080),
];

const _prefs = PlaybackPreferences();
const _saver = PlaybackPreferences(dataSaver: true);

void main() {
  group('resolveAudio', () {
    String? url(PlaybackPreferences p, bool metered,
            {List<MediaRendition> r = _audio, AudioQuality? override}) =>
        resolveAudio(
          original: 'orig.mp3',
          renditions: r,
          prefs: p,
          metered: metered,
          override: override,
        )?.url;

    test('Auto : 64 kbps sur données mobiles, 320 kbps en Wi-Fi', () {
      expect(url(_prefs, true), 'a64');
      expect(url(_prefs, false), 'a320');
    });

    test('Économiseur : 32 kbps mobile, 64 kbps Wi-Fi', () {
      expect(url(_saver, true), 'a32');
      expect(url(_saver, false), 'a64');
    });

    test('Choix explicite (préférence ou override)', () {
      const low = PlaybackPreferences(audioQuality: AudioQuality.standard);
      expect(url(low, false), 'a128');
      expect(url(low, true), 'a128');
      expect(url(_prefs, false, override: AudioQuality.veryLow), 'a32');
      // L'override prime sur la préférence.
      expect(url(low, false, override: AudioQuality.high), 'a320');
    });

    test('Toutes les versions au-dessus du plafond → la plus basse', () {
      const r = [
        MediaRendition(url: 'a96', label: '96 kbps', bitrateKbps: 96),
        MediaRendition(url: 'a192', label: '192 kbps', bitrateKbps: 192),
      ];
      expect(url(_prefs, true, r: r), 'a96');
      expect(url(_prefs, false, r: r, override: AudioQuality.veryLow), 'a96');
    });

    test('Sans versions → fichier original « Originale »', () {
      final m = resolveAudio(
        original: 'orig.mp3',
        renditions: const [],
        prefs: _prefs,
        metered: true,
      );
      expect(m?.url, 'orig.mp3');
      expect(m?.label, 'Originale');
      expect(m?.rendition, isNull);
    });

    test('Sans versions ni original → null', () {
      expect(
        resolveAudio(
            original: null, renditions: const [], prefs: _prefs, metered: true),
        isNull,
      );
    });

    test('Libellé de la version choisie', () {
      final m = resolveAudio(
          original: 'o', renditions: _audio, prefs: _prefs, metered: true);
      expect(m?.label, '64 kbps');
      expect(m?.rendition?.bitrateKbps, 64);
    });
  });

  group('resolveVideo', () {
    String? url(PlaybackPreferences p, bool metered,
            {List<MediaRendition> r = _video, VideoQuality? override}) =>
        resolveVideo(
          original: 'orig.mp4',
          renditions: r,
          prefs: p,
          metered: metered,
          override: override,
        )?.url;

    test('Auto : 360p sur données mobiles, 720p en Wi-Fi', () {
      expect(url(_prefs, true), 'v360');
      expect(url(_prefs, false), 'v720');
    });

    test('Économiseur : 144p mobile, 480p Wi-Fi', () {
      expect(url(_saver, true), 'v144');
      expect(url(_saver, false), 'v480');
    });

    test('Choix explicite', () {
      const p = PlaybackPreferences(videoQuality: VideoQuality.p1080);
      expect(url(p, true), 'v1080');
      expect(url(_prefs, false, override: VideoQuality.p480), 'v480');
      // 240p absent → meilleure version ≤ 240 = 144p.
      expect(url(_prefs, false, override: VideoQuality.p240), 'v144');
    });

    test('Toutes les versions au-dessus du plafond → la plus basse', () {
      const r = [
        MediaRendition(url: 'v720', label: '720p', height: 720),
        MediaRendition(url: 'v1080', label: '1080p', height: 1080),
      ];
      expect(url(_prefs, true, r: r), 'v720');
    });

    test('Sans versions → « Originale »', () {
      final m = resolveVideo(
        original: 'orig.mp4',
        renditions: const [],
        prefs: _prefs,
        metered: false,
      );
      expect(m?.url, 'orig.mp4');
      expect(m?.label, 'Originale');
    });

    test('Plafonds Auto', () {
      expect(autoVideoHeight(metered: true, dataSaver: false), 360);
      expect(autoVideoHeight(metered: false, dataSaver: false), 720);
      expect(autoAudioKbps(metered: true, dataSaver: false), 64);
      expect(autoAudioKbps(metered: false, dataSaver: false), 320);
    });
  });

  group('MediaRendition.parseList', () {
    test('Forme liste, triée du plus bas au plus haut', () {
      final r = MediaRendition.parseList([
        {'quality': '720p', 'height': 720, 'bitrate': 1800, 'url': 'u720'},
        {'quality': '360p', 'height': 360, 'url': 'u360'},
        {'label': '480p', 'src': 'u480'}, // libellé seul
        {'quality': '240p'}, // sans URL → ignoré
        'invalide', // pas une map → ignoré
      ]);
      expect(r.map((e) => e.url), ['u360', 'u480', 'u720']);
      expect(r.map((e) => e.height), [360, 480, 720]);
      expect(r.last.bitrateKbps, 1800);
      expect(r[1].label, '480p');
    });

    test('Forme liste audio (débits)', () {
      final r = MediaRendition.parseList([
        {'bitrate': 128, 'url': 'b'},
        {'bitrate_kbps': '64', 'url': 'a'},
      ]);
      expect(r.map((e) => e.url), ['a', 'b']);
      expect(r.first.label, '64 kbps');
      expect(r.first.bitrateKbps, 64);
      expect(r.first.height, 0);
    });

    test('Forme map courte {"360p": url, "64k": url}', () {
      final r = MediaRendition.parseList({
        '360p': 'v360',
        '64k': 'a64',
        '720p': 'v720',
        '128k': null, // ignoré
      });
      final byUrl = {for (final e in r) e.url: e};
      expect(byUrl.keys.toSet(), {'v360', 'a64', 'v720'});
      expect(byUrl['v360']!.height, 360);
      expect(byUrl['v360']!.label, '360p');
      expect(byUrl['a64']!.bitrateKbps, 64);
      expect(byUrl['a64']!.height, 0);
      expect(byUrl['a64']!.label, '64 kbps');
      // Tri par rang (hauteur ou débit).
      expect(r.map((e) => e.rank), [64, 360, 720]);
    });

    test('absUrl appliqué aux URLs', () {
      final r = MediaRendition.parseList(
        {'64k': '/media/a.mp3'},
        absUrl: (u) => u == null ? null : 'https://x.test$u',
      );
      expect(r.single.url, 'https://x.test/media/a.mp3');
    });

    test('Entrée nulle ou inattendue → liste vide', () {
      expect(MediaRendition.parseList(null), isEmpty);
      expect(MediaRendition.parseList('abc'), isEmpty);
    });
  });
}
