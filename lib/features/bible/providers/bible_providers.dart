import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/local_db/daos/bible_dao.dart';
import '../../../core/local_db/daos/bible_highlight_dao.dart';
import '../../../core/local_db/database_service.dart';
import '../../../services/api_service.dart';
import '../models/bible_models.dart';

// ── DAO providers ──────────────────────────────────────────────────────────────

final bibleDaoProvider = Provider<BibleDao>((ref) {
  return BibleDao(ref.watch(databaseServiceProvider));
});

final bibleHighlightDaoProvider = Provider<BibleHighlightDao>((ref) {
  return BibleHighlightDao(ref.watch(databaseServiceProvider));
});

// ── Highlights (per chapter) ───────────────────────────────────────────────────

final bibleHighlightsProvider =
    FutureProvider.family.autoDispose<Map<int, String>, _VerseKey>(
  (ref, key) async {
    final dao = ref.watch(bibleHighlightDaoProvider);
    return dao.getChapterHighlights(
        key.translationCode, key.bookNumber, key.chapter);
  },
);

// ── Verse to pre-fill in the publish screen ────────────────────────────────────

class BibleVerseToInsertNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? verse) => state = verse;
  void clear() => state = null;
}

final bibleVerseToInsertProvider =
    NotifierProvider<BibleVerseToInsertNotifier, String?>(
  BibleVerseToInsertNotifier.new,
);

// ── Translations list notifier ─────────────────────────────────────────────────

class BibleTranslationsNotifier
    extends AsyncNotifier<List<BibleTranslation>> {
  @override
  Future<List<BibleTranslation>> build() async {
    final dao = ref.watch(bibleDaoProvider);
    final api = ref.watch(apiServiceProvider);

    // 1. Load locally stored translations (includes download status).
    final local = await dao.getLocalTranslations();
    final localMap = {for (final t in local) t.code: t};

    // 2. Fetch server list — merge download status from local.
    try {
      final response =
          await api.get<List<dynamic>>(AppConstants.bibleTranslations);
      final serverList = response.data.cast<Map<String, dynamic>>();

      final merged = serverList.map((json) {
        final localT = localMap[json['code'] as String];
        return BibleTranslation.fromServer(
          json,
          downloadStatus:
              localT?.downloadStatus ?? DownloadStatus.notDownloaded,
          downloadedAt: localT?.downloadedAt,
        );
      }).toList();

      // Persist server metadata for any new translation.
      for (final t in merged) {
        if (!localMap.containsKey(t.code)) {
          await dao.upsertTranslationMeta(t);
        }
      }

      return merged;
    } catch (_) {
      // Offline or server unreachable — show only locally known translations.
      return local;
    }
  }

  // ── Download ─────────────────────────────────────────────────────────────

  Future<void> download(String translationCode) async {
    // Mark as "downloading" immediately.
    _updateTranslation(
      translationCode,
      (t) => t.copyWith(
        downloadStatus: DownloadStatus.downloading,
        downloadProgress: 0.0,
        clearError: true,
      ),
    );

    final dao = ref.read(bibleDaoProvider);

    try {
      // Use a dedicated Dio instance so the shared client's 30 s receiveTimeout
      // doesn't truncate the large Bible JSON (5–15 MB) mid-stream.
      final token = await ref
          .read(secureStorageProvider)
          .read(key: AppConstants.keyAccessToken);

      final downloader = Dio(BaseOptions(
        baseUrl:        AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 15),
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      ));

      // ResponseType.json : Dio décode le JSON automatiquement (pas besoin
      // de utf8.decode / jsonDecode manuels). Le receiveTimeout de 15 min
      // couvre les fichiers volumineux (Bible complète ≈ 5–15 Mo).
      final response = await downloader.get<dynamic>(
        AppConstants.bibleDownload(translationCode),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _updateTranslation(
              translationCode,
              (t) => t.copyWith(downloadProgress: received / total),
            );
          }
        },
      );

      final raw = response.data;
      // Support des deux formes de réponse :
      //   { "success": true, "data": { "books": [...] } }
      //   { "books": [...] }
      final Map<String, dynamic> root = raw is Map<String, dynamic>
          ? raw
          : throw FormatException(
              'Réponse inattendue (type: ${raw.runtimeType})');
      final data = (root['data'] as Map<String, dynamic>?) ?? root;

      // Debug : affiche la structure reçue si `books` est absent
      // ignore: avoid_print
      if (data['books'] == null) print('[Bible] ⚠ clé "books" absente — data keys: ${data.keys}');

      // Insert all verses into SQLite.
      await dao.insertFullTranslation(translationCode, data);

      _updateTranslation(
        translationCode,
        (t) => t.copyWith(
          downloadStatus:  DownloadStatus.downloaded,
          downloadedAt:    DateTime.now(),
          clearProgress:   true,
          clearError:      true,
        ),
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[Bible] ✖ download error ($translationCode): $e\n$st');
      _updateTranslation(
        translationCode,
        (t) => t.copyWith(
          downloadStatus:  DownloadStatus.error,
          errorMessage:    _friendlyError(e),
          clearProgress:   true,
        ),
      );
    }
  }

  static String _friendlyError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 404) return 'Endpoint introuvable (404). Vérifiez la configuration du serveur.';
      if (status == 401) return 'Non autorisé (401). Reconnectez-vous et réessayez.';
      if (status != null) return 'Erreur serveur $status : ${e.message}';
      return 'Erreur réseau : ${e.message}';
    }
    if (e is FormatException) return 'Format de réponse invalide : ${e.message}';
    return e.toString();
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(String translationCode) async {
    await ref.read(bibleDaoProvider).deleteTranslation(translationCode);
    _updateTranslation(
      translationCode,
      (t) => t.copyWith(
        downloadStatus: DownloadStatus.notDownloaded,
        clearProgress:  true,
        clearError:     true,
      ),
    );
  }

  // ── Internal helper ────────────────────────────────────────────────────────

  void _updateTranslation(
    String code,
    BibleTranslation Function(BibleTranslation) updater,
  ) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.map((t) => t.code == code ? updater(t) : t).toList(),
    );
  }
}

