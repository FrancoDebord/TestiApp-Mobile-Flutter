// « Mes témoignages » gardés dans la base SQLite du téléphone, relus hors connexion,
// retirables (lib/features/downloads/data/offline_testimonies_store.dart).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart' show currentUserProvider;
import 'package:testi_app/features/downloads/data/offline_testimonies_store.dart';
import 'package:testi_app/features/profile/providers/profile_provider.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/shared/models/user_model.dart';

/// Base en mémoire, mêmes règles que la table offline_testimonies.
class _Store extends OfflineTestimoniesStore {
  final rows = <String, ({Map<String, dynamic> json, bool excluded})>{};
  final saved = DateTime(2026, 10, 26, 9);

  @override
  Future<void> saveMine(String userId, List<Map<String, dynamic>> items) async {
    final ids = {for (final j in items) '${j['id']}'};
    rows.removeWhere((id, _) => !ids.contains(id));
    for (final j in items) {
      final id = '${j['id']}';
      if (rows[id]?.excluded ?? false) continue;
      rows[id] = (json: j, excluded: false);
    }
  }

  @override
  Future<List<StoredTestimony>> mine(String userId) async => [
        for (final e in rows.entries)
          if (!e.value.excluded) (id: e.key, json: e.value.json, savedAt: saved),
      ];

  @override
  Future<void> removeMine(String userId, String id) async => rows[id] = (json: const {}, excluded: true);

  @override
  Future<void> removeAllMine(String userId) async {
    for (final id in rows.keys.toList()) {
      rows[id] = (json: const {}, excluded: true);
    }
  }
}

class _Api implements ApiService {
  bool offline = false;
  List<Map<String, dynamic>> items = [];

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    if (offline) throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
    return LaravelResponse<T>(success: true, data: items as T, meta: const {'lastPage': 1});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

Map<String, dynamic> _t(String id, String title) => {
      'id': id,
      'title': title,
      'type': 'text',
      'status': 'published',
      'bodyText': 'Texte de $title',
      'createdAt': '2026-10-20T10:00:00Z',
    };

({ProviderContainer c, _Store store, _Api api}) _setup() {
  final store = _Store();
  final api = _Api();
  final c = ProviderContainer(overrides: [
    offlineTestimoniesStoreProvider.overrideWithValue(store),
    apiServiceProvider.overrideWithValue(api),
    currentUserProvider.overrideWithValue(const UserModel(id: 'me', displayName: 'Awa')),
  ]);
  addTearDown(c.dispose);
  return (c: c, store: store, api: api);
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('en ligne : mes témoignages sont copiés sur le téléphone', () async {
    final s = _setup();
    s.api.items = [_t('a', 'Guérie'), _t('b', 'Délivré')];
    final list = await s.c.read(myTestimoniesNotifierProvider.future);
    await _settle();
    expect(list.map((t) => t.title), ['Guérie', 'Délivré']);
    expect(s.store.rows.keys, ['a', 'b']);
    expect(s.c.read(myTestimoniesOfflineSinceProvider), isNull);
  });

  test('hors connexion : la copie du téléphone est affichée, avec sa date', () async {
    final s = _setup();
    s.api.items = [_t('a', 'Guérie')];
    await s.c.read(myTestimoniesNotifierProvider.future);
    await _settle();

    s.api.offline = true;
    await s.c.read(myTestimoniesNotifierProvider.notifier).refresh();
    final list = s.c.read(myTestimoniesNotifierProvider).value!;
    expect(list.single.title, 'Guérie');
    expect(list.single.bodyText, 'Texte de Guérie');
    expect(s.c.read(myTestimoniesOfflineSinceProvider), s.store.saved);
  });

  test('retiré du téléphone : n\'est plus recopié ; supprimé en ligne : disparaît', () async {
    final s = _setup();
    s.api.items = [_t('a', 'Guérie'), _t('b', 'Délivré')];
    await s.c.read(myTestimoniesNotifierProvider.future);
    await _settle();

    expect((await s.c.read(offlineMyTestimoniesProvider.future)).map((x) => x.id), ['a', 'b']);
    await s.c.read(offlineMyTestimoniesProvider.notifier).remove('a');
    expect(s.c.read(offlineMyTestimoniesProvider).value!.map((x) => x.id), ['b']);

    // Nouveau chargement : « a » reste retiré, « b » supprimé en ligne disparaît.
    s.api.items = [_t('a', 'Guérie'), _t('c', 'Nouveau')];
    await s.c.read(myTestimoniesNotifierProvider.notifier).refresh();
    await _settle();
    expect((await s.store.mine('me')).map((x) => x.id), ['c']);

    await s.c.read(offlineMyTestimoniesProvider.notifier).removeAll();
    expect(await s.store.mine('me'), isEmpty);
  });
}
