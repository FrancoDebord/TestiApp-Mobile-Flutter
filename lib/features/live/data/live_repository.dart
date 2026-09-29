import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../models/live_models.dart';

/// Erreur lisible d'une action de direct.
///
/// Codes du backend : 403 droits/exclusion · 404 introuvable ou pas encore
/// public · 409 direct déjà en cours (voir [liveId]) · 410 terminé ·
/// 422 validation · 429 trop de messages · 503 service vidéo indisponible.
class LiveFailure implements Exception {
  const LiveFailure(this.message, {this.statusCode = 0, this.liveId});

  final String message;
  final int statusCode;

  /// Direct déjà en cours du diffuseur (409), à reprendre.
  final String? liveId;

  bool get isEnded => statusCode == 410;

  @override
  String toString() => message;
}

class LiveRepository {
  LiveRepository(this._api);
  final ApiService _api;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on LaravelApiException catch (e) {
      // `errors` contient { liveId } pour un 409 : ne pas l'afficher comme
      // une erreur de champ, garder le message du serveur.
      final liveId = e.errors?['liveId'];
      final fieldErrors = liveId == null ? e.allFieldErrors : '';
      throw LiveFailure(
        fieldErrors.isNotEmpty ? fieldErrors : e.message,
        statusCode: e.statusCode,
        liveId: liveId is String ? liveId : null,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      final serverMsg = body is Map ? body['message'] as String? : null;
      if (status == 503) {
        throw LiveFailure(
          serverMsg ?? 'Le service vidéo est momentanément indisponible.',
          statusCode: 503,
        );
      }
      if (status >= 500) {
        throw LiveFailure(serverMsg ?? 'Erreur du serveur ($status).',
            statusCode: status);
      }
      throw const LiveFailure(
          'Connexion impossible. Vérifiez votre accès à Internet.');
    }
  }

  static Map<String, dynamic> _asMap(Object? data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  // ── Lecture publique ────────────────────────────────────────────────────

  Future<LivesIndex> index() => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.lives);
        return LivesIndex.fromJson(_asMap(res.data));
      });

  Future<LiveSession> show(String id) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.liveById(id));
        return LiveSession.fromJson(_asMap(res.data));
      });

  Future<LiveStats> stats(String id) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.liveStats(id));
        return LiveStats.fromJson(_asMap(res.data));
      });

  /// Qui regarde : comptes connectés et nombre de visiteurs.
  Future<LiveViewers> viewers(String id) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.liveViewers(id));
        return LiveViewers.fromJson(_asMap(res.data));
      });

  Future<List<LiveComment>> comments(String id) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.liveComments(id));
        final data = res.data;
        return data is List
            ? data
                .whereType<Map>()
                .map((e) => LiveComment.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : <LiveComment>[];
      });

  Future<LiveCredentials> viewerToken(String id) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.liveViewerToken(id));
        return LiveCredentials.fromJson(_asMap(res.data));
      });

  // ── Diffusion (modérateurs / administrateurs) ─────────────────────────────

  /// Crée le direct : renvoie le direct et l'accès diffuseur.
  Future<(LiveSession, LiveCredentials)> start({
    required String title,
    String? description,
    String? categorySlug,
    bool commentsEnabled = true,
  }) =>
      _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.lives, data: {
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (categorySlug != null && categorySlug.isNotEmpty)
            'category_slug': categorySlug,
          'comments_enabled': commentsEnabled,
        });
        final data = _asMap(res.data);
        return (
          LiveSession.fromJson(_asMap(data['live'])),
          LiveCredentials.fromJson(_asMap(data['video'])),
        );
      });

  Future<LiveCredentials> hostToken(String id) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.liveHostToken(id));
        return LiveCredentials.fromJson(_asMap(res.data));
      });

  Future<LiveSession> goLive(String id) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.liveGoLive(id));
        return LiveSession.fromJson(_asMap(res.data));
      });

  Future<LiveSession> end(String id) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.liveEnd(id));
        return LiveSession.fromJson(_asMap(res.data));
      });

  // ── Interactions (connecté) ───────────────────────────────────────────────

  Future<LiveComment> postComment(String id, String body) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.liveComments(id),
            data: {'body': body});
        return LiveComment.fromJson(_asMap(res.data));
      });

  Future<LiveReactionCounts> react(String id, LiveReactionType type) =>
      _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.liveReactions(id),
            data: {'type': type.apiValue});
        return LiveReactionCounts.fromJson(_asMap(res.data)['reactions']);
      });

  // ── Modération ────────────────────────────────────────────────────────────

  Future<void> hideComment(String id, String commentId) =>
      _guard(() => _api.delete<dynamic>(AppConstants.liveComment(id, commentId)));

  /// Épingle un commentaire (remplace l'éventuel précédent).
  Future<LiveComment> pinComment(String id, String commentId) =>
      _guard(() async {
        final res = await _api.post<dynamic>(
            AppConstants.livePinComment(id, commentId));
        return LiveComment.fromJson(_asMap(res.data));
      });

  Future<void> unpinComment(String id) =>
      _guard(() => _api.delete<dynamic>(AppConstants.liveUnpin(id)));

  Future<void> ban(String id, String userId) => _guard(
      () => _api.post<dynamic>(AppConstants.liveBans(id), data: {'user_id': userId}));

  // ── Intervenants (un à la fois) ───────────────────────────────────────────
  // Chaque action renvoie l'état complet de la scène.

  Future<LiveStageState> stage(String id) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.liveStage(id));
        return LiveStageState.fromJson(_asMap(res.data));
      });

  Future<LiveStageState> requestStage(String id, {String? message}) =>
      _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.liveStageRequests(id),
            data: {if (message != null && message.trim().isNotEmpty) 'message': message.trim()});
        return LiveStageState.fromJson(_asMap(res.data));
      });

  /// Retirer sa demande, refuser l'invitation ou quitter l'antenne.
  Future<LiveStageState> withdrawStage(String id) => _guard(() async {
        final res = await _api.delete<dynamic>(AppConstants.liveStageMine(id));
        return LiveStageState.fromJson(_asMap(res.data));
      });

  /// Accepter l'invitation : [identity] = participant LiveKit de la connexion
  /// spectateur en cours (le serveur y ouvre micro et caméra).
  Future<LiveStageState> acceptStage(String id,
          {required String identity, required bool camera}) =>
      _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.liveStageAccept(id),
            data: {'identity': identity, 'camera': camera});
        return LiveStageState.fromJson(_asMap(res.data));
      });

  /// Diffuseur / modération : [action] ∈ invite, decline, remove.
  Future<LiveStageState> speakerAction(String id, String speakerId, String action) =>
      _guard(() async {
        final res = await _api.post<dynamic>(
            AppConstants.liveStageSpeaker(id, speakerId, action));
        return LiveStageState.fromJson(_asMap(res.data));
      });

  Future<LiveStageState> stageSettings(String id, {required bool enabled}) =>
      _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.liveStageSettings(id),
            data: {'enabled': enabled});
        return LiveStageState.fromJson(_asMap(res.data));
      });
}

final liveRepositoryProvider = Provider<LiveRepository>(
  (ref) => LiveRepository(ref.watch(apiServiceProvider)),
);

/// Liste des directs (en cours + récents). `ref.invalidate` pour rafraîchir.
final livesIndexProvider = FutureProvider.autoDispose<LivesIndex>(
  (ref) => ref.watch(liveRepositoryProvider).index(),
);
