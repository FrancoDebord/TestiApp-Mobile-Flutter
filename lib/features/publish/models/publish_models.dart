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
enum PublishStatus { draft, submitted, inReview, published, pendingSync }

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
    }
  }
}

/// Visibility of a published testimony.
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

  // publication
  TestimonyVisibility visibility;
  bool consentGiven;
  PublishStatus status;
  String? errorMessage;
  bool isAuthError;
  int? categoryId;

  // upload
  bool isUploadingMedia;
  String? uploadError;

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
    TestimonyVisibility? visibility,
    bool? consentGiven,
    PublishStatus? status,
    bool? isAuthError,
    int? categoryId,
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
