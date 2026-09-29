// Modèles des témoignages en direct, calqués sur l'API Laravel
// (LiveSessionResource, LiveComment::toPayload, LiveService::stats).
// Doc backend : docs/fonctionnalites/lives.md

import 'package:flutter/widgets.dart' show StringCharacters;

enum LiveStatus {
  preparing,
  live,
  ended;

  static LiveStatus parse(Object? raw) => switch (raw) {
        'live'  => LiveStatus.live,
        'ended' => LiveStatus.ended,
        _       => LiveStatus.preparing,
      };
}

/// Réactions acceptées par `POST /lives/{id}/reactions`.
enum LiveReactionType {
  like('like', '❤️', "J'aime"),
  pray('pray', '🙏', 'Prière'),
  amen('amen', '🙌', 'Amen'),
  worship('worship', '🛐', 'Adorer'),
  fire('fire', '🔥', 'Feu');

  const LiveReactionType(this.apiValue, this.emoji, this.label);
  final String apiValue;
  final String emoji;
  final String label;

  static LiveReactionType? parse(Object? raw) {
    for (final t in values) {
      if (t.apiValue == raw) return t;
    }
    return null;
  }
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

/// Personne affichée (diffuseur ou auteur d'un commentaire).
class LivePerson {
  const LivePerson({
    required this.id,
    required this.displayName,
    required this.initials,
    this.avatarUrl,
  });

  factory LivePerson.fromJson(Map<String, dynamic> m) {
    final name = (m['displayName'] as String?)?.trim();
    final display = (name == null || name.isEmpty) ? 'Anonyme' : name;
    final initials = (m['initials'] as String?)?.trim();
    return LivePerson(
      id: '${m['id'] ?? ''}',
      displayName: display,
      initials: (initials == null || initials.isEmpty)
          ? display.characters.first.toUpperCase()
          : initials,
      avatarUrl: (m['avatarUrl'] as String?)?.isNotEmpty == true
          ? m['avatarUrl'] as String
          : null,
    );
  }

  final String id;
  final String displayName;
  final String initials;
  final String? avatarUrl;
}

/// Compteurs de réactions `{ like, pray, amen, fire }`.
class LiveReactionCounts {
  const LiveReactionCounts(this.values);

  factory LiveReactionCounts.fromJson(Object? raw) {
    final m = _map(raw);
    return LiveReactionCounts({
      for (final t in LiveReactionType.values) t: _int(m[t.apiValue]),
    });
  }

  static const empty = LiveReactionCounts({});

  final Map<LiveReactionType, int> values;

  int operator [](LiveReactionType t) => values[t] ?? 0;

  int get total => values.values.fold(0, (a, b) => a + b);
}

/// Statistiques d'un direct (`GET /lives/{id}/stats`, ou `liveStats`).
class LiveStats {
  const LiveStats({
    required this.status,
    required this.viewers,
    required this.peakViewers,
    required this.commentCount,
    required this.reactions,
    this.pinnedComment,
  });

  factory LiveStats.fromJson(Map<String, dynamic> m) => LiveStats(
        status: LiveStatus.parse(m['status']),
        viewers: _int(m['viewers']),
        peakViewers: _int(m['peakViewers']),
        commentCount: _int(m['commentCount']),
        reactions: LiveReactionCounts.fromJson(m['reactions']),
        pinnedComment: _commentOrNull(m['pinnedComment']),
      );

  final LiveStatus status;
  final int viewers;
  final int peakViewers;
  final int commentCount;
  final LiveReactionCounts reactions;

  /// Commentaire épinglé (null : aucun).
  final LiveComment? pinnedComment;
}

LiveComment? _commentOrNull(Object? raw) =>
    raw is Map ? LiveComment.fromJson(Map<String, dynamic>.from(raw)) : null;

/// Un direct (LiveSessionResource).
class LiveSession {
  const LiveSession({
    required this.id,
    required this.title,
    required this.status,
    required this.host,
    required this.commentsEnabled,
    required this.peakViewers,
    required this.commentCount,
    required this.reactions,
    required this.isHost,
    required this.canModerate,
    this.description,
    this.category,
    this.statusLabel,
    this.webUrl,
    this.startedAt,
    this.endedAt,
    this.endReason,
    this.createdAt,
    this.liveStats,
    this.pinnedComment,
  });

