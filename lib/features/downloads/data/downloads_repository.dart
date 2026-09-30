// Stockage des téléchargements sur l'appareil.
//
//   <documents>/downloads/<id>.<ext>          fichier média (audio / vidéo)
//   <documents>/downloads/<id>_thumb.<ext>    vignette
//   <documents>/downloads/index.json          métadonnées (DownloadEntry)
//
// Le dossier de base est injectable (tests : dossier temporaire).

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../home/models/testimony_model.dart';
import '../models/download_models.dart';

typedef BaseDirResolver = Future<Directory> Function();

Future<Directory> _defaultBaseDir() => getApplicationDocumentsDirectory();

class DownloadsRepository {
  DownloadsRepository({BaseDirResolver? baseDir, Dio? dio})
      : _baseDirResolver = baseDir ?? _defaultBaseDir,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 5),
            ));

  final BaseDirResolver _baseDirResolver;
  final Dio _dio;
  Directory? _dir;

  static const indexFileName = 'index.json';

  /// Dossier `downloads/` (créé si besoin).
  Future<Directory> downloadsDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await _baseDirResolver();
    final dir = Directory(p.join(base.path, 'downloads'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  // ── Index ─────────────────────────────────────────────────────────────────

  /// Entrées dont le fichier média existe encore (les autres sont ignorées).
  Future<List<DownloadEntry>> loadIndex() async {
    final dir = await downloadsDir();
    final file = File(p.join(dir.path, indexFileName));
    if (!await file.exists()) return const [];
    try {
      final raw = jsonDecode(await file.readAsString());
      final list = raw is Map ? raw['items'] : raw;
      if (list is! List) return const [];
      final out = <DownloadEntry>[];
      for (final item in list) {
        final e = DownloadEntry.fromJson(item);
        if (e == null) continue;
        if (e.type != TestimonyType.text &&
            (e.filePath == null || !File(e.filePath!).existsSync())) {
          continue; // fichier supprimé hors de l'application
        }
        out.add(e);
      }
      return out;
    } catch (_) {
      return const []; // index corrompu : on repart d'une liste vide
    }
  }

  /// Écriture atomique (fichier temporaire puis renommage).
  Future<void> saveIndex(Iterable<DownloadEntry> entries) async {
    final dir = await downloadsDir();
    final file = File(p.join(dir.path, indexFileName));
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'version': 1,
      'items': [for (final e in entries) e.toJson()],
    }));
    await tmp.rename(file.path);
  }

  // ── Fichiers ──────────────────────────────────────────────────────────────

  /// Extension déduite de l'adresse, sinon [fallback].
  static String extensionFor(String url, String fallback) {
    final path = Uri.tryParse(url)?.path ?? url;
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (ext.isEmpty || ext.length > 5 || !RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
      return fallback;
    }
    return ext;
  }

  /// Chemin cible `<downloads>/<nom>.<ext>` (identifiant assaini).
  Future<String> pathFor(String id, String ext, {String suffix = ''}) async {
    final dir = await downloadsDir();
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return p.join(dir.path, '$safe$suffix.$ext');
  }

  /// Télécharge [url] vers [target] (via un fichier `.part`). Renvoie la
  /// taille en octets. Lève [DioException] (type cancel) si annulé.
  Future<int> downloadFile(
    String url,
    String target, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final part = '$target.part';
    try {
      await _dio.download(
        url,
        part,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        deleteOnError: true,
      );
      final f = File(part);
      final out = await f.rename(target);
      return await out.length();
    } catch (_) {
      await _deleteQuietly(part);
      rethrow;
    }
  }

  /// Supprime les fichiers d'une entrée (média + vignette).
  Future<void> deleteFiles(DownloadEntry e) async {
    await _deleteQuietly(e.filePath);
    await _deleteQuietly(e.thumbnailPath);
  }

  /// Supprime tous les fichiers téléchargés (et l'index).
  Future<void> deleteAll() async {
    final dir = await downloadsDir();
    if (await dir.exists()) {
      await for (final f in dir.list()) {
        try {
          await f.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Taille réelle du dossier (contrôle).
  Future<int> diskUsage() async {
    final dir = await downloadsDir();
    var total = 0;
    await for (final f in dir.list(recursive: true)) {
      if (f is File) total += await f.length();
    }
    return total;
  }

  static Future<void> _deleteQuietly(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
