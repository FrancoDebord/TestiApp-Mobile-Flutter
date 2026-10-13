// Administrateurs de compte : appels API.
// Chaque titulaire nomme 2 personnes au plus, qui agissent en son nom (en-tête
// X-Act-As, lib/services/acting_as_interceptor.dart).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../../../shared/models/user_model.dart';
import '../models/account_models.dart';

/// Échec lisible (message du serveur).
class AccountsFailure implements Exception {
  const AccountsFailure(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class AccountsRepository {
  AccountsRepository(this._api);
  final ApiService _api;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on LaravelApiException catch (e) {
      final fields = e.allFieldErrors;
      throw AccountsFailure(fields.isNotEmpty ? fields : e.message, statusCode: e.statusCode);
    } on DioException catch (e) {
      throw AccountsFailure(
        e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout
            ? 'Connexion impossible. Vérifiez votre réseau.'
            : 'Une erreur est survenue. Réessayez.',
        statusCode: e.response?.statusCode ?? 0,
      );
    }
  }

  /// Mon compte (en premier) et les comptes que j'administre.
  Future<AccountsSnapshot> accounts() => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.myAccounts);
        return AccountsSnapshot.fromJson(res.data);
      });

  /// Profil du compte actif (suit l'en-tête X-Act-As).
  Future<UserModel> me() => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.me);
        final data = res.data;
        if (data is! Map) throw const AccountsFailure('Réponse inattendue du serveur.');
        final map = Map<String, dynamic>.from(data);
        // Certaines réponses enveloppent le compte dans `user`.
        final user = map['user'] is Map ? Map<String, dynamic>.from(map['user'] as Map) : map;
        user['id'] = '${user['id']}';
        return UserModel.fromJson(user);
      });

  // ── Administrateurs de mon compte ─────────────────────────────────────────

  Future<AccountManagers> managers() => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.myManagers);
        return AccountManagers.fromJson(res.data);
      });

  Future<AccountManagers> addManager(String userId) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.myManagers, data: {'user_id': userId});
        final data = res.data;
        return data is Map && data['managers'] is List ? AccountManagers.fromJson(data) : managers();
      });

  Future<AccountManagers> removeManager(String userId) => _guard(() async {
        final res = await _api.delete<dynamic>(AppConstants.myManager(userId));
        final data = res.data;
        return data is Map && data['managers'] is List ? AccountManagers.fromJson(data) : managers();
      });

  /// Journal des actions faites en mon nom (50 dernières).
  Future<List<ManagerActivity>> activity() => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.myManagersActivity);
        final data = res.data;
        final list = data is List ? data : (data is Map && data['items'] is List ? data['items'] as List : const []);
        return list.whereType<Map>().map((m) => ManagerActivity.fromJson(Map<String, dynamic>.from(m))).toList();
      });

  // ── Comptes que j'administre ──────────────────────────────────────────────

  Future<List<AccountSummary>> managedAccounts() => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.myManagedOrganizations);
        final data = res.data;
        final list = data is List ? data : (data is Map && data['accounts'] is List ? data['accounts'] as List : const []);
        return list.whereType<Map>().map((m) => AccountSummary.fromJson(Map<String, dynamic>.from(m))).toList();
      });

  /// Ne plus administrer ce compte.
  Future<void> leave(String accountId) => _guard(() async {
        await _api.delete<dynamic>(AppConstants.myManagedOrganization(accountId));
      });
}

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(apiServiceProvider)),
);
