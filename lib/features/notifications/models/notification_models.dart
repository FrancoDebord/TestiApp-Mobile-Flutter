// =============================================================================
// Notifications feature — domain models
// =============================================================================

enum NotificationType {
  comment,
  like,
  prayer,
  approved,
  newFollowedTestimony,
  pendingCorrection,
  organizationVerified,
  organizationRejected,
  // Compte personnel vérifié / demande refusée ou vérification retirée
  // (docs/fonctionnalites/verification-des-comptes.md).
  accountVerified,
  accountVerificationRejected,
  liveStarted,
  // Événement : reporté, annulé, sondage d'après l'événement (types event_*).
  event,
  // Nouvel abonné, partage d'un de mes témoignages, mention « @ » (commentaire de
  // témoignage, d'événement, de direct, message de prière, verset du jour).
  follow,
  share,
  mention,
  // Témoignage refusé par la modération (le motif est dans le message).
  rejected,
  // Administrateurs de compte : on m'a nommé / retiré administrateur d'un compte
  // (types account_manager_added / account_manager_removed, système).
  accountManagerAdded,
  accountManagerRemoved,
}

extension NotificationTypeLabel on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.comment:
        return 'Commentaire';
      case NotificationType.like:
        return 'Like';
      case NotificationType.prayer:
        return 'Prière';
      case NotificationType.approved:
        return 'Approuvé';
      case NotificationType.newFollowedTestimony:
        return 'Nouveau témoignage';
      case NotificationType.pendingCorrection:
        return 'Correction requise';
      case NotificationType.organizationVerified:
        return 'Organisation vérifiée';
      case NotificationType.organizationRejected:
        return 'Vérification refusée';
      case NotificationType.accountVerified:
        return 'Compte vérifié';
      case NotificationType.accountVerificationRejected:
        return 'Vérification du compte';
      case NotificationType.liveStarted:
        return 'En direct';
      case NotificationType.event:
        return 'Événement';
      case NotificationType.follow:
        return 'Abonné';
      case NotificationType.share:
        return 'Partage';
      case NotificationType.mention:
        return 'Mention';
      case NotificationType.rejected:
        return 'Refusé';
      case NotificationType.accountManagerAdded:
      case NotificationType.accountManagerRemoved:
        return 'Administrateurs';
    }
  }
}

/// Onglets du filtre de l'écran Notifications (maquette : Toutes / Nouveaux /
/// Populaires). « Nouveaux » = non lues ; « Populaires » = réactions (j'aime,
/// prières).
enum NotificationFilterTab { all, unread, popular }

