// lib/features/publish/upload/video_upload_controller.dart
//
// Publication d'un témoignage vidéo sur Bunny Stream (une tâche à la fois).
//
//   1. compression : video_compress, qualité moyenne (720p au plus) ;
//   2. POST /videos/upload-init : crée le témoignage (video_status = uploading,
//      invisible publiquement) et la vidéo Bunny ; les preuves sont envoyées
//      juste après ;
//   3. envoi reprenable TUS 1.0 (paquet tusc) vers tus_endpoint, en-têtes
//      AuthorizationSignature / AuthorizationExpire / VideoId / LibraryId,
//      métadonnées filetype et title. La signature est renouvelée
//      (POST /videos/{id}/upload-signature) avant chaque démarrage ou reprise
//      si elle expire dans moins de 5 minutes, ou si Bunny la refuse ;
//   4. POST /videos/{id}/upload-complete : Bunny encode, push « video_ready »
//      (ou « video_failed »). Le témoignage renvoyé est aussitôt affiché
//      « en traitement » (fil, détail, « Mes témoignages ») : inutile
//      d'attendre l'encodage, l'utilisateur peut quitter l'écran.
//
// Reprise automatique : nouvelles tentatives de tusc, puis attente du réseau
// (connectivity_plus), du retour au premier plan (AppLifecycleListener) ou d'un
// court délai. La tâche est enregistrée sur l'appareil à chaque étape franchie,
// et l'URL d'envoi TUS dans TusPersistentCache : un envoi interrompu par la
// fermeture de l'application reprend à la connexion suivante, au même octet.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';
import 'package:tusc/tusc.dart';
import 'package:video_compress/video_compress.dart' as vc;

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../../home/providers/home_providers.dart'
    show feedNotifierProvider, testimonyFromApiJson;
import '../../profile/providers/profile_provider.dart'
    show myTestimoniesNotifierProvider;
import '../../testimony/providers/testimony_refresh.dart'
    show testimonyReloaderProvider;
import 'video_upload_models.dart';

/// Client TUS dont l'empreinte (clé du cache persistant) est la vidéo Bunny :
/// stable d'un lancement à l'autre, quel que soit le nom du fichier.
class _BunnyTusClient extends TusClient {
  _BunnyTusClient({
    required this.bunnyVideoId,
    required super.file,
    required super.url,
    super.headers,
    super.metadata,
    super.cache,
    super.chunkSize,
    super.timeout,
    super.retryDelays,
  });

  final String bunnyVideoId;

  @override
  String generateFingerprint() => 'bunny-$bunnyVideoId';
}

/// Erreur affichable telle quelle.
class _UploadFailure implements Exception {
  const _UploadFailure(this.message);
  final String message;
}

/// Coupure réseau (ou serveur momentanément indisponible) : reprise automatique.
class _NetworkInterruption implements Exception {
  const _NetworkInterruption();
}

/// Annulation demandée par l'utilisateur.
class _Cancelled implements Exception {
  const _Cancelled();
}

class VideoUploadController extends Notifier<VideoUploadState?> {
  /// Reprises automatiques après une coupure, avant d'afficher « Réessayer ».
  static const _maxAutoRetries = 20;
  static const _retryDelay = Duration(seconds: 15);

  VideoUploadJob? _job;
  _BunnyTusClient? _tus;
  TusPersistentCache? _tusCache;
  bool _running = false;
  bool _cancelled = false;
  int _autoRetries = 0;
  Timer? _retryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  AppLifecycleListener? _lifecycle;
  vc.Subscription? _compressProgress;

  @override
  VideoUploadState? build() {
    if (!kIsWeb) {
      _connectivity = Connectivity().onConnectivityChanged.listen((r) {
        if (!r.contains(ConnectivityResult.none)) _resumeIfWaiting();
      });
      // Retour au premier plan : l'envoi coupé en arrière-plan reprend aussitôt.
      _lifecycle = AppLifecycleListener(onResume: _resumeIfWaiting);
    }
    ref.onDispose(() {
      _retryTimer?.cancel();
      _connectivity?.cancel();
      _lifecycle?.dispose();
      _compressProgress?.unsubscribe();
    });
    return null;
  }

