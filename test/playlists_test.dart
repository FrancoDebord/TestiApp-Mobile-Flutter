// Listes de témoignages (docs serveur fonctionnalites/listes-de-temoignages.md) :
// modèles JSON, suivant à lire, réglage de lecture auto, publication, API,
// bandeau « À suivre », panneau du lecteur et écran d'une liste.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/home/providers/home_providers.dart' show testimonyFromApiJson;
import 'package:testi_app/features/playlists/data/playlist_api.dart';
import 'package:testi_app/features/playlists/models/playlist_models.dart';
import 'package:testi_app/features/playlists/providers/playlist_providers.dart';
import 'package:testi_app/features/playlists/screens/playlist_screen.dart';
import 'package:testi_app/features/playlists/widgets/playlist_panel.dart';
import 'package:testi_app/features/playlists/widgets/playlist_up_next_banner.dart';
import 'package:testi_app/features/publish/models/publish_models.dart';
import 'package:testi_app/features/publish/providers/publish_provider.dart';
import 'package:testi_app/l10n/app_localizations.dart';
import 'package:testi_app/services/api_service.dart';

const _pid = '0199aaaa-bbbb-7ccc-8ddd-000000000001';

Map<String, dynamic> _item(String id, String title, {String type = 'video', int duration = 312}) => {
      'id': id,
      'title': title,
      'type': type,
      'isShort': false,
      'coverUrl': null,
      'durationSec': duration,
      'viewsCount': 40,
      'publishedAt': '2026-10-30T10:00:00+00:00',
    };

final _items = [_item('t1', 'Partie 1'), _item('t2', 'Partie 2', type: 'audio'), _item('t3', 'Partie 3', type: 'text', duration: 0)];

Map<String, dynamic> _playlist({bool isMine = false, List<Map<String, dynamic>>? items}) => {
      'id': _pid,
      'title': 'Guérison de ma mère',
      'description': null,
      'owner': {'id': 'u1', 'displayName': 'Ama'},
      'isMine': isMine,
      'count': (items ?? _items).length,
      'coverUrl': null,
      'shareUrl': 'https://temoignage.as-krea.com/listes/$_pid',
      'updatedAt': '2026-10-30T10:00:00+00:00',
      'items': items ?? _items,
    };

Map<String, dynamic> _context({required int position, String? previousId, String? nextId, bool autoplay = true}) => {
      'id': _pid,
      'title': 'Guérison de ma mère',
      'description': null,
      'owner': {'id': 'u1', 'displayName': 'Ama'},
      'position': position,
      'count': 3,
      'previousId': previousId,
      'nextId': nextId,
      'autoplay': autoplay,
      'items': _items,
    };

class _Api implements ApiService {
  final calls = <String>[];
  final bodies = <dynamic>[];
  final queries = <Map<String, dynamic>?>[];
  Map<String, dynamic> playlist = _playlist(isMine: true);

