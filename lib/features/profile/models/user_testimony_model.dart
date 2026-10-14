// lib/features/profile/models/user_testimony_model.dart
//
// Lightweight model for the "Mes témoignages" screen.
// Independent of the sealed Testimony hierarchy — avoids touching the feed model.

import '../../../core/media/video_source.dart';

class UserTestimony {
  const UserTestimony({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.category,
    this.durationSeconds = 0,
    this.thumbnailUrl,
    this.mediaPath,
    this.bodyPreview,
    this.rejectionReason,
    this.views = 0,
    this.videoStatus,
    this.bodyText = '',
    this.hasApprovedLabel = false,
  });

  final String  id;
  final String  title;
  final String  type;             // 'text' | 'audio' | 'video'
  final String  status;           // 'pending' | 'published' | 'rejected'
  final DateTime createdAt;
  final String  category;
  final int     durationSeconds;
  final String? thumbnailUrl;
  final String? mediaPath;
  final String? bodyPreview;
  final String? rejectionReason;
  final int     views;

  /// Vidéo Bunny Stream : uploading | processing | ready | failed (`null` sinon).
  final String? videoStatus;

  /// Texte complet (description, transcription) : prérempli dans « Modifier ».
  final String bodyText;

  /// Label « Témoignage approuvé » (badges contient "verified") : perdu si
  /// l'auteur modifie le témoignage.
  final bool hasApprovedLabel;

  /// État de traitement de la vidéo (ready sans suivi d'état).
  VideoProcessingState get videoState => VideoProcessingState.parse(videoStatus);

  /// Vidéo en cours d'envoi ou de traitement (« Vidéo en cours de traitement »).
  bool get isVideoProcessing => videoState == VideoProcessingState.processing;

  /// Traitement de la vidéo échoué (« La vidéo n'a pas pu être traitée »).
  bool get isVideoFailed => videoState == VideoProcessingState.failed;

  /// Statut de modération (docs serveur fonctionnalites/gestion-des-temoignages.md) :
  /// pending → En attente, approved → Publié, rejected → Refusé.
  String get statusLabel => switch (status) {
        'pending'   => 'En attente',
        'published' => 'Publié',
        'rejected'  => 'Refusé',
        _           => status,
      };

  static String _normalize(String raw) {
    final s = raw.toLowerCase();
    if (s == 'approved' || s == 'published' || s == 'active') return 'published';
    if (s == 'rejected' || s == 'declined') return 'rejected';
    return 'pending';
  }

  factory UserTestimony.fromJson(Map<String, dynamic> m) {
    final id    = m['id']?.toString() ?? '';
    final title = (m['title'] ?? '') as String;
    final type  = ((m['type'] ?? 'text') as String).toLowerCase();

    final rawStatus = (m['status'] ?? 'pending') as String;
    final status    = _normalize(rawStatus);

    final createdAt = DateTime.tryParse(
          (m['createdAt'] ?? m['created_at'] ?? '') as String? ?? '',
        ) ??
        DateTime.now();

    final catRaw   = m['category'];
    final category = catRaw is Map
        ? ((catRaw['slug'] ?? catRaw['name'] ?? '') as String)
        : ((catRaw ?? '') as String);

    // Vidéo Bunny Stream : objet « video » (ancien format à plat en secours).
    // Champs absents ou null tolérés.
    final video        = m['video'] is Map ? m['video'] as Map : null;
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    int toInt(Object? v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    final videoDuration   = toInt(video?['duration']);
    final durationSeconds = videoDuration > 0
        ? videoDuration
        : toInt(m['duration'] ?? m['duration_seconds']);

    final videoStatus  = str(video?['status']) ??
        str(m['video_status']) ?? str(m['videoStatus']);
    final videoThumb   = str(video?['thumbnail_url']) ?? str(m['thumbnail_url']);
    final thumbnailUrl = videoThumb ?? str(m['coverUrl']) ?? str(m['cover_url']);
    final mediaPath    = str(m['mediaUrl']) ?? str(m['media_url']) ??
        str(video?['mp4_url']);

    final body        = (m['bodyText'] ?? m['body_text'] ?? '') as String;
    final bodyPreview = body.isNotEmpty
        ? body.substring(0, body.length.clamp(0, 120))
        : null;

    final statsMap = m['stats'] as Map<String, dynamic>? ?? {};
    final views    = (statsMap['viewsCount'] ??
                      statsMap['views_count'] ??
                      0) as int? ?? 0;

    final rejection = (m['rejectionReason'] ?? m['rejection_reason']) as String?;

    return UserTestimony(
      id: id, title: title, type: type, status: status,
      createdAt: createdAt, category: category,
      durationSeconds: durationSeconds,
      thumbnailUrl: thumbnailUrl, mediaPath: mediaPath,
      bodyPreview: bodyPreview, rejectionReason: rejection,
      views: views, videoStatus: videoStatus,
      bodyText: body,
      hasApprovedLabel: m['badges'] is List
          ? (m['badges'] as List).contains('verified')
          : (m['isVerified'] == true || m['is_verified'] == true),
    );
  }
}
