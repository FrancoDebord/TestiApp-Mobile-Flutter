// Listes de témoignages : toutes les routes de l'API.
// Docs serveur : fonctionnalites/listes-de-temoignages.md

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/network/network_failure.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../models/playlist_models.dart';

/// Erreur lisible : 403 (pas le propriétaire), 404, 422 (carnet privé, liste
/// pleine, titre vide) ; [offline] : pas de connexion.
class PlaylistFailure implements Exception, OfflineAwareFailure {
  const PlaylistFailure(this.message, {this.statusCode = 0, this.offline = false, this.fieldErrors = const {}});

  final String message;
  final int statusCode;
  @override
  final bool offline;

  /// Première erreur par champ (`title`, `testimonyIds`…).
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}

class PlaylistApi {
  PlaylistApi(this._api);
  final ApiService _api;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on LaravelApiException catch (e) {
      throw PlaylistFailure(
        e.message,
        statusCode: e.statusCode,
        fieldErrors: {
          for (final k in e.errors?.keys ?? const <String>[]) k: ?e.fieldError(k),
        },
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status >= 500) throw PlaylistFailure(L10n.current.apiServerError(status), statusCode: status);
      throw PlaylistFailure(L10n.current.commonErrorNetwork, offline: true);
    }
  }

  static Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const {};

  /// Mes listes (`items: null`).
  Future<List<Playlist>> mine() => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.myPlaylists);
        return Playlist.listFrom(res.data);
      });

  /// Listes d'un compte ayant au moins un témoignage visible.
  Future<List<Playlist>> ofUser(String userId) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.userPlaylists(userId));
        return Playlist.listFrom(res.data);
      });

  /// Liste et témoignages visibles, dans l'ordre.
  Future<Playlist> show(String id) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.playlistById(id));
        return Playlist.fromJson(_map(res.data));
      });

  Future<Playlist> create({required String title, String? description, List<String> testimonyIds = const []}) =>
      _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.playlists, data: {
          'title': title.trim(),
          if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
          if (testimonyIds.isNotEmpty) 'testimonyIds': testimonyIds,
        });
        return Playlist.fromJson(_map(res.data));
      });

  /// [testimonyIds] : nouvel ordre complet.
  Future<Playlist> update(String id, {String? title, String? description, List<String>? testimonyIds}) =>
      _guard(() async {
        final res = await _api.put<dynamic>(AppConstants.playlistById(id), data: {
          'title': ?title?.trim(),
          // Chaîne vide : description effacée.
          if (description != null) 'description': description.trim().isEmpty ? null : description.trim(),
          'testimonyIds': ?testimonyIds,
        });
        return Playlist.fromJson(_map(res.data));
      });

  Future<void> delete(String id) => _guard(() async {
        await _api.delete<dynamic>(AppConstants.playlistById(id));
      });

  /// Ajout à la fin (sans effet s'il y est déjà).
  Future<Playlist> add(String id, String testimonyId) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.playlistTestimonies(id), data: {'testimonyId': testimonyId});
        return Playlist.fromJson(_map(res.data));
      });

  Future<Playlist> remove(String id, String testimonyId) => _guard(() async {
        final res = await _api.delete<dynamic>(AppConstants.playlistTestimony(id, testimonyId));
        return Playlist.fromJson(_map(res.data));
      });

  /// Liste en cours de [testimonyId] (`?list=` si l'on vient d'une liste) ; null hors liste.
  Future<PlaylistContext?> contextOf(String testimonyId, {String? listId}) => _guard(() async {
        final res = await _api.get<dynamic>(
          AppConstants.testimonyById(testimonyId),
          query: {'list': ?listId},
        );
        return PlaylistContext.fromJson(_map(res.data)['playlist']);
      });
}

final playlistApiProvider = Provider<PlaylistApi>((ref) => PlaylistApi(ref.watch(apiServiceProvider)));