  LaravelResponse<T> _ok<T>(Object? data) => LaravelResponse<T>(success: true, data: data as T);

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET $path');
    queries.add(query);
    if (path == AppConstants.testimonyById('t2')) {
      return _ok({'id': 't2', 'title': 'Partie 2', 'type': 'audio', 'playlist': _context(position: 2, previousId: 't1', nextId: 't3')});
    }
    return _ok(path == AppConstants.myPlaylists ? [{..._playlist(isMine: true), 'items': null}] : playlist);
  }

  @override
  Future<LaravelResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query, dynamic options}) async {
    calls.add('POST $path');
    bodies.add(data);
    return _ok(playlist);
  }

  @override
  Future<LaravelResponse<T>> put<T>(String path, {dynamic data, dynamic options}) async {
    calls.add('PUT $path');
    bodies.add(data);
    return _ok(playlist);
  }

  @override
  Future<LaravelResponse<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? query, dynamic options}) async {
    calls.add('DELETE $path');
    return _ok(path == AppConstants.playlistById(_pid) ? null : playlist);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

Widget _app(Widget child, {List overrides = const []}) => ProviderScope(
      overrides: [...overrides],
      child: MaterialApp(
        locale: L10n.fr,
        supportedLocales: L10n.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    );

void main() {
  group('Modèles JSON', () {
    test('liste avec ses témoignages, et liste de listes (items null)', () {
      final p = Playlist.fromJson(_playlist(isMine: true));
      expect(p.title, 'Guérison de ma mère');
      expect(p.owner.displayName, 'Ama');
      expect(p.isMine, isTrue);
      expect(p.count, 3);
      expect(p.shareUrl, endsWith('/listes/$_pid'));
      expect(p.items!.map((i) => i.type), [PlaylistItemType.video, PlaylistItemType.audio, PlaylistItemType.text]);
      expect(p.items!.first.durationLabel, '5:12');
      expect(p.items!.last.durationLabel, isNull);

      final mine = Playlist.listFrom([{..._playlist(), 'items': null}]);
      expect(mine.single.items, isNull);
    });

    test('liste en cours : position, précédent, suivant ; null hors liste', () {
      final c = PlaylistContext.fromJson(_context(position: 2, previousId: 't1', nextId: 't3'))!;
      expect(c.position, 2);
      expect(c.previous!.title, 'Partie 1');
      expect(c.next!.title, 'Partie 3');
      expect(c.autoplay, isTrue);
      expect(PlaylistContext.fromJson(null), isNull);
      // Suivant absent de items : témoignage minimal (ouvert par sa page).
      final missing = PlaylistContext.fromJson({..._context(position: 3, nextId: 'tx'), 'items': const []})!;
      expect(missing.next!.id, 'tx');
    });

    test('témoignage du détail : champ playlist (null hors liste)', () {
      final base = {'id': 't2', 'title': 'Partie 2', 'type': 'text', 'bodyText': 'x', 'user': {'id': 'u1', 'displayName': 'Ama'}};
      expect(testimonyFromApiJson(base)!.playlist, isNull);
      final t = testimonyFromApiJson({...base, 'playlist': _context(position: 2, previousId: 't1', nextId: 't3')});
      expect(t!.playlist!.nextId, 't3');
    });
  });

  group('Suivant à lire automatiquement', () {
    final middle = PlaylistContext.fromJson(_context(position: 2, previousId: 't1', nextId: 't3'));
    final last = PlaylistContext.fromJson(_context(position: 3, previousId: 't2'));

    test('lecture auto de la liste active : le suivant', () {
      expect(playlistNextToAutoplay(middle, enabled: true)!.id, 't3');
    });

    test('réglage coupé, autoplay serveur coupé, fin de liste ou hors liste : rien', () {
      expect(playlistNextToAutoplay(middle, enabled: false), isNull);
      expect(playlistNextToAutoplay(
          PlaylistContext.fromJson(_context(position: 2, nextId: 't3', autoplay: false)), enabled: true), isNull);
      expect(playlistNextToAutoplay(last, enabled: true), isNull);
      expect(playlistNextToAutoplay(null, enabled: true), isNull);
    });
  });

  group('Réglage « Lecture auto de la liste »', () {
    test('activé par défaut, mémorisé à part de la lecture auto ordinaire', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(playlistAutoplayProvider), isTrue);
      await c.read(playlistAutoplayProvider.notifier).set(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PlaylistAutoplayNotifier.storageKey), isFalse);
      expect(prefs.getKeys(), {PlaylistAutoplayNotifier.storageKey});

      // Relu au démarrage suivant.
      final again = ProviderContainer();
      addTearDown(again.dispose);
      again.read(playlistAutoplayProvider);
      await Future<void>.delayed(Duration.zero);
      expect(again.read(playlistAutoplayProvider), isFalse);
    });
  });

  group('Publication', () {
    test('playlist_title prioritaire, sinon playlist_id ; rien pour le carnet privé', () {
      expect(playlistPublishFields(PublishDraft()), isEmpty);
      expect(playlistPublishFields(PublishDraft(playlistId: _pid)), {'playlist_id': _pid});
      expect(playlistPublishFields(PublishDraft(playlistId: _pid, playlistTitle: '  Nouvelle  ')),
          {'playlist_title': 'Nouvelle'});
      expect(
        playlistPublishFields(PublishDraft(playlistId: _pid, visibility: TestimonyVisibility.private)),
        isEmpty,
      );
    });

    test('erreur 422 errors.playlist_id lue pour le champ', () {
      expect(playlistErrorFrom({'errors': {'playlist_id': ['Cette liste ne vous appartient pas.']}}),
          'Cette liste ne vous appartient pas.');
      expect(playlistErrorFrom({'errors': {'title': ['x']}}), isNull);
      expect(playlistErrorFrom(null), isNull);
    });

    test('brouillon : liste choisie et titre gardés', () {
      final d = PublishDraft.fromDraftJson(PublishDraft(playlistId: _pid, playlistTitle: 'T').toDraftJson());
      expect(d.playlistId, _pid);
      expect(d.playlistTitle, 'T');
    });
  });

  group('API', () {
    test('routes et corps envoyés', () async {
      final api = _Api();
      final p = PlaylistApi(api);
      await p.create(title: ' Guérison ', description: '', testimonyIds: ['t1']);
      await p.update(_pid, testimonyIds: ['t3', 't1', 't2']);
      await p.add(_pid, 't2');
      await p.remove(_pid, 't2');
      await p.delete(_pid);
      final ctx = await p.contextOf('t2', listId: _pid);
      expect(api.calls, [
        'POST /playlists',
        'PUT /playlists/$_pid',
        'POST /playlists/$_pid/testimonies',
        'DELETE /playlists/$_pid/testimonies/t2',
        'DELETE /playlists/$_pid',
        'GET /testimonies/t2',
      ]);
      expect(api.bodies[0], {'title': 'Guérison', 'testimonyIds': ['t1']});
      expect(api.bodies[1], {'testimonyIds': ['t3', 't1', 't2']});
      expect(api.bodies[2], {'testimonyId': 't2'});
      expect(api.queries.last, {'list': _pid});
      expect(ctx!.position, 2);
    });

    test('403 / 422 : message du serveur et erreurs par champ', () async {
      final p = PlaylistApi(_FailingApi());
      await expectLater(
        p.create(title: ''),
        throwsA(isA<PlaylistFailure>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.fieldErrors['title'], 'title', 'Donnez un titre.')),
      );
    });
  });

  group('Bandeau « À suivre »', () {
    testWidgets('5 s puis lecture ; Annuler arrête le compte à rebours', (tester) async {
      var played = 0;
      var cancelled = 0;
      final item = PlaylistItem.fromJson(_item('t3', 'Partie 3'));
      await tester.pumpWidget(_app(Scaffold(
        body: PlaylistUpNextBanner(item: item, onPlay: () => played++, onCancel: () => cancelled++),
      )));
      expect(find.text('À suivre : Partie 3'), findsOneWidget);
      expect(find.text('Lecture dans 5 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Lecture dans 2 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(played, 1);

      await tester.pumpWidget(_app(Scaffold(
        body: PlaylistUpNextBanner(
            key: const ValueKey('b2'), item: item, onPlay: () => played++, onCancel: () => cancelled++),
      )));
      await tester.tap(find.text('Annuler'));
      await tester.pump(const Duration(seconds: 6));
      expect(cancelled, 1);
      expect(played, 1);
    });
  });

  group('Panneau du lecteur', () {
    testWidgets('titre, « auteur · 2 sur 3 », en cours en surbrillance, Suivant', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final opened = <String>[];
      final ctx = PlaylistContext.fromJson(_context(position: 1, nextId: 't2'))!;
      await tester.pumpWidget(_app(Scaffold(
        body: SingleChildScrollView(
          child: PlaylistPanel(playlist: ctx, currentId: 't1', onOpenItem: (i) => opened.add(i.id)),
        ),
      )));
      expect(find.text('Guérison de ma mère'), findsOneWidget);
      expect(find.text('Ama · 1 sur 3'), findsOneWidget);
      expect(find.text('Lecture auto de la liste'), findsOneWidget);
      // Premier de la liste : pas de précédent.
      final previous = tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('playlist-previous')));
      expect(previous.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('playlist-next')));
      await tester.tap(find.text('Partie 3'));
      // L'élément en cours ne se rouvre pas.
      await tester.tap(find.text('Partie 1'));
      expect(opened, ['t2', 't3']);
      expect(tester.takeException(), isNull);
    });
  });

  group('Écran d’une liste', () {
    testWidgets('propriétaire : Tout lire, retrait et suppression avec confirmation', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final api = _Api();
      await tester.pumpWidget(_app(
        const PlaylistScreen(playlistId: _pid),
        overrides: [apiServiceProvider.overrideWithValue(api)],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Tout lire'), findsOneWidget);
      expect(find.text('Ajouter un de mes témoignages'), findsOneWidget);
      expect(find.text('Partie 2'), findsOneWidget);

      // Retirer : dialogue, puis DELETE.
      await tester.tap(find.byKey(const ValueKey('playlist-remove-t2')));
      await tester.pumpAndSettle();
      expect(find.text('Retirer ce témoignage de la liste ?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('playlist-remove-confirm')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('DELETE /playlists/$_pid/testimonies/t2'));

      // Supprimer la liste : dialogue, annuler d'abord (rien n'est envoyé).
      await tester.tap(find.byKey(const ValueKey('playlist-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer la liste'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('DELETE /playlists/$_pid')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('visiteur : pas de modification, liste vide signalée', (tester) async {
      final api = _Api()..playlist = _playlist(items: const []);
      await tester.pumpWidget(_app(
        const PlaylistScreen(playlistId: _pid),
        overrides: [apiServiceProvider.overrideWithValue(api)],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Cette liste est vide.'), findsOneWidget);
      expect(find.byKey(const ValueKey('playlist-menu')), findsNothing);
      expect(find.text('Ajouter un de mes témoignages'), findsNothing);
    });
  });
}

class _FailingApi implements ApiService {
  @override
  Future<LaravelResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query, dynamic options}) async =>
      throw const LaravelApiException(
        message: 'Donnez un titre.',
        statusCode: 422,
        errors: {'title': ['Donnez un titre.']},
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}
