// lib/shared/models/comment_model.dart — Dart pur, sans génération de code.

import 'user_model.dart';

class CommentModel {
  const CommentModel({
    required this.id,
    required this.testimonyId,
    required this.userId,
    this.user,
    required this.text,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.isLikedByMe = false,
    this.parentId,
    this.createdAt,
    this.updatedAt,
  });

  final String     id;
  final String     testimonyId;
  final String     userId;
  final UserModel? user;
  final String     text;
  final int        likesCount;
  final int        repliesCount;
  final bool       isLikedByMe;
  final String?    parentId;
  final String?    createdAt;
  final String?    updatedAt;

  bool get isReply => parentId != null;

  factory CommentModel.fromJson(Map<String, dynamic> j) => CommentModel(
    id:           j['id'] as String,
    testimonyId:  (j['testimonyId']   ?? j['testimony_id'])  as String? ?? '',
    userId:       (j['userId']        ?? j['user_id'])       as String? ?? '',
    user:         j['user'] is Map
        ? UserModel.fromJson(Map<String, dynamic>.from(j['user'] as Map))
        : null,
    text:         (j['text'] ?? j['body']) as String? ?? '',
    likesCount:   ((j['likesCount']   ?? j['likes_count'])   as num?)?.toInt() ?? 0,
    repliesCount: ((j['repliesCount'] ?? j['replies_count']  ?? j['reply_count']) as num?)?.toInt() ?? 0,
    isLikedByMe:  (j['isLikedByMe']  ?? j['is_liked_by_me']) as bool? ?? false,
    parentId:     (j['parentId']     ?? j['parent_id'])      as String?,
    createdAt:    (j['createdAt']    ?? j['created_at'])     as String?,
    updatedAt:    (j['updatedAt']    ?? j['updated_at'])     as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'testimony_id': testimonyId, 'user_id': userId,
    'text': text, 'likes_count': likesCount, 'replies_count': repliesCount,
    'is_liked_by_me': isLikedByMe,
    if (parentId != null)  'parent_id': parentId,
    if (createdAt != null) 'created_at': createdAt,
    if (updatedAt != null) 'updated_at': updatedAt,
  };

  @override bool operator ==(Object other) =>
      other is CommentModel && other.id == id;
  @override int get hashCode => id.hashCode;
}