  /// Un envoi est en cours ou attend une reprise (une seule tâche à la fois).
  bool get hasPendingJob => _job != null;

  // ── API publique ───────────────────────────────────────────────────────────

  /// Démarre la publication d'un témoignage vidéo. [body] : champs de
  /// POST /testimonies (title, type, category, body_text, visibility…).
  Future<void> start({
    required String sourcePath,
    required String title,
    required Map<String, dynamic> body,
    List<PendingProof> proofs = const [],
    String? replacesTestimonyId,
  }) async {
    if (_job != null) {
      throw StateError('Un envoi de vidéo est déjà en cours.');
    }
    _job = VideoUploadJob(
      sourcePath: sourcePath,
      title: title,
      body: body,
      proofs: proofs,
      replacesTestimonyId: replacesTestimonyId,
    );
    _cancelled = false;
    _autoRetries = 0;
    state = VideoUploadState(phase: VideoUploadPhase.compressing, title: title);
    await _save();
    unawaited(_run());
  }

  /// Reprend après un échec, là où l'envoi s'était arrêté.
  void retry() {
    if (_job == null || _running) return;
    _autoRetries = 0;
    unawaited(_run());
  }

  /// Annule l'envoi : arrête la compression ou l'envoi TUS, puis supprime le
  /// témoignage déjà créé par upload-init (le serveur retire la vidéo Bunny).
  Future<void> cancel() async {
    final job = _job;
    if (job == null) return;
    _cancelled = true;
    _retryTimer?.cancel();
    if (state?.phase == VideoUploadPhase.compressing) {
      try {
        await vc.VideoCompress.cancelCompression();
      } catch (_) {}
    }
    try {
      await _tus?.cancelUpload();
    } catch (_) {}
    final testimonyId = job.testimonyId;
    if (testimonyId != null) {
      try {
        await ref
            .read(apiServiceProvider)
            .delete<void>(AppConstants.testimonyById(testimonyId));
      } catch (e) {
        debugPrint('VideoUpload ✗ suppression du témoignage annulé : $e');
      }
      ref.invalidate(myTestimoniesNotifierProvider);
    }
    await _clear(job);
    state = null;
  }

  /// Ferme l'écran de fin (« en cours de traitement ») : oublie l'état.
  void dismiss() {
    if (state?.phase == VideoUploadPhase.done) state = null;
  }

  /// Après la connexion : reprend un envoi interrompu par la fermeture de
  /// l'application (même octet si l'envoi TUS avait commencé).
  Future<void> restorePending() async {
    if (_job != null || kIsWeb) return;
    try {
      final file = await _jobFile();
      if (!await file.exists()) return;
      final job = VideoUploadJob.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      if (!await File(job.uploadPath).exists() &&
          !await File(job.sourcePath).exists()) {
        await file.delete();
        return;
      }
      _job = job;
      _cancelled = false;
      _autoRetries = 0;
      state = VideoUploadState(
        phase: job.isInitialized
            ? VideoUploadPhase.uploading
            : VideoUploadPhase.failed,
        title: job.title,
        testimonyId: job.testimonyId,
        error: job.isInitialized
            ? null
            : 'L’envoi de votre vidéo a été interrompu.',
      );
      // Témoignage déjà créé : on reprend tout seul ; sinon « Réessayer ».
      if (job.isInitialized) unawaited(_run());
    } catch (e) {
      debugPrint('VideoUpload ✗ restauration : $e');
    }
  }

  // ── Déroulement ────────────────────────────────────────────────────────────

  Future<void> _run() async {
    final job = _job;
    if (job == null || _running) return;
    _running = true;
    _retryTimer?.cancel();
    try {
      if (job.compressedPath == null) await _compress(job);
      if (!job.isInitialized) await _init(job);
      if (!job.uploadDone) await _upload(job);
      final created = await _complete(job);
      if (_cancelled) return;
      await _clear(job, keepState: true);
      state = state!.copyWith(
          phase: VideoUploadPhase.done, progress: 1, error: null);
      ref.invalidate(myTestimoniesNotifierProvider);
      _showProcessing(job, created);
      await _removeReplaced(job);
    } on _Cancelled {
      // Annulation : cancel() a déjà nettoyé.
    } on _NetworkInterruption {
      if (_cancelled) return;
      _waitForNetwork();
    } on _UploadFailure catch (e) {
      if (_cancelled) return;
      _fail(e.message);
    } catch (e, st) {
      if (_cancelled) return;
      debugPrint('VideoUpload ✗ $e\n$st');
      _fail('Une erreur inattendue est survenue.');
    } finally {
      _running = false;
    }
  }

