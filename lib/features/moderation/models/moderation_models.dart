// =============================================================================
// Moderation domain models
// =============================================================================

import '../../../core/media/video_source.dart';
import '../../../l10n/app_localizations.dart';

enum ModerationStatus { pending, inReview, approved, rejected }

enum TestimonyType { text, audio, video }

enum RejectionReason {
  inappropriateContent,
  falseTestimony,
  hateSpeech,
  spam,
  other,
}

extension RejectionReasonLabel on RejectionReason {
  String get label {
    switch (this) {
      case RejectionReason.inappropriateContent:
        return L10n.current.moderationReasonInappropriate;
      case RejectionReason.falseTestimony:
        return L10n.current.moderationReasonFalseTestimony;
      case RejectionReason.hateSpeech:
        return L10n.current.moderationReasonHateSpeech;
      case RejectionReason.spam:
        return L10n.current.moderationReasonSpam;
      case RejectionReason.other:
        return L10n.current.moderationReasonOther;
    }
  }
}

class ModerationAuthor {
  const ModerationAuthor({
    required this.uid,
    required this.displayName,
    required this.country,
    this.avatarUrl,
  });

  final String uid;
  final String displayName;
  final String country;
  final String? avatarUrl;
}

class ModerationItem {
  const ModerationItem({
    required this.id,
    required this.author,
    required this.title,
    required this.category,
    required this.type,
    required this.status,
    required this.submittedAt,
    this.contentPreview,
    this.rejectionReason,
    this.moderatorNote,
    this.videoStatus,
    this.thumbnailUrl,
    this.durationSeconds = 0,
  });

  final String id;
  final ModerationAuthor author;
  final String title;
  final String category;
  final TestimonyType type;
  final ModerationStatus status;
  final DateTime submittedAt;
  final String? contentPreview;
  final RejectionReason? rejectionReason;
  final String? moderatorNote;

  /// Vidéo Bunny Stream (`video.status`) : processing, ready, failed ;
  /// `null` hors vidéo ou ancienne vidéo (lisible).
  final String? videoStatus;

  /// Miniature (`video.thumbnail_url`, sinon couverture).
  final String? thumbnailUrl;

  /// Durée de la vidéo en secondes (0 si inconnue).
  final int durationSeconds;

  VideoProcessingState get videoState => VideoProcessingState.parse(videoStatus);

  String get truncatedTitle =>
      title.length > 60 ? '${title.substring(0, 60)}…' : title;

  ModerationItem copyWith({
    String? id,
    ModerationAuthor? author,
    String? title,
    String? category,
    TestimonyType? type,
    ModerationStatus? status,
    DateTime? submittedAt,
    String? contentPreview,
    RejectionReason? rejectionReason,
    String? moderatorNote,
  }) => ModerationItem(
    id:             id             ?? this.id,
    author:         author         ?? this.author,
    title:          title          ?? this.title,
    category:       category       ?? this.category,
    type:           type           ?? this.type,
    status:         status         ?? this.status,
    submittedAt:    submittedAt    ?? this.submittedAt,
    contentPreview: contentPreview ?? this.contentPreview,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    moderatorNote:  moderatorNote  ?? this.moderatorNote,
    videoStatus:    videoStatus,
    thumbnailUrl:   thumbnailUrl,
    durationSeconds: durationSeconds,
  );
}

class ModerationStats {
  const ModerationStats({
    required this.pending,
    required this.approvedToday,
    required this.rejectedToday,
    required this.totalThisMonth,
  });

  final int pending;
  final int approvedToday;
  final int rejectedToday;
  final int totalThisMonth;
}
