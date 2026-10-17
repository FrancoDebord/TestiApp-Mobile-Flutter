import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart' show testimonyFromApiJson;
import '../models/event_models.dart';
import '../../../l10n/app_localizations.dart';

/// Erreur lisible d'une action sur un événement.
/// Codes : 403 droits · 404 introuvable · 409 déjà fait · 422 validation · 429 trop rapide.
class EventFailure implements Exception {
  const EventFailure(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// Liste demandée à `GET /events`.
enum EventScope {
  upcoming('upcoming'),

  /// Commencés et pas encore terminés.
  ongoing('ongoing'),
  past('past'),
  going('going'),
  mine('mine'),

  /// À venir, organisés par les comptes suivis (« Mon fil »).
  following('following');

  const EventScope(this.apiValue);
  final String apiValue;
}

class EventsRepository {
  EventsRepository(this._api);
  final ApiService _api;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on LaravelApiException catch (e) {
      final fields = e.allFieldErrors;
      throw EventFailure(fields.isNotEmpty ? fields : e.message,
          statusCode: e.statusCode);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      if (body is Map) {
        final errors = body['errors'];
        final first = errors is Map && errors.isNotEmpty
            ? (errors.values.first is List
                ? (errors.values.first as List).firstOrNull?.toString()
                : errors.values.first?.toString())
            : null;
        final msg = first ?? body['message'] as String?;
        if (msg != null) throw EventFailure(msg, statusCode: status);
      }
      if (status >= 500) {
        throw EventFailure(L10n.current.eventsServerError(status), statusCode: status);
      }
      throw EventFailure(L10n.current.eventsConnectionError);
    }
  }

  static Map<String, dynamic> _asMap(Object? data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  static List<Map<String, dynamic>> _asList(Object? data) => data is List
      ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  static EventPage<T> _page<T>(LaravelResponse<dynamic> res, List<T> items) {
    final meta = _asMap(res.meta);
    int n(Object? v, int d) => v is num ? v.toInt() : d;
    return EventPage(
      items: items,
      page: n(meta['currentPage'], 1),
      lastPage: n(meta['lastPage'], 1),
      total: n(meta['total'], items.length),
      canCreate: meta['canCreate'] == true,
      organizations: _asList(meta['organizations']).map(EventPerson.fromJson).toList(),
    );
  }

  ChristianEvent _event(LaravelResponse<dynamic> res) =>
      ChristianEvent.fromJson(_asMap(res.data));

  // ── Lecture ──────────────────────────────────────────────────────────────

  Future<EventPage<ChristianEvent>> list({
    EventScope scope = EventScope.upcoming,
    EventType? type,
    String? query,
    int page = 1,
    String? organizerId,
    int? limit,
  }) =>
      _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.events, query: {
          'scope': scope.apiValue,
          if (type != null) 'type': type.apiValue,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          // Profil d'un organisateur : ses seuls événements.
          'organizer_id': ?organizerId,
          'limit': ?limit,
          'page': page,
        });
        return _page(res, _asList(res.data).map(ChristianEvent.fromJson).toList());
      });

  Future<ChristianEvent> show(String id) => _guard(() async {
        return _event(await _api.get<dynamic>(AppConstants.eventById(id)));
      });

  Future<EventPage<EventComment>> comments(String id, {int page = 1}) =>
      _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.eventComments(id),
            query: {'page': page});
        return _page(res, _asList(res.data).map(EventComment.fromJson).toList());
      });

  Future<EventPage<Testimony>> testimonies(String id, {int page = 1}) =>
      _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.eventTestimonies(id),
            query: {'page': page});
        final list = res.data is List ? res.data as List : const [];
        return _page(res, list.map(testimonyFromApiJson).whereType<Testimony>().toList());
      });

  Future<EventPage<EventAttendee>> participants(String id, {int page = 1}) =>
      _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.eventParticipants(id),
            query: {'page': page});
        return _page(res, _asList(res.data).map(EventAttendee.fromJson).toList());
      });

  // ── Gestion (organisation vérifiée / administrateur) ──────────────────────

  Future<ChristianEvent> create(EventDraft draft) => _guard(() async {
        return _event(await _api.post<dynamic>(AppConstants.events, data: draft.toJson()));
      });

  Future<ChristianEvent> update(String id, EventDraft draft) => _guard(() async {
        return _event(await _api.put<dynamic>(AppConstants.eventById(id), data: draft.toJson()));
      });

  Future<void> delete(String id) => _guard(() async {
        await _api.delete<dynamic>(AppConstants.eventById(id));
      });

  /// Ajoute une image au carrousel (fonctionne aussi sur le web : octets du fichier).
  Future<ChristianEvent> addImage(String id, XFile file) => _guard(() async {
        final bytes = await file.readAsBytes();
        final form = FormData.fromMap({
          'image': MultipartFile.fromBytes(bytes, filename: file.name),
        });
        final res = await _api.rawDio.post<Map<String, dynamic>>(
          AppConstants.eventImages(id),
          data: form,
          options: Options(
            contentType: 'multipart/form-data',
            receiveTimeout: const Duration(minutes: 2),
          ),
        );
        return _event(LaravelResponse<dynamic>.fromDio(res));
      });

  Future<ChristianEvent> removeImage(String id, String imageId) => _guard(() async {
        return _event(await _api.delete<dynamic>(AppConstants.eventImage(id, imageId)));
      });

  Future<ChristianEvent> makeCover(String id, String imageId) => _guard(() async {
        return _event(await _api.post<dynamic>(AppConstants.eventImageCover(id, imageId)));
      });

  // ── Participation ─────────────────────────────────────────────────────────

  Future<ChristianEvent> participate(String id, EventParticipation answer) =>
      _guard(() async {
        return _event(await _api.post<dynamic>(AppConstants.eventParticipation(id),
            data: {'status': answer.apiValue}));
      });

  Future<ChristianEvent> cancelParticipation(String id) => _guard(() async {
        return _event(await _api.delete<dynamic>(AppConstants.eventParticipation(id)));
      });

  // ── Commentaires et témoignages officiels ─────────────────────────────────

  Future<EventComment> addComment(String id, String body) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.eventComments(id),
            data: {'body': body.trim()});
        return EventComment.fromJson(_asMap(res.data));
      });

  Future<void> deleteComment(String id, String commentId) => _guard(() async {
        await _api.delete<dynamic>(AppConstants.eventComment(id, commentId));
      });

  /// Enregistre le commentaire comme témoignage officiel. Renvoie (id du témoignage, message).
  Future<(String, String)> promote(
    String id,
    String commentId, {
    String? title,
    String? category,
  }) =>
      _guard(() async {
        final res = await _api.post<dynamic>(
          AppConstants.eventCommentPromote(id, commentId),
          data: {
            if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
            if (category != null && category.isNotEmpty) 'category': category,
          },
        );
        return ('${_asMap(res.data)['id']}', res.message ?? L10n.current.eventsTestimonySaved);
      });
}

