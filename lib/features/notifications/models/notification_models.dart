// =============================================================================
// Notifications feature — domain models
// =============================================================================

import '../../../l10n/app_localizations.dart';

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
  // Modérateurs : témoignage modifié par son auteur et renvoyé en modération
  // (type testimony_resubmitted, docs serveur fonctionnalites/gestion-des-temoignages.md).
  resubmitted,
  // Badge « Approuvé » retiré (type account_approval_revoked), distinct d'un refus de demande.
  approvalRevoked,
}

extension NotificationTypeLabel on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.comment:
        return L10n.current.notifTypeComment;
      case NotificationType.like:
        return L10n.current.notifTypeLike;
      case NotificationType.prayer:
        return L10n.current.notifTypePrayer;
      case NotificationType.approved:
        return L10n.current.notifTypeApproved;
      case NotificationType.newFollowedTestimony:
        return L10n.current.notifTypeNewTestimony;
      case NotificationType.resubmitted:
        return L10n.current.notifTypeResubmitted;
      case NotificationType.approvalRevoked:
        return L10n.current.notifTypeApprovalRevoked;
      case NotificationType.pendingCorrection:
        return L10n.current.notifTypePendingCorrection;
      case NotificationType.organizationVerified:
        return L10n.current.notifTypeOrganizationVerified;
      case NotificationType.organizationRejected:
        return L10n.current.notifTypeOrganizationRejected;
      case NotificationType.accountVerified:
        return L10n.current.notifTypeAccountVerified;
      case NotificationType.accountVerificationRejected:
        return L10n.current.notifTypeAccountVerification;
      case NotificationType.liveStarted:
        return L10n.current.notifTypeLive;
      case NotificationType.event:
        return L10n.current.notifTypeEvent;
      case NotificationType.follow:
        return L10n.current.notifTypeFollow;
      case NotificationType.share:
        return L10n.current.notifTypeShare;
      case NotificationType.mention:
        return L10n.current.notifTypeMention;
      case NotificationType.rejected:
        return L10n.current.notifTypeRejected;
      case NotificationType.accountManagerAdded:
      case NotificationType.accountManagerRemoved:
        return L10n.current.notifTypeAccountManagers;
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
        return L10n.current.notifTabAll;
      case NotificationFilterTab.unread:
        return L10n.current.notifTabNew;
      case NotificationFilterTab.popular:
        return L10n.current.notifTabPopular;
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
    final l = L10n.current;
    switch (type) {
      case NotificationType.comment:
        return l.notifBodyComment(actorName, testimonyTitle);
      case NotificationType.like:
        if (_aboutOtherContent) return _serverMessageOr(l.notifBodyReacted(actorName));
        return l.notifBodyLiked(actorName, testimonyTitle);
      case NotificationType.prayer:
        // Requêtes, sessions de prière et événements : texte rédigé par le serveur.
        final prayerMsg = message?.trim() ?? '';
        if ((prayerRequestId != null || prayerSessionId != null || eventId != null) && prayerMsg.isNotEmpty) {
          // Le nom n'est ajouté que si le serveur ne l'a pas déjà mis (prayer_request_prayed :
          // « {Nom} prie pour votre requête de prière »).
          return actorName.isNotEmpty && !prayerMsg.startsWith(actorName)
              ? '$actorName $prayerMsg' // i18n-ignore
              : prayerMsg;
        }
        return l.notifBodyPrayer(actorName, testimonyTitle);
      case NotificationType.approved:
        return l.notifBodyApproved(testimonyTitle);
      case NotificationType.newFollowedTestimony:
        return l.notifBodyNewTestimony(actorName, testimonyTitle);
      case NotificationType.approvalRevoked:
        return _serverMessageOr(l.notifBodyApprovalRevoked);
      case NotificationType.resubmitted:
        return _serverMessageOr(l.notifBodyResubmitted);
      case NotificationType.pendingCorrection:
        return l.notifBodyPendingCorrection(testimonyTitle);
      case NotificationType.organizationVerified:
        return l.notifBodyOrganizationVerified;
      case NotificationType.organizationRejected:
        return l.notifBodyOrganizationRejected;
      case NotificationType.accountVerified:
        return _serverMessageOr(l.notifBodyAccountVerified);
      case NotificationType.accountVerificationRejected:
        return _serverMessageOr(l.notifBodyAccountVerificationRejected);
      case NotificationType.liveStarted:
        final msg = message?.trim() ?? '';
        if (msg.isNotEmpty) return msg;
        return testimonyTitle.isNotEmpty
            ? l.notifBodyLiveTitle(actorName, testimonyTitle)
            : l.notifBodyLive(actorName);
      case NotificationType.event:
        return message?.trim() ?? '';
      case NotificationType.follow:
        return _serverMessageOr(l.notifBodyFollow(actorName));
      case NotificationType.share:
        return _serverMessageOr(testimonyTitle.isNotEmpty
            ? l.notifBodyShareTitle(actorName, testimonyTitle)
            : l.notifBodyShare(actorName));
      case NotificationType.mention:
        return _serverMessageOr(l.notifBodyMention(actorName));
      case NotificationType.rejected:
        return _serverMessageOr(
            l.notifBodyRejected(testimonyTitle));
      case NotificationType.accountManagerAdded:
        return _serverMessageOr(actorName.isNotEmpty
            ? l.notifBodyManagerAddedBy(actorName)
            : l.notifBodyManagerAdded);
      case NotificationType.accountManagerRemoved:
        return _serverMessageOr(actorName.isNotEmpty
            ? l.notifBodyManagerRemovedBy(actorName)
            : l.notifBodyManagerRemoved);
    }
  }

  /// Titre court en gras de la notification (maquette écran 10).
  String get title {
    final l = L10n.current;
    switch (type) {
      case NotificationType.comment:
        return l.notifTitleComment;
      case NotificationType.like:
        return _aboutOtherContent ? l.notifTitleReaction : l.notifTitlePopular;
      case NotificationType.prayer:
        return prayerSessionId != null ? l.notifTitlePrayerSession : l.notifTitlePrayer;
      case NotificationType.approved:
        return l.notifTitleApproved;
      case NotificationType.newFollowedTestimony:
        return l.notifTypeNewTestimony;
      case NotificationType.resubmitted:
        return l.notifTypeResubmitted;
      case NotificationType.approvalRevoked:
        return l.notifTypeApprovalRevoked;
      case NotificationType.pendingCorrection:
        return l.notifTypePendingCorrection;
      case NotificationType.organizationVerified:
        return l.notifTypeOrganizationVerified;
      case NotificationType.organizationRejected:
        return l.notifTypeOrganizationRejected;
      case NotificationType.accountVerified:
        return l.notifTypeAccountVerified;
      case NotificationType.accountVerificationRejected:
        return l.notifTypeAccountVerification;
      case NotificationType.liveStarted:
        return l.notifTypeLive;
      case NotificationType.event:
        return l.notifTypeEvent;
      case NotificationType.follow:
        return l.notifTitleFollow;
      case NotificationType.share:
        return _aboutOtherContent ? l.notifTitlePostShared : l.notifTitleTestimonyShared;
      case NotificationType.mention:
        return l.notifTitleMention;
      case NotificationType.rejected:
        return l.notifTitleRejected;
      case NotificationType.accountManagerAdded:
        return l.notifTitleManagerAdded;
      case NotificationType.accountManagerRemoved:
        return l.notifTitleManagerRemoved;
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