  void _fail(String message) {
    state = state?.copyWith(phase: VideoUploadPhase.failed, error: message);
  }

  void _waitForNetwork() {
    if (_autoRetries >= _maxAutoRetries) {
      _fail('La connexion est trop instable pour envoyer la vidéo. '
          'Vérifiez votre réseau puis réessayez : l’envoi reprendra là où il s’était arrêté.');
      return;
    }
    state = state?.copyWith(phase: VideoUploadPhase.waitingNetwork, error: null);
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, _resumeIfWaiting);
  }

  void _resumeIfWaiting() {
    if (state?.phase != VideoUploadPhase.waitingNetwork || _running) return;
    _autoRetries++;
    unawaited(_run());
  }

  // 1. Compression ───────────────────────────────────────────────────────────

  Future<void> _compress(VideoUploadJob job) async {
    if (kIsWeb) {
      job.compressedPath = job.sourcePath;
      return;
    }
    _setPhase(VideoUploadPhase.compressing, 0);
    _compressProgress?.unsubscribe();
    _compressProgress = vc.VideoCompress.compressProgress$.subscribe((p) {
      if (state?.phase == VideoUploadPhase.compressing) {
        state = state!.copyWith(progress: (p / 100).clamp(0, 1).toDouble());
      }
    });
    vc.MediaInfo? info;
    try {
      // Qualité moyenne : 640 px au plus sur Android, preset « Medium » sur iOS
      // (toujours sous 720p).
      info = await vc.VideoCompress.compressVideo(
        job.sourcePath,
        quality: vc.VideoQuality.MediumQuality,
        includeAudio: true,
      );
    } catch (e) {
      debugPrint('VideoUpload ✗ compression : $e');
    } finally {
      _compressProgress?.unsubscribe();
      _compressProgress = null;
    }
    if (_cancelled) throw const _Cancelled();
    final out = info?.path;
    if (out == null || !await File(out).exists()) {
      throw const _UploadFailure(
          'La compression de la vidéo a échoué. Réessayez, ou choisissez une autre vidéo.');
    }
    // Compression inutile (vidéo déjà légère) : on envoie l'original.
    final source = File(job.sourcePath);
    final compressed = File(out);
    if (await source.exists() &&
        await compressed.length() >= await source.length()) {
      await compressed.delete();
      job.compressedPath = job.sourcePath;
    } else {
      job.compressedPath = out;
    }
    await _save();
  }

  // 2. Création du témoignage et de la vidéo Bunny ───────────────────────────

  Future<void> _init(VideoUploadJob job) async {
    _setPhase(VideoUploadPhase.preparing, 0);
    final api = ref.read(apiServiceProvider);
    final Map<String, dynamic> data;
    try {
      final res = await api.post<Map<String, dynamic>>(
        AppConstants.videoUploadInit,
        data: job.body,
      );
      data = res.data;
    } on DioException catch (e) {
      throw _classifyDio(e);
    } on LaravelApiException catch (e) {
      throw _UploadFailure(e.displayMessage);
    }
    job.applyInit(data);
    if (!job.isInitialized) {
      throw const _UploadFailure('Réponse inattendue du serveur.');
    }
    // Annulé pendant la création : le témoignage créé entre-temps est retiré.
    if (_cancelled) {
      try {
        await api.delete<void>(AppConstants.testimonyById(job.testimonyId!));
      } catch (_) {}
      throw const _Cancelled();
    }
    await _save();
    state = state!.copyWith(testimonyId: job.testimonyId);
    ref.invalidate(myTestimoniesNotifierProvider);
    await _sendProofs(job);
  }

  /// Preuves : envoyées une fois le témoignage créé. Un échec ne bloque pas la
  /// vidéo (signalé à l'écran).
  Future<void> _sendProofs(VideoUploadJob job) async {
    if (job.proofs.isEmpty) return;
    final api = ref.read(apiServiceProvider);
    final failed = <int>[];
    for (final p in job.proofs) {
      try {
        await api.upload<Map<String, dynamic>>(
          AppConstants.testimonyProofs(job.testimonyId!),
          filePath: p.path,
          fieldName: 'file',
          extraFields: {'position': p.position},
        );
      } catch (e) {
        debugPrint('VideoUpload ✗ preuve ${p.position} : $e');
        failed.add(p.position);
      }
    }
    state = state!.copyWith(failedProofs: failed);
  }

  // 3. Envoi TUS ─────────────────────────────────────────────────────────────

  Future<void> _upload(VideoUploadJob job) async {
    _setPhase(VideoUploadPhase.uploading, state?.progress ?? 0);
    if (!await File(job.uploadPath).exists()) {
      throw const _UploadFailure(
          'Le fichier vidéo est introuvable sur l’appareil. Annulez puis publiez-le à nouveau.');
    }
    if (job.signatureExpiresSoon) await _refreshSignature(job);

    var signatureRefreshed = false;
    while (true) {
      final client = _tus ??= _BunnyTusClient(
        bunnyVideoId: job.bunnyVideoId!,
        file: XFile(job.uploadPath),
        url: job.tusEndpoint!,
        headers: job.tusHeaders,
        metadata: {'filetype': job.fileType, 'title': job.title},
        cache: _tusCache ??= TusPersistentCache(await _uploadDir()),
        chunkSize: 2.MB,
        // Réseaux mobiles lents : 2 Mo peuvent prendre plus d'une minute.
        timeout: const Duration(minutes: 2),
        retryDelays: const [
          Duration(seconds: 2),
          Duration(seconds: 5),
          Duration(seconds: 10),
        ],
      );
      // En-têtes modifiables entre deux reprises (signature renouvelée).
      client.headers.addAll(job.tusHeaders);

      ProtocolException? protocolError;
      try {
        await client.startUpload(
          onProgress: (count, total, _) {
            if (total > 0 && state?.phase == VideoUploadPhase.uploading) {
              state = state!.copyWith(progress: (count / total).clamp(0, 1).toDouble());
            }
          },
          onError: (e) => protocolError = e,
        );
      } on ProtocolException catch (e) {
        protocolError = e;
      } catch (e) {
        // Transport : coupure réseau, DNS, TLS… (nouvelles tentatives épuisées).
        if (_cancelled) throw const _Cancelled();
        debugPrint('VideoUpload ✗ TUS transport : $e');
        throw const _NetworkInterruption();
      }
      if (_cancelled || client.state == TusUploadState.cancelled) {
        throw const _Cancelled();
      }
      final err = protocolError;
      if (err == null) {
        if (client.state == TusUploadState.completed) break;
        // Interrompu sans erreur (pause) : reprise automatique.
        throw const _NetworkInterruption();
      }
      final code = err.statusCode ?? 0;
      debugPrint('VideoUpload ✗ TUS $code : ${err.message}');
      // Signature expirée ou refusée : on la renouvelle une fois, même offset.
      if ((code == 401 || code == 403) && !signatureRefreshed) {
        signatureRefreshed = true;
        await _refreshSignature(job);
        continue;
      }
      if (code == 0 || code == 408 || code == 429 || code >= 500) {
        throw const _NetworkInterruption();
      }
      throw _UploadFailure(code == 401 || code == 403
          ? 'L’autorisation d’envoi a été refusée. Réessayez dans quelques instants.'
          : 'Le serveur vidéo a refusé l’envoi (erreur $code).');
    }
    job.uploadDone = true;
    _tus?.close();
    _tus = null;
    await _save();
  }

  Future<void> _refreshSignature(VideoUploadJob job) async {
    try {
      final res = await ref.read(apiServiceProvider).post<Map<String, dynamic>>(
            AppConstants.videoUploadSignature(job.videoId!),
          );
      job.applySignature(res.data);
    } on DioException catch (e) {
      throw _classifyDio(e);
    } on LaravelApiException catch (e) {
      throw _UploadFailure(e.displayMessage);
    }
    _tus?.headers.addAll(job.tusHeaders);
    await _save();
  }

  // 4. Fin de l'envoi ────────────────────────────────────────────────────────

  /// Témoignage renvoyé par upload-complete (état « processing »), si lisible.
  Future<Map<String, dynamic>?> _complete(VideoUploadJob job) async {
    _setPhase(VideoUploadPhase.finalizing, 1);
    try {
      final res = await ref.read(apiServiceProvider).post<dynamic>(
            AppConstants.videoUploadComplete(job.videoId!),
          );
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } on DioException catch (e) {
      throw _classifyDio(e);
    } on LaravelApiException catch (e) {
      throw _UploadFailure(e.displayMessage);
    }
  }

  /// Envoi terminé : le témoignage est affiché tout de suite « en
  /// traitement » (en tête du fil de l'auteur, détail, « Mes témoignages »),
  /// sans attendre l'encodage.
  void _showProcessing(VideoUploadJob job, Map<String, dynamic>? created) {
    final reloader = ref.read(testimonyReloaderProvider);
    final t = created == null ? null : testimonyFromApiJson(created);
    if (t != null) {
      reloader.apply(t);
      ref.read(feedNotifierProvider.notifier).showOwnProcessing(t);
    } else if (job.testimonyId != null) {
      unawaited(reloader.reload(job.testimonyId!).then((t) {
        if (t != null) {
          ref.read(feedNotifierProvider.notifier).showOwnProcessing(t);
        }
      }));
    }
  }

  /// « Renvoyer la vidéo » : le témoignage en échec est supprimé une fois le
  /// nouvel envoi terminé. Un échec est seulement journalisé.
  Future<void> _removeReplaced(VideoUploadJob job) async {
    final old = job.replacesTestimonyId;
    if (old == null || old == job.testimonyId) return;
    try {
      await ref
          .read(apiServiceProvider)
          .delete<void>(AppConstants.testimonyById(old));
      ref.read(feedNotifierProvider.notifier).removeTestimony(old);
      ref.invalidate(myTestimoniesNotifierProvider);
    } catch (e) {
      debugPrint('VideoUpload ✗ suppression du témoignage en échec : $e');
    }
  }

  // ── Utilitaires ────────────────────────────────────────────────────────────

  void _setPhase(VideoUploadPhase phase, double progress) {
    if (_cancelled) throw const _Cancelled();
    state = (state ?? VideoUploadState(phase: phase, title: _job?.title ?? ''))
        .copyWith(phase: phase, progress: progress, error: null);
  }

  /// Réseau / serveur indisponible → reprise automatique ; sinon message.
  Exception _classifyDio(DioException e) {
    final code = e.response?.statusCode ?? 0;
    final network = e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        code >= 500;
    if (network) return const _NetworkInterruption();
    final body = e.response?.data;
    final msg = body is Map ? body['message'] as String? : null;
    return _UploadFailure(msg ?? 'Erreur du serveur ($code).');
  }

  Future<String> _uploadDir() async {
    final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}video_upload');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<File> _jobFile() async =>
      File('${await _uploadDir()}${Platform.pathSeparator}job.json');

  Future<void> _save() async {
    final job = _job;
    if (job == null || kIsWeb) return;
    try {
      await (await _jobFile()).writeAsString(jsonEncode(job.toJson()));
    } catch (e) {
      debugPrint('VideoUpload ✗ enregistrement de la tâche : $e');
    }
  }

  /// Oublie la tâche : fichier de suivi, vidéo compressée, client TUS.
  Future<void> _clear(VideoUploadJob job, {bool keepState = false}) async {
    _tus?.close();
    _tus = null;
    _job = null;
    if (kIsWeb) return;
    try {
      final f = await _jobFile();
      if (await f.exists()) await f.delete();
      final c = job.compressedPath;
      if (c != null && c != job.sourcePath && await File(c).exists()) {
        await File(c).delete();
      }
      if (job.bunnyVideoId != null) {
        await _tusCache?.remove('bunny-${job.bunnyVideoId}');
      }
    } catch (_) {}
  }
}

/// Envoi de la vidéo en cours (garde son état quand on quitte l'écran).
final videoUploadProvider =
    NotifierProvider<VideoUploadController, VideoUploadState?>(
        VideoUploadController.new);
