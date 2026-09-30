// Moteur de téléchargement (Riverpod) : file d'attente, progression,
// annulation, reprise, suppression, taille totale.
//
// L'index est chargé au premier accès à [downloadsProvider] ; il alimente
// ensuite [OfflineMedia.lookup] pour que les lecteurs lisent les fichiers
// locaux (media_quality.dart).

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_quality.dart';
import '../../../core/media/playback_preferences.dart';
import '../../home/models/testimony_model.dart';
import '../data/downloads_repository.dart';
import '../models/download_models.dart';

export '../models/download_models.dart';

/// Résultat d'un téléchargement.
enum DownloadOutcome { done, cancelled, failed, unsupported }

/// Stockage : repli configurable quand l'espace libre de l'appareil n'est pas
/// connu (pas de paquet dédié) — plafond de l'espace réservé aux
/// téléchargements de l'application.
const int kDefaultDownloadsCapBytes = 1024 * 1024 * 1024; // 1 Go

final downloadsStorageCapProvider =
    Provider<int>((ref) => kDefaultDownloadsCapBytes);

final downloadsRepositoryProvider =
    Provider<DownloadsRepository>((ref) => DownloadsRepository());

/// Nombre de téléchargements simultanés.
const int _maxParallel = 2;

class DownloadsNotifier extends Notifier<DownloadsState> {
  final Map<String, CancelToken> _tokens = {};
  final List<String> _queue = [];
  final Map<String, Testimony> _pending = {};
  // Témoignages d'origine des tâches (pour réessayer depuis la liste).
  final Map<String, Testimony> _originals = {};
  final Map<String, Completer<DownloadOutcome>> _waiters = {};
  final Map<String, String> _byUrl = {};
  int _running = 0;
  Future<void>? _loading;

  DownloadsRepository get _repo => ref.read(downloadsRepositoryProvider);

  @override
  DownloadsState build() {
    if (kIsWeb) {
      return const DownloadsState(loaded: true, supported: false);
    }
    OfflineMedia.lookup = _lookup;
    ref.onDispose(() {
      if (OfflineMedia.lookup == _lookup) OfflineMedia.lookup = null;
      for (final t in _tokens.values) {
        t.cancel();
      }
    });
    _loading = Future.microtask(_load);
    return const DownloadsState();
  }

  /// Attend la fin du chargement de l'index.
  Future<void> ensureLoaded() => _loading ?? Future.value();

  Future<void> _load() async {
    try {
      final list = await _repo.loadIndex();
      _setEntries({for (final e in list) e.id: e}, save: false);
    } catch (_) {
      // Pas d'accès aux fichiers : on reste vide.
    }
    state = state.copyWith(loaded: true);
  }

  // ── Lecture synchrone ─────────────────────────────────────────────────────

  String? _lookup({String? id, String? url}) {
    if (id != null) return localPathFor(id);
    if (url != null) {
      final owner = _byUrl[url];
      return owner == null ? null : localPathFor(owner);
    }
    return null;
  }

  /// Fichier média local d'un témoignage téléchargé (null pour un texte ou
  /// s'il n'est pas téléchargé).
  String? localPathFor(String id) {
    final e = state.entries[id];
    final path = e?.filePath;
    return (path == null || path.isEmpty) ? null : path;
  }

  DownloadItemState statusOf(String id) => state.itemState(id);

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Met [t] en file d'attente et attend la fin du téléchargement.
  Future<DownloadOutcome> download(Testimony t) async {
    if (!state.supported) return DownloadOutcome.unsupported;
    if (t is VideoTestimony && t.isYouTube) {
      _fail(t, 'Les vidéos YouTube ne peuvent pas être téléchargées.');
      return DownloadOutcome.unsupported;
    }
    await ensureLoaded();
    if (state.entries.containsKey(t.id)) return DownloadOutcome.done;
    final existing = _waiters[t.id];
    if (existing != null) return existing.future;

    final completer = Completer<DownloadOutcome>();
    _waiters[t.id] = completer;
    _pending[t.id] = t;
    _originals[t.id] = t;
    _queue.add(t.id);
    _setTask(DownloadTask(
      entry: DownloadEntry.fromTestimony(t),
      status: DownloadStatus.queued,
    ));
    _pump();
    return completer.future;
  }

