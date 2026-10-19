// Événements chrétiens (croisades, conférences, séminaires, camps, tournées…),
// calqués sur l'API Laravel (EventResource, EventCommentResource).
// Doc backend : docs/fonctionnalites/evenements.md

import '../../../shared/models/mention.dart';
import '../../repost/content_interactions.dart' show ContentReactions;
import '../../repost/repost.dart' show RepostInfo, repostInfoFromContent;
import '../../../core/media/youtube.dart' show extractYouTubeId;
import '../../../l10n/app_localizations.dart';

export '../../../shared/models/mention.dart' show MentionRef;

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

String? _str(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// Nombre décimal (`6.3702928` ou `"6.3702928"`), null sinon.
double? _double(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v.trim()) : null);

/// Nature de l'événement (`type`).
/// Type (catégorie) d'événement, géré par les administrateurs (GET /event-types,
/// docs serveur fonctionnalites/types-evenements.md) : identifiant `slug`, nom
/// dans la langue de l'application, icône. Les 8 types d'origine servent de repli
/// hors ligne ou avec un serveur plus ancien.
class EventType {
  const EventType(
    this.apiValue, {
    this.name,
    this.iconKey,
    this.id,
    this.nameFr,
    this.nameEn,
    this.position = 0,
    this.isActive = true,
    this.eventsCount = 0,
  });

  factory EventType.fromJson(Map<String, dynamic> m) => EventType(
        '${m['slug'] ?? m['value'] ?? 'other'}',
        name: _str(m['name'] ?? m['label']),
        iconKey: _str(m['icon']),
        id: (m['id'] as num?)?.toInt(),
        nameFr: _str(m['nameFr']),
        nameEn: _str(m['nameEn']),
        position: _int(m['position']),
        isActive: m['isActive'] != false,
        eventsCount: _int(m['eventsCount']),
      );

  /// Identifiant envoyé au serveur (`type` d'un événement).
  final String apiValue;

  /// Nom fourni par le serveur (déjà dans la langue de l'application).
  final String? name;

  /// Clé d'icône (bullhorn, microphone, music…), voir `eventTypeIcon`.
  final String? iconKey;

  // Gestion (administrateurs).
  final int? id;
  final String? nameFr;
  final String? nameEn;
  final int position;
  final bool isActive;
  final int eventsCount;

  static const crusade = EventType('crusade', iconKey: 'bullhorn');
  static const conference = EventType('conference', iconKey: 'microphone');
  static const seminar = EventType('seminar', iconKey: 'chalkboard');
  static const camp = EventType('camp', iconKey: 'campground');
  static const tour = EventType('tour', iconKey: 'route');
  static const worship = EventType('worship', iconKey: 'music');
  static const retreat = EventType('retreat', iconKey: 'dove');
  static const other = EventType('other', iconKey: 'calendar');

  /// Types d'origine (repli sans serveur).
  static const builtins = [crusade, conference, seminar, camp, tour, worship, retreat, other];

  static List<EventType> _registry = builtins;

  /// Types proposés (actifs, dans l'ordre choisi par l'administrateur).
  static List<EventType> get values => _registry.where((t) => t.isActive).toList();

  /// Liste reçue du serveur (eventTypesProvider) ; vide : on garde les types d'origine.
  static void register(List<EventType> types) {
    if (types.isNotEmpty) _registry = [...types]..sort((a, b) => a.position.compareTo(b.position));
  }

  String get label {
    final n = name;
    if (n != null && n.isNotEmpty) return n;
    final known = _registry.where((t) => t.apiValue == apiValue && (t.name?.isNotEmpty ?? false)).firstOrNull;
    if (known != null) return known.name!;
    final l = L10n.current;
    return switch (apiValue) {
      'crusade' => l.eventsTypeCrusade,
      'conference' => l.eventsTypeConference,
      'seminar' => l.eventsTypeSeminar,
      'camp' => l.eventsTypeCamp,
      'tour' => l.eventsTypeTour,
      'worship' => l.eventsTypeWorship,
      'retreat' => l.eventsTypeRetreat,
      'other' => l.eventsTypeOther,
      _ => apiValue.replaceAll('-', ' ').replaceAll('_', ' '),
    };
  }

  /// Clé d'icône : celle du serveur, sinon celle du type connu.
  String get icon =>
      iconKey ?? _registry.where((t) => t.apiValue == apiValue).firstOrNull?.iconKey ?? 'calendar';

