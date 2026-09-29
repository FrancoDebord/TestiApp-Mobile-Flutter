/// Shared testimony domain models used by both the Home feed
/// and the Explorer results grid.
library;

import '../../../core/app_constants.dart';
import 'media_rendition.dart';

export 'media_rendition.dart';

// ── Enums ────────────────────────────────────────────────────────────────────

enum TestimonyType { text, audio, video }

enum TestimonyCategory {
  guerison,
  delivrance,
  conversion,
  mariage,
  famille,
  finances,
  miracles,
  protection,
  ministere,
  salut,
}

extension TestimonyCategoryLabel on TestimonyCategory {
  String get label => switch (this) {
        TestimonyCategory.guerison => 'Guérison',
        TestimonyCategory.delivrance => 'Délivrance',
        TestimonyCategory.conversion => 'Conversion',
        TestimonyCategory.mariage => 'Mariage',
        TestimonyCategory.famille => 'Famille',
        TestimonyCategory.finances => 'Finances',
        TestimonyCategory.miracles => 'Miracles',
        TestimonyCategory.protection => 'Protection divine',
        TestimonyCategory.ministere => 'Ministère',
        TestimonyCategory.salut => 'Salut',
      };

  String get slug => name; // already lowercase ascii
}

// ── Author ───────────────────────────────────────────────────────────────────

class TestimonyAuthor {
  const TestimonyAuthor({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
    this.isOrganization = false,
    this.isVerified = false,
  });

  final String uid;
  final String displayName;
  final String? avatarUrl;

  /// Compte organisation (église, ministère, association…).
  final bool isOrganization;

  /// Organisation vérifiée par un administrateur (badge).
  final bool isVerified;
}

// ── Stats ────────────────────────────────────────────────────────────────────

class TestimonyStats {
  const TestimonyStats({
    required this.views,
    required this.comments,
    required this.likes,
    required this.prayers,
  });

  final int views;
  final int comments;
  final int likes;
  final int prayers;

  static const zero = TestimonyStats(
    views: 0,
    comments: 0,
    likes: 0,
    prayers: 0,
  );
}

// ── Base testimony ───────────────────────────────────────────────────────────

sealed class Testimony {
  const Testimony({
    required this.id,
    required this.author,
    required this.title,
    required this.category,
    required this.createdAt,
    required this.stats,
    this.isFeatured = false,
    this.isLiked = false,
    this.isPrayed = false,
    this.isSaved = false,
    this.shareUrl,
  });

  final String id;
  final TestimonyAuthor author;
  final String title;
  final TestimonyCategory category;
  final DateTime createdAt;
  final TestimonyStats stats;
  final bool isFeatured;
  final bool isLiked;
  final bool isPrayed;
  final bool isSaved;

  /// Lien public renvoyé par l'API (`share_url`), intercepté par l'app.
  final String? shareUrl;

  /// Lien à partager : `share_url` du serveur, sinon même format que le
  /// backend (APP_URL/testimonies/{id}) pour les témoignages en cache local.
  String get shareLink => (shareUrl?.isNotEmpty ?? false)
      ? shareUrl!
      : AppConstants.testimonyWebUrl(id);

  TestimonyType get type;
}

// ── Text testimony ────────────────────────────────────────────────────────────

final class TextTestimony extends Testimony {
  const TextTestimony({
    required super.id,
    required super.author,
    required super.title,
    required super.category,
    required super.createdAt,
    required super.stats,
    required this.preview,
    this.coverImageUrl,
    this.bibleVerse,
    this.bibleVerseRef,
    super.isFeatured,
    super.isLiked,
    super.isPrayed,
    super.isSaved,
    super.shareUrl,
  });

  final String preview;
  final String? coverImageUrl;
  final String? bibleVerse;
  final String? bibleVerseRef;

  @override
  TestimonyType get type => TestimonyType.text;
}

// ── Audio testimony ────────────────────────────────────────────────────────────