  /// Relance un téléchargement en échec.
  Future<DownloadOutcome> retry(Testimony t) {
    _removeTask(t.id);
    return download(t);
  }

  /// Relance un téléchargement en échec à partir de son identifiant.
  Future<DownloadOutcome> retryId(String id) {
    final t = _originals[id];
    if (t == null) {
      _removeTask(id);
      return Future.value(DownloadOutcome.failed);
    }
    return retry(t);
  }

  /// Relance possible depuis la liste (témoignage d'origine connu).
  bool canRetry(String id) => _originals.containsKey(id);

  /// Annule un téléchargement en attente ou en cours.
  void cancel(String id) {
    if (_queue.remove(id)) {
      _pending.remove(id);
      _removeTask(id);
      _complete(id, DownloadOutcome.cancelled);
      return;
    }
    _tokens[id]?.cancel('Annulé');
    if (!_tokens.containsKey(id)) _removeTask(id); // échec affiché : on l'efface
  }

  /// Supprime un témoignage téléchargé (fichiers + index).
  Future<void> delete(String id) async {
    cancel(id);
    final e = state.entries[id];
    if (e == null) return;
    final next = Map.of(state.entries)..remove(id);
    _setEntries(next);
    await _repo.deleteFiles(e);
  }

  /// Supprime tous les téléchargements d'un type.
  Future<void> deleteType(TestimonyType type) async {
    final victims =
        state.entries.values.where((e) => e.type == type).toList();
    if (victims.isEmpty) return;
    final next = Map.of(state.entries)
      ..removeWhere((_, e) => e.type == type);
    _setEntries(next);
    for (final e in victims) {
      await _repo.deleteFiles(e);
    }
  }

  /// Supprime tout (et annule les téléchargements en cours).
  Future<void> deleteAll() async {
    for (final id in [..._queue, ..._tokens.keys]) {
      cancel(id);
    }
    _setEntries(const {}, save: false);
    state = state.copyWith(tasks: const {});
    await _repo.deleteAll();
  }

  int get totalBytes => state.totalBytes;

  // ── Moteur ────────────────────────────────────────────────────────────────

  void _pump() {
    while (_running < _maxParallel && _queue.isNotEmpty) {
      final id = _queue.removeAt(0);
      final t = _pending.remove(id);
      if (t == null) continue;
      _running++;
      unawaited(_run(t).whenComplete(() {
        _running--;
        _pump();
      }));
    }
  }

