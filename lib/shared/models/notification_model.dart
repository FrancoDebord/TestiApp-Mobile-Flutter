// lib/shared/models/notification_model.dart — Dart pur, sans génération de code.

enum NotificationType {
  like, comment, reply, follow, testimonyApproved, testimonyRejected, mention, share;

  static NotificationType fromJson(String? v) => switch (v) {
    'comment'            => NotificationType.comment,
    'reply'              => NotificationType.reply,
    'follow'             => NotificationType.follow,
    'testimony_approved' => NotificationType.testimonyApproved,
    'testimony_rejected' => NotificationType.testimonyRejected,
    'mention'            => NotificationType.mention,
    'share'              => NotificationType.share,
    _                    => NotificationType.like,
  };
  String toJson() => switch (this) {
    NotificationType.testimonyApproved => 'testimony_approved',
    NotificationType.testimonyRejected => 'testimony_rejected',
    _ => name,
  };
}

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    this.actorId,
    this.actorName,
    this.actorAvatar,
    this.testimonyId,
    this.testimonyTitle,
    required this.message,
    this.isRead = false,
    this.createdAt,
  });

  final String           id;
  final NotificationType type;
  final String?          actorId;
  final String?          actorName;
  final String?          actorAvatar;
  final String?          testimonyId;
  final String?          testimonyTitle;
  final String           message;
  final bool             isRead;
  final String?          createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> j) {
    final actor = j['actor_user'] is Map
        ? Map<String, dynamic>.from(j['actor_user'] as Map)
        : null;
    return NotificationModel(
      id:             j['id']          as String,
      type:           NotificationType.fromJson(j['type'] as String?),
      actorId:        actor?['id']     as String? ?? j['actor_id'] as String?,
      actorName:      actor?['display_name'] as String? ?? j['actor_name'] as String?,
      actorAvatar:    actor?['avatar_url']   as String? ?? j['actor_avatar'] as String?,
      testimonyId:    j['testimony_id']    as String?,
      testimonyTitle: j['testimony_title'] as String?,
      message:        j['message'] as String? ?? '',
      isRead:         j['is_read'] as bool? ?? false,
      createdAt:      j['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type.toJson(), 'message': message, 'is_read': isRead,
    if (actorId != null)        'actor_id': actorId,
    if (actorName != null)      'actor_name': actorName,
    if (actorAvatar != null)    'actor_avatar': actorAvatar,
    if (testimonyId != null)    'testimony_id': testimonyId,
    if (testimonyTitle != null) 'testimony_title': testimonyTitle,
    if (createdAt != null)      'created_at': createdAt,
  };

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id: id, type: type, actorId: actorId, actorName: actorName,
    actorAvatar: actorAvatar, testimonyId: testimonyId,
    testimonyTitle: testimonyTitle, message: message,
    isRead: isRead ?? this.isRead, createdAt: createdAt,
  );

  @override bool operator ==(Object other) =>
      other is NotificationModel && other.id == id;
  @override int get hashCode => id.hashCode;
}
