// Événements chrétiens (croisades, conférences, séminaires, camps, tournées…),
// calqués sur l'API Laravel (EventResource, EventCommentResource).
// Doc backend : docs/fonctionnalites/evenements.md

import '../../../shared/models/mention.dart';

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
enum EventType {
  crusade('crusade', "Croisade d'évangélisation"),
  conference('conference', 'Conférence'),
  seminar('seminar', 'Séminaire'),
  camp('camp', 'Camp'),
  tour('tour', 'Tournée'),
  worship('worship', 'Concert de louange'),
  retreat('retreat', 'Retraite spirituelle'),
  other('other', 'Autre événement');

  const EventType(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static EventType parse(Object? raw) =>
      values.firstWhere((t) => t.apiValue == raw, orElse: () => EventType.other);
}

/// Publication : brouillon (gestionnaires seulement), publié, reporté (date à
/// confirmer), annulé. Un report avec nouvelle date repasse en « publié ».
enum EventStatus {
  draft('draft', 'Brouillon'),
  published('published', 'Publié'),
  postponed('postponed', 'Reporté — date à confirmer'),
  cancelled('cancelled', 'Annulé');

  const EventStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

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
    final name = _str(m['displayName']) ?? 'Anonyme';
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
  yes('yes', 'Oui, il a eu lieu'),
  no('no', "Non, il n'a pas eu lieu"),
  absent('absent', "Je n'y étais pas");

  const EventAttendance(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static EventAttendance? parse(Object? raw) {
    for (final a in values) {
      if (a.apiValue == raw) return a;
    }
    return null;
  }
}

/// Motifs de signalement d'un événement (`Event::REPORT_REASONS`).
enum EventReportReason {
  notChristian('not_christian', 'Pas un événement chrétien'),
  fake('fake', "Événement faux / n'existe pas"),
  inappropriate('inappropriate_content', 'Contenu inapproprié'),
  scam('scam', "Arnaque / demande d'argent"),
  other('other', 'Autre');

  const EventReportReason(this.apiValue, this.label);
  final String apiValue;
  final String label;
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
  String get summary => [
        if (confirmedPercent != null) "$confirmedPercent % confirment qu'il a eu lieu",
        if (ratingAverage != null) '★ ${ratingAverage!.toStringAsFixed(1).replaceAll('.', ',')}',
        '$total avis',
      ].join(' · ');
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
    this.managers = const [],
    this.live,
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
      title: _str(m['title']) ?? 'Événement',
      description: _str(m['description']),
      type: EventType.parse(m['type']),
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
      testimonyCount: _int(stats['testimonies']),
      myParticipation: EventParticipation.parse(m['myParticipation']),
      acceptsParticipation: m['acceptsParticipation'] == true,
      canManage: m['canManage'] == true,
      canAdministrate: m['canAdministrate'] == true,
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

  /// Co-gestionnaires (2 au plus), fournis aux seuls gestionnaires.
  final List<EventPerson> managers;
  final EventLiveRef? live;
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
    if (isCancelled) return 'Annulé';
    if (isDraft) return 'Brouillon';
    if (dateTbd) return 'Reporté — date à confirmer';
    return switch (phase) {
      EventPhase.ongoing => 'En cours',
      EventPhase.past => 'Terminé',
      EventPhase.upcoming => 'À venir',
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
    this.createdAt,
    this.mentions = const [],
  });

  factory EventComment.fromJson(Map<String, dynamic> m) => EventComment(
        id: '${m['id']}',
        body: '${m['body'] ?? ''}',
        user: EventPerson.fromJson(_map(m['user'])),
        testimonyId: _str(m['testimonyId']),
        isMine: m['isMine'] == true,
        createdAt: _date(m['createdAt']),
        mentions: MentionRef.listFrom(m['mentions']),
      );

  final String id;

  /// Texte lisible (« @Nom ») ; les comptes mentionnés sont dans [mentions].
  final String body;
  final EventPerson user;

  /// Comptes mentionnés (« @Nom » cliquables).
  final List<MentionRef> mentions;

  /// Enregistré comme témoignage officiel par un gestionnaire.
  final String? testimonyId;
  final bool isMine;
  final DateTime? createdAt;

  EventComment copyWith({String? testimonyId}) => EventComment(
        id: id,
        body: body,
        user: user,
        testimonyId: testimonyId ?? this.testimonyId,
        isMine: isMine,
        createdAt: createdAt,
        mentions: mentions,
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
