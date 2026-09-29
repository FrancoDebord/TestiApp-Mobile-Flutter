import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/journal_entry.dart';
import 'journal_repository.dart';

/// Télécharge [url] dans [destination] (remplaçable dans les tests).
typedef JournalDownloader = Future<void> Function(String url, File destination);

/// Réglages de la copie hors ligne, propres à un compte sur ce téléphone.
class JournalOfflineSettings {
  const JournalOfflineSettings({
    this.enabled = false,
    this.asked = false,
    this.lastSyncAt,
  });

  factory JournalOfflineSettings.fromJson(Map<String, dynamic> m) =>
      JournalOfflineSettings(
        enabled: m['enabled'] == true,
        asked: m['asked'] == true,
        lastSyncAt: DateTime.tryParse('${m['lastSyncAt']}'),
      );

  /// L'utilisateur garde une copie de son carnet sur ce téléphone.
  final bool enabled;

  /// La question « garder une copie ? » a déjà été posée.
  final bool asked;
  final DateTime? lastSyncAt;

  JournalOfflineSettings copyWith({bool? enabled, bool? asked, DateTime? lastSyncAt}) =>
      JournalOfflineSettings(
        enabled: enabled ?? this.enabled,
        asked: asked ?? this.asked,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'asked': asked,
        'lastSyncAt': lastSyncAt?.toUtc().toIso8601String(),
      };
}

/// Résultat d'une synchronisation.
class JournalSyncResult {
  const JournalSyncResult({
    required this.entries,
    required this.mediaAvailable,
    required this.mediaFailed,
  });

  final int entries;

  /// Fichiers audio / vidéo présents sur le téléphone après la synchro.
  final int mediaAvailable;

  /// Fichiers qui n'ont pas pu être téléchargés (réessayés à la prochaine synchro).
  final int mediaFailed;
}

/// Copie hors ligne du carnet privé.
///
/// Le serveur reste la référence (récupération après perte du téléphone) ;
/// cette copie, facultative, permet de relire son carnet sans connexion.
/// Rangée dans l'espace privé de l'application (invisible de la galerie),
/// dans un dossier par compte : `journal/<userId>/`.
class JournalOfflineStore {
  JournalOfflineStore({
    Future<Directory> Function()? baseDir,
    JournalDownloader? downloader,
  })  : _baseDir = baseDir ?? getApplicationSupportDirectory,
        _download = downloader ?? _dioDownload;

  final Future<Directory> Function() _baseDir;
  final JournalDownloader _download;

