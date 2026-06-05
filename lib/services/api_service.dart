// lib/services/api_service.dart
//
// HTTP client configured for a Laravel backend.
// Laravel response envelope:
//   { "success": true, "data": {...}, "message": "...", "errors": {...} }
// Authentication: Bearer JWT via Laravel Sanctum.
// Token refresh: POST /auth/refresh with refresh_token cookie/body.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/app_constants.dart';

// ── Secure storage singleton ───────────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

// ── Laravel response wrapper ───────────────────────────────────────────────────

/// Unwraps the standard Laravel API envelope.
/// Throws [LaravelApiException] when success == false.
class LaravelResponse<T> {
  const LaravelResponse({
    required this.success,
    required this.data,
    this.message,
  });

  final bool success;
  final T data;
  final String? message;

  factory LaravelResponse.fromDio(Response response) {
    final body = response.data as Map<String, dynamic>? ?? {};
    final success = body['success'] as bool? ?? true;
    final message = body['message'] as String?;

    if (!success) {
      final errors = body['errors'];
      throw LaravelApiException(
        message: message ?? 'Une erreur est survenue.',
        errors: errors is Map<String, dynamic> ? errors : null,
        statusCode: response.statusCode ?? 0,
      );
    }

    return LaravelResponse(
      success: success,
      data: body['data'] as T,
      message: message,
    );
  }
}

class LaravelApiException implements Exception {
  const LaravelApiException({
    required this.message,
    this.errors,
    this.statusCode = 0,
  });

  final String message;
  final Map<String, dynamic>? errors;
  final int statusCode;

  /// First validation error for a given field.
  String? fieldError(String field) {
    final raw = errors?[field];
    if (raw is List && raw.isNotEmpty) return raw.first as String?;
    if (raw is String) return raw;
    return null;
  }

  @override
  String toString() => 'LaravelApiException($statusCode): $message';
}

// ── Auth interceptor ───────────────────────────────────────────────────────────

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: AppConstants.keyAccessToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    options.headers['X-Requested-With'] = 'XMLHttpRequest';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      try {
        final refreshToken =
            await _storage.read(key: AppConstants.keyRefreshToken);
        if (refreshToken == null) {
          handler.next(err);
          return;
        }

        final refreshDio = Dio(BaseOptions(
          baseUrl: AppConstants.baseUrl,
          headers: {'Accept': 'application/json'},
        ));

        final response = await refreshDio.post(
          AppConstants.authRefresh,
          data: {'refresh_token': refreshToken},
        );

        final body = response.data as Map<String, dynamic>? ?? {};
        final data = body['data'] as Map<String, dynamic>? ?? body;
        final newAccess  = data['access_token']  as String?;
        final newRefresh = data['refresh_token'] as String?;

        if (newAccess != null) {
          await _storage.write(
              key: AppConstants.keyAccessToken, value: newAccess);
        }
        if (newRefresh != null) {
          await _storage.write(
              key: AppConstants.keyRefreshToken, value: newRefresh);
        }

        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retried = await Dio().fetch(err.requestOptions);
        handler.resolve(retried);
        return;
      } catch (_) {}
    }
    handler.next(err);
  }
}

// ── Retry interceptor ──────────────────────────────────────────────────────────

class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio);
  final Dio _dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final code = err.response?.statusCode ?? 0;
    final attempt = err.requestOptions.extra['_retry'] as int? ?? 0;

    final shouldRetry = attempt < AppConstants.maxRetries &&
        (err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            (code >= 500 && code < 600));

    if (shouldRetry) {
      err.requestOptions.extra['_retry'] = attempt + 1;
      await Future<void>.delayed(Duration(milliseconds: 500 * (1 << attempt)));
      try {
        final res = await _dio.fetch(err.requestOptions);
        handler.resolve(res);
        return;
      } on DioException catch (e) {
        handler.next(e);
        return;
      }
    }
    handler.next(err);
  }
}

// ── Logging interceptor ────────────────────────────────────────────────────────

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API] ▶ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API] ◀ ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API] ✖ ${err.response?.statusCode ?? err.type} '
        '${err.requestOptions.uri} — ${err.message}');
    handler.next(err);
  }
}

// ── ApiService ─────────────────────────────────────────────────────────────────

class ApiService {
  ApiService._({required FlutterSecureStorage storage}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout:
            const Duration(milliseconds: AppConstants.connectTimeoutMs),
        receiveTimeout:
            const Duration(milliseconds: AppConstants.receiveTimeoutMs),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    )
      ..interceptors.add(AuthInterceptor(storage))
      ..interceptors.add(LoggingInterceptor());

    _dio.interceptors.add(RetryInterceptor(_dio));
  }

  late final Dio _dio;

  // ── Generic helpers ────────────────────────────────────────────────────────

  Future<LaravelResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
        path, queryParameters: query);
    return LaravelResponse.fromDio(res);
  }

  Future<LaravelResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
        path, data: data, queryParameters: query);
    return LaravelResponse.fromDio(res);
  }

  Future<LaravelResponse<T>> put<T>(
    String path, {
    dynamic data,
  }) async {
    final res = await _dio.put<Map<String, dynamic>>(path, data: data);
    return LaravelResponse.fromDio(res);
  }

  Future<LaravelResponse<T>> delete<T>(
    String path, {
    dynamic data,
  }) async {
    final res = await _dio.delete<Map<String, dynamic>>(path, data: data);
    return LaravelResponse.fromDio(res);
  }

  /// Multipart file upload.
  Future<LaravelResponse<T>> upload<T>(
    String path, {
    required String filePath,
    String fieldName = 'file',
    Map<String, dynamic> extraFields = const {},
    ProgressCallback? onProgress,
  }) async {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath, filename: fileName),
      ...extraFields,
    });
    final res = await _dio.post<Map<String, dynamic>>(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onProgress,
    );
    return LaravelResponse.fromDio(res);
  }

  Dio get rawDio => _dio;
}

// ── Provider ───────────────────────────────────────────────────────────────────

final apiServiceProvider = Provider<ApiService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiService._(storage: storage);
});
