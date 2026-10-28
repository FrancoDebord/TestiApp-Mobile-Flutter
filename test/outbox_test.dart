// File d'envoi hors connexion : actions gardées sur le téléphone puis envoyées
// dans l'ordre au retour du réseau (lib/features/offline/outbox_controller.dart).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/local_db/daos/outbox_dao.dart';
import 'package:testi_app/core/local_db/database_service.dart';
import 'package:testi_app/core/network/network_failure.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart' show realUserProvider;
import 'package:testi_app/features/events/models/event_models.dart';
import 'package:testi_app/features/offline/outbox_controller.dart';
import 'package:testi_app/features/prayer/data/prayer_repository.dart' show PrayerFailure;
import 'package:testi_app/services/acting_as_interceptor.dart' show kActingAsOverride;
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/shared/models/user_model.dart';

/// Base en mémoire (mêmes lignes que la table `outbox`).
class _Dao extends OutboxDao {
  _Dao() : super(DatabaseService());

  final rows = <String, Map<String, dynamic>>{};
  final ids = <String, String>{};

  List<OutboxItem> get all =>
      (rows.values.map(OutboxItem.fromRow).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt)));

  @override
  Future<List<OutboxItem>> forUser(String userId) async =>
      all.where((i) => i.userId == userId || i.userId == '').toList();

  @override
  Future<OutboxItem?> byId(String id) async => rows[id] == null ? null : OutboxItem.fromRow(rows[id]!);

  @override
  Future<List<OutboxItem>> insert(OutboxItem item) async {
    final replaced = all
        .where((i) => item.dedupeKey != null && i.dedupeKey == item.dedupeKey && !i.isFailed)
        .toList();
    for (final r in replaced) {
      rows.remove(r.id);
    }
    rows[item.id] = {
      'id': item.id,
      'user_id': item.userId,
      'act_as': item.actAs,
      'kind': item.kind.name,
      'target_id': item.targetId,
      'local_id': item.localId,
      'dedupe_key': item.dedupeKey,
      'payload': item.payload.encode(),
      'label': item.label,
      'status': item.status.name,
      'attempts': item.attempts,
      // Ordre d'insertion garanti même dans la même microseconde.
      'created_at': item.createdAt.add(Duration(microseconds: rows.length)).toIso8601String(),
    };
    return replaced;
  }

  @override
  Future<void> savePayload(String id, OutboxPayload payload) async => rows[id]!['payload'] = payload.encode();

  @override
  Future<void> postpone(String id, int attempts, DateTime nextTryAt) async {
    rows[id]!['attempts'] = attempts;
    rows[id]!['next_try_at'] = nextTryAt.toIso8601String();
  }

  @override
  Future<void> markFailed(String id, String error) async {
    rows[id]!['status'] = 'failed';
    rows[id]!['error'] = error;
  }

  @override
  Future<void> resetForRetry(String id) async {
    rows[id]!
      ..['status'] = 'pending'
      ..['error'] = null
      ..['attempts'] = 0
      ..['next_try_at'] = null;
  }

  @override
  Future<void> adoptOrphans(String userId) async {}

  @override
  Future<void> delete(String id) async => rows.remove(id);

  @override
  Future<void> mapId(String localId, String remoteId) async => ids[localId] = remoteId;

  @override
  Future<Map<String, String>> idMap(Iterable<String> localIds) async =>
      {for (final l in localIds) if (ids[l] != null) l: ids[l]!};

  @override
  Future<bool> isQueuedCreation(String localId) async => all.any((i) => i.localId == localId);
}

class _Network extends OutboxNetwork {
  bool online = false;
  final _changes = StreamController<bool>.broadcast();

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<bool> isOnline() async => online;
}

class _Files extends OutboxFiles {
  @override
  Future<String> keep(String id, String path) async => 'kept/$id/$path';

  @override
  Future<String> dir(String id) async => 'kept/$id';

  @override
  Future<void> delete(String id) async {}
}

typedef _Call = ({String method, String path, Object? data, Map<String, dynamic>? query, Options? options});

class _Api implements ApiService {
  final calls = <_Call>[];

  /// Réponse (ou erreur) par « MÉTHODE chemin ».
  final answers = <String, Object Function()>{};
  var _ids = 0;

