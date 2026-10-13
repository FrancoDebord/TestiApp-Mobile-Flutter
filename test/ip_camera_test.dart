// Caméra IP d'un direct : composition / lecture de l'adresse, encodage des
// identifiants, adresses privées, préréglages (lib/features/live/models/ip_camera_config.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/live/widgets/ip_camera_form.dart';
import 'package:testi_app/features/live/models/ip_camera_config.dart';
import 'package:testi_app/features/live/models/live_models.dart';

void main() {
  group('Composition', () {
    test('RTSP avec identifiants et port par défaut', () {
      const c = IpCameraConfig(host: 'cam.exemple.org', path: '/stream1', username: 'admin', password: 'secret');
      expect(c.toUrl(), 'rtsp://admin:secret@cam.exemple.org:554/stream1');
      expect(c.maskedUrl(), 'rtsp://admin:••••@cam.exemple.org:554/stream1');
      expect(liveCameraUrlPattern.hasMatch(c.toUrl()), isTrue);
    });

    test('sans identifiant, chemin sans « / » initial, IPv6 entre crochets', () {
      expect(const IpCameraConfig(host: '203.0.113.5', port: 8554, path: 'live').toUrl(),
          'rtsp://203.0.113.5:8554/live');
      expect(const IpCameraConfig(protocol: IpCameraProtocol.https, host: '2001:db8::1', path: '/hls/index.m3u8').toUrl(),
          'https://[2001:db8::1]:443/hls/index.m3u8');
    });

    test('caractères spéciaux encodés (@ : / % # espace, accents)', () {
      expect(IpCameraConfig.encodeUserInfo('p@ss:w/rd%#1 é'), 'p%40ss%3Aw%2Frd%25%231%20%C3%A9');
      expect(IpCameraConfig.encodeUserInfo('Abc-_.~9'), 'Abc-_.~9');
      const c = IpCameraConfig(host: 'h.org', username: 'ad@min', password: 'a:b@c/d', path: '/s');
      expect(c.toUrl(), 'rtsp://ad%40min:a%3Ab%40c%2Fd@h.org:554/s');
      expect(c.maskedUrl(), isNot(contains('a%3Ab')));
    });

    test('SRT : streamid et passphrase en paramètres, pas d\'identifiants', () {
      const c = IpCameraConfig(
        protocol: IpCameraProtocol.srt,
        host: 'srt.exemple.org',
        username: 'ignoré',
        password: 'ignoré',
        streamId: 'cam 1',
        passphrase: 'phrase-secrete-123',
      );
      expect(c.toUrl(), 'srt://srt.exemple.org:9000?streamid=cam%201&passphrase=phrase-secrete-123');
      expect(c.maskedUrl(), 'srt://srt.exemple.org:9000?streamid=cam%201&passphrase=••••');
    });

    test('ports par défaut des protocoles', () {
      expect({for (final p in IpCameraProtocol.values) p.scheme: p.defaultPort},
          {'rtsp': 554, 'rtsps': 322, 'rtmp': 1935, 'rtmps': 443, 'http': 80, 'https': 443, 'srt': 9000});
    });
  });

  group('Lecture d\'une adresse collée', () {
    test('RTSP Hikvision complet', () {
      final c = IpCameraConfig.parse('rtsp://admin:p%40ss@203.0.113.7:554/Streaming/Channels/102')!;
      expect(c.protocol, IpCameraProtocol.rtsp);
      expect(c.host, '203.0.113.7');
      expect(c.port, 554);
      expect(c.username, 'admin');
      expect(c.password, 'p@ss');
      expect(c.path, '/Streaming/Channels/102');
      expect(c.presetId, 'hikvision');
      expect(c.stream, IpCameraStream.sub);
    });

    test('mot de passe non encodé contenant @ et /, paramètres Dahua', () {
      final c = IpCameraConfig.parse('rtsp://admin:a@b/c@cam.org/cam/realmonitor?channel=1&subtype=0')!;
      expect(c.password, 'a@b/c');
      expect(c.host, 'cam.org');
      expect(c.port, 554); // port par défaut
      expect(c.path, '/cam/realmonitor?channel=1&subtype=0');
      expect(c.presetId, 'dahua');
      // Recomposée : encodée proprement.
      expect(c.toUrl(), 'rtsp://admin:a%40b%2Fc@cam.org:554/cam/realmonitor?channel=1&subtype=0');
    });

    test('aller-retour composition → lecture', () {
      const c = IpCameraConfig(host: 'x.org', port: 1935, protocol: IpCameraProtocol.rtmp, path: '/live/cam', username: 'u:1', password: '%p@');
      final back = IpCameraConfig.parse(c.toUrl())!;
      expect(back.username, 'u:1');
      expect(back.password, '%p@');
      expect(back.toUrl(), c.toUrl());
    });

    test('SRT et IPv6', () {
      final c = IpCameraConfig.parse('srt://[2001:db8::2]:7001?streamid=abc&passphrase=0123456789&latency=200')!;
      expect(c.host, '2001:db8::2');
      expect(c.port, 7001);
      expect(c.streamId, 'abc');
      expect(c.passphrase, '0123456789');
      expect(c.path, '?latency=200');
    });

    test('adresses refusées', () {
      expect(IpCameraConfig.parse('ftp://cam.org/x'), isNull);
      expect(IpCameraConfig.parse('cam.org'), isNull);
      expect(IpCameraConfig.parse('rtsp://user:pass@/x'), isNull);
    });
  });

  group('Vérifications', () {
    test('hôte et port', () {
      expect(IpCameraConfig.validateHost(''), isNotNull);
      expect(IpCameraConfig.validateHost('rtsp://cam.org'), isNotNull);
      expect(IpCameraConfig.validateHost('300.1.1.1'), isNotNull);
      expect(IpCameraConfig.validateHost('cam_1.org'), isNotNull);
      expect(IpCameraConfig.validateHost('cam.exemple.org'), isNull);
      expect(IpCameraConfig.validateHost('203.0.113.5'), isNull);
      expect(IpCameraConfig.validateHost('2001:db8::1'), isNull);
      expect(IpCameraConfig.validatePort(''), isNull);
      expect(IpCameraConfig.validatePort('0'), isNotNull);
      expect(IpCameraConfig.validatePort('65536'), isNotNull);
      expect(IpCameraConfig.validatePort('65535'), isNull);
      expect(const IpCameraConfig().isValid, isFalse);
      expect(const IpCameraConfig(host: 'cam.org', path: '/a b').isValid, isFalse);
      expect(const IpCameraConfig(host: 'cam.org', path: '/s').isValid, isTrue);
    });

    test('adresses privées', () {
      for (final h in ['192.168.1.20', '10.0.0.3', '172.16.0.1', '172.31.255.1', '127.0.0.1',
        '169.254.3.4', '100.64.0.1', 'localhost', 'camera.local', 'fd12::1', 'fe80::1', '[::1]']) {
        expect(IpCameraConfig.isPrivateHost(h), isTrue, reason: h);
      }
      for (final h in ['203.0.113.5', '172.32.0.1', '8.8.8.8', 'cam.exemple.org', '2001:db8::1', '']) {
        expect(IpCameraConfig.isPrivateHost(h), isFalse, reason: h);
      }
    });

    test('phrase secrète SRT : 10 à 79 caractères', () {
      expect(IpCameraConfig.validatePassphrase(''), isNull);
      expect(IpCameraConfig.validatePassphrase('court'), isNotNull);
      expect(IpCameraConfig.validatePassphrase('0123456789'), isNull);
    });
  });

  group('Préréglages', () {
    test('appliquer un modèle : port et chemin, flux principal / secondaire', () {
      const base = IpCameraConfig(host: 'cam.org', username: 'admin', password: 'x');
      final hik = base.applyPreset(IpCameraPreset.hikvision);
      expect(hik.toUrl(), 'rtsp://admin:x@cam.org:554/Streaming/Channels/101');
      expect(hik.applyPreset(IpCameraPreset.hikvision, stream: IpCameraStream.sub).path, '/Streaming/Channels/102');
      expect(base.applyPreset(IpCameraPreset.tapo).path, '/stream1');
      expect(base.applyPreset(IpCameraPreset.reolink).path, '/h264Preview_01_main');
      expect(base.applyPreset(IpCameraPreset.axis).path, '/axis-media/media.amp');
      final foscam = base.applyPreset(IpCameraPreset.foscam);
      expect(foscam.port, 88);
      expect(foscam.path, '/videoMain');
    });

    test('ONVIF / Autre : chemin saisi conservé', () {
      const c = IpCameraConfig(host: 'cam.org', path: '/onvif1', port: 8554);
      final o = c.applyPreset(IpCameraPreset.onvif);
      expect(o.path, '/onvif1');
      expect(o.port, 8554);
      expect(o.presetId, 'onvif');
    });

    test('tous les chemins des préréglages donnent une adresse valide', () {
      for (final p in IpCameraPreset.all) {
        for (final s in IpCameraStream.values) {
          final c = const IpCameraConfig(host: 'cam.org').applyPreset(p, stream: s);
          expect(c.isValid, isTrue, reason: p.id);
          expect(liveCameraUrlPattern.hasMatch(c.toUrl()), isTrue, reason: p.id);
        }
      }
    });
  });

  test('mémorisation : jamais de mot de passe ni de phrase secrète', () {
    const c = IpCameraConfig(
      host: 'cam.org', username: 'admin', password: 'secret', passphrase: 'phrase-secrete', presetId: 'tapo', stream: IpCameraStream.sub,
    );
    final stored = c.toStorage();
    expect(stored.values, isNot(contains('secret')));
    expect(stored.values, isNot(contains('phrase-secrete')));
    final back = IpCameraConfig.fromStorage(stored);
    expect(back.host, 'cam.org');
    expect(back.username, 'admin');
    expect(back.password, '');
    expect(back.presetId, 'tapo');
    expect(back.stream, IpCameraStream.sub);
  });

  testWidgets('formulaire : préréglage, aperçu masqué, avertissement IP locale', (tester) async {
    String? url;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(child: IpCameraForm(onChanged: (u, _) => url = u)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Autre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TP-Link Tapo').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, "Adresse IP ou nom d'hôte *"), '192.168.1.20');
    await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant de la caméra'), 'admin');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'p@ss');
    await tester.pump();

    expect(url, 'rtsp://admin:p%40ss@192.168.1.20:554/stream1');
    expect(find.text('rtsp://admin:••••@192.168.1.20:554/stream1'), findsOneWidget);
    expect(find.textContaining('adresse du réseau local'), findsOneWidget);

    await tester.tap(find.text('Flux secondaire'));
    await tester.pump();
    expect(url, endsWith('/stream2'));
  });
}
