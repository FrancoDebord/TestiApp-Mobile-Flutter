// lib/features/profile/providers/account_verification_provider.dart
//
// Vérification d'un compte personnel : état (GET) et envoi de la demande
// (POST multipart). Voir lib/features/profile/models/account_verification.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../models/account_verification.dart';

class AccountVerificationRepository {
  AccountVerificationRepository(this._api);
  final ApiService _api;

  Future<AccountVerificationState> fetch() async {
    final res = await _api.get<dynamic>(AppConstants.myVerification);
    return AccountVerificationState.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<AccountVerificationState> submit({
    required String fullName,
    required String role,
    String? roleOther,
    required String church,
    List<String> links = const [],
    String? message,
    required List<VerificationDocument> documents,
  }) async {
    final form = FormData();
    form.fields
      ..add(MapEntry('full_name', fullName.trim()))
      ..add(MapEntry('role', role))
      ..add(MapEntry('church', church.trim()));
    if (role == 'other' && (roleOther?.trim().isNotEmpty ?? false)) {
      form.fields.add(MapEntry('role_other', roleOther!.trim()));
    }
    for (final l in links.map((l) => l.trim()).where((l) => l.isNotEmpty)) {
      form.fields.add(MapEntry('links[]', l));
    }
    if (message != null && message.trim().isNotEmpty) {
      form.fields.add(MapEntry('message', message.trim()));
    }
    for (final d in documents) {
      form.files.add(MapEntry(
        'documents[]',
        d.bytes != null
            ? MultipartFile.fromBytes(d.bytes!, filename: d.name)
            : await MultipartFile.fromFile(d.path!, filename: d.name),
      ));
    }

    try {
      final res = await _api.rawDio.post<Map<String, dynamic>>(
        AppConstants.myVerification,
        data: form,
        options: Options(contentType: 'multipart/form-data', receiveTimeout: const Duration(minutes: 3)),
      );
      final body = LaravelResponse<dynamic>.fromDio(res);
      return AccountVerificationState.fromJson(Map<String, dynamic>.from(body.data as Map));
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final raw = e.response?.data;
      if (status >= 400 && status < 500 && raw is Map) {
        final errors = raw['errors'];
        throw LaravelApiException(
          message: raw['message'] as String? ?? L10n.current.profileErrorStatus(status),
          errors: errors is Map<String, dynamic> ? errors : null,
          statusCode: status,
        );
      }
      rethrow;
    }
  }
}

final accountVerificationRepositoryProvider = Provider<AccountVerificationRepository>(
  (ref) => AccountVerificationRepository(ref.watch(apiServiceProvider)),
);

/// État de la vérification de mon compte (rechargé après l'envoi).
final accountVerificationProvider = FutureProvider.autoDispose<AccountVerificationState>(
  (ref) => ref.watch(accountVerificationRepositoryProvider).fetch(),
);