  static Future<void> _dioDownload(String url, File destination) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5),
    ));
    await dio.download(url, destination.path);
  }

  Future<Directory> _userDir(String userId) async {
    // Identifiant nettoyé : jamais de « .. » ni de séparateur dans le chemin.
    final safe = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final dir = Directory(p.join((await _baseDir()).path, 'journal', safe));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String userId, String name) async =>
      File(p.join((await _userDir(userId)).path, name));

  Future<Directory> _mediaDir(String userId) async {
    final dir = Directory(p.join((await _userDir(userId)).path, 'media'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Réglages ────────────────────────────────────────────────────────────

  Future<JournalOfflineSettings> readSettings(String userId) async {
    try {
      final f = await _file(userId, 'settings.json');
      if (!await f.exists()) return const JournalOfflineSettings();
      return JournalOfflineSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(await f.readAsString()) as Map));
    } catch (_) {
      return const JournalOfflineSettings();
    }
  }

  Future<void> writeSettings(String userId, JournalOfflineSettings s) async {
    final f = await _file(userId, 'settings.json');
    await f.writeAsString(jsonEncode(s.toJson()), flush: true);
  }

  // ── Entrées ─────────────────────────────────────────────────────────────

  Future<List<JournalEntry>> readEntries(String userId) async {
    try {
      final f = await _file(userId, 'entries.json');
      if (!await f.exists()) return const [];
      final raw = jsonDecode(await f.readAsString());
      return raw is List
          ? raw
              .whereType<Map>()
              .map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [];
    } catch (_) {
      return const [];
    }
  }

  /// Écriture atomique : un fichier temporaire, puis renommage.
  Future<void> _writeEntries(String userId, List<JournalEntry> entries) async {
    final f = await _file(userId, 'entries.json');
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final e in entries) e.toJson()]), flush: true);
    await tmp.rename(f.path);
  }

  /// Entrées locales filtrées comme le serveur (type, recherche), récentes d'abord.
  Future<List<JournalEntry>> search(String userId, {JournalEntryType? type, String? query}) async {
    final q = (query ?? '').trim().toLowerCase();
    final all = await readEntries(userId);
    return all
        .where((e) => type == null || e.type == type)
        .where((e) =>
            q.isEmpty || e.title.toLowerCase().contains(q) || e.body.toLowerCase().contains(q))
        .toList();
  }

  // ── Médias ──────────────────────────────────────────────────────────────

  static String _mediaName(JournalEntry e) {
    final ext = p.extension(Uri.tryParse(e.mediaUrl ?? '')?.path ?? '').toLowerCase();
    final safeExt = RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext) ? ext : '';
    return '${e.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}$safeExt';
  }

  /// Fichier audio / vidéo de l'entrée sur le téléphone, s'il y est.
  Future<File?> localMedia(String userId, JournalEntry e) async {
    if (e.mediaUrl == null) return null;
    final f = File(p.join((await _mediaDir(userId)).path, _mediaName(e)));
    return await f.exists() && await f.length() > 0 ? f : null;
  }

  /// Place occupée sur le téléphone (octets).
  Future<int> sizeBytes(String userId) async {
    var total = 0;
    final dir = await _userDir(userId);
    await for (final f in dir.list(recursive: true)) {
      if (f is File) total += await f.length();
    }
    return total;
  }

  // ── Synchronisation ─────────────────────────────────────────────────────

  /// Recopie tout le carnet du serveur sur le téléphone : toutes les pages,
  /// puis les fichiers audio / vidéo manquants. Supprime du téléphone ce qui
  /// n'est plus dans le carnet (partagé ou supprimé). Un fichier en échec
  /// n'interrompt pas la synchro : il sera retenté la fois suivante.
  Future<JournalSyncResult> sync(
    String userId,
    JournalRepository repo, {
    void Function(int done, int total)? onProgress,
  }) async {
    final entries = <JournalEntry>[];
    var page = 1;
    while (true) {
      final res = await repo.list(page: page);
      entries.addAll(res.entries);
      if (!res.hasMore || res.entries.isEmpty) break;
      page++;
    }
    await _writeEntries(userId, entries);

    final mediaDir = await _mediaDir(userId);
    final withMedia = entries.where((e) => e.mediaUrl != null).toList();
    final keep = <String>{for (final e in withMedia) _mediaName(e)};

    // Nettoyage : fichiers d'entrées qui ne sont plus dans le carnet.
    await for (final f in mediaDir.list()) {
      if (f is File && !keep.contains(p.basename(f.path))) await f.delete();
    }

    var available = 0, failed = 0, done = 0;
    onProgress?.call(0, withMedia.length);
    for (final e in withMedia) {
      final target = File(p.join(mediaDir.path, _mediaName(e)));
      if (await target.exists() && await target.length() > 0) {
        available++;
      } else {
        final part = File('${target.path}.part');
        try {
          await _download(e.mediaUrl!, part);
          await part.rename(target.path);
          available++;
        } catch (_) {
          failed++;
          if (await part.exists()) await part.delete();
        }
      }
      onProgress?.call(++done, withMedia.length);
    }

    final settings = await readSettings(userId);
    await writeSettings(userId, settings.copyWith(lastSyncAt: DateTime.now()));

    return JournalSyncResult(
      entries: entries.length,
      mediaAvailable: available,
      mediaFailed: failed,
    );
  }

  /// Efface la copie du téléphone (le serveur n'est pas touché).
  /// Les réglages sont conservés, pour ne pas reposer la question.
  Future<void> clear(String userId) async {
    final dir = await _userDir(userId);
    final settings = await readSettings(userId);
    if (await dir.exists()) await dir.delete(recursive: true);
    await writeSettings(userId, settings.copyWith(enabled: false));
  }
}
