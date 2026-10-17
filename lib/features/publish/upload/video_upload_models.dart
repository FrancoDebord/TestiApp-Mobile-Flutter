// lib/features/publish/upload/video_upload_models.dart
//
// Envoi d'un témoignage vidéo vers Bunny Stream : tâche persistée (reprise
// après un redémarrage de l'application) et état affiché par l'interface.
//
// Étapes : compression (video_compress) → upload-init (crée le témoignage et la
// vidéo Bunny) → preuves → envoi TUS reprenable → upload-complete.

import '../../../l10n/app_localizations.dart';

/// Étape en cours de l'envoi.
enum VideoUploadPhase {
  compressing,
  preparing,
  uploading,

  /// Réseau coupé : l'envoi reprendra seul au retour de la connexion.
  waitingNetwork,
  finalizing,
  done,
  failed;

  bool get isActive =>
      this == compressing ||
      this == preparing ||
      this == uploading ||
      this == finalizing;

  String get label => switch (this) {
        compressing => L10n.current.uploadPhaseCompressing,
        preparing => L10n.current.uploadPhasePreparing,
        uploading => L10n.current.uploadPhaseUploading,
        waitingNetwork => L10n.current.uploadPhaseWaitingNetwork,
        finalizing => L10n.current.uploadPhaseFinalizing,
        done => L10n.current.uploadPhaseDone,
        failed => L10n.current.uploadPhaseFailed,
      };
}

/// Une preuve à envoyer une fois le témoignage créé (emplacement 1 ou 2).
typedef PendingProof = ({int position, String path});

/// Tâche d'envoi, enregistrée sur l'appareil à chaque étape franchie.
class VideoUploadJob {
  VideoUploadJob({
    required this.sourcePath,
    required this.title,
    required this.body,
    this.proofs = const [],
    this.compressedPath,
    this.videoId,
    this.testimonyId,
    this.libraryId,
    this.bunnyVideoId,
    this.signature,
    this.expiration,
    this.tusEndpoint,
    this.uploadDone = false,
    this.replacesTestimonyId,
  });

  /// Fichier choisi ou filmé par l'utilisateur.
  final String sourcePath;

  /// Titre du témoignage (métadonnée TUS « title »).
  final String title;

  /// Corps de POST /videos/upload-init (mêmes champs que POST /testimonies).
  final Map<String, dynamic> body;

  final List<PendingProof> proofs;

  /// Fichier compressé (ou [sourcePath] si la compression n'a rien gagné).
  String? compressedPath;

  // Réponse de upload-init.
  String? videoId;
  String? testimonyId;
  String? libraryId;
  String? bunnyVideoId;
  String? signature;

  /// Fin de validité de [signature] (secondes UNIX).
  int? expiration;
  String? tusEndpoint;

  /// Envoi TUS terminé (il reste upload-complete).
  bool uploadDone;

  /// « Renvoyer la vidéo » : témoignage en échec, supprimé une fois ce nouvel
  /// envoi terminé (upload-init crée toujours un nouveau témoignage).
  final String? replacesTestimonyId;

  bool get isInitialized => videoId != null && tusEndpoint != null;

  /// Fichier réellement envoyé.
  String get uploadPath => compressedPath ?? sourcePath;

  /// La signature expire dans moins de 5 minutes : à renouveler avant l'envoi.
  bool get signatureExpiresSoon {
    final exp = expiration;
    if (exp == null) return true;
    final limit = DateTime.now().add(const Duration(minutes: 5));
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(limit);
  }

  /// Applique la réponse de POST /videos/upload-init.
  void applyInit(Map<String, dynamic> d) {
    videoId = d['video_id']?.toString();
    testimonyId = d['testimony_id']?.toString();
    libraryId = d['library_id']?.toString();
    bunnyVideoId = d['bunny_video_id']?.toString();
    tusEndpoint = d['tus_endpoint']?.toString();
    applySignature(d);
  }

  /// Applique { signature, expiration } (upload-init ou upload-signature).
  void applySignature(Map<String, dynamic> d) {
    signature = d['signature']?.toString();
    expiration = parseExpiration(d['expiration']);
  }

