// Moteur de téléchargement : persistance de l'index, suppression, taille,
// résolution hors ligne — dossier temporaire et faux client HTTP.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/media/media_quality.dart';
import 'package:testi_app/core/media/playback_preferences.dart';
import 'package:testi_app/features/downloads/data/downloads_repository.dart';
import 'package:testi_app/features/downloads/providers/downloads_provider.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';

/// Répond à chaque requête par [bytesPerFile] octets.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.fail = false});
  static const bytesPerFile = 1000;
  final bool fail;
  final requested = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requested.add(options.uri.toString());
    if (fail) {
      return ResponseBody.fromString('error', 500);
    }
    return ResponseBody.fromBytes(
      Uint8List(bytesPerFile),
      200,
      headers: {
        Headers.contentLengthHeader: ['$bytesPerFile'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _author = TestimonyAuthor(uid: 'u1', displayName: 'Marie L.');

VideoTestimony _video(String id) => VideoTestimony(
      id: id,
      author: _author,
      title: 'Un miracle dans ma famille',
      category: TestimonyCategory.miracles,
      createdAt: DateTime(2026, 1, 1),
      stats: TestimonyStats.zero,
      durationSeconds: 312,
      thumbnailUrl: 'https://cdn.test/$id.jpg',
      mediaPath: 'https://cdn.test/$id/original.mp4',
      renditions: const [
        MediaRendition(url: 'https://cdn.test/v360.mp4', label: '360p', height: 360),
        MediaRendition(url: 'https://cdn.test/v720.mp4', label: '720p', height: 720),
      ],
    );

TextTestimony _text(String id) => TextTestimony(
      id: id,
      author: _author,
      title: 'Témoignage de foi',
      category: TestimonyCategory.guerison,
      createdAt: DateTime(2026, 1, 1),
      stats: TestimonyStats.zero,
      preview: 'Après plusieurs mois de prière, Dieu a touché notre famille.',
      bibleVerse: 'Je suis l’Éternel qui te guérit.',
      bibleVerseRef: 'Exode 15:26',
    );

AudioTestimony _audio(String id) => AudioTestimony(
      id: id,
      author: _author,
      title: 'Ma délivrance',
      category: TestimonyCategory.delivrance,
      createdAt: DateTime(2026, 1, 1),
      stats: TestimonyStats.zero,
      durationSeconds: 90,
      transcriptPreview: '',
      mediaPath: 'https://cdn.test/$id.m4a',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late _FakeAdapter adapter;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('downloads_test_');
    adapter = _FakeAdapter();
  });

  tearDown(() async {
    OfflineMedia.lookup = null;
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  DownloadsRepository repo([_FakeAdapter? a]) => DownloadsRepository(
        baseDir: () async => tmp,
        dio: Dio()..httpClientAdapter = a ?? adapter,
      );

  ProviderContainer container({DownloadsRepository? r, bool metered = true}) {
    final c = ProviderContainer(overrides: [
      downloadsRepositoryProvider.overrideWithValue(r ?? repo()),
      isMeteredConnectionProvider.overrideWith((ref) => Stream.value(metered)),
      downloadsStorageCapProvider.overrideWithValue(1024 * 1024),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<DownloadsNotifier> ready(ProviderContainer c) async {
    // Laisse le flux « réseau » émettre avant de résoudre la qualité.
    c.listen(isMeteredConnectionProvider, (_, _) {});
    await c.read(isMeteredConnectionProvider.future);
    final n = c.read(downloadsProvider.notifier);
    await n.ensureLoaded();
    return n;
  }

  test('index : enregistrement puis relecture', () async {
    final r = repo();
    final target = await r.pathFor('v1', 'mp4');
    await File(target).writeAsBytes(List.filled(10, 1));
    final e = DownloadEntry.fromTestimony(_video('v1'))
        .copyWith(filePath: target, sizeBytes: 10, qualityLabel: '360p');
    await r.saveIndex([e, DownloadEntry.fromTestimony(_text('t1'))]);

    final loaded = await repo().loadIndex();
    expect(loaded.map((e) => e.id), ['v1', 't1']);
    expect(loaded.first.title, 'Un miracle dans ma famille');
    expect(loaded.first.authorName, 'Marie L.');
    expect(loaded.first.qualityLabel, '360p');
    expect(loaded.first.durationSeconds, 312);
    expect(loaded.first.sourceUrls, contains('https://cdn.test/v360.mp4'));
    expect(loaded.last.textBody, contains('Dieu a touché'));
    expect(loaded.last.bibleVerseRef, 'Exode 15:26');
  });

  test('index : une entrée dont le fichier a disparu est ignorée', () async {
    final r = repo();
    final e = DownloadEntry.fromTestimony(_video('v1'))
        .copyWith(filePath: '${tmp.path}/absent.mp4');
    await r.saveIndex([e]);
    expect(await repo().loadIndex(), isEmpty);
  });

  test('index corrompu → liste vide', () async {
    final dir = await repo().downloadsDir();
    await File('${dir.path}/index.json').writeAsString('{pas du json');
    expect(await repo().loadIndex(), isEmpty);
  });

  test('téléchargement vidéo : 360p sur données mobiles, vignette, taille',
      () async {
    final c = container();
    final n = await ready(c);
    final outcome = await n.download(_video('v1'));
    expect(outcome, DownloadOutcome.done);

    final s = c.read(downloadsProvider);
    final e = s.entries['v1']!;
    expect(e.qualityLabel, '360p');
    expect(adapter.requested, contains('https://cdn.test/v360.mp4'));
    expect(e.thumbnailPath, isNotNull);
    expect(e.sizeBytes, 2000); // média + vignette
    expect(s.totalBytes, 2000);
    expect(File(e.filePath!).existsSync(), isTrue);
    expect(c.read(downloadItemProvider('v1')).status, DownloadStatus.done);

    // Lecture : le fichier local est prioritaire (« Hors ligne »).
    final r = resolveVideoTestimony(_video('v1'),
        prefs: const PlaybackPreferences(), metered: true);
    expect(r!.url, e.filePath);
    expect(r.label, 'Hors ligne');
    // Recherche par URL d'origine (lecteurs qui n'ont que l'adresse).
    expect(
      resolveVideo(
        original: 'https://cdn.test/v1/original.mp4',
        renditions: const [],
        prefs: const PlaybackPreferences(),
        metered: false,
      )!.url,
      e.filePath,
    );
    expect(n.localPathFor('v1'), e.filePath);

    // L'index est persisté : un nouveau conteneur le relit.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final c2 = container();
    final n2 = await ready(c2);
    expect(n2.localPathFor('v1'), e.filePath);
    expect(c2.read(downloadsProvider).totalBytes, 2000);
  });

  test('Wi-Fi : 720p', () async {
    final c = container(metered: false);
    final n = await ready(c);
    await n.download(_video('v2'));
    expect(c.read(downloadsProvider).entries['v2']!.qualityLabel, '720p');
  });

  test('texte : stocké dans l’index, sans fichier média', () async {
    final c = container();
    final n = await ready(c);
    expect(await n.download(_text('t1')), DownloadOutcome.done);
    final e = c.read(downloadsProvider).entries['t1']!;
    expect(e.filePath, isNull);
    expect(e.textBody, contains('prière'));
    expect(e.sizeBytes, greaterThan(0));
    expect(n.localPathFor('t1'), isNull);
    expect((e.toTestimony() as TextTestimony).preview, contains('prière'));
  });

  test('suppression : fichiers et taille mis à jour', () async {
    final c = container();
    final n = await ready(c);
    await n.download(_video('v1'));
    await n.download(_audio('a1'));
    await n.download(_text('t1'));
    final path = n.localPathFor('v1')!;
    final before = c.read(downloadsProvider).totalBytes;

    await n.delete('v1');
    expect(File(path).existsSync(), isFalse);
    expect(n.localPathFor('v1'), isNull);
    expect(c.read(downloadsProvider).totalBytes, before - 2000);

    await n.deleteType(TestimonyType.audio);
    expect(c.read(downloadsProvider).entries.keys, ['t1']);

    await n.deleteAll();
    expect(c.read(downloadsProvider).entries, isEmpty);
    expect(c.read(downloadsProvider).totalBytes, 0);
    expect(await repo().loadIndex(), isEmpty);
  });

  test('mode hors ligne : seulement les fichiers locaux', () async {
    const offline = PlaybackPreferences(offlineMode: true);
    expect(
      resolveAudioTestimony(_audio('x'), prefs: offline, metered: false),
      isNull,
    );
    final c = container();
    final n = await ready(c);
    await n.download(_audio('a1'));
    final r = resolveAudioTestimony(_audio('a1'), prefs: offline, metered: true);
    expect(r?.url, n.localPathFor('a1'));
    expect(r?.label, 'Hors ligne');
  });

  test('échec réseau → failed, relance possible', () async {
    final failing = _FakeAdapter(fail: true);
    final r = repo(failing);
    final c = container(r: r);
    final n = await ready(c);
    expect(await n.download(_audio('a1')), DownloadOutcome.failed);
    final st = c.read(downloadItemProvider('a1'));
    expect(st.status, DownloadStatus.failed);
    expect(st.error, isNotNull);
    expect(n.canRetry('a1'), isTrue);
    // Fichier partiel nettoyé.
    expect(n.localPathFor('a1'), isNull);
  });

  test('YouTube : non téléchargeable', () async {
    final c = container();
    final n = await ready(c);
    final yt = VideoTestimony(
      id: 'y1',
      author: _author,
      title: 'YT',
      category: TestimonyCategory.salut,
      createdAt: DateTime(2026),
      stats: TestimonyStats.zero,
      durationSeconds: 0,
      thumbnailUrl: '',
      youtubeId: 'abcdefghijk',
    );
    expect(await n.download(yt), DownloadOutcome.unsupported);
  });

  test('formatBytes en français', () {
    expect(formatBytes(3565158), '3,4 Mo');
    expect(formatBytes(800 * 1024), '800 Ko');
    expect(formatBytes(256 * 1024 * 1024), '256 Mo');
  });
}