final bibleTranslationsProvider =
    AsyncNotifierProvider<BibleTranslationsNotifier, List<BibleTranslation>>(
  BibleTranslationsNotifier.new,
);

// ── Book list provider (family per translation code) ──────────────────────────

final bibleBookListProvider =
    FutureProvider.family<List<BibleBook>, String>((ref, translationCode) async {
  final dao = ref.watch(bibleDaoProvider);
  return dao.getBooks(translationCode);
});

// ── Verse list provider (family: (translationCode, bookNumber, chapter)) ──────

typedef _VerseKey = ({String translationCode, int bookNumber, int chapter});

final bibleVerseListProvider =
    FutureProvider.family<List<BibleVerse>, _VerseKey>(
  (ref, key) async {
    final dao = ref.watch(bibleDaoProvider);
    return dao.getVerses(key.translationCode, key.bookNumber, key.chapter);
  },
);

// ── Chapter count (family: (translationCode, bookNumber)) ────────────────────

typedef _ChapterKey = ({String translationCode, int bookNumber});

final bibleChapterCountProvider =
    FutureProvider.family<int, _ChapterKey>((ref, key) async {
  final dao = ref.watch(bibleDaoProvider);
  return dao.getChapterCount(key.translationCode, key.bookNumber);
});

// ── Reader position (bookNumber + chapterNumber) per translation ──────────────
// Stored as a map so multiple translations can have independent positions.

class BibleReaderPositionNotifier
    extends Notifier<Map<String, (int, int)>> {
  @override
  Map<String, (int, int)> build() => const {};

  (int, int) positionFor(String translationCode) =>
      state[translationCode] ?? (1, 1);

  void setPosition(String translationCode, int bookNumber, int chapter) {
    state = {...state, translationCode: (bookNumber, chapter)};
  }
}

final bibleReaderPositionProvider =
    NotifierProvider<BibleReaderPositionNotifier, Map<String, (int, int)>>(
  BibleReaderPositionNotifier.new,
);