  Future<LaravelResponse<T>> _answer<T>(String method, String path, Object? data, Map<String, dynamic>? query, Options? options) async {
    calls.add((method: method, path: path, data: data, query: query, options: options));
    final a = answers['$method $path'];
    final r = a == null ? <String, dynamic>{'id': 'srv-${++_ids}'} : a();
    if (r is Exception) throw r;
    return LaravelResponse<T>(success: true, data: r as T);
  }

  @override
  Future<LaravelResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query, Options? options}) =>
      _answer('POST', path, data, query, options);

  @override
  Future<LaravelResponse<T>> put<T>(String path, {dynamic data, Options? options}) =>
      _answer('PUT', path, data, null, options);

  @override
  Future<LaravelResponse<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? query, Options? options}) =>
      _answer('DELETE', path, data, query, options);

  @override
  Future<LaravelResponse<T>> upload<T>(String path,
          {required String filePath,
          String fieldName = 'file',
          Map<String, dynamic> extraFields = const {},
          ProgressCallback? onProgress,
          Options? options}) =>
      _answer('UPLOAD', path, {'file': filePath, 'field': fieldName, ...extraFields}, null, options);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

DioException _offline() => DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);

({ProviderContainer c, _Dao dao, _Network net, _Api api}) _setup({String userId = 'me'}) {
  final dao = _Dao();
  final net = _Network();
  final api = _Api();
  final c = ProviderContainer(overrides: [
    outboxDaoProvider.overrideWithValue(dao),
    outboxNetworkProvider.overrideWithValue(net),
    outboxFilesProvider.overrideWithValue(_Files()),
    apiServiceProvider.overrideWithValue(api),
    realUserProvider.overrideWithValue(UserModel(id: userId, displayName: 'Awa')),
  ]);
  addTearDown(c.dispose);
  return (c: c, dao: dao, net: net, api: api);
}

