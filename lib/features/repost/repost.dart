// Partage interne d'un témoignage sur TestiApp (« X a partagé »), comme un transfert :
// l'auteur d'origine reste toujours affiché, le contenu n'est jamais recopié.
// API : POST /testimonies/{id}/repost { comment? } · DELETE /testimonies/{id}/repost ;
// dans Mon fil, feedReason = repost (+ repostedBy, repostComment, repostedAt).
// Doc serveur : fonctionnalites/partage-interne.md

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';

/// Informations d'un partage dans un fil (élément de GET /feed ou GET /users/{id}/reposts).
class RepostInfo {
  const RepostInfo({
    required this.byId,
    required this.byName,
    this.id,
    this.byAvatarUrl,
    this.comment,
    this.at,
  });

  final String? id;
  final String byId;
  final String byName;
  final String? byAvatarUrl;
  final String? comment;
  final DateTime? at;

  /// Null si l'élément n'est pas un partage : `feedReason = repost` (Mon fil) ou
  /// `repostedBy` présent (tous les fils et listes de témoignages).
  static RepostInfo? fromFeedItem(Object? raw) {
    if (raw is! Map || (raw['feedReason'] != 'repost' && raw['repostedBy'] is! Map)) return null;
    final by = raw['repostedBy'] is Map ? Map<String, dynamic>.from(raw['repostedBy'] as Map) : const <String, dynamic>{};
    final comment = raw['repostComment'];
    return RepostInfo(
      id: raw['repostId']?.toString(),
      byId: by['id']?.toString() ?? '',
      byName: (by['displayName'] ?? by['display_name'])?.toString() ?? L10n.current.repostSomeone,
      byAvatarUrl: (by['avatarUrl'] ?? by['avatar_url'])?.toString(),
      comment: comment is String && comment.trim().isNotEmpty ? comment.trim() : null,
      at: raw['repostedAt'] is String ? DateTime.tryParse(raw['repostedAt'] as String) : null,
    );
  }
}

/// « X a partagé » d'un événement, d'une requête ou d'une session de prière
/// (champ `repost` : { id, comment, createdAt, user { id, displayName, avatarUrl } }).
RepostInfo? repostInfoFromContent(Object? raw) {
  if (raw is! Map || raw['user'] is! Map) return null;
  final by = Map<String, dynamic>.from(raw['user'] as Map);
  final comment = raw['comment'];
  return RepostInfo(
    id: raw['id']?.toString(),
    byId: by['id']?.toString() ?? '',
    byName: (by['displayName'] ?? by['display_name'])?.toString() ?? L10n.current.repostSomeone,
    byAvatarUrl: (by['avatarUrl'] ?? by['avatar_url'])?.toString(),
    comment: comment is String && comment.trim().isNotEmpty ? comment.trim() : null,
    at: raw['createdAt'] is String ? DateTime.tryParse(raw['createdAt'] as String) : null,
  );
}

/// Résultat d'un partage : message à afficher et nombre de partages du témoignage.
class RepostResult {
  const RepostResult({required this.message, required this.reposted, this.count});
  final String message;
  final bool reposted;
  final int? count;
}

class RepostRepository {
  const RepostRepository(this._api);
  final ApiService _api;

  static int? _count(Object? data) => data is Map && data['repostsCount'] is num ? (data['repostsCount'] as num).toInt() : null;

  /// Partager (ou modifier le commentaire d'un partage existant).
  Future<RepostResult> repost(String testimonyId, {String? comment}) async {
    final c = comment?.trim();
    final res = await _api.post<dynamic>(
      AppConstants.testimonyRepost(testimonyId),
      data: {if (c != null && c.isNotEmpty) 'comment': c},
    );
    return RepostResult(
      message: (res.message ?? '').isNotEmpty ? res.message! : L10n.current.repostTestimonyShared,
      reposted: true,
      count: _count(res.data),
    );
  }

  /// Annuler son partage.
  Future<RepostResult> remove(String testimonyId) async {
    final res = await _api.delete<dynamic>(AppConstants.testimonyRepost(testimonyId));
    return RepostResult(
      message: (res.message ?? '').isNotEmpty ? res.message! : L10n.current.repostCancelled,
      reposted: false,
      count: _count(res.data),
    );
  }
}

final repostRepositoryProvider = Provider<RepostRepository>((ref) => RepostRepository(ref.watch(apiServiceProvider)));

/// Partages faits pendant la session (témoignage → partagé ?) : met à jour la feuille
/// « Partager sur TestiApp » sans recharger le témoignage.
class RepostedByMe extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => const {};

  void set(String testimonyId, bool reposted) => state = {...state, testimonyId: reposted};
}

final repostedByMeProvider = NotifierProvider<RepostedByMe, Map<String, bool>>(RepostedByMe.new);