  /// [label] / [icon] : `typeLabel` / `typeIcon` de l'événement.
  static EventType parse(Object? raw, {Object? label, Object? icon}) {
    final slug = _str(raw) ?? 'other';
    final known = _registry.where((t) => t.apiValue == slug).firstOrNull ??
        builtins.where((t) => t.apiValue == slug).firstOrNull;
    final l = _str(label);
    final i = _str(icon);
    if (known != null && l == null && i == null) return known;
    return EventType(slug, name: l ?? known?.name, iconKey: i ?? known?.iconKey);
  }

  @override
  bool operator ==(Object other) => other is EventType && other.apiValue == apiValue;

  @override
  int get hashCode => apiValue.hashCode;
}

/// Publication : brouillon (gestionnaires seulement), publié, reporté (date à
/// confirmer), annulé. Un report avec nouvelle date repasse en « publié ».
enum EventStatus {
  draft('draft'),
  published('published'),
  postponed('postponed'),
  cancelled('cancelled');

  const EventStatus(this.apiValue);
  final String apiValue;

  String get label {
    final l = L10n.current;
    return switch (this) {
      EventStatus.draft => l.eventsStatusDraft,
      EventStatus.published => l.eventsStatusPublished,
      EventStatus.postponed => l.eventsStatusPostponedTbc,
      EventStatus.cancelled => l.eventsStatusCancelled,
    };
  }

  static EventStatus parse(Object? raw) => values
      .firstWhere((s) => s.apiValue == raw, orElse: () => EventStatus.published);
}

/// Moment de l'événement par rapport à maintenant.
enum EventPhase {
  upcoming,
  ongoing,
  past;

  static EventPhase parse(Object? raw) => switch (raw) {
        'ongoing' => EventPhase.ongoing,
        'past' => EventPhase.past,
        _ => EventPhase.upcoming,
      };
}

/// Réponse à « Participer ».
enum EventParticipation {
  going('going'),
  notGoing('not_going');

  const EventParticipation(this.apiValue);
  final String apiValue;

  static EventParticipation? parse(Object? raw) => switch (raw) {
        'going' => EventParticipation.going,
        'not_going' => EventParticipation.notGoing,
        _ => null,
      };
}

class EventGuest {
  const EventGuest({required this.name, this.role});

  factory EventGuest.fromJson(Map<String, dynamic> m) =>
      EventGuest(name: _str(m['name']) ?? '', role: _str(m['role']));

  final String name;
  final String? role;

  Map<String, dynamic> toJson() => {'name': name, if (role != null) 'role': role};
}

class EventImage {
  const EventImage({required this.id, required this.url});

  factory EventImage.fromJson(Map<String, dynamic> m) =>
      EventImage(id: '${m['id']}', url: '${m['url'] ?? ''}');

  final String id;
  final String url;
}

/// Organisateur (organisation ou administrateur) ou auteur d'un commentaire.
class EventPerson {
  const EventPerson({
    required this.id,
    required this.displayName,
    this.initials,
    this.avatarUrl,
    this.isOrganization = false,
    this.isVerified = false,
    this.isReliable = false,
  });

  factory EventPerson.fromJson(Map<String, dynamic> m) {
    final name = _str(m['displayName']) ?? L10n.current.commonAnonymous;
    return EventPerson(
      id: '${m['id'] ?? ''}',
      displayName: name,
      initials: _str(m['initials']) ?? name.characters1,
      avatarUrl: _str(m['avatarUrl']),
      isOrganization: m['isOrganization'] == true,
      isVerified: m['isVerified'] == true,
      isReliable: m['isReliable'] == true,
    );
  }

  final String id;
  final String displayName;
  final String? initials;
  final String? avatarUrl;
  final bool isOrganization;
  final bool isVerified;

  /// Organisateur fiable : ≥ 3 événements confirmés par le sondage, aucun non confirmé
  /// (fourni sur la page d'un événement seulement).
  final bool isReliable;
}

// ── Sondage d'après l'événement, signalement, modération ─────────────────────

/// Réponse à « L'événement a-t-il eu lieu ? ».
enum EventAttendance {
  yes('yes'),
  no('no'),
  absent('absent');

  const EventAttendance(this.apiValue);
  final String apiValue;

  String get label {
    final l = L10n.current;
    return switch (this) {
      EventAttendance.yes => l.eventsAttendanceYes,
      EventAttendance.no => l.eventsAttendanceNo,
      EventAttendance.absent => l.eventsAttendanceAbsent,
    };
  }

