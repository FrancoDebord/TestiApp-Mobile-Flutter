// lib/shared/models/testimony_model.dart — Dart pur, sans génération de code.

import 'user_model.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum TestimonyType {
  text, audio, video;

  static TestimonyType fromJson(String? v) => switch (v) {
    'audio' => TestimonyType.audio,
    'video' => TestimonyType.video,
    _       => TestimonyType.text,
  };
  String toJson() => name;
}

enum TestimonyStatus {
  draft, pending, approved, rejected;

  static TestimonyStatus fromJson(String? v) => switch (v) {
    'draft'    => TestimonyStatus.draft,
    'approved' => TestimonyStatus.approved,
    'rejected' => TestimonyStatus.rejected,
    _          => TestimonyStatus.pending,
  };
  String toJson() => name;
}

enum TestimonyVisibility {
  public, private, followers;

  static TestimonyVisibility fromJson(String? v) => switch (v) {
    'private'   => TestimonyVisibility.private,
    'followers' => TestimonyVisibility.followers,
    _           => TestimonyVisibility.public,
  };
  String toJson() => name;
}

enum TestimonyCategory {
  guerison,
  delivrance,
  conversion,
  mariage,
  famille,
  finances,
  miracles,
  protectionDivine,
  ministere,
  salut;

  static TestimonyCategory fromJson(String? v) => switch (v) {
    'delivrance'       => TestimonyCategory.delivrance,
    'conversion'       => TestimonyCategory.conversion,
    'mariage'          => TestimonyCategory.mariage,
    'famille'          => TestimonyCategory.famille,
    'finances'         => TestimonyCategory.finances,
    'miracles'         => TestimonyCategory.miracles,
    'protection-divine'=> TestimonyCategory.protectionDivine,
    'ministere'        => TestimonyCategory.ministere,
    'salut'            => TestimonyCategory.salut,
    _                  => TestimonyCategory.guerison,
  };

  String toJson() => switch (this) {
    TestimonyCategory.protectionDivine => 'protection-divine',
    _ => name,
  };

  String get label => switch (this) {
    TestimonyCategory.guerison        => 'Guérison',
    TestimonyCategory.delivrance      => 'Délivrance',
    TestimonyCategory.conversion      => 'Conversion',
    TestimonyCategory.mariage         => 'Mariage',
    TestimonyCategory.famille         => 'Famille',
    TestimonyCategory.finances        => 'Finances',
    TestimonyCategory.miracles        => 'Miracles',
    TestimonyCategory.protectionDivine=> 'Protection divine',
    TestimonyCategory.ministere       => 'Ministère',
    TestimonyCategory.salut           => 'Salut',
  };
}

// ── TestimonyStats ────────────────────────────────────────────────────────────

class TestimonyStats {
  const TestimonyStats({
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    this.bookmarksCount = 0,
  });

  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final int bookmarksCount;