  /// En-têtes d'autorisation Bunny Stream de l'envoi TUS.
  Map<String, String> get tusHeaders => {
        'AuthorizationSignature': signature ?? '', // i18n-ignore
        'AuthorizationExpire': '${expiration ?? 0}', // i18n-ignore
        'VideoId': bunnyVideoId ?? '', // i18n-ignore
        'LibraryId': libraryId ?? '', // i18n-ignore
      };

  /// Type MIME de la métadonnée TUS « filetype ».
  String get fileType {
    final ext = uploadPath.split('.').last.toLowerCase();
    return switch (ext) {
      'mov' || 'qt' => 'video/quicktime',
      'webm' => 'video/webm',
      '3gp' => 'video/3gpp',
      'mkv' => 'video/x-matroska',
      _ => 'video/mp4',
    };
  }

  /// Secondes UNIX depuis un entier, une chaîne numérique ou une date ISO 8601.
  static int? parseExpiration(Object? raw) {
    if (raw is num) return raw.toInt();
    final s = raw?.toString() ?? '';
    final n = int.tryParse(s);
    if (n != null) return n;
    final d = DateTime.tryParse(s);
    return d == null ? null : d.millisecondsSinceEpoch ~/ 1000;
  }

  Map<String, dynamic> toJson() => {
        'source_path': sourcePath,
        'title': title,
        'body': body,
        'proofs': [
          for (final p in proofs) {'position': p.position, 'path': p.path},
        ],
        'compressed_path': compressedPath,
        'video_id': videoId,
        'testimony_id': testimonyId,
        'library_id': libraryId,
        'bunny_video_id': bunnyVideoId,
        'signature': signature,
        'expiration': expiration,
        'tus_endpoint': tusEndpoint,
        'upload_done': uploadDone,
        'replaces_testimony_id': replacesTestimonyId,
      };

  factory VideoUploadJob.fromJson(Map<String, dynamic> j) => VideoUploadJob(
        sourcePath: j['source_path'] as String,
        title: j['title'] as String? ?? '',
        body: Map<String, dynamic>.from(j['body'] as Map? ?? const {}),
        proofs: [
          for (final p in (j['proofs'] as List? ?? const []))
            if (p is Map)
              (position: (p['position'] as num).toInt(), path: p['path'] as String),
        ],
        compressedPath: j['compressed_path'] as String?,
        videoId: j['video_id'] as String?,
        testimonyId: j['testimony_id'] as String?,
        libraryId: j['library_id'] as String?,
        bunnyVideoId: j['bunny_video_id'] as String?,
        signature: j['signature'] as String?,
        expiration: parseExpiration(j['expiration']),
        tusEndpoint: j['tus_endpoint'] as String?,
        uploadDone: j['upload_done'] as bool? ?? false,
        replacesTestimonyId: j['replaces_testimony_id'] as String?,
      );
}

/// État affiché : étape, progression (0 à 1) et message d'erreur.
class VideoUploadState {
  const VideoUploadState({
    required this.phase,
    this.progress = 0,
    this.error,
    this.testimonyId,
    this.title = '',
    this.failedProofs = const [],
  });

  final VideoUploadPhase phase;

  /// Progression de l'étape en cours (compression ou envoi), de 0 à 1.
  final double progress;

  /// Message clair en cas d'échec ([VideoUploadPhase.failed]).
  final String? error;

  final String? testimonyId;
  final String title;

  /// Preuves dont l'envoi a échoué (emplacements).
  final List<int> failedProofs;

  VideoUploadState copyWith({
    VideoUploadPhase? phase,
    double? progress,
    Object? error = _keep,
    String? testimonyId,
    List<int>? failedProofs,
  }) =>
      VideoUploadState(
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        error: error == _keep ? this.error : error as String?,
        testimonyId: testimonyId ?? this.testimonyId,
        title: title,
        failedProofs: failedProofs ?? this.failedProofs,
      );
}

const Object _keep = Object();
