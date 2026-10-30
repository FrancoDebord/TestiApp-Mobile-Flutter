// =============================================================================
// Publish feature — domain models
// =============================================================================

import '../../../shared/models/mention.dart';
import '../../../shared/utils/rich_text_utils.dart' show stripFormatting;
import '../../../l10n/app_localizations.dart';

/// The three testimony formats a user can publish.
enum TestimonyFormat { text, audio, video }

extension TestimonyFormatLabel on TestimonyFormat {
  String get label {
    switch (this) {
      case TestimonyFormat.text:
        return L10n.current.publishFormatText;
      case TestimonyFormat.audio:
        return L10n.current.publishFormatAudio;
      case TestimonyFormat.video:
        return L10n.current.publishFormatVideo;
    }
  }

  String get description {
    switch (this) {
      case TestimonyFormat.text:
        return L10n.current.publishFormatTextHint;
      case TestimonyFormat.audio:
        return L10n.current.publishFormatAudioHint;
      case TestimonyFormat.video:
        return L10n.current.publishFormatVideoHint;
    }
  }
}

/// Workflow status chips shown in the status bar.
enum PublishStatus {
  draft,
  submitted,
  inReview,
  published,
  pendingSync,

  /// Enregistré dans le carnet privé (jamais soumis à la modération).
  savedToJournal,

  /// Vidéo confiée à l'envoi Bunny Stream (videoUploadProvider) : compression,
  /// envoi reprenable, puis traitement côté serveur.
  videoUploading,
}

extension PublishStatusLabel on PublishStatus {
  String get label {
    switch (this) {
      case PublishStatus.draft:
        return L10n.current.publishStatusDraft;
      case PublishStatus.submitted:
        return L10n.current.publishStatusSubmitted;
      case PublishStatus.inReview:
        return L10n.current.publishStatusInReview;
      case PublishStatus.published:
        return L10n.current.publishStatusPublished;
      case PublishStatus.pendingSync:
        return L10n.current.publishStatusOffline;
      case PublishStatus.savedToJournal:
        return L10n.current.publishStatusJournal;
      case PublishStatus.videoUploading:
        return L10n.current.publishStatusVideoUploading;
    }
  }
}

/// Visibility of a published testimony.
/// `private` = carnet privé : visible uniquement par l'auteur, sans modération.
enum TestimonyVisibility { public, friends, private }

/// All available testimony categories (valeurs internes, cf. _categoryFromString
/// dans publish_provider.dart ; les libellés affichés viennent de l'API).
const List<String> kTestimonyCategories = [
  'Guérison', // i18n-ignore
  'Délivrance', // i18n-ignore
  'Conversion', // i18n-ignore
  'Mariage', // i18n-ignore
  'Famille', // i18n-ignore
  'Finances', // i18n-ignore
  'Miracles', // i18n-ignore
  'Protection divine', // i18n-ignore
  'Ministère', // i18n-ignore
  'Salut', // i18n-ignore
];

// ---------------------------------------------------------------------------
// Preuves du témoignage (facultatives, jamais publiées)
// ---------------------------------------------------------------------------

/// Taille maximale d'une preuve (même limite que le serveur : 10 Mo).
const int kMaxProofBytes = 10 * 1024 * 1024;

/// Extensions acceptées par POST /testimonies/{id}/proofs.
const List<String> kProofExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];

/// Fichier local choisi pour un emplacement de preuve (1 ou 2).
class ProofAttachment {
  const ProofAttachment({
    required this.path,
    required this.name,
    required this.size,
  });

  final String path;
  final String name;

  /// Taille en octets.
  final int size;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  bool get isPdf => extension == 'pdf';
}