OutboxDraft _prayer(String body, {String? localId}) => OutboxDraft(
      kind: OutboxKind.prayerRequest,
      label: body,
      localId: localId ?? newLocalId(),
      request: OutboxRequest('POST', '/prayer/requests', body: {'body': body}),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hors ligne : gardée, puis envoyée au retour du réseau avec sa clé anti-doublon', () async {
    final s = _setup();
    final outbox = s.c.read(outboxProvider.notifier);
    final item = await outbox.enqueue(_prayer('Priez pour ma famille'));
    await outbox.flush();
    expect(s.api.calls, isEmpty, reason: 'hors ligne, rien ne part');
    expect(s.c.read(outboxProvider).pendingCount, 1);

    s.net.online = true;
    await outbox.flush();
    expect(s.api.calls, hasLength(1));
    final call = s.api.calls.single;
    expect('${call.method} ${call.path}', 'POST /prayer/requests');
    expect(call.data, {'body': 'Priez pour ma famille'});
    expect(call.options!.headers!['Idempotency-Key'], item!.id);
    expect(call.options!.extra!.containsKey(kActingAsOverride), isTrue);
    expect(s.dao.rows, isEmpty);
    expect(s.dao.ids[item.localId], 'srv-1');
    expect(s.c.read(outboxProvider).items, isEmpty);
  });

  test('fichiers : couverture envoyée avant (URL dans le corps), images après (identifiant créé)', () async {
    final s = _setup();
    s.net.online = true;
    s.api.answers['UPLOAD /media/upload'] = () => {'url': '/storage/cover.jpg'};
    s.api.answers['POST /events'] = () => {'id': 'ev-9'};
    final outbox = s.c.read(outboxProvider.notifier);
    final item = await outbox.enqueue(OutboxDraft(
      kind: OutboxKind.event,
      label: 'Croisade',
      localId: newLocalId(),
      request: const OutboxRequest('POST', '/events', body: {'title': 'Croisade'}),
      before: const [OutboxFile(path: '/media/upload', file: 'c.jpg', fields: {'type': 'image'}, into: 'cover_url')],
      after: const [
        OutboxFile(path: '/events/{id}/images', file: 'a.jpg', field: 'image'),
        OutboxFile(path: '/events/{id}/images', file: 'b.jpg', field: 'image'),
      ],
    ));
    await outbox.flush();

    expect(s.api.calls.map((c) => '${c.method} ${c.path}'), [
      'UPLOAD /media/upload',
      'POST /events',
      'UPLOAD /events/ev-9/images',
      'UPLOAD /events/ev-9/images',
    ]);
    expect((s.api.calls[0].data as Map)['file'], 'kept/${item!.id}/c.jpg', reason: 'copie gardée par la file');
    expect((s.api.calls[1].data as Map)['cover_url'], endsWith('/storage/cover.jpg'));
    // Une clé distincte et stable par étape.
    final keys = s.api.calls.map((c) => c.options!.headers!['Idempotency-Key']).toList();
    expect(keys.toSet(), hasLength(4));
    expect(keys[1], item.id);
    expect(s.dao.rows, isEmpty);
  });

  test("action sur un contenu créé hors ligne : part après lui, avec l'identifiant du serveur", () async {
    final s = _setup();
    final outbox = s.c.read(outboxProvider.notifier);
    final local = newLocalId();
    await outbox.enqueue(_prayer('Guérison', localId: local));
    // Encouragement sur la requête pas encore envoyée : mis en file, même en ligne.
    s.net.online = true;
    final sent = await outbox.sendOrQueue<String>(
      () async => fail('ne doit pas partir avant la requête'),
      () => OutboxDraft(
        kind: OutboxKind.prayerMessage,
        label: 'Courage',
        targetId: local,
        request: OutboxRequest('POST', '/prayer/requests/$local/messages', body: {'message': 'Courage'}),
      ),
    );
    expect(sent, isNull);
    s.api.answers['POST /prayer/requests'] = () => {'id': 'pr-42'};
    await outbox.flush();

    expect(s.api.calls.map((c) => '${c.method} ${c.path}'),
        ['POST /prayer/requests', 'POST /prayer/requests/pr-42/messages']);
    expect(s.dao.rows, isEmpty);
  });

  test('contenu visé supprimé de la file : action marquée « non envoyée »', () async {
    final s = _setup();
    s.net.online = true;
    final outbox = s.c.read(outboxProvider.notifier);
    final ghost = newLocalId();
    await outbox.enqueue(OutboxDraft(
      kind: OutboxKind.prayerMessage,
      label: 'Courage',
      request: OutboxRequest('POST', '/prayer/requests/$ghost/messages', body: const {'message': 'Courage'}),
    ));
    await outbox.flush();
    expect(s.api.calls, isEmpty);
    expect(s.c.read(outboxProvider).failedCount, 1);
  });

  test('refus du serveur : « non envoyé » avec son message, puis Réessayer', () async {
    final s = _setup();
    s.net.online = true;
    s.api.answers['POST /prayer/requests'] = () => const LaravelApiException(
        message: 'Données invalides', statusCode: 422, errors: {'body': ['Le texte est trop court.']});
    final outbox = s.c.read(outboxProvider.notifier);
    final item = await outbox.enqueue(_prayer('Hm'));
    await outbox.flush();

    final failed = s.c.read(outboxProvider).items.single;
    expect(failed.isFailed, isTrue);
    expect(failed.error, contains('trop court'));

    s.api.answers.remove('POST /prayer/requests');
    await outbox.retry(item!.id);
    expect(s.dao.rows, isEmpty);
    expect(s.api.calls, hasLength(2));
  });

  test("coupure pendant l'envoi : on s'arrête, l'action reste en attente sans tentative comptée", () async {
    final s = _setup();
    s.net.online = true;
    s.api.answers['POST /prayer/requests'] = () => _offline();
    final outbox = s.c.read(outboxProvider.notifier);
    await outbox.enqueue(_prayer('Un'));
    await outbox.enqueue(_prayer('Deux'));
    await outbox.flush();

    expect(s.api.calls, hasLength(1), reason: 'la seconde attend le réseau');
    expect(s.c.read(outboxProvider).pendingCount, 2);
    expect(s.dao.all.every((i) => i.attempts == 0 && !i.isFailed), isTrue);
  });

  test('serveur indisponible (5xx) : nouvelle tentative plus tard', () async {
    final s = _setup();
    s.net.online = true;
    s.api.answers['POST /prayer/requests'] =
        () => DioException(requestOptions: RequestOptions(), response: Response(requestOptions: RequestOptions(), statusCode: 503));
    final outbox = s.c.read(outboxProvider.notifier);
    await outbox.enqueue(_prayer('Un'));
    await outbox.flush();
    await outbox.flush();

    expect(s.api.calls, hasLength(1), reason: 'pas avant le délai');
    final item = s.dao.all.single;
    expect(item.attempts, 1);
    expect(item.nextTryAt!.isAfter(DateTime.now()), isTrue);
  });

  test('réactions : seule la dernière posée sur un contenu reste en attente', () async {
    final s = _setup();
    final outbox = s.c.read(outboxProvider.notifier);
    OutboxDraft like(String method) => OutboxDraft(
          kind: OutboxKind.reaction,
          label: 'Témoignage',
          dedupeKey: 'reaction:testimony:t1:appreciation',
          request: OutboxRequest(method, '/testimonies/t1/reactions',
              body: method == 'POST' ? const {'type': 'like'} : null,
              query: method == 'DELETE' ? const {'group': 'appreciation'} : null),
        );
    await outbox.enqueue(like('POST'));
    await outbox.enqueue(like('DELETE'));
    expect(s.c.read(outboxProvider).items, hasLength(1));

    s.net.online = true;
    await outbox.flush();
    expect(s.api.calls.single.method, 'DELETE');
    expect(s.api.calls.single.query, {'group': 'appreciation'});
  });

  test("sendOrQueue : en ligne, résultat ; refus relancé ; coupure gardée", () async {
    final s = _setup();
    s.net.online = true;
    final outbox = s.c.read(outboxProvider.notifier);
    expect(await outbox.sendOrQueue(() async => 'ok', () => _prayer('x')), 'ok');
    await expectLater(
      outbox.sendOrQueue<String>(() async => throw const PrayerFailure('Refusé', statusCode: 403), () => _prayer('x')),
      throwsA(isA<PrayerFailure>()),
    );
    expect(await outbox.sendOrQueue<String>(() async => throw const PrayerFailure('Pas de réseau', offline: true), () => _prayer('x')),
        isNull);
    expect(s.c.read(outboxProvider).pendingCount, 1);
  });

  test("la file appartient à la personne connectée", () async {
    final s = _setup();
    final outbox = s.c.read(outboxProvider.notifier);
    await outbox.enqueue(_prayer('À moi'));
    s.dao.rows['other'] = {
      ...s.dao.rows.values.single,
      'id': 'other',
      'user_id': 'someone-else',
    };
    await outbox.reload();
    expect(s.c.read(outboxProvider).items, hasLength(1));
  });

  test('erreurs réseau reconnues', () {
    expect(isNetworkFailure(_offline()), isTrue);
    expect(isNetworkFailure(const PrayerFailure('x', offline: true)), isTrue);
    expect(isNetworkFailure(const PrayerFailure('x', statusCode: 422)), isFalse);
    expect(isNetworkFailure(const LaravelApiException(message: 'x', statusCode: 422)), isFalse);
    expect(
        isNetworkFailure(DioException(
            requestOptions: RequestOptions(), response: Response(requestOptions: RequestOptions(), statusCode: 500))),
        isFalse);
  });

  test('étapes restantes conservées en JSON (reprise après fermeture)', () {
    final p = OutboxPayload(
      request: const OutboxRequest('POST', '/testimonies', body: {'title': 'T'}),
      after: [const OutboxFile(path: '/testimonies/{id}/proofs', file: 'p.pdf', fields: {'position': 1})],
      createdId: 't-1',
      preview: const {'text': 'Bonjour'},
    );
    final back = OutboxItem.fromRow({'id': 'x', 'payload': p.encode(), 'created_at': DateTime.now().toIso8601String()}).payload;
    expect(back.request!.path, '/testimonies');
    expect(back.after.single.fields, {'position': 1});
    expect(back.createdId, 't-1');
    expect(back.preview['text'], 'Bonjour');
    expect(localIdPattern.hasMatch(newLocalId()), isTrue);
  });

  test("modification d'événement en attente : relue telle quelle dans le formulaire", () {
    final d = EventDraft(
      title: 'Croisade de Cotonou',
      description: 'Trois soirs',
      startsAt: DateTime(2026, 11, 20, 18),
      endsAt: DateTime(2026, 11, 22, 22),
      city: 'Cotonou',
      latitude: 6.3654321,
      longitude: 2.4183456,
      commentsEnabled: false,
      youtubeLiveUrl: 'https://youtu.be/abcdefghijk',
      guests: [const EventGuest(name: 'Pasteur Jean', role: 'Orateur')],
    );
    final back = EventDraft.fromJson(d.toJson());
    expect(back.toJson(), d.toJson());
    expect(back.startsAt, DateTime(2026, 11, 20, 18));
    expect(back.guests.single.role, 'Orateur');
  });
}
