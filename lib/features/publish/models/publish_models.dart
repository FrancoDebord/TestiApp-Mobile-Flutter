// =============================================================================
// Publish feature — domain models
// =============================================================================

/// The three testimony formats a user can publish.
enum TestimonyFormat { text, audio, video }

extension TestimonyFormatLabel on TestimonyFormat {
  String get label {
    switch (this) {
      case TestimonyFormat.text:
        return 'Témoignage Écrit';
      case TestimonyFormat.audio:
        return 'Témoignage Audio';
      case TestimonyFormat.video:
        return 'Témoignage Vidéo';
    }
  }

  String get description {
    switch (this) {
      case TestimonyFormat.text:
        return 'Racontez avec vos mots';
      case TestimonyFormat.audio:
        return 'Enregistrez votre voix';
      case TestimonyFormat.video:
        return 'Filmez votre histoire';
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
}

extension PublishStatusLabel on PublishStatus {
  String get label {
    switch (this) {
      case PublishStatus.draft:
        return 'Brouillon';
      case PublishStatus.submitted:
        return 'Soumis';
      case PublishStatus.inReview:
        return 'En validation';
      case PublishStatus.published:
        return 'Publié';
      case PublishStatus.pendingSync:
        return 'Hors ligne';
      case PublishStatus.savedToJournal:
        return 'Dans mon carnet';
    }
  }
}

/// Visibility of a published testimony.
/// `private` = carnet privé : visible uniquement par l'auteur, sans modération.
enum TestimonyVisibility { public, friends, private }

/// All available testimony categories.
const List<String> kTestimonyCategories = [
  'Guérison',
  'Délivrance',
  'Conversion',
  'Mariage',
  'Famille',
  'Finances',
  'Miracles',
  'Protection divine',
  'Ministère',
  'Salut',
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
    return 'Format non accepté : image (JPG, PNG, WebP) ou PDF uniquement.';
  }
  if (size > kMaxProofBytes) {
    return 'Fichier trop lourd : 10 Mo au maximum.';
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
  });

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

  /// Titre envoyé au serveur : le titre saisi, sinon (titre facultatif) la
  /// première ligne de la description, sinon un libellé selon le format.
  String get effectiveTitle {
    final t = title.trim();
    if (t.isNotEmpty) return t;
    final desc = (format == TestimonyFormat.audio ? audioTranscript : bodyText)
        .replaceAll(RegExp(r'^[#>\-\s]+|[*_~]'), '')
        .trim();
    if (desc.isNotEmpty) {
      final line = desc.split('\n').first.trim();
      if (line.isNotEmpty) {
        return line.length > 60 ? '${line.substring(0, 60).trimRight()}…' : line;
      }
    }
    return 'Mon témoignage';
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
    );
  }
}

const Object _sentinel = Object();
