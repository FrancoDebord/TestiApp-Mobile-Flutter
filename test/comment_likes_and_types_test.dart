// « J'aime » des commentaires, types de témoignages autorisés, réglages administrateur.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/admin/providers/admin_provider.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/shared/comments/comment_likes.dart';
import 'package:testi_app/shared/models/user_model.dart';

class _Api implements ApiService {
  _Api({this.fail = false});
  final bool fail;
  final calls = <String>[];
  final puts = <(String, Object?)>[];

  @override
  Future<LaravelResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query}) async {
    calls.add('POST $path');
    if (fail) throw const LaravelApiException(message: 'Refusé', statusCode: 403);
    return LaravelResponse<T>(success: true, data: <String, dynamic>{'likesCount': 8, 'isLikedByMe': true} as T);
  }

  @override
  Future<LaravelResponse<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? query}) async {
    calls.add('DELETE $path');
    return LaravelResponse<T>(success: true, data: <String, dynamic>{'likesCount': 7, 'isLikedByMe': false} as T);
  }

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    // Paramètres groupés comme le serveur (AppSetting::allGrouped).
    return LaravelResponse<T>(success: true, data: <String, dynamic>{
      'general': {'maintenance_mode': false, 'allow_new_registrations': false},
      'publishing': {'testimony_type_audio_enabled': false, 'testimony_type_youtube_enabled': '1'},
    } as T);
  }

  @override
  Future<LaravelResponse<T>> put<T>(String path, {dynamic data}) async {
    puts.add((path, data));
    if (fail) throw const LaravelApiException(message: 'Refusé', statusCode: 403);
    return LaravelResponse<T>(success: true, data: <String, dynamic>{} as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

ProviderContainer _container(_Api api) {
  final c = ProviderContainer(overrides: [apiServiceProvider.overrideWithValue(api)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group("J'aime des commentaires", () {
    test('adresses des trois sortes de commentaires', () {
      expect(const CommentRef.testimony('c1').likePath, '/comments/c1/like');
      expect(const CommentRef.event('e1', 'c1').likePath, '/events/e1/comments/c1/like');
      expect(const CommentRef.verse('12', 'c1').likePath, '/daily-verse/12/comments/c1/like');
      expect(const CommentRef.testimony('temp_1').isPending, isTrue);
    });

    test('aimer puis ne plus aimer : état du serveur, partagé par clé', () async {
      final api = _Api();
      final c = _container(api);
      final n = c.read(commentLikesProvider.notifier);
      const ref = CommentRef.event('e1', 'c1');
      expect(await n.toggle(ref, count: 7, liked: false), isNull);
      expect(n.of(ref, count: 0, liked: false), (count: 8, liked: true));
      expect(await n.toggle(ref, count: 7, liked: false), isNull);
      expect(n.of(ref, count: 0, liked: false), (count: 7, liked: false));
      expect(api.calls, ['POST /events/e1/comments/c1/like', 'DELETE /events/e1/comments/c1/like']);
    });

    test('échec : retour à l\'état précédent et message du serveur', () async {
      final c = _container(_Api(fail: true));
      final n = c.read(commentLikesProvider.notifier);
      const ref = CommentRef.testimony('c9');
      expect(await n.toggle(ref, count: 2, liked: false), 'Refusé');
      expect(n.of(ref, count: 2, liked: false), (count: 2, liked: false));
    });
  });

  group('Types de témoignages autorisés', () {
    test('liste du serveur prioritaire', () {
      const u = UserModel(id: 'u1', allowedTestimonyTypes: ['text', 'youtube']);
      expect(u.canPublishType('text'), isTrue);
      expect(u.canPublishType('video'), isFalse);
      expect(u.canPublishType('youtube'), isTrue);
    });

    test('serveur plus ancien : tout, sauf YouTube réservé aux administrateurs', () {
      const u = UserModel(id: 'u1');
      expect(u.canPublishType('audio'), isTrue);
      expect(u.canPublishType('youtube'), isFalse);
      expect(const UserModel(id: 'a1', role: UserRole.administrateur).canPublishType('youtube'), isTrue);
    });

    test('lu depuis la réponse de /me', () {
      final u = UserModel.fromJson({'id': 'u1', 'allowed_testimony_types': ['audio']});
      expect(u.allowedTestimonyTypes, ['audio']);
      expect(UserModel.fromJson(u.toJson()).allowedTestimonyTypes, ['audio']);
    });
  });

  group('Réglages administrateur', () {
    test('réponse groupée du serveur mise à plat', () async {
      final c = _container(_Api());
      final s = await c.read(appSettingsProvider.future);
      expect(s.allowNewRegistrations, isFalse);
      expect(s.audioTestimoniesEnabled, isFalse);
      expect(s.youtubeTestimoniesEnabled, isTrue);
      expect(s.textTestimoniesEnabled, isTrue);
    });

    test('chaque bascule est enregistrée aussitôt', () async {
      final api = _Api();
      final c = _container(api);
      await c.read(appSettingsProvider.future);
      expect(await c.read(appSettingsProvider.notifier).toggle('videoTestimoniesEnabled'), isNull);
      expect(api.puts.single.$1, AppConstants.adminSettings);
      expect(api.puts.single.$2, {'testimony_type_video_enabled': false});
      expect(c.read(appSettingsProvider).value!.videoTestimoniesEnabled, isFalse);
    });

    test('refus du serveur : l\'interrupteur revient', () async {
      final c = _container(_Api(fail: true));
      await c.read(appSettingsProvider.future);
      expect(await c.read(appSettingsProvider.notifier).toggle('textTestimoniesEnabled'), 'Refusé');
      expect(c.read(appSettingsProvider).value!.textTestimoniesEnabled, isTrue);
    });
  });
}
