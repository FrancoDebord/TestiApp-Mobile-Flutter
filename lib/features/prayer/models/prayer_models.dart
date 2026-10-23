// Requêtes et sessions de prière — modèles lus depuis l'API.
// Docs serveur : fonctionnalites/requetes-de-priere.md, fonctionnalites/sessions-de-priere.md

import '../../../l10n/app_localizations.dart';
import '../../../shared/models/mention.dart';
import '../../repost/content_interactions.dart' show ContentReactions;
import '../../repost/repost.dart' show RepostInfo, repostInfoFromContent;

/// Qui peut voir une requête (ou une session : pas de « privé »).
enum PrayerVisibility {
  public('public'),
  followers('followers'),
  private('private');

  const PrayerVisibility(this.apiValue);
  final String apiValue;

  String get label => switch (this) {
        PrayerVisibility.public => L10n.current.prayerVisibilityPublic,
        PrayerVisibility.followers => L10n.current.prayerVisibilityFollowers,
        PrayerVisibility.private => L10n.current.prayerVisibilityPrivate,
      };

  static PrayerVisibility parse(Object? v) => switch (v) {
        'followers' => PrayerVisibility.followers,
        'private' => PrayerVisibility.private,
        _ => PrayerVisibility.public,
      };
}

/// Raisons de signalement acceptées par `POST /prayer/requests/{id}/report`.
enum PrayerReportReason {
  inappropriateContent('inappropriate_content'),
  hateSpeech('hate_speech'),
  spam('spam'),
  other('other');

  const PrayerReportReason(this.apiValue);
  final String apiValue;

  String get label => switch (this) {
        PrayerReportReason.inappropriateContent => L10n.current.prayerReportInappropriate,
        PrayerReportReason.hateSpeech => L10n.current.prayerReportHate,
        PrayerReportReason.spam => L10n.current.prayerReportSpam,
        PrayerReportReason.other => L10n.current.prayerReportOther,
      };
}

// ── Outils de lecture ─────────────────────────────────────────────────────────

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

String? _str(Object? v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// Initiales d'un nom (« Jean Dupont » → « JD »).
String prayerInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}