extension NotificationFilterLabel on NotificationFilterTab {
  String get label {
    switch (this) {
      case NotificationFilterTab.all:
        return 'Toutes';
      case NotificationFilterTab.unread:
        return 'Nouveaux';
      case NotificationFilterTab.popular:
        return 'Populaires';
    }
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.actorName,
    required this.testimonyTitle,
    required this.createdAt,
    this.actorAvatarUrl,
    this.testimonyThumbnailUrl,
    this.isRead = false,
    this.testimonyId,
    this.liveId,
    this.message,
    this.prayerRequestId,
    this.prayerSessionId,
    this.eventId,
    this.actorId,
    this.dailyVerseId,
  });

  final String id;
  final NotificationType type;
  final String actorName;
  final String testimonyTitle;
  final DateTime createdAt;
  final String? actorAvatarUrl;
  final String? testimonyThumbnailUrl;
  final bool isRead;

  /// Témoignage concerné (null pour les notifications système / direct).
  final String? testimonyId;

  /// Direct annoncé (type live_started uniquement).
  final String? liveId;

  /// Message pré-rédigé par le serveur (peut être null / vide).
  final String? message;

  /// Requête / session de prière concernée (types prayer_*, docs serveur
  /// fonctionnalites/requetes-de-priere.md, sessions-de-priere.md).
  final String? prayerRequestId;
  final String? prayerSessionId;

  /// Événement concerné (types event_*, mention dans un commentaire d'événement).
  final String? eventId;

  /// Compte à l'origine de la notification (nouvel abonné : ouvre son profil).
  final String? actorId;

  /// Verset du jour (mention dans un commentaire du verset).
  final String? dailyVerseId;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      actorName: actorName,
      testimonyTitle: testimonyTitle,
      createdAt: createdAt,
      actorAvatarUrl: actorAvatarUrl,
      testimonyThumbnailUrl: testimonyThumbnailUrl,
      isRead: isRead ?? this.isRead,
      testimonyId: testimonyId,
      liveId: liveId,
      message: message,
      prayerRequestId: prayerRequestId,
      prayerSessionId: prayerSessionId,
      eventId: eventId,
      actorId: actorId,
      dailyVerseId: dailyVerseId,
    );
  }

  /// Texte rédigé par le serveur (contient déjà le nom de l'auteur), sinon [fallback].
  String _serverMessageOr(String fallback) {
    final msg = message?.trim() ?? '';
    return msg.isNotEmpty ? msg : fallback;
  }

  /// Réaction ou partage d'un événement, d'une requête ou d'une session de prière
  /// (pas d'un témoignage) : le serveur rédige le texte.
  bool get _aboutOtherContent =>
      testimonyId == null && (eventId != null || prayerRequestId != null || prayerSessionId != null);

  String get body {
    switch (type) {
      case NotificationType.comment:
        return '$actorName a commenté votre témoignage « $testimonyTitle »';
      case NotificationType.like:
        if (_aboutOtherContent) return _serverMessageOr('$actorName a réagi à votre publication');
        return '$actorName a aimé votre témoignage « $testimonyTitle »';
      case NotificationType.prayer:
        // Requêtes, sessions de prière et événements : texte rédigé par le serveur.
        final prayerMsg = message?.trim() ?? '';
        if ((prayerRequestId != null || prayerSessionId != null || eventId != null) && prayerMsg.isNotEmpty) {
          // Le nom n'est ajouté que si le serveur ne l'a pas déjà mis (prayer_request_prayed :
          // « {Nom} prie pour votre requête de prière »).
          return actorName.isNotEmpty && !prayerMsg.startsWith(actorName)
              ? '$actorName $prayerMsg'
              : prayerMsg;
        }
        return '$actorName prie pour vous suite à « $testimonyTitle »';
      case NotificationType.approved:
        return 'Votre témoignage « $testimonyTitle » a été approuvé';
      case NotificationType.newFollowedTestimony:
        return '$actorName a partagé un nouveau témoignage « $testimonyTitle »';
      case NotificationType.pendingCorrection:
        return 'Votre témoignage « $testimonyTitle » nécessite des corrections';
      case NotificationType.organizationVerified:
        return 'Votre organisation a été vérifiée : le badge est maintenant visible';
      case NotificationType.organizationRejected:
        return 'La vérification de votre organisation a été refusée';
      case NotificationType.accountVerified:
        return _serverMessageOr('Votre compte est vérifié : le badge est maintenant visible');
      case NotificationType.accountVerificationRejected:
        return _serverMessageOr('La vérification de votre compte a été refusée');
      case NotificationType.liveStarted:
        final msg = message?.trim() ?? '';
        if (msg.isNotEmpty) return msg;
        return testimonyTitle.isNotEmpty
            ? '$actorName est en direct : $testimonyTitle'
            : '$actorName est en direct';
      case NotificationType.event:
        return message?.trim() ?? '';
      case NotificationType.follow:
        return _serverMessageOr('$actorName vous suit maintenant');
      case NotificationType.share:
        return _serverMessageOr(testimonyTitle.isNotEmpty
            ? '$actorName a partagé votre témoignage « $testimonyTitle »'
            : '$actorName a partagé votre témoignage');
      case NotificationType.mention:
        return _serverMessageOr('$actorName vous a mentionné');
      case NotificationType.rejected:
        return _serverMessageOr(
            "Votre témoignage « $testimonyTitle » n'a pas été publié");
      case NotificationType.accountManagerAdded:
        return _serverMessageOr(actorName.isNotEmpty
            ? '$actorName vous a nommé administrateur de son compte'
            : "Vous avez été nommé administrateur d'un compte");
      case NotificationType.accountManagerRemoved:
        return _serverMessageOr(actorName.isNotEmpty
            ? "Vous n'administrez plus le compte de $actorName"
            : "Vous n'administrez plus un compte");
    }
  }

  /// Titre court en gras de la notification (maquette écran 10).
  String get title {
    switch (type) {
      case NotificationType.comment:
        return 'Nouveau commentaire';
      case NotificationType.like:
        return _aboutOtherContent ? 'Nouvelle réaction' : 'Témoignage populaire';
      case NotificationType.prayer:
        return prayerSessionId != null ? 'Session de prière' : 'Prière pour vous';
      case NotificationType.approved:
        return 'Témoignage approuvé';
      case NotificationType.newFollowedTestimony:
        return 'Nouveau témoignage';
      case NotificationType.pendingCorrection:
        return 'Correction requise';
      case NotificationType.organizationVerified:
        return 'Organisation vérifiée';
      case NotificationType.organizationRejected:
        return 'Vérification refusée';
      case NotificationType.accountVerified:
        return 'Compte vérifié';
      case NotificationType.accountVerificationRejected:
        return 'Vérification du compte';
      case NotificationType.liveStarted:
        return 'En direct';
      case NotificationType.event:
        return 'Événement';
      case NotificationType.follow:
        return 'Nouvel abonné';
      case NotificationType.share:
        return _aboutOtherContent ? 'Publication partagée' : 'Témoignage partagé';
      case NotificationType.mention:
        return 'Vous avez été mentionné';
      case NotificationType.rejected:
        return 'Témoignage non publié';
      case NotificationType.accountManagerAdded:
        return 'Nouveau compte à administrer';
      case NotificationType.accountManagerRemoved:
        return 'Administration retirée';
    }
  }

  bool get isSystemType =>
      type == NotificationType.approved ||
      type == NotificationType.rejected ||
      type == NotificationType.pendingCorrection ||
      type == NotificationType.organizationVerified ||
      type == NotificationType.organizationRejected ||
      type == NotificationType.accountVerified ||
      type == NotificationType.accountVerificationRejected ||
      type == NotificationType.accountManagerAdded ||
      type == NotificationType.accountManagerRemoved;

  /// Ouvre l'écran des administrateurs du compte (comptes que j'administre).
  bool get opensAccountManagers =>
      type == NotificationType.accountManagerAdded ||
      type == NotificationType.accountManagerRemoved;

  bool get isReactionType =>
      type == NotificationType.like ||
      type == NotificationType.prayer ||
      type == NotificationType.share;

  bool get isCommentType =>
      type == NotificationType.comment || type == NotificationType.mention;
}