  factory LiveSession.fromJson(Map<String, dynamic> m) {
    final stats = _map(m['stats']);
    final liveStats = m['liveStats'];
    return LiveSession(
      id: '${m['id']}',
      title: (m['title'] as String?) ?? 'Direct',
      description: m['description'] as String?,
      category: m['category'] as String?,
      status: LiveStatus.parse(m['status']),
      statusLabel: m['statusLabel'] as String?,
      commentsEnabled: m['commentsEnabled'] as bool? ?? true,
      host: LivePerson.fromJson(_map(m['host'])),
      peakViewers: _int(stats['peakViewers']),
      commentCount: _int(stats['commentCount']),
      reactions: LiveReactionCounts.fromJson(stats['reactions']),
      isHost: m['isHost'] as bool? ?? false,
      canModerate: m['canModerate'] as bool? ?? false,
      webUrl: m['webUrl'] as String?,
      startedAt: _date(m['startedAt']),
      endedAt: _date(m['endedAt']),
      endReason: m['endReason'] as String?,
      createdAt: _date(m['createdAt']),
      liveStats: liveStats is Map
          ? LiveStats.fromJson(Map<String, dynamic>.from(liveStats))
          : null,
      pinnedComment: _commentOrNull(m['pinnedComment']),
    );
  }

  final String id;
  final String title;
  final String? description;
  final String? category;
  final LiveStatus status;
  final String? statusLabel;
  final bool commentsEnabled;
  final LivePerson host;
  final int peakViewers;
  final int commentCount;
  final LiveReactionCounts reactions;
  final bool isHost;
  final bool canModerate;
  final String? webUrl;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? endReason;
  final DateTime? createdAt;
  final LiveStats? liveStats;

  /// Commentaire épinglé en haut du direct (null : aucun).
  final LiveComment? pinnedComment;

  bool get isOnAir => status == LiveStatus.live;

  /// Durée du direct (en cours ou terminé).
  Duration? get duration {
    final start = startedAt;
    if (start == null) return null;
    return (endedAt ?? DateTime.now()).difference(start);
  }

  /// Motif de fin lisible (`end_reason`).
  String get endReasonLabel => liveEndReasonLabel(endReason);
}

/// Libellé d'un motif de fin (`end_reason`) ; null → message générique.
String liveEndReasonLabel(String? reason) => switch (reason) {
      'host'       => 'Terminé par le diffuseur',
      'moderator'  => 'Coupé par la modération',
      'connection' => 'Interrompu (connexion perdue)',
      'abandoned'  => "Jamais passé à l'antenne",
      _            => "Merci d'avoir suivi ce témoignage.",
    };

/// Réponse de `GET /lives`.
class LivesIndex {
  const LivesIndex({
    required this.configured,
    required this.canGoLive,
    required this.active,
    required this.recent,
  });

  factory LivesIndex.fromJson(Map<String, dynamic> m) {
    List<LiveSession> list(Object? raw) => raw is List
        ? raw
            .whereType<Map>()
            .map((e) => LiveSession.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const [];
    return LivesIndex(
      configured: m['configured'] as bool? ?? false,
      canGoLive: m['canGoLive'] as bool? ?? false,
      active: list(m['active']),
      recent: list(m['recent']),
    );
  }

  /// false : le service vidéo n'est pas configuré côté serveur.
  final bool configured;

  /// true pour les modérateurs et administrateurs.
  final bool canGoLive;
  final List<LiveSession> active;
  final List<LiveSession> recent;
}

/// Accès à la salle LiveKit (`viewer-token`, `host-token`, `video`).
class LiveCredentials {
  const LiveCredentials({
    required this.url,
    required this.token,
    required this.identity,
  });

  factory LiveCredentials.fromJson(Map<String, dynamic> m) => LiveCredentials(
        url: '${m['url'] ?? ''}',
        token: '${m['token'] ?? ''}',
        identity: '${m['identity'] ?? ''}',
      );