/// « à l'instant », « il y a 5 min », « il y a 3 h », « il y a 2 j », puis la date.
String prayerTimeAgo(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  final diff = (now ?? DateTime.now()).difference(date);
  final l = L10n.current;
  if (diff.inMinutes < 1) return l.timeJustNow;
  if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
  if (diff.inDays < 30) return l.timeDaysAgo(diff.inDays);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

// ── Personnes ─────────────────────────────────────────────────────────────────

/// Auteur d'une requête, d'un message ou hôte d'une session.
class PrayerPerson {
  const PrayerPerson({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isVerified = false,
    this.isOrganization = false,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
  final bool isOrganization;

  String get initials => prayerInitials(displayName);

  factory PrayerPerson.fromJson(Map<String, dynamic> j) => PrayerPerson(
        id: '${j['id'] ?? ''}',
        displayName: _str(j['displayName']) ?? _str(j['name']) ?? L10n.current.prayerDefaultUser,
        avatarUrl: _str(j['avatarUrl']) ?? _str(j['avatar']),
        isVerified: j['isVerified'] == true,
        isOrganization: j['isOrganization'] == true,
      );
}

/// Événement de rattachement ({ id, title }).
class PrayerEventRef {
  const PrayerEventRef({required this.id, required this.title});
  final String id;
  final String title;

  static PrayerEventRef? fromJson(Object? v) {
    final j = _map(v);
    if (j['id'] == null) return null;
    return PrayerEventRef(id: '${j['id']}', title: _str(j['title']) ?? L10n.current.prayerDefaultEvent);
  }
}

/// Témoignage depuis lequel une requête est confiée ({ id, title }) ; absent si le
/// témoignage n'est plus publié.
class PrayerTestimonyRef {
  const PrayerTestimonyRef({required this.id, required this.title});
  final String id;
  final String title;

  static PrayerTestimonyRef? fromJson(Object? v) {
    final j = _map(v);
    if (j['id'] == null) return null;
    return PrayerTestimonyRef(id: '${j['id']}', title: _str(j['title']) ?? '');
  }
}

// ── Requête de prière ─────────────────────────────────────────────────────────

/// Requête de prière (PrayerRequestResource). [author] est null si elle est
/// anonyme (sauf pour son auteur et la modération).
class PrayerRequest {
  const PrayerRequest({
    required this.id,
    required this.body,
    required this.createdAt,
    this.author,
    this.visibility = PrayerVisibility.public,
    this.isAnonymous = false,
    this.isAnswered = false,
    this.answeredAt,
    this.answerNote,
    this.testimonyId,
    this.prayerCount = 0,
    this.messageCount = 0,
    this.hasPrayed = false,
    this.event,
    this.sourceTestimony,
    this.isMine = false,
    this.isHidden = false,
    this.hiddenReason,
    this.canEdit = false,
    this.canDelete = false,
    this.canReport = false,
    this.canModerate = false,
    this.canMessage = false,
    this.webUrl,
    this.mentions = const [],
    this.reactions = const ContentReactions(),
    this.repost,
  });

  final String id;
  final String body;

  /// Comptes mentionnés dans [body] (« @Nom » cliquable) — docs serveur fonctionnalites/mentions.md
  final List<MentionRef> mentions;
  final DateTime? createdAt;
  final PrayerPerson? author;
  final PrayerVisibility visibility;
  final bool isAnonymous;
  final bool isAnswered;
  final DateTime? answeredAt;
  final String? answerNote;
  final String? testimonyId;
  final int prayerCount;
  final int messageCount;
  final bool hasPrayed;
  final PrayerEventRef? event;

  /// Témoignage de quelqu'un depuis lequel la requête a été confiée (≠ [testimonyId], l'exaucement).
  final PrayerTestimonyRef? sourceTestimony;
  final bool isMine;
  final bool isHidden;
  final String? hiddenReason;
  final bool canEdit;
  final bool canDelete;
  final bool canReport;
  final bool canModerate;
  final bool canMessage;
  final String? webUrl;

  /// J'aime et partages (« Je prie » : [prayerCount], [hasPrayed]).
  final ContentReactions reactions;

  /// « X a partagé » (compte suivi d'abord).
  final RepostInfo? repost;

  /// Nom affiché : « Anonyme » si l'auteur est masqué.
  String get authorName => author?.displayName ?? L10n.current.commonAnonymous;

  factory PrayerRequest.fromJson(Map<String, dynamic> j) {
    final author = _map(j['author']);
    return PrayerRequest(
      id: '${j['id']}',
      body: _str(j['body']) ?? '',
      createdAt: _date(j['createdAt']),
      author: author.isEmpty ? null : PrayerPerson.fromJson(author),
      visibility: PrayerVisibility.parse(j['visibility']),
      isAnonymous: j['isAnonymous'] == true,
      isAnswered: j['isAnswered'] == true || j['status'] == 'answered',
      answeredAt: _date(j['answeredAt']),
      answerNote: _str(j['answerNote']),
      testimonyId: _str(j['testimonyId']),
      prayerCount: _int(j['prayerCount']),
      messageCount: _int(j['messageCount']),
      hasPrayed: j['hasPrayed'] == true,
      event: PrayerEventRef.fromJson(j['event']),
      sourceTestimony: PrayerTestimonyRef.fromJson(j['sourceTestimony']),
      isMine: j['isMine'] == true,
      isHidden: j['isHidden'] == true,
      hiddenReason: _str(j['hiddenReason']),
      canEdit: j['canEdit'] == true,
      canDelete: j['canDelete'] == true,
      canReport: j['canReport'] == true,
      canModerate: j['canModerate'] == true,
      canMessage: j['canMessage'] == true,
      webUrl: _str(j['webUrl']),
      mentions: MentionRef.listFrom(j['mentions']),
      reactions: ContentReactions.fromJson(j['reactions']),
      repost: repostInfoFromContent(j['repost']),
    );
  }

  /// État local après « Je prie » (mise à jour immédiate, avant la réponse du serveur).
  PrayerRequest withPrayed(bool prayed) => prayed == hasPrayed
      ? this
      : PrayerRequest(
          id: id,
          body: body,
          createdAt: createdAt,
          author: author,
          visibility: visibility,
          isAnonymous: isAnonymous,
          isAnswered: isAnswered,
          answeredAt: answeredAt,
          answerNote: answerNote,
          testimonyId: testimonyId,
          prayerCount: (prayerCount + (prayed ? 1 : -1)).clamp(0, 1 << 31),
          messageCount: messageCount,
          hasPrayed: prayed,
          event: event,
          sourceTestimony: sourceTestimony,
          isMine: isMine,
          isHidden: isHidden,
          hiddenReason: hiddenReason,
          canEdit: canEdit,
          canDelete: canDelete,
          canReport: canReport,
          canModerate: canModerate,
          canMessage: canMessage,
          webUrl: webUrl,
          mentions: mentions,
          reactions: reactions,
          repost: repost,
        );
}

/// Message d'encouragement sous une requête.
class PrayerMessage {
  const PrayerMessage({
    required this.id,
    required this.body,
    required this.author,
    this.bibleReference,
    this.createdAt,
    this.isMine = false,
    this.canDelete = false,
    this.mentions = const [],
  });

  final String id;
  final String body;

  /// Comptes mentionnés (« @Nom » cliquable) — docs serveur fonctionnalites/mentions.md
  final List<MentionRef> mentions;
  final PrayerPerson author;
  final String? bibleReference;
  final DateTime? createdAt;
  final bool isMine;
  final bool canDelete;

  factory PrayerMessage.fromJson(Map<String, dynamic> j) => PrayerMessage(
        id: '${j['id']}',
        body: _str(j['body']) ?? '',
        author: PrayerPerson.fromJson(_map(j['author'])),
        bibleReference: _str(j['bibleReference']),
        createdAt: _date(j['createdAt']),
        isMine: j['isMine'] == true,
        canDelete: j['canDelete'] == true,
        mentions: MentionRef.listFrom(j['mentions']),
      );
}

/// Brouillon d'une requête (création).
class PrayerRequestDraft {
  PrayerRequestDraft({
    this.body = '',
    this.visibility = PrayerVisibility.public,
    this.isAnonymous = false,
    this.eventId,
    this.dailyVerseId,
    this.sourceTestimonyId,
  });

  String body;
  PrayerVisibility visibility;
  bool isAnonymous;
  String? eventId;

  /// Verset du jour de rattachement (docs serveur fonctionnalites/verset-du-jour.md).
  int? dailyVerseId;

  /// Témoignage publié depuis lequel la requête est confiée (création seulement).
  String? sourceTestimonyId;

  Map<String, dynamic> toJson() => {
        'body': body.trim(),
        'visibility': visibility.apiValue,
        'is_anonymous': isAnonymous,
        'event_id': ?eventId,
        'daily_verse_id': ?dailyVerseId,
        'source_testimony_id': ?sourceTestimonyId,
      };
}

// ── Session de prière ─────────────────────────────────────────────────────────

/// Phase d'une session, calculée par le serveur.
enum PrayerSessionPhase {
  upcoming,
  live,
  ended,
  cancelled;

  String get label => switch (this) {
        PrayerSessionPhase.upcoming => L10n.current.prayerPhaseUpcoming,
        PrayerSessionPhase.live => L10n.current.prayerPhaseLive,
        PrayerSessionPhase.ended => L10n.current.prayerPhaseEnded,
        PrayerSessionPhase.cancelled => L10n.current.prayerPhaseCancelled,
      };

  static PrayerSessionPhase parse(Object? v) => switch (v) {
        'live' => PrayerSessionPhase.live,
        'ended' => PrayerSessionPhase.ended,
        'cancelled' => PrayerSessionPhase.cancelled,
        _ => PrayerSessionPhase.upcoming,
      };
}

/// Session de prière (PrayerSessionResource). La salle est un direct :
/// [liveId] renseigné quand elle est ouverte (écran `/lives/{id}`, studio pour l'hôte).
class PrayerSession {
  const PrayerSession({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.host,
    this.description,
    this.topics = const [],
    this.durationMinutes = 60,
    this.visibility = PrayerVisibility.public,
    this.phase = PrayerSessionPhase.upcoming,
    this.event,
    this.participantCount = 0,
    this.isRegistered = false,
    this.isHost = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canStart = false,
    this.opensAt,
    this.liveId,
    this.liveStatus,
    this.webUrl,
    this.reactions = const ContentReactions(),
    this.repost,
  });

  final String id;
  final String title;
  final String? description;
  final List<String> topics;
  final DateTime startsAt;
  final DateTime endsAt;
  final int durationMinutes;
  final PrayerVisibility visibility;
  final PrayerSessionPhase phase;
  final PrayerPerson host;
  final PrayerEventRef? event;
  final int participantCount;
  final bool isRegistered;
  final bool isHost;
  final bool canEdit;
  final bool canDelete;
  final bool canStart;
  final DateTime? opensAt;
  final String? liveId;

  /// `preparing` (studio de l'hôte) ou `live` (à l'antenne).
  final String? liveStatus;
  final String? webUrl;

  /// J'aime, je prie, partages (docs serveur fonctionnalites/reactions.md).
  final ContentReactions reactions;

  /// « X a partagé » (compte suivi d'abord).
  final RepostInfo? repost;

  bool get isLive => phase == PrayerSessionPhase.live;
  bool get isOver => phase == PrayerSessionPhase.ended || phase == PrayerSessionPhase.cancelled;
  bool get hasRoom => liveId != null;

  factory PrayerSession.fromJson(Map<String, dynamic> j) {
    final live = _map(j['live']);
    final starts = _date(j['startsAt']) ?? DateTime.now();
    return PrayerSession(
      id: '${j['id']}',
      title: _str(j['title']) ?? L10n.current.prayerSessionDefaultTitle,
      description: _str(j['description']),
      topics: (j['topics'] is List ? j['topics'] as List : const [])
          .map((e) => '$e')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      startsAt: starts,
      endsAt: _date(j['endsAt']) ?? starts.add(Duration(minutes: _int(j['durationMinutes']))),
      durationMinutes: _int(j['durationMinutes']),
      visibility: PrayerVisibility.parse(j['visibility']),
      phase: PrayerSessionPhase.parse(j['phase']),
      host: PrayerPerson.fromJson(_map(j['host'])),
      event: PrayerEventRef.fromJson(j['event']),
      participantCount: _int(j['participantCount']),
      isRegistered: j['isRegistered'] == true,
      isHost: j['isHost'] == true,
      canEdit: j['canEdit'] == true,
      canDelete: j['canDelete'] == true,
      canStart: j['canStart'] == true,
      opensAt: _date(j['opensAt']),
      liveId: _str(live['id']),
      liveStatus: _str(live['status']),
      webUrl: _str(j['webUrl']),
      reactions: ContentReactions.fromJson(j['reactions']),
      repost: repostInfoFromContent(j['repost']),
    );
  }
}

/// Brouillon d'une session (création / modification).
class PrayerSessionDraft {
  PrayerSessionDraft({
    this.title = '',
    this.description = '',
    List<String>? topics,
    required this.startsAt,
    this.durationMinutes = 60,
    this.visibility = PrayerVisibility.public,
    this.eventId,
  }) : topics = topics ?? [];

  factory PrayerSessionDraft.from(PrayerSession s) => PrayerSessionDraft(
        title: s.title,
        description: s.description ?? '',
        topics: [...s.topics],
        startsAt: s.startsAt,
        durationMinutes: s.durationMinutes,
        visibility: s.visibility,
        eventId: s.event?.id,
      );

  String title;
  String description;
  List<String> topics;
  DateTime startsAt;
  int durationMinutes;
  PrayerVisibility visibility;
  String? eventId;

  Map<String, dynamic> toJson() => {
        'title': title.trim(),
        'description': description.trim().isEmpty ? null : description.trim(),
        'topics': topics.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
        'starts_at': startsAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        // Pas de session « privée » : moi seul n'a pas de sens pour prier ensemble.
        'visibility': visibility == PrayerVisibility.followers ? 'followers' : 'public',
        'event_id': ?eventId,
      };
}

/// Page d'une liste paginée de l'API (`meta.currentPage`, `meta.lastPage`…).
class PrayerPage<T> {
  const PrayerPage({
    required this.items,
    this.page = 1,
    this.lastPage = 1,
    this.total = 0,
    this.canCreate = false,
  });

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;
  final bool canCreate;

  bool get hasMore => page < lastPage;
}
