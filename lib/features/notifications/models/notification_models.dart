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
  liveStarted,
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
      case NotificationType.liveStarted:
        return 'En direct';
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
    );
  }

  String get body {
    switch (type) {
      case NotificationType.comment:
        return '$actorName a commenté votre témoignage « $testimonyTitle »';
      case NotificationType.like:
        return '$actorName a aimé votre témoignage « $testimonyTitle »';
      case NotificationType.prayer:
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
      case NotificationType.liveStarted:
        final msg = message?.trim() ?? '';
        if (msg.isNotEmpty) return msg;
        return testimonyTitle.isNotEmpty
            ? '$actorName est en direct : $testimonyTitle'
            : '$actorName est en direct';
    }
  }

  /// Titre court en gras de la notification (maquette écran 10).
  String get title {
    switch (type) {
      case NotificationType.comment:
        return 'Nouveau commentaire';
      case NotificationType.like:
        return 'Témoignage populaire';
      case NotificationType.prayer:
        return 'Prière pour vous';
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
      case NotificationType.liveStarted:
        return 'En direct';
    }
  }

  bool get isSystemType =>
      type == NotificationType.approved ||
      type == NotificationType.pendingCorrection ||
      type == NotificationType.organizationVerified ||
      type == NotificationType.organizationRejected;

  bool get isReactionType =>
      type == NotificationType.like || type == NotificationType.prayer;

  bool get isCommentType => type == NotificationType.comment;
}
