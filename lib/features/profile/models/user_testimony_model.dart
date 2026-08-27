// lib/features/profile/models/user_testimony_model.dart
//
// Lightweight model for the "Mes témoignages" screen.
// Independent of the sealed Testimony hierarchy — avoids touching the feed model.

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

  String get statusLabel => switch (status) {
        'pending'   => 'En attente',
        'published' => 'Publié',
        'rejected'  => 'Rejeté',
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

    final durRaw          = m['duration'] ?? m['duration_seconds'];
    final durationSeconds = durRaw is int
        ? durRaw
        : int.tryParse(durRaw?.toString() ?? '') ?? 0;

    final thumbnailUrl = (m['coverUrl'] ?? m['cover_url']) as String?;
    final mediaPath    = (m['mediaUrl'] ?? m['media_url']) as String?;

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
      views: views,
    );
  }
}