final class AudioTestimony extends Testimony {
  const AudioTestimony({
    required super.id,
    required super.author,
    required super.title,
    required super.category,
    required super.createdAt,
    required super.stats,
    required this.durationSeconds,
    required this.transcriptPreview,
    this.mediaPath,
    this.renditions = const [],
    this.renditionsStatus,
    this.coverImageUrl,
    this.bibleVerse,
    this.bibleVerseRef,
    super.isFeatured,
    super.isLiked,
    super.isPrayed,
    super.isSaved,
    super.shareUrl,
  });

  final int     durationSeconds;
  final String  transcriptPreview;
  final String? mediaPath;

  /// Versions disponibles (débits), de la plus basse à la plus haute.
  /// Vide → seul [mediaPath] (fichier original) est disponible.
  final List<MediaRendition> renditions;

  /// État des versions allégées côté serveur : done, pending, processing, failed, none (ou null).
  final String? renditionsStatus;
  final String? coverImageUrl;
  final String? bibleVerse;
  final String? bibleVerseRef;

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  TestimonyType get type => TestimonyType.audio;
}

// ── Video testimony ────────────────────────────────────────────────────────────

final class VideoTestimony extends Testimony {
  const VideoTestimony({
    required super.id,
    required super.author,
    required super.title,
    required super.category,
    required super.createdAt,
    required super.stats,
    required this.durationSeconds,
    required this.thumbnailUrl,
    this.mediaPath,
    this.renditions = const [],
    this.renditionsStatus,
    this.bibleVerse,
    this.bibleVerseRef,
    super.isFeatured,
    super.isLiked,
    super.isPrayed,
    super.isSaved,
    super.shareUrl,
  });

  final int     durationSeconds;
  final String  thumbnailUrl;
  final String? mediaPath;

  /// Versions disponibles (360p, 720p…), de la plus basse à la plus haute.
  /// Vide → seul [mediaPath] (fichier original) est disponible.
  final List<MediaRendition> renditions;

  /// État des versions allégées côté serveur : done, pending, processing, failed, none (ou null).
  final String? renditionsStatus;
  final String? bibleVerse;
  final String? bibleVerseRef;

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  TestimonyType get type => TestimonyType.video;
}

// ── Daily verse ───────────────────────────────────────────────────────────────

class DailyVerse {
  const DailyVerse({
    this.id = 0,
    required this.text,
    required this.reference,
    this.likeCount  = 0,
    this.prayerCount = 0,
    this.isLiked  = false,
    this.isPrayed = false,
  });

  final int    id;
  final String text;
  final String reference;
  final int    likeCount;
  final int    prayerCount;
  final bool   isLiked;
  final bool   isPrayed;

  factory DailyVerse.fromJson(Map<String, dynamic> j) {
    String str(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return '';
    }

    return DailyVerse(
      id: (j['id'] as num?)?.toInt() ?? 0,
      text: str(['text', 'content', 'verse_text', 'verseText', 'body',
                  'scripture', 'passage']),
      reference: str(['reference', 'verse', 'citation', 'ref',
                       'verse_reference', 'verseReference', 'address',
                       'book_chapter_verse', 'location']),
      likeCount:   (j['like_count']   as num?)?.toInt() ??
                   (j['likes_count']  as num?)?.toInt() ?? 0,
      prayerCount: (j['prayer_count'] as num?)?.toInt() ??
                   (j['prayers_count'] as num?)?.toInt() ?? 0,
      isLiked:  j['is_liked']  as bool? ?? j['isLiked']  as bool? ?? false,
      isPrayed: j['is_prayed'] as bool? ?? j['isPrayed'] as bool? ?? false,
    );
  }

  DailyVerse copyWith({
    int? likeCount,
    int? prayerCount,
    bool? isLiked,
    bool? isPrayed,
  }) => DailyVerse(
    id:          id,
    text:        text,
    reference:   reference,
    likeCount:   likeCount   ?? this.likeCount,
    prayerCount: prayerCount ?? this.prayerCount,
    isLiked:     isLiked     ?? this.isLiked,
    isPrayed:    isPrayed    ?? this.isPrayed,
  );
}
