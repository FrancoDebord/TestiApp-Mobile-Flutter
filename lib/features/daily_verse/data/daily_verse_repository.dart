// Verset du jour en plein écran : versions, commentaires, requêtes de prière
// et témoignages liés. Docs serveur : fonctionnalites/verset-du-jour.md

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/local_db/daos/bible_dao.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../bible/providers/bible_providers.dart' show bibleDaoProvider;
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart' show testimonyFromApiJson;
import '../../prayer/models/prayer_models.dart';
import '../models/daily_verse_models.dart';
import '../models/verse_reference.dart';

/// Erreur lisible ([offline] : pas de connexion).
class DailyVerseFailure implements Exception {
  const DailyVerseFailure(this.message, {this.statusCode = 0, this.offline = false});
  final String message;
  final int statusCode;
  final bool offline;

  @override
  String toString() => message;
}

class DailyVerseRepository {
  DailyVerseRepository(this._api, this._bible);
  final ApiService _api;
  final BibleDao? _bible;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on LaravelApiException catch (e) {
      final fields = e.allFieldErrors;
      throw DailyVerseFailure(fields.isNotEmpty ? fields : e.message, statusCode: e.statusCode);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status >= 500) throw DailyVerseFailure(L10n.current.verseServerError(status), statusCode: status);
      throw DailyVerseFailure(L10n.current.verseOfflineError, offline: true);
    }
  }

  static List<Map<String, dynamic>> _list(Object? v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  // ── Versions ──────────────────────────────────────────────────────────────

  /// Le passage dans chaque traduction installée sur le serveur ; hors
  /// connexion, dans les Bibles téléchargées sur l'appareil.
  Future<DailyVerseVersions> versions(DailyVerse verse) async {
    if (verse.id > 0) {
      try {
        final res = await _api.get<dynamic>(AppConstants.verseVersions(verse.id));
        final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
        return DailyVerseVersions.fromJson(data, fallbackText: verse.text);
      } on DioException catch (_) {
        // Hors connexion : Bibles téléchargées.
      } on LaravelApiException catch (_) {
        // Route absente (serveur ancien) : Bibles téléchargées.
      }
    }
    return offlineVersions(verse);
  }

  /// Versions lues dans les Bibles téléchargées (SQLite local).
  Future<DailyVerseVersions> offlineVersions(DailyVerse verse) async {
    final parsed = VerseReference.parse(verse.reference);
    final versions = <VerseVersion>[];
    final dao = _bible;
    if (parsed != null && dao != null) {
      try {
        final local = await dao.getLocalTranslations();
        for (final t in local.where((t) => t.isDownloaded)) {
          final verses = await dao.getVerses(t.code, parsed.book, parsed.chapter);
          final lines = verses
              .where((v) => parsed.contains(v.verseNumber))
              .map((v) => VerseLine(v.verseNumber, v.text.trim()))
              .toList()
            ..sort((a, b) => a.verse.compareTo(b.verse));
          // Nom du livre dans la langue de la Bible téléchargée (« John » en KJV).
          String? bookName;
          for (final b in await dao.getBooks(t.code)) {
            if (b.bookNumber == parsed.book) bookName = b.name;
          }
          versions.add(VerseVersion(
            code: t.code,
            name: t.name,
            language: t.language,
            bookName: bookName,
            reference: parsed.labelWith(bookName),
            lines: lines,
          ));
        }
      } catch (_) {/* base locale indisponible */}
    }
    return DailyVerseVersions(
      reference: verse.reference,
      originalText: verse.text,
      parsed: parsed,
      versions: versions,
      offline: true,
    );
  }

  // ── Réactions ─────────────────────────────────────────────────────────────

  Future<void> react(int verseId, String type, {required bool active}) => _guard(() async {
        await _api.post<dynamic>(AppConstants.verseReactTo(verseId), data: {'type': type, 'active': active});
      });

  // ── Commentaires ──────────────────────────────────────────────────────────

  Future<List<VerseComment>> comments(int verseId) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.verseComments(verseId), query: {'limit': 50});
        return _list(res.data).map(VerseComment.fromJson).toList();
      });

  /// [body] peut contenir des jetons de mention `@[Nom](user:id)`.
  Future<VerseComment> addComment(int verseId, String body) => _guard(() async {
        final res = await _api.post<dynamic>(AppConstants.verseComments(verseId), data: {'body': body.trim()});
        return VerseComment.fromJson(Map<String, dynamic>.from(res.data as Map));
      });

  Future<void> deleteComment(int verseId, String commentId) => _guard(() async {
        await _api.delete<dynamic>(AppConstants.verseComment(verseId, commentId));
      });

  Future<void> reportComment(int verseId, String commentId, String reason) => _guard(() async {
        await _api.post<dynamic>('${AppConstants.verseComment(verseId, commentId)}/report', data: {'reason': reason});
      });

  // ── Requêtes de prière et témoignages liés ────────────────────────────────

  Future<List<PrayerRequest>> prayerRequests(int verseId) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.versePrayerRequests(verseId), query: {'limit': 30});
        return _list(res.data).map(PrayerRequest.fromJson).toList();
      });

  Future<List<Testimony>> testimonies(int verseId) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.verseTestimonies(verseId));
        return _list(res.data).map(testimonyFromApiJson).whereType<Testimony>().toList();
      });
}

final dailyVerseRepositoryProvider = Provider<DailyVerseRepository>(
  (ref) => DailyVerseRepository(ref.watch(apiServiceProvider), ref.watch(bibleDaoProvider)),
);
