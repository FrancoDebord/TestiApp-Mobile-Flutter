// Verset du jour en plein écran : versions de la Bible et commentaires.
// Docs serveur : fonctionnalites/verset-du-jour.md

import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/models/mention.dart';
import 'verse_reference.dart';

/// Un verset numéroté d'un passage.
@immutable
class VerseLine {
  const VerseLine(this.verse, this.text);
  final int verse;
  final String text;
}

/// Le passage du jour dans une traduction (`GET /daily-verse/{id}/versions`).
@immutable
class VerseVersion {
  const VerseVersion({
    required this.code,
    required this.name,
    this.language,
    this.bookName,
    this.reference,
    this.lines = const [],
  });

  final String code;
  final String name;
  final String? language;

  /// Nom du livre dans la langue de la traduction (« John » en KJV) ; null : serveur ancien.
  final String? bookName;

  /// Référence dans la langue de la traduction (« John 3:16 ») ; null : serveur ancien.
  final String? reference;

  /// Versets présents dans cette traduction ([] : passage absent).
  final List<VerseLine> lines;

  bool get available => lines.isNotEmpty;

  /// Texte continu du passage (null si absent).
  String? get text => available ? lines.map((l) => l.text).join(' ') : null;

  factory VerseVersion.fromJson(Map<String, dynamic> j) {
    final raw = j['verses'];
    final lines = raw is List
        ? raw
            .whereType<Map>()
            .map((m) => VerseLine((m['verse'] as num?)?.toInt() ?? 0, '${m['text'] ?? ''}'.trim()))
            .where((l) => l.text.isNotEmpty)
            .toList()
        : <VerseLine>[];
    // Ancien format : seulement `text`.
    if (lines.isEmpty && j['text'] is String && (j['text'] as String).isNotEmpty) {
      lines.add(VerseLine(0, j['text'] as String));
    }
    return VerseVersion(
      code: '${j['code'] ?? ''}',
      name: '${j['name'] ?? j['code'] ?? ''}',
      language: j['language'] as String?,
      bookName: (j['bookName'] as String?)?.trim().isNotEmpty == true ? j['bookName'] as String : null,
      reference: (j['reference'] as String?)?.trim().isNotEmpty == true ? j['reference'] as String : null,
      lines: lines,
    );
  }
}

/// Toutes les versions du passage du jour.
@immutable
class DailyVerseVersions {
  const DailyVerseVersions({
    required this.reference,
    required this.originalText,
    this.parsed,
    this.versions = const [],
    this.offline = false,
  });

  /// Référence saisie par l'équipe (« Jean 3 : 16 »).
  final String reference;

  /// Texte du jour saisi par l'équipe (toujours disponible).
  final String originalText;

  /// Référence reconnue (null : seules les données du jour sont proposées).
  final VerseReference? parsed;

  final List<VerseVersion> versions;

  /// Vrai si la liste vient des Bibles téléchargées (pas de connexion).
  final bool offline;

  VerseVersion? byCode(String? code) {
    if (code == null) return null;
    for (final v in versions) {
      if (v.code == code) return v;
    }
    return null;
  }

  factory DailyVerseVersions.fromJson(
    Map<String, dynamic> j, {
    required String fallbackText,
  }) {
    final parsedRaw = j['parsed'];
    VerseReference? parsed;
    if (parsedRaw is Map) {
      int n(Object? v) => v is num ? v.toInt() : 0;
      final book = n(parsedRaw['book']);
      if (book > 0) {
        parsed = VerseReference(
          book: book,
          chapter: n(parsedRaw['chapter']),
          verseStart: n(parsedRaw['verseStart']),
          verseEnd: n(parsedRaw['verseEnd']),
        );
      }
    }
    final original = j['original'] is Map ? j['original'] as Map : const {};
    final raw = j['versions'];
    return DailyVerseVersions(
      reference: '${j['reference'] ?? ''}',
      originalText: (original['text'] as String?)?.trim().isNotEmpty == true
          ? original['text'] as String
          : fallbackText,
      parsed: parsed,
      versions: raw is List
          ? raw.whereType<Map>().map((m) => VerseVersion.fromJson(Map<String, dynamic>.from(m))).toList()
          : const [],
    );
  }
}

/// Commentaire sous le verset du jour.
@immutable
class VerseComment {
  const VerseComment({
    required this.id,
    required this.body,
    required this.authorName,
    this.mentions = const [],
    this.authorId,
    this.avatarUrl,
    this.isVerified = false,
    this.createdAt,
    this.isMine = false,
    this.isHidden = false,
    this.canDelete = false,
    this.canReport = false,
    this.likesCount = 0,
    this.isLikedByMe = false,
  });

  final String id;
  final String body;
  final String authorName;

  /// « J'aime » (docs serveur fonctionnalites/jaime-commentaires.md).
  final int likesCount;
  final bool isLikedByMe;

  /// Comptes mentionnés (« @Nom » cliquables) — docs serveur fonctionnalites/mentions.md
  final List<MentionRef> mentions;
  final String? authorId;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime? createdAt;
  final bool isMine;
  final bool isHidden;
  final bool canDelete;
  final bool canReport;

  String get initials {
    final parts = authorName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  factory VerseComment.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? Map<String, dynamic>.from(j['user'] as Map) : const <String, dynamic>{};
    return VerseComment(
      id: '${j['id']}',
      body: '${j['body'] ?? ''}',
      authorName: (user['displayName'] as String?) ?? L10n.current.verseMember,
      mentions: MentionRef.listFrom(j['mentions']),
      authorId: user['id'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      isVerified: user['isVerified'] == true,
      createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal(),
      isMine: j['isMine'] == true,
      isHidden: j['isHidden'] == true,
      canDelete: j['canDelete'] == true,
      canReport: j['canReport'] == true,
      likesCount: (j['likesCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: j['isLikedByMe'] == true,
    );
  }
}

/// Raisons de signalement d'un commentaire (mêmes codes que le serveur).
/// Getter : les libellés suivent la langue affichée.
Map<String, String> get kVerseCommentReportReasons {
  final l10n = L10n.current;
  return {
    'inappropriate_content': l10n.prayerReportInappropriate,
    'hate_speech': l10n.prayerReportHate,
    'spam': l10n.prayerReportSpam,
    'other': l10n.prayerReportOther,
  };
}
