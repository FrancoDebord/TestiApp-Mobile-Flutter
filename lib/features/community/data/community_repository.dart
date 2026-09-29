import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart' show testimonyFromApiJson;
import '../models/community_account.dart';

/// Une page de la liste « Communauté ».
class CommunityPage {
  const CommunityPage(this.accounts, {required this.currentPage, required this.lastPage, this.total});
  final List<CommunityAccount> accounts;
  final int currentPage;
  final int lastPage;
  final int? total;
  bool get hasMore => currentPage < lastPage;
}

/// Résultat d'un abonnement / désabonnement.
class FollowResult {
  const FollowResult({required this.following, this.followerCount});
  final bool following;
  final int? followerCount;
}

/// Appels « Communauté » et « Suivre ». Backend : docs/fonctionnalites/abonnements.md
class CommunityRepository {
  CommunityRepository(this._api);
  final ApiService _api;

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  Future<CommunityPage> community(CommunityTab tab, {String? query, int page = 1}) =>
      _page(AppConstants.community, {'tab': tab.apiValue}, query, page);

  /// « Mes abonnements » : comptes suivis, les plus récents d'abord.
  Future<CommunityPage> following({String? query, int page = 1}) =>
      _page(AppConstants.myFollowing, const {}, query, page);

  Future<CommunityPage> _page(String path, Map<String, dynamic> params, String? query, int page) async {
    final res = await _api.get<dynamic>(path, query: {
      ...params,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      'page': page,
    });
    final data = res.data;
    final list = data is List
        ? data.whereType<Map>().map((e) => CommunityAccount.fromJson(Map<String, dynamic>.from(e))).toList()
        : <CommunityAccount>[];
    final meta = _map(res.meta);
    return CommunityPage(
      list,
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
      total: (meta['total'] as num?)?.toInt(),
    );
  }

  Future<CommunityAccount> account(String id) async {
    final res = await _api.get<dynamic>(AppConstants.userById(id));
    return CommunityAccount.fromJson(_map(res.data));
  }

  Future<List<Testimony>> testimoniesOf(String id) async {
    final res = await _api.get<dynamic>(AppConstants.userTestimonies(id));
    final data = res.data;
    return data is List ? data.map(testimonyFromApiJson).whereType<Testimony>().toList() : const [];
  }

  /// Comptes suivis par la personne connectée.
  Future<Set<String>> followingIds() async {
    final res = await _api.get<dynamic>(AppConstants.followingIds);
    final data = res.data;
    return data is List ? data.map((e) => '$e').toSet() : <String>{};
  }

  Future<FollowResult> follow(String id) async {
    final res = await _api.post<dynamic>(AppConstants.userFollow(id));
    final m = _map(res.data);
    return FollowResult(following: true, followerCount: (m['followerCount'] as num?)?.toInt());
  }

  Future<FollowResult> unfollow(String id) async {
    final res = await _api.delete<dynamic>(AppConstants.userUnfollow(id));
    final m = _map(res.data);
    return FollowResult(following: false, followerCount: (m['followerCount'] as num?)?.toInt());
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(apiServiceProvider)),
);
