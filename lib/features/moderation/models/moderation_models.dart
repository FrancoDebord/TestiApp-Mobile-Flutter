// =============================================================================
// Moderation domain models
// =============================================================================

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
        return 'Contenu inapproprié';
      case RejectionReason.falseTestimony:
        return 'Faux témoignage';
      case RejectionReason.hateSpeech:
        return 'Discours haineux';
      case RejectionReason.spam:
        return 'Spam';
      case RejectionReason.other:
        return 'Autre';
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
