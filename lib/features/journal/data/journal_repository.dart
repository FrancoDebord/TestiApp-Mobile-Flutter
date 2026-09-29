import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../models/journal_entry.dart';

/// Erreur lisible d'une action du carnet.
class JournalFailure implements Exception {
  const JournalFailure(this.message, {this.statusCode = 0});
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// Accès au carnet privé (`GET /journal`, partage, retour au carnet…).
class JournalRepository {
  JournalRepository(this._api);
  final ApiService _api;

  static const pageSize = 30;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on LaravelApiException catch (e) {
      throw JournalFailure(e.displayMessage, statusCode: e.statusCode);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      final msg = body is Map ? body['message'] as String? : null;
      if (status == 0) {
        throw const JournalFailure(
            'Connexion impossible. Vérifiez votre accès à Internet.');
      }
      throw JournalFailure(msg ?? 'Erreur du serveur ($status).',
          statusCode: status);
    }
  }

  static Map<String, dynamic> _asMap(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  /// Une page du carnet, la plus récente d'abord.
  Future<JournalPage> list({
    int page = 1,
    JournalEntryType? type,
    String? query,
  }) =>
      _guard(() async {
        // rawDio : la pagination est dans `meta`, que LaravelResponse ignore.
        final res = await _api.rawDio.get<dynamic>(
          AppConstants.journal,
          queryParameters: {
            'page': page,
            'limit': pageSize,
            if (type != null) 'type': type.apiValue,
            if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          },
        );
        final body = _asMap(res.data);
        final meta = _asMap(body['meta']);
        final data = body['data'];
        int n(Object? v, int fallback) =>
            v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
        return JournalPage(
          entries: data is List
              ? data
                  .whereType<Map>()
                  .map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : const [],
          currentPage: n(meta['currentPage'], page),
          lastPage: n(meta['lastPage'], page),
          total: n(meta['total'], 0),
        );
      });

  Future<JournalEntry> show(String id) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.testimonyById(id));
        return JournalEntry.fromJson(_asMap(res.data));
      });

  /// Partager : l'entrée devient publique et passe en modération.
  Future<JournalEntry> share(String id, {String? category}) => _guard(() async {
        final res = await _api.post<dynamic>(
          AppConstants.testimonyPublish(id),
          data: {'category': ?category},
        );
        return JournalEntry.fromJson(_asMap(res.data));
      });

  /// Retirer du public et ranger dans le carnet.
  Future<JournalEntry> moveToJournal(String id) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.testimonyMakePrivate(id));
        return JournalEntry.fromJson(_asMap(res.data));
      });

  Future<void> delete(String id) =>
      _guard(() => _api.delete<dynamic>(AppConstants.testimonyById(id)));
}

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => JournalRepository(ref.watch(apiServiceProvider)),
);

/// Compteur incrémenté à chaque changement du carnet (nouvelle entrée,
/// partage, suppression) : les écrans qui l'écoutent se rechargent.
class JournalRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final journalRefreshProvider =
    NotifierProvider<JournalRefresh, int>(JournalRefresh.new);
