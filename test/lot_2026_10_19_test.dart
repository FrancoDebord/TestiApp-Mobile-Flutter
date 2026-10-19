// Lot du 2026-10-19 : verset du jour synchronisé, crédit YouTube, discussion d'un
// direct terminé, paramètres globaux décrits par le serveur, catégories push.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/admin/providers/admin_settings_schema.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/live/widgets/live_replay.dart';
import 'package:testi_app/features/profile/models/profile_models.dart';
import 'package:testi_app/services/api_service.dart';

Map<String, dynamic> _verse({bool liked = false, int likes = 3}) => {
      'id': 42,
      'verseText': 'Car Dieu a tant aimé le monde…',
      'reference': 'Jean 3:16',
      'counts': {'likes': likes, 'prayers': 1, 'comments': 5},
      'myReactions': [if (liked) 'like'],
    };

class _Api implements ApiService {
  final posts = <(String, Object?)>[];
  final puts = <(String, Object?)>[];
  Map<String, dynamic> today = _verse();

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    if (path == AppConstants.verseToday) return LaravelResponse<T>(success: true, data: today as T);
    if (path == AppConstants.adminSettingsSchema) {
      return LaravelResponse<T>(success: true, data: <String, dynamic>{
        'groups': [
          {
            'key': 'general',
            'label': 'Général',
            'settings': [
              {'key': 'maintenance_mode', 'label': 'Maintenance', 'type': 'boolean', 'value': false},
              {'key': 'max_upload_mb', 'label': 'Taille maximale', 'type': 'integer', 'value': 50},
            ],
          },
        ],
      } as T);
    }
    if (path == AppConstants.liveComments('l1')) {
      return LaravelResponse<T>(
        success: true,
        data: [
          {'id': 'c1', 'body': 'Gloire à Dieu !', 'user': {'id': 'u1', 'displayName': 'Afi'}, 'offsetSeconds': 125},
        ] as T,
        meta: const {'currentPage': 1, 'lastPage': 2},
      );
    }
    throw UnimplementedError(path);
  }

  @override
  Future<LaravelResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query}) async {
    posts.add((path, data));
    // Le serveur renvoie le verset à jour, avec les réactions faites ailleurs.
    return LaravelResponse<T>(success: true, data: _verse(liked: true, likes: 10) as T);
  }

  @override
  Future<LaravelResponse<T>> put<T>(String path, {dynamic data}) async {
    puts.add((path, data));
    return LaravelResponse<T>(success: true, data: <String, dynamic>{} as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

ProviderContainer _c(_Api api) {
  final c = ProviderContainer(overrides: [apiServiceProvider.overrideWithValue(api)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('Verset du jour synchronisé', () {
    test('compteurs et commentaires lus depuis le serveur', () {
      final v = DailyVerse.fromJson(_verse(liked: true));
      expect(v.isLiked, isTrue);
      expect(v.commentCount, 5);
    });

    test("« J'aime » : POST /daily-verse/{id}/react, état du serveur repris", () async {
      final api = _Api();
      final c = _c(api);
      await c.read(dailyVerseProvider.future);
      await c.read(dailyVerseProvider.notifier).toggleLike();
      expect(api.posts.single.$1, AppConstants.verseReactTo(42));
      expect(api.posts.single.$2, {'type': 'like', 'active': true});
      expect(c.read(dailyVerseProvider).value!.likeCount, 10);
    });

    test('réactions faites sur le site visibles après refresh()', () async {
      final api = _Api();
      final c = _c(api);
      await c.read(dailyVerseProvider.future);
      api.today = _verse(liked: true, likes: 7);
      await c.read(dailyVerseProvider.notifier).refresh();
      expect(c.read(dailyVerseProvider).value!.isLiked, isTrue);
      expect(c.read(dailyVerseProvider).value!.likeCount, 7);
    });
  });

  test('crédit YouTube : null si vide, sinon auteur / chaîne / lien', () {
    expect(YouTubeCredit.fromJson({'author': ' ', 'channel': null}), isNull);
    final c = YouTubeCredit.fromJson({'author': 'Pasteur Jean', 'channel': 'Lumière TV', 'url': 'https://youtube.com/@lumiere'})!;
    expect(c.author, 'Pasteur Jean');
    expect(c.channel, 'Lumière TV');
  });

  test('discussion d\'un direct terminé : moment dans le direct, pages suivantes', () async {
    final page = await fetchLiveReplay(_Api(), 'l1');
    expect(page.items.single.comment.body, 'Gloire à Dieu !');
    expect(page.items.single.offsetSeconds, 125);
    expect(page.hasMore, isTrue);
    expect(formatLiveOffset(125), '02:05');
    expect(formatLiveOffset(3725), '1:02:05');
  });

  test('paramètres globaux : groupes du serveur, valeur enregistrée aussitôt', () async {
    final api = _Api();
    final c = _c(api);
    final groups = (await c.read(adminSettingsSchemaProvider.future))!;
    expect(groups.single.label, 'Général');
    expect(groups.single.settings.map((s) => s.key), ['maintenance_mode', 'max_upload_mb']);
    expect(await c.read(adminSettingsSchemaProvider.notifier).set('maintenance_mode', true), isNull);
    expect(api.puts.single.$2, {'maintenance_mode': true});
    expect(c.read(adminSettingsSchemaProvider.notifier).find('maintenance_mode')!.boolValue, isTrue);
  });

  test('catégories push : absentes = activées, lues et renvoyées', () {
    final s = UserSettings.fromJson({'push_events': false, 'push_follows': '1'});
    expect(s.push('push_events'), isFalse);
    expect(s.push('push_follows'), isTrue);
    expect(s.push('push_account'), isTrue);
    expect(s.toJson()['push_events'], isFalse);
  });
}