/// Raison du refus d'un fichier de preuve, ou `null` s'il est accepté.
String? proofRejectionReason({required String name, required int size}) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  if (!kProofExtensions.contains(ext)) {
    return L10n.current.publishProofBadFormat;
  }
  if (size > kMaxProofBytes) {
    return L10n.current.publishProofTooBig;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Draft / in-progress form state
// ---------------------------------------------------------------------------

/// Mutable data class carried through the multi-step publish flow.
class PublishDraft {
  PublishDraft({
    this.format,
    this.title = '',
    this.category,
    this.coverImagePath,
    this.coverImageRemoteUrl,
    this.bodyText = '',
    this.bibleVerse = '',
    this.audioPath,
    this.audioDurationSeconds = 0,
    this.audioTranscript = '',
    this.audioRemoteUrl,
    this.videoPath,
    this.videoDurationSeconds = 0,
    this.videoTrimStart = Duration.zero,
    this.videoTrimEnd = Duration.zero,
    this.videoThumbnailIndex = 0,
    this.videoRemoteUrl,
    this.useYouTube = false,
    this.youtubeUrl = '',
    this.youtubeCreditAuthor = '',
    this.youtubeCreditChannel = '',
    this.youtubeCreditUrl = '',
    this.proofs = const {},
    this.proofsPublic = false,
    this.failedProofPositions = const [],
    this.visibility = TestimonyVisibility.public,
    this.consentGiven = false,
    this.status = PublishStatus.draft,
    this.errorMessage,
    this.isAuthError = false,
    this.categoryId,
    this.isUploadingMedia = false,
    this.uploadError,
    this.mentions = const [],
    this.draftId,
    this.publicationWeb = true,
    this.isAnonymous = false,
    this.resume = '',
    this.transcription = '',
    this.playlistId,
    this.playlistTitle = '',
    this.playlistError,
  });

  /// Brouillon enregistré sur le téléphone (table `drafts`) dont ce formulaire est la suite.
  String? draftId;

  TestimonyFormat? format;
  String title;
  String? category;
  String? coverImagePath;
  /// URL distante de l'image de couverture après upload (null = pas encore uploadée).
  String? coverImageRemoteUrl;

  // text
  String bodyText;
  String bibleVerse;

  // audio
  String? audioPath;
  int audioDurationSeconds;
  String audioTranscript;
  String? audioRemoteUrl;

  // video
  String? videoPath;
  int videoDurationSeconds;
  Duration videoTrimStart;
  Duration videoTrimEnd;
  int videoThumbnailIndex;
  String? videoRemoteUrl;

  /// Administrateurs : vidéo publiée par lien YouTube au lieu d'un fichier.
  bool useYouTube;
  String youtubeUrl;

  /// Crédit de la vidéo YouTube d'origine : auteur / intervenant, chaîne, lien.
  String youtubeCreditAuthor;
  String youtubeCreditChannel;
  String youtubeCreditUrl;

  // Référencement (docs serveur fonctionnalites/referencement.md)
  /// Accord pour publier aussi sur le site et dans Google (`publicationWeb`) ;
  /// coché par défaut, comme sur le site.
  bool publicationWeb;

  /// « Témoignage anonyme » sur le site (`isAnonymous`) ; l'application
  /// montre toujours l'auteur.
  bool isAnonymous;

  /// Audio / vidéo : résumé écrit (recommandé) et transcription (vidéo),
  /// lus par Google sur la page du témoignage.
  String resume;
  String transcription;

  // Liste de témoignages (facultatif ; docs serveur listes-de-temoignages.md)
  /// Liste existante choisie (`playlist_id`) ; null : aucune.
  String? playlistId;

  /// Titre d'une nouvelle liste (`playlist_title`), prioritaire sur [playlistId].
  String playlistTitle;

  /// Erreur 422 du serveur (`errors.playlist_id`), affichée sous le champ.
  String? playlistError;

  // preuves : emplacement (1 ou 2) → fichier local
  Map<int, ProofAttachment> proofs;

  /// Accord de l'auteur pour montrer ses preuves au public une fois le témoignage publié.
  bool proofsPublic;

  /// Emplacements dont l'envoi a échoué après la publication (message à afficher).
  List<int> failedProofPositions;

  // publication
  TestimonyVisibility visibility;
  bool consentGiven;
  PublishStatus status;
  String? errorMessage;
  bool isAuthError;
  String? categoryId;

  // upload
  bool isUploadingMedia;
  String? uploadError;

  /// Comptes choisis après « @ » dans la description / transcription
  /// (docs serveur fonctionnalites/mentions.md : prévenus à la publication).
  List<MentionRef> mentions;

  /// Identifiants des comptes mentionnés encore présents (« @Nom ») dans [text].
  List<String> mentionIdsIn(String? text) {
    if (text == null || text.isEmpty || mentions.isEmpty) return const [];
    return MentionCodec.ranges(text, mentions).map((r) => r.ref.id).toSet().toList();
  }

  /// Titre envoyé au serveur : le titre saisi, sinon (titre facultatif) la
  /// première ligne de la description, sinon un libellé selon le format.
  String get effectiveTitle {
    final t = title.trim();
    if (t.isNotEmpty) return t;
    // Sans image ni adresse de lien.
    final desc = stripFormatting(format == TestimonyFormat.audio ? audioTranscript : bodyText)
        .replaceAll(RegExp(r'^[#>\-\s]+|[*_~]'), '')
        .trim();
    if (desc.isNotEmpty) {
      final line = desc.split('\n').first.trim();
      if (line.isNotEmpty) {
        return line.length > 60 ? '${line.substring(0, 60).trimRight()}…' : line;
      }
    }
    return L10n.current.publishDefaultTitle;
  }

  /// Quelque chose a été saisi ou choisi : à garder en brouillon si on quitte.
  bool get hasContent =>
      title.trim().isNotEmpty ||
      bodyText.trim().isNotEmpty ||
      audioTranscript.trim().isNotEmpty ||
      bibleVerse.trim().isNotEmpty ||
      (coverImagePath ?? '').isNotEmpty ||
      (audioPath ?? '').isNotEmpty ||
      (videoPath ?? '').isNotEmpty ||
      youtubeUrl.trim().isNotEmpty ||
      resume.trim().isNotEmpty ||
      transcription.trim().isNotEmpty ||
      proofs.isNotEmpty;

  /// Champs gardés dans un brouillon (fichiers : chemins sur le téléphone).
  Map<String, dynamic> toDraftJson() => {
        'format': format?.name,
        'title': title,
        'category': category,
        'categoryId': categoryId,
        'coverImagePath': coverImagePath,
        'coverImageRemoteUrl': coverImageRemoteUrl,
        'bodyText': bodyText,
        'bibleVerse': bibleVerse,
        'audioPath': audioPath,
        'audioDurationSeconds': audioDurationSeconds,
        'audioTranscript': audioTranscript,
        'audioRemoteUrl': audioRemoteUrl,
        'videoPath': videoPath,
        'videoDurationSeconds': videoDurationSeconds,
        'videoTrimStartMs': videoTrimStart.inMilliseconds,
        'videoTrimEndMs': videoTrimEnd.inMilliseconds,
        'videoThumbnailIndex': videoThumbnailIndex,
        'useYouTube': useYouTube,
        'youtubeUrl': youtubeUrl,
        'youtubeCreditAuthor': youtubeCreditAuthor,
        'youtubeCreditChannel': youtubeCreditChannel,
        'youtubeCreditUrl': youtubeCreditUrl,
        'proofs': {
          for (final e in proofs.entries)
            '${e.key}': {'path': e.value.path, 'name': e.value.name, 'size': e.value.size},
        },
        'proofsPublic': proofsPublic,
        'visibility': visibility.name,
        'consentGiven': consentGiven,
        'mentions': [for (final m in mentions) m.toJson()],
        'publicationWeb': publicationWeb,
        'isAnonymous': isAnonymous,
        'resume': resume,
        'transcription': transcription,
        'playlistId': playlistId,
        'playlistTitle': playlistTitle,
      };

  factory PublishDraft.fromDraftJson(Map<String, dynamic> j, {String? draftId}) {
    T? pick<T>(String k) => j[k] is T ? j[k] as T : null;
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    final proofs = <int, ProofAttachment>{};
    final rawProofs = j['proofs'];
    if (rawProofs is Map) {
      for (final e in rawProofs.entries) {
        final pos = int.tryParse('${e.key}');
        final v = e.value;
        if (pos != null && v is Map && v['path'] is String) {
          proofs[pos] = ProofAttachment(
            path: v['path'] as String,
            name: v['name'] as String? ?? '',
            size: (v['size'] as num?)?.toInt() ?? 0,
          );
        }
      }
    }
    return PublishDraft(
      draftId: draftId,
      format: TestimonyFormat.values.where((f) => f.name == j['format']).firstOrNull,
      title: pick<String>('title') ?? '',
      category: pick<String>('category'),
      categoryId: pick<String>('categoryId'),
      coverImagePath: pick<String>('coverImagePath'),
      coverImageRemoteUrl: pick<String>('coverImageRemoteUrl'),
      bodyText: pick<String>('bodyText') ?? '',
      bibleVerse: pick<String>('bibleVerse') ?? '',
      audioPath: pick<String>('audioPath'),
      audioDurationSeconds: n('audioDurationSeconds'),
      audioTranscript: pick<String>('audioTranscript') ?? '',
      audioRemoteUrl: pick<String>('audioRemoteUrl'),
      videoPath: pick<String>('videoPath'),
      videoDurationSeconds: n('videoDurationSeconds'),
      videoTrimStart: Duration(milliseconds: n('videoTrimStartMs')),
      videoTrimEnd: Duration(milliseconds: n('videoTrimEndMs')),
      videoThumbnailIndex: n('videoThumbnailIndex'),
      useYouTube: j['useYouTube'] == true,
      youtubeUrl: pick<String>('youtubeUrl') ?? '',
      youtubeCreditAuthor: pick<String>('youtubeCreditAuthor') ?? '',
      youtubeCreditChannel: pick<String>('youtubeCreditChannel') ?? '',
      youtubeCreditUrl: pick<String>('youtubeCreditUrl') ?? '',
      proofs: proofs,
      proofsPublic: j['proofsPublic'] == true,
      visibility: TestimonyVisibility.values.where((v) => v.name == j['visibility']).firstOrNull ??
          TestimonyVisibility.public,
      consentGiven: j['consentGiven'] == true,
      mentions: MentionRef.listFrom(j['mentions']),
      // Brouillon antérieur au 2026-10-28 : accord pour le web donné par défaut.
      publicationWeb: j['publicationWeb'] != false,
      isAnonymous: j['isAnonymous'] == true,
      resume: pick<String>('resume') ?? '',
      transcription: pick<String>('transcription') ?? '',
      playlistId: pick<String>('playlistId'),
      playlistTitle: pick<String>('playlistTitle') ?? '',
    );
  }

  PublishDraft copyWith({
    TestimonyFormat? format,
    String? title,
    String? category,
    String? coverImagePath,
    String? bodyText,
    String? bibleVerse,
    String? audioPath,
    int? audioDurationSeconds,
    String? audioTranscript,
    String? videoPath,
    int? videoDurationSeconds,
    Duration? videoTrimStart,
    Duration? videoTrimEnd,
    int? videoThumbnailIndex,
    bool? useYouTube,
    String? youtubeUrl,
    String? youtubeCreditAuthor,
    String? youtubeCreditChannel,
    String? youtubeCreditUrl,
    Map<int, ProofAttachment>? proofs,
    bool? proofsPublic,
    List<int>? failedProofPositions,
    TestimonyVisibility? visibility,
    bool? consentGiven,
    PublishStatus? status,
    bool? isAuthError,
    String? categoryId,
    bool? isUploadingMedia,
    Object? errorMessage = _sentinel,
    Object? coverImageRemoteUrl = _sentinel,
    Object? audioRemoteUrl = _sentinel,
    Object? videoRemoteUrl = _sentinel,
    Object? uploadError = _sentinel,
    List<MentionRef>? mentions,
    Object? draftId = _sentinel,
    bool? publicationWeb,
    bool? isAnonymous,
    String? resume,
    String? transcription,
    Object? playlistId = _sentinel,
    String? playlistTitle,
    Object? playlistError = _sentinel,
  }) {
    return PublishDraft(
      format: format ?? this.format,
      title: title ?? this.title,
      category: category ?? this.category,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      coverImageRemoteUrl: coverImageRemoteUrl == _sentinel
          ? this.coverImageRemoteUrl
          : coverImageRemoteUrl as String?,
      bodyText: bodyText ?? this.bodyText,
      bibleVerse: bibleVerse ?? this.bibleVerse,
      audioPath: audioPath ?? this.audioPath,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      audioTranscript: audioTranscript ?? this.audioTranscript,
      audioRemoteUrl: audioRemoteUrl == _sentinel
          ? this.audioRemoteUrl
          : audioRemoteUrl as String?,
      videoPath: videoPath ?? this.videoPath,
      videoDurationSeconds: videoDurationSeconds ?? this.videoDurationSeconds,
      videoTrimStart: videoTrimStart ?? this.videoTrimStart,
      videoTrimEnd: videoTrimEnd ?? this.videoTrimEnd,
      videoThumbnailIndex: videoThumbnailIndex ?? this.videoThumbnailIndex,
      videoRemoteUrl: videoRemoteUrl == _sentinel
          ? this.videoRemoteUrl
          : videoRemoteUrl as String?,
      useYouTube: useYouTube ?? this.useYouTube,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      youtubeCreditAuthor: youtubeCreditAuthor ?? this.youtubeCreditAuthor,
      youtubeCreditChannel: youtubeCreditChannel ?? this.youtubeCreditChannel,
      youtubeCreditUrl: youtubeCreditUrl ?? this.youtubeCreditUrl,
      proofs: proofs ?? this.proofs,
      proofsPublic: proofsPublic ?? this.proofsPublic,
      failedProofPositions: failedProofPositions ?? this.failedProofPositions,
      visibility: visibility ?? this.visibility,
      consentGiven: consentGiven ?? this.consentGiven,
      status: status ?? this.status,
      isAuthError: isAuthError ?? this.isAuthError,
      categoryId: categoryId ?? this.categoryId,
      isUploadingMedia: isUploadingMedia ?? this.isUploadingMedia,
      errorMessage:
          errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      uploadError:
          uploadError == _sentinel ? this.uploadError : uploadError as String?,
      mentions: mentions ?? this.mentions,
      draftId: draftId == _sentinel ? this.draftId : draftId as String?,
      publicationWeb: publicationWeb ?? this.publicationWeb,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      resume: resume ?? this.resume,
      transcription: transcription ?? this.transcription,
      playlistId: playlistId == _sentinel ? this.playlistId : playlistId as String?,
      playlistTitle: playlistTitle ?? this.playlistTitle,
      playlistError: playlistError == _sentinel ? this.playlistError : playlistError as String?,
    );
  }
}

const Object _sentinel = Object();