  final String url;
  final String token;
  final String identity;
}

class LiveComment {
  const LiveComment({
    required this.id,
    required this.body,
    required this.user,
    this.createdAt,
  });

  factory LiveComment.fromJson(Map<String, dynamic> m) => LiveComment(
        id: '${m['id']}',
        body: (m['body'] as String?) ?? '',
        createdAt: _date(m['createdAt']),
        user: LivePerson.fromJson(_map(m['user'])),
      );

  final String id;
  final String body;
  final DateTime? createdAt;
  final LivePerson user;
}

/// Qui regarde (`GET /lives/{id}/viewers`), visible de tous : comptes connectés et visiteurs.
class LiveViewers {
  const LiveViewers({this.total = 0, this.people = const [], this.anonymous = 0});

  factory LiveViewers.fromJson(Map<String, dynamic> m) {
    final people = m['people'];
    return LiveViewers(
      total: _int(m['total']),
      anonymous: _int(m['anonymous']),
      people: people is List
          ? people.whereType<Map>().map((e) => LivePerson.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
    );
  }

  final int total;
  final List<LivePerson> people;

  /// Visiteurs non connectés.
  final int anonymous;
}

// ── Intervenants (backend : docs/fonctionnalites/lives-intervenants.md) ──────

/// État d'une demande d'intervention (`live_speakers.status`).
enum LiveSpeakerStatus {
  waiting,
  invited,
  onStage,
  closed;

  static LiveSpeakerStatus parse(Object? raw) => switch (raw) {
        'waiting'  => LiveSpeakerStatus.waiting,
        'invited'  => LiveSpeakerStatus.invited,
        'on_stage' => LiveSpeakerStatus.onStage,
        _          => LiveSpeakerStatus.closed,
      };
}

/// Une demande d'intervention (file, invitation ou antenne).
class LiveSpeaker {
  const LiveSpeaker({
    required this.id,
    required this.status,
    required this.user,
    this.camera = false,
    this.position,
    this.message,
    this.expiresAt,
    this.startedAt,
    this.createdAt,
  });

  factory LiveSpeaker.fromJson(Map<String, dynamic> m) {
    final message = (m['message'] as String?)?.trim();
    return LiveSpeaker(
      id: '${m['id'] ?? ''}',
      status: LiveSpeakerStatus.parse(m['status']),
      user: LivePerson.fromJson(_map(m['user'])),
      camera: m['camera'] == true,
      position: m['position'] == null ? null : _int(m['position']),
      message: (message == null || message.isEmpty) ? null : message,
      expiresAt: _date(m['expiresAt']),
      startedAt: _date(m['startedAt']),
      createdAt: _date(m['createdAt']),
    );
  }

  final String id;
  final LiveSpeakerStatus status;
  final LivePerson user;

  /// Caméra choisie en acceptant l'invitation.
  final bool camera;

  /// Place dans la file (n° 1 = le prochain), si en attente.
  final int? position;

  /// Sujet annoncé : fourni seulement au diffuseur, aux modérateurs et à l'intéressé.
  final String? message;

  /// Fin de l'invitation : au-delà, la place passe à la personne suivante.
  final DateTime? expiresAt;
  final DateTime? startedAt;
  final DateTime? createdAt;

  bool get isOnStage => status == LiveSpeakerStatus.onStage;
  bool get isInvited => status == LiveSpeakerStatus.invited;
}

LiveSpeaker? _speakerOrNull(Object? raw) =>
    raw is Map ? LiveSpeaker.fromJson(Map<String, dynamic>.from(raw)) : null;

/// État de la scène (`GET /lives/{id}/stage` et réponse de chaque action).
/// Une seule personne invitée ou à l'antenne à la fois.
class LiveStageState {
  const LiveStageState({
    this.enabled = true,
    this.current,
    this.queueCount = 0,
    this.queue,
    this.mine,
    this.canRequest = false,
    this.refusal,
    this.inviteTimeout = 60,
  });

