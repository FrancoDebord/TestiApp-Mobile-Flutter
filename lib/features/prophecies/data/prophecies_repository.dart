import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../models/prophecy.dart';
import '../../../l10n/app_localizations.dart';

/// Erreur lisible d'une action sur une parole prophétique.
class ProphecyFailure implements Exception {
  const ProphecyFailure(this.message, {this.statusCode = 0});
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// Paroles prophétiques du carnet privé (visibles de leur seul auteur).
/// Doc serveur : docs/fonctionnalites/paroles-prophetiques.md
class PropheciesRepository {
  PropheciesRepository(this._api);
  final ApiService _api;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on LaravelApiException catch (e) {
      final fields = e.allFieldErrors;
      throw ProphecyFailure(fields.isNotEmpty ? fields : e.message, statusCode: e.statusCode);
    } on DioException catch (e) {
      final body = e.response?.data;
      final msg = body is Map ? body['message'] as String? : null;
      throw ProphecyFailure(msg ?? L10n.current.prophecyNetworkError,
          statusCode: e.response?.statusCode ?? 0);
    }
  }

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<Map<String, dynamic>> _list(Object? v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  Future<List<Prophecy>> list() => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.prophecies, query: {'limit': 200});
        return _list(res.data).map(Prophecy.fromJson).toList();
      });

  Future<Prophecy> show(String id) => _guard(() async {
        return Prophecy.fromJson(_map((await _api.get<dynamic>(AppConstants.prophecyById(id))).data));
      });

  /// Envoie l'audio enregistré (s'il y en a un), puis crée ou modifie la parole.
  Future<Prophecy> save(ProphecyDraft draft, {String? id}) => _guard(() async {
        if (draft.localAudioPath != null) {
          final res = await _api.upload<dynamic>(AppConstants.uploadMedia,
              filePath: draft.localAudioPath!, fieldName: 'file');
          draft
            ..audioUrl = _map(res.data)['url'] as String?
            ..localAudioPath = null;
        }
        final res = id == null
            ? await _api.post<dynamic>(AppConstants.prophecies, data: draft.toJson())
            : await _api.put<dynamic>(AppConstants.prophecyById(id), data: draft.toJson());
        return Prophecy.fromJson(_map(res.data));
      });

  Future<void> delete(String id) => _guard(() async {
        await _api.delete<dynamic>(AppConstants.prophecyById(id));
      });

  /// Marquer accomplie (sans témoignage) ou de nouveau en attente.
  Future<Prophecy> setFulfilled(String id, bool fulfilled) => _guard(() async {
        final res = await _api.put<dynamic>(AppConstants.prophecyById(id),
            data: {'status': fulfilled ? 'fulfilled' : 'waiting'});
        return Prophecy.fromJson(_map(res.data));
      });

  /// Rappel de prière seul (null : aucun).
  Future<Prophecy> setReminder(String id, ProphecyReminder? r) => _guard(() async {
        final res = await _api.put<dynamic>(AppConstants.prophecyById(id), data: {
          'reminder_frequency': r?.frequency.apiValue,
          'reminder_time': r?.time,
          'reminder_weekday': r?.frequency == ReminderFrequency.weekly ? r?.weekday : null,
        });
        return Prophecy.fromJson(_map(res.data));
      });

  Future<List<ProphecyPrayer>> prayers(String id) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.prophecyPrayers(id));
        return _list(res.data).map(ProphecyPrayer.fromJson).toList();
      });

  /// « J'ai prié » : renvoie la parole à jour (compteur).
  /// Début du temps de prière (5 minutes avant « J'ai prié »).
  Future<void> startPrayer(String id) => _guard(() async {
        await _api.post<dynamic>(AppConstants.prophecyPrayStart(id));
      });

  Future<Prophecy> pray(String id, {String? note}) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.prophecyPrayers(id),
            data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
        return Prophecy.fromJson(_map(_map(res.data)['prophecy']));
      });

  Future<Prophecy> deletePrayer(String id, int prayerId) => _guard(() async {
        final res = await _api.delete<dynamic>(AppConstants.prophecyPrayer(id, prayerId));
        return Prophecy.fromJson(_map(res.data));
      });
}

final propheciesRepositoryProvider = Provider<PropheciesRepository>(
  (ref) => PropheciesRepository(ref.watch(apiServiceProvider)),
);