  static EventAttendance? parse(Object? raw) {
    for (final a in values) {
      if (a.apiValue == raw) return a;
    }
    return null;
  }
}

/// Motifs de signalement d'un événement (`Event::REPORT_REASONS`).
enum EventReportReason {
  notChristian('not_christian'),
  fake('fake'),
  inappropriate('inappropriate_content'),
  scam('scam'),
  other('other');

  const EventReportReason(this.apiValue);
  final String apiValue;

  String get label {
    final l = L10n.current;
    return switch (this) {
      EventReportReason.notChristian => l.eventsReportNotChristian,
      EventReportReason.fake => l.eventsReportFake,
      EventReportReason.inappropriate => l.eventsReportInappropriate,
      EventReportReason.scam => l.eventsReportScam,
      EventReportReason.other => l.eventsReportOther,
    };
  }
}

/// Ma réponse au sondage (`survey.mine`).
class EventMyReview {
  const EventMyReview({required this.attended, this.rating, this.body, this.editableUntil, this.canEdit = false});

  factory EventMyReview.fromJson(Map<String, dynamic> m) => EventMyReview(
        attended: EventAttendance.parse(m['attended']) ?? EventAttendance.absent,
        rating: m['rating'] is num ? (m['rating'] as num).toInt() : null,
        body: _str(m['body']),
        editableUntil: _date(m['editableUntil']),
        canEdit: m['canEdit'] == true,
      );

  final EventAttendance attended;
  final int? rating;
  final String? body;
  final DateTime? editableUntil;
  final bool canEdit;
}

/// Résultats du sondage « A-t-il vraiment eu lieu ? » (`survey`).
class EventSurvey {
  const EventSurvey({
    this.open = false,
    this.canAnswer = false,
    this.yes = 0,
    this.no = 0,
    this.absent = 0,
    this.total = 0,
    this.confirmedPercent,
    this.ratingAverage,
    this.ratingCount = 0,
    this.mine,
  });

  factory EventSurvey.fromJson(Map<String, dynamic> m) {
    final mine = _map(m['mine']);
    return EventSurvey(
      open: m['open'] == true,
      canAnswer: m['canAnswer'] == true,
      yes: _int(m['yes']),
      no: _int(m['no']),
      absent: _int(m['absent']),
      total: _int(m['total']),
      confirmedPercent: m['confirmedPercent'] is num ? (m['confirmedPercent'] as num).toInt() : null,
      ratingAverage: _double(m['ratingAverage']),
      ratingCount: _int(m['ratingCount']),
      mine: mine.isEmpty ? null : EventMyReview.fromJson(mine),
    );
  }

  /// Sondage ouvert (événement publié et terminé).
  final bool open;

  /// La personne peut répondre / modifier sa réponse (pas les gestionnaires).
  final bool canAnswer;
  final int yes;
  final int no;
  final int absent;
  final int total;

  /// % de « Oui » parmi « Oui » + « Non » (null sans réponse).
  final int? confirmedPercent;
  final double? ratingAverage;
  final int ratingCount;
  final EventMyReview? mine;

  /// « 87 % confirment qu'il a eu lieu · ★ 4,6 · 23 avis ».
  String get summary {
    final l = L10n.current;
    final rating = ratingAverage?.toStringAsFixed(1);
    return [
      if (confirmedPercent != null) l.eventsSurveyConfirmedPercent(confirmedPercent!),
      if (rating != null) '★ ${l.isFr ? rating.replaceAll('.', ',') : rating}',
      l.eventsReviewCount(total),
    ].join(' · ');
  }
}

/// Avis d'un participant (`GET /events/{id}/reviews`).
class EventReviewItem {
  const EventReviewItem({
    required this.id,
    required this.user,
    required this.attended,
    this.rating,
    this.body,
    this.isMine = false,
    this.updatedAt,
  });

  factory EventReviewItem.fromJson(Map<String, dynamic> m) => EventReviewItem(
        id: '${m['id']}',
        user: EventPerson.fromJson(_map(m['user'])),
        attended: EventAttendance.parse(m['attended']) ?? EventAttendance.absent,
        rating: m['rating'] is num ? (m['rating'] as num).toInt() : null,
        body: _str(m['body']),
        isMine: m['isMine'] == true,
        updatedAt: _date(m['updatedAt']),
      );

