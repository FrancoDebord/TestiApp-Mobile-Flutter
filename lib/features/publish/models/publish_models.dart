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
enum PublishStatus { draft, submitted, inReview, published }

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
    }
  }
}

/// Visibility of a published testimony.
enum TestimonyVisibility { public, private }

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
    this.bodyText = '',
    this.bibleVerse = '',
    this.audioPath,
    this.audioDurationSeconds = 0,
    this.audioTranscript = '',
    this.videoPath,
    this.videoTrimStart = Duration.zero,
    this.videoTrimEnd = Duration.zero,
    this.videoThumbnailIndex = 0,
    this.visibility = TestimonyVisibility.public,
    this.consentGiven = false,
    this.status = PublishStatus.draft,
  });

  TestimonyFormat? format;
  String title;
  String? category;
  String? coverImagePath;

  // text
  String bodyText;
  String bibleVerse;

  // audio
  String? audioPath;
  int audioDurationSeconds;
  String audioTranscript;

  // video
  String? videoPath;
  Duration videoTrimStart;
  Duration videoTrimEnd;
  int videoThumbnailIndex;

  // publication
  TestimonyVisibility visibility;
  bool consentGiven;
  PublishStatus status;

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
    Duration? videoTrimStart,
    Duration? videoTrimEnd,
    int? videoThumbnailIndex,
    TestimonyVisibility? visibility,
    bool? consentGiven,
    PublishStatus? status,
  }) {
    return PublishDraft(
      format: format ?? this.format,
      title: title ?? this.title,
      category: category ?? this.category,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      bodyText: bodyText ?? this.bodyText,
      bibleVerse: bibleVerse ?? this.bibleVerse,
      audioPath: audioPath ?? this.audioPath,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      audioTranscript: audioTranscript ?? this.audioTranscript,
      videoPath: videoPath ?? this.videoPath,
      videoTrimStart: videoTrimStart ?? this.videoTrimStart,
      videoTrimEnd: videoTrimEnd ?? this.videoTrimEnd,
      videoThumbnailIndex: videoThumbnailIndex ?? this.videoThumbnailIndex,
      visibility: visibility ?? this.visibility,
      consentGiven: consentGiven ?? this.consentGiven,
      status: status ?? this.status,
    );
  }
}