  factory LiveStageState.fromJson(Map<String, dynamic> m) {
    final queue = m['queue'];
    return LiveStageState(
      enabled: m['enabled'] as bool? ?? true,
      current: _speakerOrNull(m['current']),
      queueCount: _int(m['queueCount']),
      queue: queue is List
          ? queue
              .whereType<Map>()
              .map((e) => LiveSpeaker.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      mine: _speakerOrNull(m['mine']),
      canRequest: m['canRequest'] as bool? ?? false,
      refusal: m['refusal'] as String?,
      inviteTimeout: m['inviteTimeout'] == null ? 60 : _int(m['inviteTimeout']),
    );
  }

  static const empty = LiveStageState();

  /// Demandes ouvertes par le diffuseur.
  final bool enabled;

  /// Personne invitée ou à l'antenne.
  final LiveSpeaker? current;
  final int queueCount;

  /// File détaillée : seulement pour le diffuseur et les modérateurs (null sinon).
  final List<LiveSpeaker>? queue;

  /// Demande de la personne connectée.
  final LiveSpeaker? mine;
  final bool canRequest;

  /// Raison affichable quand [canRequest] est faux.
  final String? refusal;

  /// Délai pour accepter une invitation (secondes).
  final int inviteTimeout;

  /// Personne à l'antenne (pas seulement invitée).
  LiveSpeaker? get onStage => current?.isOnStage == true ? current : null;
}

/// Message temps réel reçu dans la salle (sujet `live`).
sealed class LiveEvent {
  const LiveEvent();

  /// null si le message est inconnu ou mal formé.
  static LiveEvent? fromJson(Map<String, dynamic> m) {
    switch (m['type']) {
      case 'status':
        return LiveStatusEvent(LiveStatus.parse(m['status']));
      case 'comment':
        final c = m['comment'];
        return c is Map
            ? LiveCommentEvent(
                LiveComment.fromJson(Map<String, dynamic>.from(c)))
            : null;
      case 'comment_hidden':
        return LiveCommentHiddenEvent('${m['id']}');
      case 'user_banned':
        return LiveUserBannedEvent('${m['userId']}');
      case 'reaction':
        return LiveReactionEvent(
          LiveReactionType.parse(m['reaction']),
          LiveReactionCounts.fromJson(m['counts']),
        );
      case 'comment_pinned':
        final pinned = _commentOrNull(m['comment']);
        return pinned == null ? null : LiveCommentPinnedEvent(pinned);
      case 'comment_unpinned':
        return const LiveCommentUnpinnedEvent();
      case 'ended':
        return LiveEndedEvent(m['reason'] as String?);
      case 'stage':
        return LiveStageEvent(
          '${m['event'] ?? ''}',
          _speakerOrNull(m['speaker']),
          m['reason'] as String?,
        );
    }
    return null;
  }
}

/// Intervenants : `event` ∈ requested, invited, on_stage, ended (avec `reason`),
/// cancelled, declined, expired, settings. L'état complet est rechargé à réception.
class LiveStageEvent extends LiveEvent {
  const LiveStageEvent(this.event, this.speaker, this.reason);
  final String event;
  final LiveSpeaker? speaker;

  /// Fin d'intervention : left, removed, disconnected, banned, live_ended.
  final String? reason;
}

class LiveStatusEvent extends LiveEvent {
  const LiveStatusEvent(this.status);
  final LiveStatus status;
}

class LiveCommentEvent extends LiveEvent {
  const LiveCommentEvent(this.comment);
  final LiveComment comment;
}

class LiveCommentHiddenEvent extends LiveEvent {
  const LiveCommentHiddenEvent(this.commentId);
  final String commentId;
}

class LiveUserBannedEvent extends LiveEvent {
  const LiveUserBannedEvent(this.userId);
  final String userId;
}

class LiveReactionEvent extends LiveEvent {
  const LiveReactionEvent(this.reaction, this.counts);
  final LiveReactionType? reaction;
  final LiveReactionCounts counts;
}

class LiveCommentPinnedEvent extends LiveEvent {
  const LiveCommentPinnedEvent(this.comment);
  final LiveComment comment;
}

class LiveCommentUnpinnedEvent extends LiveEvent {
  const LiveCommentUnpinnedEvent();
}

class LiveEndedEvent extends LiveEvent {
  const LiveEndedEvent(this.reason);
  final String? reason;
}