extension EventManagersApi on EventsRepository {
  // ── Co-gestionnaires d'un événement (2 au plus) ───────────────────────────

  Future<ChristianEvent> addManager(String id, String userId) => _guard(() async {
        return _event(await _api.post<dynamic>(AppConstants.eventManagers(id), data: {'user_id': userId}));
      });

  Future<ChristianEvent> removeManager(String id, String userId) => _guard(() async {
        return _event(await _api.delete<dynamic>(AppConstants.eventManager(id, userId)));
      });

  // ── Gestionnaires d'une organisation (2 au plus) ──────────────────────────

  Future<OrganizationManagers> organizationManagers() => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.myManagers);
        return OrganizationManagers.fromJson(EventsRepository._asMap(res.data));
      });

  Future<OrganizationManagers> addOrganizationManager(String userId) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.myManagers, data: {'user_id': userId});
        return OrganizationManagers.fromJson(EventsRepository._asMap(res.data));
      });

  Future<OrganizationManagers> removeOrganizationManager(String userId) => _guard(() async {
        final res = await _api.delete<dynamic>(AppConstants.myManager(userId));
        return OrganizationManagers.fromJson(EventsRepository._asMap(res.data));
      });

  /// Organisations dont la personne connectée est gestionnaire.
  Future<List<(EventPerson, bool)>> managedOrganizations() => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.myManagedOrganizations);
        return EventsRepository._asList(res.data)
            .map((m) => (EventPerson.fromJson(m), m['isVerified'] == true))
            .toList();
      });

  Future<void> leaveOrganization(String organizationId) => _guard(() async {
        await _api.delete<dynamic>(AppConstants.myManagedOrganization(organizationId));
      });
}

/// Report / annulation, signalement, sondage d'après l'événement, modération.
/// Doc serveur : docs/fonctionnalites/evenements.md
extension EventLifecycleApi on EventsRepository {
  /// Reporte : nouvelles dates, ou « date à confirmer » si [startsAt] est null.
  Future<ChristianEvent> postpone(String id, {DateTime? startsAt, DateTime? endsAt, String? reason}) =>
      _guard(() async {
        final tbd = startsAt == null;
        return _event(await _api.post<dynamic>(AppConstants.eventPostpone(id), data: {
          'date_tbd': tbd,
          if (!tbd) 'starts_at': startsAt.toUtc().toIso8601String(),
          if (!tbd) 'ends_at': (endsAt ?? startsAt).toUtc().toIso8601String(),
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        }));
      });

  Future<ChristianEvent> cancelEvent(String id, {String? reason}) => _guard(() async {
        return _event(await _api.post<dynamic>(AppConstants.eventCancel(id), data: {
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        }));
      });

  /// Signale l'événement (une fois par personne, 409 ensuite). Renvoie le message du serveur.
  Future<String> report(String id, EventReportReason reason, {String? comment}) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.eventReport(id), data: {
          'reason': reason.apiValue,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        });
        return res.message ?? L10n.current.eventsReportThanks;
      });

  /// Répond au sondage (modifiable 30 jours) ; renvoie l'événement à jour.
  Future<ChristianEvent> review(String id, EventAttendance attended, {int? rating, String? body}) =>
      _guard(() async {
        return _event(await _api.post<dynamic>(AppConstants.eventReview(id), data: {
          'attended': attended.apiValue,
          if (attended == EventAttendance.yes && rating != null) 'rating': rating,
          if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
        }));
      });

  Future<EventPage<EventReviewItem>> reviews(String id, {int page = 1}) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.eventReviews(id), query: {'page': page});
        return EventsRepository._page(
            res, EventsRepository._asList(res.data).map(EventReviewItem.fromJson).toList());
      });

  /// Modérateurs : `hide` (motif facultatif), `restore`, `dismiss`.
  Future<ChristianEvent> moderate(String id, String action, {String? reason}) => _guard(() async {
        return _event(await _api.post<dynamic>(AppConstants.eventModeration(id, action), data: {
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        }));
      });
}

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(apiServiceProvider)),
);
