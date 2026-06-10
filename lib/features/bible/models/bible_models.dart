import 'package:flutter/foundation.dart';

enum DownloadStatus { notDownloaded, downloading, downloaded, error }

@immutable
class BibleTranslation {
  const BibleTranslation({
    required this.code,
    required this.name,
    required this.language,
    this.verseCount = 0,
    this.downloadStatus = DownloadStatus.notDownloaded,
    this.downloadProgress,
    this.downloadedAt,
    this.errorMessage,
  });

  final String code;
  final String name;
  final String language;
  final int verseCount;
  final DownloadStatus downloadStatus;
  final double? downloadProgress;
  final DateTime? downloadedAt;
  final String? errorMessage;

  // code IS the abbreviation on the server (e.g. "LSG", "NEG", "KJV")
  String get abbreviation => code;

  bool get isDownloaded   => downloadStatus == DownloadStatus.downloaded;
  bool get isDownloading  => downloadStatus == DownloadStatus.downloading;

  factory BibleTranslation.fromServer(
    Map<String, dynamic> json, {
    DownloadStatus downloadStatus = DownloadStatus.notDownloaded,
    DateTime? downloadedAt,
  }) {
    return BibleTranslation(
      code:       json['code']        as String,
      name:       json['name']        as String,
      language:   json['language']    as String? ?? 'fr',
      verseCount: json['versesCount'] as int?    ?? 0,
      downloadStatus: downloadStatus,
      downloadedAt:   downloadedAt,
    );
  }

  factory BibleTranslation.fromDb(Map<String, dynamic> row) {
    return BibleTranslation(
      code:       row['code']         as String,
      name:       row['name']         as String,
      language:   row['language']     as String? ?? 'fr',
      verseCount: row['verses_count'] as int?    ?? 0,
      downloadStatus: (row['is_downloaded'] as int? ?? 0) == 1
          ? DownloadStatus.downloaded
          : DownloadStatus.notDownloaded,
      downloadedAt: row['downloaded_at'] != null
          ? DateTime.tryParse(row['downloaded_at'] as String)
          : null,
    );
  }

  BibleTranslation copyWith({
    DownloadStatus? downloadStatus,
    double? downloadProgress,
    DateTime? downloadedAt,
    String? errorMessage,
    bool clearProgress = false,
    bool clearError = false,
  }) {
    return BibleTranslation(
      code:       code,
      name:       name,
      language:   language,
      verseCount: verseCount,
      downloadStatus:   downloadStatus ?? this.downloadStatus,
      downloadProgress: clearProgress ? null : (downloadProgress ?? this.downloadProgress),
      downloadedAt:     downloadedAt ?? this.downloadedAt,
      errorMessage:     clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

@immutable
class BibleBook {
  const BibleBook({
    required this.translationCode,
    required this.bookNumber,
    required this.name,
    this.chaptersCount = 0,
  });

  final String translationCode;
  final int    bookNumber;
  final String name;
  final int    chaptersCount;

  factory BibleBook.fromDb(Map<String, dynamic> row) {
    return BibleBook(
      translationCode: row['translation_code'] as String,
      bookNumber:      row['book_number']       as int,
      name:            row['name']              as String,
      chaptersCount:   row['chapters_count']    as int? ?? 0,
    );
  }
}

@immutable
class BibleVerse {
  const BibleVerse({
    required this.verseNumber,
    required this.text,
  });

  final int    verseNumber;
  final String text;

  factory BibleVerse.fromDb(Map<String, dynamic> row) {
    return BibleVerse(
      verseNumber: row['verse_number'] as int,
      text:        row['text']         as String,
    );
  }
}