  Future<void> _run(Testimony t) async {
    final token = CancelToken();
    _tokens[t.id] = token;
    _setTask(DownloadTask(
      entry: DownloadEntry.fromTestimony(t),
      status: DownloadStatus.downloading,
      progress: t is TextTestimony ? null : 0,
    ));
    final cap = ref.read(downloadsStorageCapProvider);
    try {
      if (state.totalBytes >= cap) {
        throw const _DownloadError(
            'Espace de téléchargement plein. Supprimez des téléchargements.');
      }
      final entry = await _fetch(t, token);
      _removeTask(t.id);
      _setEntries({...state.entries, t.id: entry});
      _complete(t.id, DownloadOutcome.done);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _removeTask(t.id);
        _complete(t.id, DownloadOutcome.cancelled);
      } else {
        _fail(t, 'Téléchargement impossible. Vérifiez votre connexion.');
        _complete(t.id, DownloadOutcome.failed);
      }
    } on _DownloadError catch (e) {
      _fail(t, e.message);
      _complete(t.id, DownloadOutcome.failed);
    } catch (_) {
      _fail(t, 'Téléchargement impossible.');
      _complete(t.id, DownloadOutcome.failed);
    } finally {
      _tokens.remove(t.id);
    }
  }

  /// Télécharge le média (qualité selon préférences + réseau) et la vignette.
  Future<DownloadEntry> _fetch(Testimony t, CancelToken token) async {
    var entry = DownloadEntry.fromTestimony(t);
    var size = 0;

    // 1. Média
    String? label;
    if (t is TextTestimony) {
      label = 'Texte';
      size += utf8.encode(t.preview).length;
    } else {
      // Qualité : même règle que la lecture (Auto → 360p / 64 kbps sur
      // données mobiles). On ignore le mode hors ligne pour télécharger.
      final prefs =
          ref.read(playbackPreferencesProvider).copyWith(offlineMode: false);
      final metered = ref.read(isMeteredConnectionProvider).value ?? true;
      final resolved = switch (t) {
        VideoTestimony v => resolveVideo(
            original: v.mediaPath,
            renditions: v.renditions,
            prefs: prefs,
            metered: metered,
          ),
        AudioTestimony a => resolveAudio(
            original: a.mediaPath,
            renditions: a.renditions,
            prefs: prefs,
            metered: metered,
          ),
        TextTestimony() => null,
      };
      if (resolved == null || resolved.isLocal) {
        throw const _DownloadError('Aucun fichier à télécharger.');
      }
      label = resolved.label;
      final ext = DownloadsRepository.extensionFor(
          resolved.url, t is VideoTestimony ? 'mp4' : 'mp3');
      final target = await _repo.pathFor(t.id, ext);
      var lastPct = -1;
      size += await _repo.downloadFile(
        resolved.url,
        target,
        cancelToken: token,
        onProgress: (received, total) {
          if (total <= 0) return;
          final pct = (received * 100 ~/ total).clamp(0, 100);
          if (pct == lastPct) return;
          lastPct = pct;
          final task = state.tasks[t.id];
          if (task != null) _setTask(task.copyWith(progress: pct / 100));
        },
      );
      entry = entry.copyWith(filePath: target);
    }

    // 2. Vignette (facultative : un échec n'empêche pas la lecture)
    final thumbUrl = entry.thumbnailUrl;
    if (thumbUrl != null && thumbUrl.startsWith('http')) {
      try {
        final ext = DownloadsRepository.extensionFor(thumbUrl, 'jpg');
        final target = await _repo.pathFor(t.id, ext, suffix: '_thumb');
        size += await _repo.downloadFile(thumbUrl, target, cancelToken: token);
        entry = entry.copyWith(thumbnailPath: target);
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          await _repo.deleteFiles(entry);
          rethrow;
        }
      } catch (_) {}
    }

    return entry.copyWith(
      sizeBytes: size,
      qualityLabel: label,
      downloadedAt: DateTime.now(),
    );
  }

  // ── État ──────────────────────────────────────────────────────────────────

  void _fail(Testimony t, String message) {
    _setTask(DownloadTask(
      entry: DownloadEntry.fromTestimony(t),
      status: DownloadStatus.failed,
      error: message,
    ));
  }

  void _complete(String id, DownloadOutcome outcome) {
    if (outcome != DownloadOutcome.failed) _originals.remove(id);
    final c = _waiters.remove(id);
    if (c != null && !c.isCompleted) c.complete(outcome);
  }

  void _setTask(DownloadTask task) {
    state = state.copyWith(tasks: {...state.tasks, task.entry.id: task});
  }

  void _removeTask(String id) {
    if (!state.tasks.containsKey(id)) return;
    state = state.copyWith(tasks: Map.of(state.tasks)..remove(id));
  }

  void _setEntries(Map<String, DownloadEntry> entries, {bool save = true}) {
    _byUrl
      ..clear()
      ..addEntries([
        for (final e in entries.values)
          for (final u in e.sourceUrls) MapEntry(u, e.id),
      ]);
    state = state.copyWith(entries: Map.unmodifiable(entries));
    if (save) unawaited(_save());
  }

  Future<void> _save() async {
    try {
      await _repo.saveIndex(state.entries.values);
    } catch (_) {}
  }
}

class _DownloadError implements Exception {
  const _DownloadError(this.message);
  final String message;
}

final downloadsProvider =
    NotifierProvider<DownloadsNotifier, DownloadsState>(DownloadsNotifier.new);

/// État de téléchargement d'un témoignage (none / queued / downloading /
/// done / failed + progression).
final downloadItemProvider = Provider.family<DownloadItemState, String>(
  (ref, id) => ref.watch(downloadsProvider).itemState(id),
);

/// `false` quand l'appareil n'a aucune connexion réseau.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  bool online(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);
  final c = Connectivity();
  try {
    yield online(await c.checkConnectivity());
  } catch (_) {
    yield true;
  }
  yield* c.onConnectivityChanged.map(online);
});
