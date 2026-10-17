import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../models/prayer_models.dart';

/// Erreur lisible d'une action de prière.
/// Codes : 403 droits · 404 introuvable · 409 état (salle pas encore ouvrable…) · 422 données · 429 trop rapide.
class PrayerFailure implements Exception {
  const PrayerFailure(this.message, {this.statusCode = 0});
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// Liste demandée à `GET /prayer/requests`.
enum PrayerRequestScope {
  /// Tout ce que je peux voir (publiques, de mes abonnements, les miennes).
  all('all'),

  /// Publiques récentes (fil « Pour vous »).
  feed('feed'),

  /// Des comptes que je suis, sans les anonymes (« Mon fil »).
  following('following'),
  mine('mine'),

  /// D'un événement (avec `event_id`).
  event('event');

  const PrayerRequestScope(this.apiValue);
  final String apiValue;
}

/// Liste demandée à `GET /prayer/sessions`.
enum PrayerSessionScope {
  upcoming('upcoming'),
  joined('joined'),
  mine('mine'),
  past('past'),
  event('event');

  const PrayerSessionScope(this.apiValue);
  final String apiValue;
}

/// Requêtes et sessions de prière. Docs serveur : fonctionnalites/requetes-de-priere.md,
/// fonctionnalites/sessions-de-priere.md
class PrayerRepository {
  PrayerRepository(this._api);
  final ApiService _api;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on LaravelApiException catch (e) {
      final fields = e.allFieldErrors;
      throw PrayerFailure(fields.isNotEmpty ? fields : e.message, statusCode: e.statusCode);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      final msg = body is Map ? body['message'] as String? : null;
      if (msg != null && msg.isNotEmpty) throw PrayerFailure(msg, statusCode: status);
      if (status >= 500) throw PrayerFailure(L10n.current.prayerErrorServer(status), statusCode: status);
      throw PrayerFailure(L10n.current.prayerErrorConnection);
    }
  }

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<Map<String, dynamic>> _list(Object? v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  static PrayerPage<T> _page<T>(LaravelResponse<dynamic> res, List<T> items) {
    final meta = _map(res.meta);
    int n(Object? v, int d) => v is num ? v.toInt() : d;
    return PrayerPage(
      items: items,
      page: n(meta['currentPage'], 1),
      lastPage: n(meta['lastPage'], 1),
      total: n(meta['total'], items.length),
      canCreate: meta['canCreate'] == true,
    );
  }

  // ── Requêtes ─────────────────────────────────────────────────────────────

  Future<PrayerPage<PrayerRequest>> requests({
    PrayerRequestScope scope = PrayerRequestScope.all,
    String? eventId,
    bool answeredOnly = false,
    int page = 1,
    int limit = 20,
    // Les plus proches de la personne d'abord (fil « Pour vous » ; docs serveur : localisation.md).
    bool near = false,
  }) =>
      _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.prayerRequests, query: {
          'scope': scope.apiValue,
          'event_id': ?eventId,
          if (answeredOnly) 'status': 'answered',
          if (near) 'near': 1,
          'page': page,
          'limit': limit,
        });
        return _page(res, _list(res.data).map(PrayerRequest.fromJson).toList());
      });

  Future<PrayerRequest> request(String id) => _guard(() async {
        return PrayerRequest.fromJson(_map((await _api.get<dynamic>(AppConstants.prayerRequestById(id))).data));
      });

  Future<PrayerRequest> create(PrayerRequestDraft draft) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.prayerRequests, data: draft.toJson());
        return PrayerRequest.fromJson(_map(res.data));
      });

  Future<void> deleteRequest(String id) => _guard(() async {
        await _api.delete<dynamic>(AppConstants.prayerRequestById(id));
      });

  /// « Je prie » : fixe l'état ([prayed]) et renvoie la requête à jour.
  Future<PrayerRequest> pray(String id, {required bool prayed}) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.prayerRequestPray(id), data: {'prayed': prayed});
        return PrayerRequest.fromJson(_map(res.data));
      });

  Future<PrayerRequest> setAnswered(String id, bool answered, {String? note}) => _guard(() async {
        final res = answered
            ? await _api.post<dynamic>(AppConstants.prayerRequestAnswered(id),
                data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()})
            : await _api.delete<dynamic>(AppConstants.prayerRequestAnswered(id));
        return PrayerRequest.fromJson(_map(res.data));
      });

  Future<List<PrayerMessage>> messages(String id) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.prayerRequestMessages(id), query: {'limit': 100});
        return _list(res.data).map(PrayerMessage.fromJson).toList();
      });

  Future<PrayerMessage> addMessage(String id, String message, {String? bibleReference}) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.prayerRequestMessages(id), data: {
          'message': message.trim(),
          if (bibleReference != null && bibleReference.trim().isNotEmpty) 'bible_reference': bibleReference.trim(),
        });
        return PrayerMessage.fromJson(_map(res.data));
      });

  Future<void> deleteMessage(String id, String messageId) => _guard(() async {
        await _api.delete<dynamic>(AppConstants.prayerRequestMessage(id, messageId));
      });

  Future<void> report(String id, PrayerReportReason reason, {String? comment}) => _guard(() async {
        await _api.post<dynamic>(AppConstants.prayerRequestReport(id), data: {
          'reason': reason.apiValue,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        });
      });

  // ── Sessions ─────────────────────────────────────────────────────────────

  Future<PrayerPage<PrayerSession>> sessions({
    PrayerSessionScope scope = PrayerSessionScope.upcoming,
    String? eventId,
    int page = 1,
  }) =>
      _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.prayerSessions, query: {
          'scope': scope.apiValue,
          'event_id': ?eventId,
          'page': page,
        });
        return _page(res, _list(res.data).map(PrayerSession.fromJson).toList());
      });

  Future<PrayerSession> session(String id) => _guard(() async {
        return PrayerSession.fromJson(_map((await _api.get<dynamic>(AppConstants.prayerSessionById(id))).data));
      });

  Future<PrayerSession> saveSession(PrayerSessionDraft draft, {String? id}) => _guard(() async {
        final res = id == null
            ? await _api.post<dynamic>(AppConstants.prayerSessions, data: draft.toJson())
            : await _api.put<dynamic>(AppConstants.prayerSessionById(id), data: draft.toJson());
        return PrayerSession.fromJson(_map(res.data));
      });

  Future<void> deleteSession(String id) => _guard(() async {
        await _api.delete<dynamic>(AppConstants.prayerSessionById(id));
      });

  Future<PrayerSession> cancelSession(String id) => _guard(() async {
        return PrayerSession.fromJson(_map((await _api.post<dynamic>(AppConstants.prayerSessionCancel(id))).data));
      });

  /// « Je serai là » ([join] = true) ou retrait de l'inscription.
  Future<PrayerSession> setRegistered(String id, bool join) => _guard(() async {
        final res = join
            ? await _api.post<dynamic>(AppConstants.prayerSessionJoin(id))
            : await _api.delete<dynamic>(AppConstants.prayerSessionJoin(id));
        return PrayerSession.fromJson(_map(res.data));
      });

  /// L'hôte ouvre la salle (ou reprend celle déjà ouverte) : renvoie l'identifiant du direct.
  Future<String> startSession(String id) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.prayerSessionStart(id));
        final liveId = _map(_map(res.data)['live'])['id'];
        if (liveId == null) throw PrayerFailure(L10n.current.prayerErrorRoomNotOpened);
        return '$liveId';
      });
}

final prayerRepositoryProvider = Provider<PrayerRepository>(
  (ref) => PrayerRepository(ref.watch(apiServiceProvider)),
);
