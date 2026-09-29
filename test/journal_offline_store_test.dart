import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/journal/data/journal_offline_store.dart';
import 'package:testi_app/features/journal/data/journal_repository.dart';
import 'package:testi_app/features/journal/models/journal_entry.dart';

JournalEntry _e(String id, String type, {String? media, String title = 'Titre', String body = ''}) =>
    JournalEntry.fromJson({
      'id': id, 'title': title, 'type': type, 'bodyText': body,
      'mediaUrl': media, 'visibility': 'private', 'status': 'draft',
      'createdAt': '2026-09-26T08:30:00+00:00',
    });

/// Serveur factice : le carnet, découpé en pages de 2.
class _FakeServer implements JournalRepository {
  _FakeServer(this.entries);
  List<JournalEntry> entries;

  @override
  Future<JournalPage> list({int page = 1, JournalEntryType? type, String? query}) async {
    final start = (page - 1) * 2;
    final slice = entries.skip(start).take(2).toList();
    final last = (entries.length / 2).ceil().clamp(1, 999);
    return JournalPage(entries: slice, currentPage: page, lastPage: last, total: entries.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late Directory tmp;
  late List<String> downloaded;
  late JournalOfflineStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('journal_offline_');
    downloaded = [];
    store = JournalOfflineStore(
      baseDir: () async => tmp,
      downloader: (url, dest) async {
        if (url.contains('introuvable')) throw Exception('404');
        downloaded.add(url);
        await dest.writeAsBytes(List.filled(100, 7));
      },
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('synchro : toutes les pages, médias téléchargés, un échec n\'arrête rien', () async {
    final server = _FakeServer([
      _e('a', 'text', title: 'Guérison de maman', body: 'Merci Seigneur'),
      _e('b', 'audio', media: 'https://srv/storage/media/audios/b.m4a'),
      _e('c', 'video', media: 'https://srv/storage/media/videos/c.mp4'),
      _e('d', 'video', media: 'https://srv/storage/media/videos/introuvable.mp4'),
    ]);

    final r = await store.sync('u1', server);

    expect(r.entries, 4);
    expect(r.mediaAvailable, 2);
    expect(r.mediaFailed, 1);
    expect((await store.readEntries('u1')).map((e) => e.id), ['a', 'b', 'c', 'd']);
    expect(await store.localMedia('u1', server.entries[1]), isNotNull);
    expect((await store.localMedia('u1', server.entries[2]))!.path, endsWith('c.mp4'));
    expect(await store.localMedia('u1', server.entries[3]), isNull);
    expect((await store.readSettings('u1')).lastSyncAt, isNotNull);

    // Deuxième synchro : rien n'est retéléchargé, l'échec est retenté.
    downloaded.clear();
    final r2 = await store.sync('u1', server);
    expect(downloaded, isEmpty);
    expect(r2.mediaFailed, 1);
  });

  test('une entrée partagée ou supprimée disparaît du téléphone', () async {
    final server = _FakeServer([
      _e('a', 'audio', media: 'https://srv/a.m4a'),
      _e('b', 'video', media: 'https://srv/b.mp4'),
    ]);
    await store.sync('u1', server);
    final b = server.entries[1];
    expect(await store.localMedia('u1', b), isNotNull);

    server.entries = [server.entries[0]]; // « b » partagée : plus dans le carnet
    await store.sync('u1', server);
    expect((await store.readEntries('u1')).map((e) => e.id), ['a']);
    expect(await store.localMedia('u1', b), isNull);
  });

  test('recherche hors ligne : type et texte', () async {
    await store.sync('u1', _FakeServer([
      _e('a', 'text', title: 'Guérison de maman'),
      _e('b', 'audio', title: 'Emploi trouvé', media: 'https://srv/b.m4a'),
      _e('c', 'text', title: 'Autre', body: 'La maman de Paul'),
    ]));
    expect((await store.search('u1', type: JournalEntryType.audio)).map((e) => e.id), ['b']);
    expect((await store.search('u1', query: 'MAMAN')).map((e) => e.id), ['a', 'c']);
  });

  test('chaque compte a sa propre copie ; effacer ne touche que la sienne', () async {
    await store.sync('u1', _FakeServer([_e('a', 'text')]));
    await store.sync('u2', _FakeServer([_e('z', 'text')]));
    await store.writeSettings('u1', const JournalOfflineSettings(enabled: true, asked: true));

    expect((await store.readEntries('u1')).single.id, 'a');
    expect((await store.readEntries('u2')).single.id, 'z');

    await store.clear('u1');
    expect(await store.readEntries('u1'), isEmpty);
    final s = await store.readSettings('u1');
    expect(s.enabled, isFalse);
    expect(s.asked, isTrue, reason: 'ne pas reposer la question');
    expect((await store.readEntries('u2')).single.id, 'z');
  });

  test('un identifiant piégé ne sort pas du dossier du carnet', () async {
    await store.sync('../../evil', _FakeServer([_e('a', 'text')]));
    final escaped = File('${tmp.parent.path}${Platform.pathSeparator}evil');
    expect(await escaped.exists(), isFalse);
    expect(await Directory('${tmp.path}${Platform.pathSeparator}journal').exists(), isTrue);
  });
}
