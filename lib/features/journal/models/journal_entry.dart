// Entrée du carnet privé : un témoignage (TestimonyResource) gardé pour soi.
// Doc backend : docs/fonctionnalites/carnet-prive.md

import '../../../core/app_constants.dart';

enum JournalEntryType {
  text,
  audio,
  video;

  static JournalEntryType parse(Object? raw) => switch (raw) {
        'audio' => JournalEntryType.audio,
        'video' => JournalEntryType.video,
        _       => JournalEntryType.text,
      };

  String get apiValue => name;

  String get label => switch (this) {
        JournalEntryType.text  => 'Texte',
        JournalEntryType.audio => 'Audio',
        JournalEntryType.video => 'Vidéo',
      };
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.title,
    required this.type,
    required this.body,
    required this.category,
    required this.visibility,
    required this.status,
    this.mediaUrl,
    this.coverUrl,
    this.durationSeconds = 0,
    this.bibleVerse,
    this.verseReference,
    this.shareUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> m) => JournalEntry(
        id: '${m['id']}',
        title: (m['title'] as String?)?.trim().isNotEmpty == true
            ? (m['title'] as String).trim()
            : 'Sans titre',
        type: JournalEntryType.parse(m['type']),
        body: (m['bodyText'] ?? m['body_text']) as String? ?? '',
        category: (m['category'] as String?) ?? 'autre',
        visibility: (m['visibility'] as String?) ?? 'private',
        status: (m['status'] as String?) ?? 'draft',
        mediaUrl: _absUrl((m['mediaUrl'] ?? m['media_url']) as String?),
        coverUrl: _absUrl((m['coverUrl'] ?? m['cover_url']) as String?),
        durationSeconds: _int(m['duration']),
        bibleVerse: m['bibleVerse'] as String?,
        verseReference: m['verseReference'] as String?,
        shareUrl: m['shareUrl'] as String?,
        createdAt: _date(m['createdAt']),
        updatedAt: _date(m['updatedAt']),
      );

  final String id;
  final String title;
  final JournalEntryType type;

  /// Texte (témoignage écrit) ou transcription / note (audio, vidéo).
  final String body;
  final String category;
  final String visibility;
  final String status;
  final String? mediaUrl;
  final String? coverUrl;
  final int durationSeconds;
  final String? bibleVerse;
  final String? verseReference;
  final String? shareUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Même format que l'API : sert à la copie hors ligne sur le téléphone.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.apiValue,
        'bodyText': body,
        'category': category,
        'visibility': visibility,
        'status': status,
        'mediaUrl': mediaUrl,
        'coverUrl': coverUrl,
        'duration': durationSeconds,
        'bibleVerse': bibleVerse,
        'verseReference': verseReference,
        'shareUrl': shareUrl,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  /// Encore dans le carnet (pas partagé).
  bool get isPrivate => visibility == 'private';

  /// Partagé : en attente de relecture.
  bool get isPendingReview => !isPrivate && status == 'pending';

  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static String? _absUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final root = AppConstants.webBaseUrl;
    return raw.startsWith('/') ? '$root$raw' : '$root/$raw';
  }
}

/// Une page de `GET /journal`.
class JournalPage {
  const JournalPage({
    required this.entries,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<JournalEntry> entries;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}