  factory TestimonyStats.fromJson(Map<String, dynamic> j) => TestimonyStats(
    likesCount:     (j['likes_count']     as num?)?.toInt()
                 ?? (j['like_count']      as num?)?.toInt() ?? 0,
    commentsCount:  (j['comments_count']  as num?)?.toInt()
                 ?? (j['comment_count']   as num?)?.toInt() ?? 0,
    sharesCount:    (j['shares_count']    as num?)?.toInt() ?? 0,
    viewsCount:     (j['views_count']     as num?)?.toInt()
                 ?? (j['views']           as num?)?.toInt() ?? 0,
    bookmarksCount: (j['bookmarks_count'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'likes_count': likesCount, 'comments_count': commentsCount,
    'shares_count': sharesCount, 'views_count': viewsCount,
    'bookmarks_count': bookmarksCount,
  };
}

// ── TestimonyModel ─────────────────────────────────────────────────────────────

class TestimonyModel {
  const TestimonyModel({
    required this.id,
    required this.userId,
    this.user,
    required this.title,
    required this.content,
    this.type = TestimonyType.text,
    required this.category,
    this.mediaUrl,
    this.coverUrl,
    this.duration = 0,
    this.stats = const TestimonyStats(),
    this.status = TestimonyStatus.pending,
    this.visibility = TestimonyVisibility.public,
    this.verse,
    this.verseReference,
    this.tags = const [],
    this.isLikedByMe = false,
    this.isPrayedByMe = false,
    this.isBookmarkedByMe = false,
    this.createdAt,
    this.updatedAt,
  });

  final String           id;
  final String           userId;
  final UserModel?       user;
  final String           title;
  final String           content;
  final TestimonyType    type;
  final TestimonyCategory category;
  final String?          mediaUrl;
  final String?          coverUrl;
  final int              duration;
  final TestimonyStats   stats;
  final TestimonyStatus  status;
  final TestimonyVisibility visibility;
  final String?          verse;
  final String?          verseReference;
  final List<String>     tags;
  final bool             isLikedByMe;
  final bool             isPrayedByMe;
  final bool             isBookmarkedByMe;
  final String?          createdAt;
  final String?          updatedAt;

  // ── JSON ──────────────────────────────────────────────────────────────────────

  factory TestimonyModel.fromJson(Map<String, dynamic> j) => TestimonyModel(
    id:           j['id']      as String,
    userId:       j['user_id'] as String? ?? '',
    user:         j['user'] is Map ? UserModel.fromJson(Map<String, dynamic>.from(j['user'] as Map)) : null,
    title:        j['title']   as String? ?? '',
    content:      j['content'] as String? ?? j['body_text'] as String? ?? '',
    type:         TestimonyType.fromJson(j['type'] as String?),
    category:     TestimonyCategory.fromJson(j['category'] as String?),
    mediaUrl:     j['media_url']  as String?,
    coverUrl:     j['cover_url']  as String?,
    duration:     (j['duration']  as num?)?.toInt() ?? (j['duration_sec'] as num?)?.toInt() ?? 0,
    stats:        j['stats'] is Map
        ? TestimonyStats.fromJson(Map<String, dynamic>.from(j['stats'] as Map))
        : TestimonyStats(
            likesCount:    (j['like_count']    as num?)?.toInt() ?? 0,
            commentsCount: (j['comment_count'] as num?)?.toInt() ?? 0,
            viewsCount:    (j['views']         as num?)?.toInt() ?? 0,
          ),
    status:       TestimonyStatus.fromJson(j['status'] as String?),
    visibility:   TestimonyVisibility.fromJson(j['visibility'] as String?),
    verse:        j['verse']          as String?,
    verseReference: j['verse_reference'] as String?,
    tags:         (j['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    isLikedByMe:     j['is_liked_by_me']     as bool? ?? j['user_liked']  as bool? ?? false,
    isPrayedByMe:    j['is_prayed_by_me']    as bool? ?? j['user_prayed'] as bool? ?? false,
    isBookmarkedByMe:j['is_bookmarked_by_me'] as bool? ?? j['user_saved']  as bool? ?? false,
    createdAt:    j['created_at'] as String?,
    updatedAt:    j['updated_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'title': title, 'content': content,
    'type': type.toJson(), 'category': category.toJson(),
    if (mediaUrl != null)  'media_url': mediaUrl,
    if (coverUrl != null)  'cover_url': coverUrl,
    'duration': duration, 'stats': stats.toJson(),
    'status': status.toJson(), 'visibility': visibility.toJson(),
    if (verse != null)      'verse': verse,
    if (verseReference != null) 'verse_reference': verseReference,
    'tags': tags,
    'is_liked_by_me': isLikedByMe, 'is_prayed_by_me': isPrayedByMe,
    'is_bookmarked_by_me': isBookmarkedByMe,
    if (createdAt != null) 'created_at': createdAt,
    if (updatedAt != null) 'updated_at': updatedAt,
  };

  TestimonyModel copyWith({
    String? id, String? userId, UserModel? user, String? title, String? content,
    TestimonyType? type, TestimonyCategory? category, String? mediaUrl, String? coverUrl,
    int? duration, TestimonyStats? stats, TestimonyStatus? status,
    TestimonyVisibility? visibility, String? verse, String? verseReference,
    List<String>? tags, bool? isLikedByMe, bool? isPrayedByMe, bool? isBookmarkedByMe,
    String? createdAt, String? updatedAt,
  }) => TestimonyModel(
    id: id ?? this.id, userId: userId ?? this.userId,
    user: user ?? this.user, title: title ?? this.title,
    content: content ?? this.content, type: type ?? this.type,
    category: category ?? this.category, mediaUrl: mediaUrl ?? this.mediaUrl,
    coverUrl: coverUrl ?? this.coverUrl, duration: duration ?? this.duration,
    stats: stats ?? this.stats, status: status ?? this.status,
    visibility: visibility ?? this.visibility, verse: verse ?? this.verse,
    verseReference: verseReference ?? this.verseReference, tags: tags ?? this.tags,
    isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    isPrayedByMe: isPrayedByMe ?? this.isPrayedByMe,
    isBookmarkedByMe: isBookmarkedByMe ?? this.isBookmarkedByMe,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
  );

  @override bool operator ==(Object other) =>
      other is TestimonyModel && other.id == id;
  @override int get hashCode => id.hashCode;

  // ── Helpers ────────────────────────────────────────────────────────────────────
  bool get isAudio   => type == TestimonyType.audio;
  bool get isVideo   => type == TestimonyType.video;
  bool get isText    => type == TestimonyType.text;
  bool get isApproved=> status == TestimonyStatus.approved;
  bool get isPending => status == TestimonyStatus.pending;
  bool get isDraft   => status == TestimonyStatus.draft;

  String get formattedDuration {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
