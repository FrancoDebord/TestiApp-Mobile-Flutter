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
    }
  }
}

/// Filter tabs on the notifications screen.
enum NotificationFilterTab { all, comments, reactions, system }

extension NotificationFilterLabel on NotificationFilterTab {
  String get label {
    switch (this) {
      case NotificationFilterTab.all:
        return 'Tout';
      case NotificationFilterTab.comments:
        return 'Commentaires';
      case NotificationFilterTab.reactions:
        return 'Réactions';
      case NotificationFilterTab.system:
        return 'Système';
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
  });

  final String id;
  final NotificationType type;
  final String actorName;
  final String testimonyTitle;
  final DateTime createdAt;
  final String? actorAvatarUrl;
  final String? testimonyThumbnailUrl;
  final bool isRead;

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
    }
  }

  bool get isSystemType =>
      type == NotificationType.approved ||
      type == NotificationType.pendingCorrection;

  bool get isReactionType =>
      type == NotificationType.like || type == NotificationType.prayer;

  bool get isCommentType => type == NotificationType.comment;
}