  final String id;
  final EventPerson user;
  final EventAttendance attended;
  final int? rating;
  final String? body;
  final bool isMine;
  final DateTime? updatedAt;
}

/// Bloc des modérateurs (`moderation`) : signalements et fiabilité de l'organisateur.
class EventModerationInfo {
  const EventModerationInfo({
    this.reportCount = 0,
    this.pendingReports = 0,
    this.confirmed = 0,
    this.unconfirmed = 0,
    this.reported = 0,
    this.total = 0,
  });

  factory EventModerationInfo.fromJson(Map<String, dynamic> m) {
    final r = _map(m['reliability']);
    return EventModerationInfo(
      reportCount: _int(m['reportCount']),
      pendingReports: _int(m['pendingReports']),
      confirmed: _int(r['confirmed']),
      unconfirmed: _int(r['unconfirmed']),
      reported: _int(r['reported']),
      total: _int(r['total']),
    );
  }

  final int reportCount;
  final int pendingReports;

  /// Fiabilité de l'organisateur : événements confirmés, non confirmés, signalés, au total.
  final int confirmed;
  final int unconfirmed;
  final int reported;
  final int total;
}

extension on String {
  String get characters1 => isEmpty ? '?' : substring(0, 1).toUpperCase();
}

/// Direct de l'événement en cours (ou en préparation pour les gestionnaires).
class EventLiveRef {
  const EventLiveRef({required this.id, required this.isOnAir, this.title});

  final String id;
  final bool isOnAir;
  final String? title;
}

class ChristianEvent {
  const ChristianEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.phase,
    required this.organizer,
    this.description,
    this.startsAt,
    this.endsAt,
    this.location,
    this.city,
    this.country,
    this.address,
    this.latitude,
    this.longitude,
    this.directionsUrl,
    this.guests = const [],
    this.images = const [],
    this.commentsEnabled = true,
    this.goingCount = 0,
    this.notGoingCount = 0,
    this.commentCount = 0,
    this.testimonyCount = 0,
    this.myParticipation,
    this.acceptsParticipation = false,
    this.canManage = false,
    this.canAdministrate = false,
    this.canDelete = false,
    this.reactions = const ContentReactions(),
    this.repost,
    this.managers = const [],
    this.live,
    this.youtubeLiveId,
    this.webUrl,
    this.isPostponed = false,
    this.dateTbd = false,
    this.originalStartsAt,
    this.originalEndsAt,
    this.statusReason,
    this.isHidden = false,
    this.hiddenReason,
    this.isUnconfirmed = false,
    this.canReport = false,
    this.hasReported = false,
    this.survey = const EventSurvey(),
    this.moderation,
  });

  /// Co-gestionnaires d'un événement au plus.
  static const maxManagers = 2;

  factory ChristianEvent.fromJson(Map<String, dynamic> m) {
    final stats = _map(m['stats']);
    final live = _map(m['live']);
    return ChristianEvent(
      id: '${m['id']}',
      title: _str(m['title']) ?? L10n.current.eventsDefaultTitle,
      description: _str(m['description']),
      type: EventType.parse(m['type'], label: m['typeLabel'], icon: m['typeIcon']),
      status: EventStatus.parse(m['status']),
      phase: EventPhase.parse(m['phase']),
      startsAt: _date(m['startsAt']),
      endsAt: _date(m['endsAt']),
      location: _str(m['location']),
      city: _str(m['city']),
      country: _str(m['country']),
      address: _str(m['address']),
      latitude: _double(m['latitude']),
      longitude: _double(m['longitude']),
      directionsUrl: _str(m['directionsUrl']),
      guests: (m['guests'] is List ? m['guests'] as List : const [])
          .whereType<Map>()
          .map((g) => EventGuest.fromJson(Map<String, dynamic>.from(g)))
          .where((g) => g.name.isNotEmpty)
          .toList(),
      images: (m['images'] is List ? m['images'] as List : const [])
          .whereType<Map>()
          .map((i) => EventImage.fromJson(Map<String, dynamic>.from(i)))
          .where((i) => i.url.isNotEmpty)
          .toList(),
      commentsEnabled: m['commentsEnabled'] as bool? ?? true,
      organizer: EventPerson.fromJson(_map(m['organizer'])),
      goingCount: _int(stats['going']),
      notGoingCount: _int(stats['notGoing']),
      commentCount: _int(stats['comments']),
      // Listes d'événements passés : `testimonies_count` (témoignages publiés).
      testimonyCount: stats['testimonies'] != null ? _int(stats['testimonies']) : _int(m['testimonies_count']),
      myParticipation: EventParticipation.parse(m['myParticipation']),
      acceptsParticipation: m['acceptsParticipation'] == true,
      canManage: m['canManage'] == true,
      canAdministrate: m['canAdministrate'] == true,
      canDelete: m['canDelete'] == true || m['canAdministrate'] == true,
      reactions: ContentReactions.fromJson(m['reactions']),
      repost: repostInfoFromContent(m['repost']),
      managers: (m['managers'] is List ? m['managers'] as List : const [])
          .whereType<Map>()
          .map((p) => EventPerson.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      live: live.isEmpty
          ? null
          : EventLiveRef(
              id: '${live['id']}',
              isOnAir: live['status'] == 'live',
              title: _str(live['title']),
            ),
      youtubeLiveId: _youtubeLiveId(m['youtubeLive']),
      webUrl: _str(m['webUrl']),
      isPostponed: m['isPostponed'] == true,
      dateTbd: m['dateTbd'] == true,
      originalStartsAt: _date(m['originalStartsAt']),
      originalEndsAt: _date(m['originalEndsAt']),
      statusReason: _str(m['statusReason']),
      isHidden: m['isHidden'] == true,
      hiddenReason: _str(m['hiddenReason']),
      isUnconfirmed: m['isUnconfirmed'] == true,
      canReport: m['canReport'] == true,
      hasReported: m['hasReported'] == true,
      survey: EventSurvey.fromJson(_map(m['survey'])),
      moderation: m['moderation'] is Map
          ? EventModerationInfo.fromJson(_map(m['moderation']))
          : null,
    );
  }

  final String id;
  final String title;
  final String? description;
  final EventType type;
  final EventStatus status;
  final EventPhase phase;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? location;
  final String? city;
  final String? country;

  /// Adresse complète (rue, quartier, point de repère).
  final String? address;

  /// Repère GPS placé sur la carte (les deux ensemble, ou aucun).
  final double? latitude;
  final double? longitude;

  /// Lien d'itinéraire Google Maps calculé par le serveur (repère, sinon adresse).
  final String? directionsUrl;
  final List<EventGuest> guests;
  final List<EventImage> images;
  final bool commentsEnabled;
  final EventPerson organizer;
  final int goingCount;
  final int notGoingCount;
  final int commentCount;
  final int testimonyCount;
  final EventParticipation? myParticipation;
  final bool acceptsParticipation;
  /// Gère la page (organisateur, gestionnaires de l'organisation, co-gestionnaires, admin).
  final bool canManage;

  /// Responsable : supprimer, désigner les co-gestionnaires (pas les co-gestionnaires).
  final bool canAdministrate;

  /// Supprimer : le responsable ou un administrateur (jamais un modérateur).
  final bool canDelete;

  /// J'aime, je prie, partages (docs serveur fonctionnalites/reactions.md).
  final ContentReactions reactions;

  /// « X a partagé » (compte suivi d'abord).
  final RepostInfo? repost;

  /// Co-gestionnaires (2 au plus), fournis aux seuls gestionnaires.
  final List<EventPerson> managers;
  final EventLiveRef? live;

  /// Direct de l'événement sur YouTube (identifiant de la vidéo) : remplace les directs de l'application.
  final String? youtubeLiveId;

  /// En direct : direct de l'application à l'antenne, ou direct YouTube pendant l'événement.
  bool get isLiveNow => live?.isOnAir == true || (youtubeLiveId != null && phase == EventPhase.ongoing);

  /// Lien public du direct YouTube.
  String? get youtubeLiveUrl =>
      youtubeLiveId == null ? null : 'https://www.youtube.com/watch?v=$youtubeLiveId'; // i18n-ignore
  final String? webUrl;

  /// Reporté (nouvelle date fixée, ou date à confirmer).
  final bool isPostponed;

  /// Reporté sans nouvelle date (« Reporté — date à confirmer »).
  final bool dateTbd;

  /// Première date annoncée (affichée barrée) d'un événement reporté.
  final DateTime? originalStartsAt;
  final DateTime? originalEndsAt;

  /// Motif du report ou de l'annulation.
  final String? statusReason;

  /// Masqué par la modération (visible des seuls gestionnaires et modérateurs).
  final bool isHidden;
  final String? hiddenReason;

  /// Majorité de « Non » au sondage d'après l'événement.
  final bool isUnconfirmed;

  /// Peut signaler (connecté, pas gestionnaire, pas encore signalé).
  final bool canReport;
  final bool hasReported;
  final EventSurvey survey;

  /// Modérateurs seulement (page d'un événement).
  final EventModerationInfo? moderation;

  String? get coverUrl => images.isEmpty ? null : images.first.url;
  bool get isCancelled => status == EventStatus.cancelled;
  bool get isDraft => status == EventStatus.draft;

  /// Publié ou reporté : on peut encore le reporter ou l'annuler (s'il n'est pas terminé).
  bool get canChangeSchedule =>
      (status == EventStatus.published || status == EventStatus.postponed) && phase != EventPhase.past;

  /// « Cotonou, Bénin » / « Stade de l'Amitié · Cotonou ».
  String? get place {
    final cityCountry = [city, country].whereType<String>().join(', ');
    final parts = [location, if (cityCountry.isNotEmpty) cityCountry].whereType<String>();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Un repère GPS valide a-t-il été placé ?
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;

  /// Adresse à copier / à donner à l'application de navigation : lieu, adresse, ville, pays.
  String? get fullAddress {
    final parts = [location, address, city, country].whereType<String>().where((s) => s.trim().isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// L'événement a-t-il un lieu (adresse ou repère) ?
  bool get hasPlace => hasCoordinates || fullAddress != null;

  /// Libellé de l'état : Annulé, Brouillon, En cours, Terminé, À venir.
  String get phaseLabel {
    final l = L10n.current;
    if (isCancelled) return l.eventsStatusCancelled;
    if (isDraft) return l.eventsStatusDraft;
    if (dateTbd) return l.eventsStatusPostponedTbc;
    return switch (phase) {
      EventPhase.ongoing => l.eventsPhaseOngoing,
      EventPhase.past => l.eventsPhasePast,
      EventPhase.upcoming => l.eventsPhaseUpcoming,
    };
  }
}

/// Commentaire d'un participant (son témoignage).
class EventComment {
  const EventComment({
    required this.id,
    required this.body,
    required this.user,
    this.testimonyId,
    this.isMine = false,
    this.canDelete = false,
    this.createdAt,
    this.mentions = const [],
    this.likesCount = 0,
    this.isLikedByMe = false,
  });

  factory EventComment.fromJson(Map<String, dynamic> m) => EventComment(
        id: '${m['id']}',
        body: '${m['body'] ?? ''}',
        user: EventPerson.fromJson(_map(m['user'])),
        testimonyId: _str(m['testimonyId']),
        isMine: m['isMine'] == true,
        canDelete: m['canDelete'] == true,
        createdAt: _date(m['createdAt']),
        mentions: MentionRef.listFrom(m['mentions']),
        likesCount: _int(m['likesCount']),
        isLikedByMe: m['isLikedByMe'] == true,
      );

  final String id;

  /// « J'aime » (docs serveur fonctionnalites/jaime-commentaires.md).
  final int likesCount;
  final bool isLikedByMe;

  /// Texte lisible (« @Nom ») ; les comptes mentionnés sont dans [mentions].
  final String body;
  final EventPerson user;

  /// Comptes mentionnés (« @Nom » cliquables).
  final List<MentionRef> mentions;

  /// Enregistré comme témoignage officiel par un gestionnaire.
  final String? testimonyId;
  final bool isMine;

  /// Auteur ou administrateur (`canDelete` de l'API) ; les gestionnaires aussi (`canManage`).
  final bool canDelete;
  final DateTime? createdAt;

  EventComment copyWith({String? testimonyId}) => EventComment(
        id: id,
        body: body,
        user: user,
        testimonyId: testimonyId ?? this.testimonyId,
        isMine: isMine,
        canDelete: canDelete,
        createdAt: createdAt,
        mentions: mentions,
        likesCount: likesCount,
        isLikedByMe: isLikedByMe,
      );
}

/// Participant (liste des gestionnaires).
class EventAttendee {
  const EventAttendee({required this.person, this.respondedAt});

  factory EventAttendee.fromJson(Map<String, dynamic> m) => EventAttendee(
        person: EventPerson.fromJson(m),
        respondedAt: _date(m['respondedAt']),
      );

  final EventPerson person;
  final DateTime? respondedAt;
}

/// Page d'une liste (`meta.lastPage`, `meta.canCreate`).
class EventPage<T> {
  const EventPage({
    required this.items,
    this.page = 1,
    this.lastPage = 1,
    this.total = 0,
    this.canCreate = false,
    this.organizations = const [],
  });

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;
  final bool canCreate;

  /// Au nom de qui créer un événement (soi-même et / ou les organisations gérées).
  final List<EventPerson> organizations;

  bool get hasMore => page < lastPage;
}

/// Données du formulaire de création / modification.
class EventDraft {
  EventDraft({
    this.title = '',
    this.description = '',
    this.type = EventType.crusade,
    this.status = EventStatus.published,
    this.startsAt,
    this.endsAt,
    this.location = '',
    this.city = '',
    this.country = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.commentsEnabled = true,
    this.organizationId,
    this.youtubeLiveUrl = '',
    List<EventGuest>? guests,
  }) : guests = guests ?? [];

  factory EventDraft.fromEvent(ChristianEvent e) => EventDraft(
        title: e.title,
        description: e.description ?? '',
        type: e.type,
        status: e.status,
        startsAt: e.startsAt,
        endsAt: e.endsAt,
        location: e.location ?? '',
        city: e.city ?? '',
        country: e.country ?? '',
        address: e.address ?? '',
        latitude: e.hasCoordinates ? e.latitude : null,
        longitude: e.hasCoordinates ? e.longitude : null,
        commentsEnabled: e.commentsEnabled,
        youtubeLiveUrl: e.youtubeLiveUrl ?? '',
        guests: [...e.guests],
      );

  String title;
  String description;
  EventType type;
  EventStatus status;
  DateTime? startsAt;
  DateTime? endsAt;
  String location;
  String city;
  String country;
  String address;

  /// Repère GPS (null : aucun repère ; les deux vont ensemble).
  double? latitude;
  double? longitude;
  bool commentsEnabled;
  List<EventGuest> guests;

  /// Création au nom d'une organisation gérée (null : soi-même ou choix du serveur).
  String? organizationId;

  /// Lien YouTube du direct (vide : aucun ; toujours envoyé pour pouvoir l'effacer).
  String youtubeLiveUrl;

  Map<String, dynamic> toJson() => {
        'title': title.trim(),
        'description': description.trim().isEmpty ? null : description.trim(),
        'type': type.apiValue,
        'status': status.apiValue,
        'starts_at': startsAt?.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'location': location.trim().isEmpty ? null : location.trim(),
        'city': city.trim().isEmpty ? null : city.trim(),
        'country': country.trim().isEmpty ? null : country.trim(),
        'address': address.trim().isEmpty ? null : address.trim(),
        // Toujours envoyés : null efface le repère lors d'une modification.
        'latitude': latitude != null && longitude != null ? _round7(latitude!) : null,
        'longitude': latitude != null && longitude != null ? _round7(longitude!) : null,
        'comments_enabled': commentsEnabled,
        'youtube_live_url': youtubeLiveUrl.trim().isEmpty ? null : youtubeLiveUrl.trim(),
        'organization_id': ?organizationId,
        'guests': guests
            .where((g) => g.name.trim().isNotEmpty)
            .map((g) => EventGuest(
                  name: g.name.trim(),
                  role: (g.role ?? '').trim().isEmpty ? null : g.role!.trim(),
                ).toJson())
            .toList(),
      };
}

/// `youtubeLive: { id, url, embedUrl, thumbnailUrl }` (ou null) → identifiant de la vidéo.
String? _youtubeLiveId(Object? v) {
  if (v is Map) return _str(v['id']) ?? extractYouTubeId(_str(v['url']));
  return null;
}

/// Coordonnée arrondie à 7 décimales (précision de la colonne decimal(10,7)).
double _round7(double v) => (v * 1e7).roundToDouble() / 1e7;

/// Gestionnaires d'une organisation (`GET /users/me/managers`).
class OrganizationManagers {
  const OrganizationManagers({required this.managers, this.max = 2});

  factory OrganizationManagers.fromJson(Map<String, dynamic> m) => OrganizationManagers(
        max: _int(m['max']) == 0 ? 2 : _int(m['max']),
        managers: (m['managers'] is List ? m['managers'] as List : const [])
            .whereType<Map>()
            .map((p) => EventPerson.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
      );

  final List<EventPerson> managers;
  final int max;
}
