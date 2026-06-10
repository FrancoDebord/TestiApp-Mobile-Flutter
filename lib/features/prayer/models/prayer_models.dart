// Prayer feature — domain models

enum PrayerVisibility { public, friends, private }

enum PrayerSessionStatus { scheduled, live, ended }

// ── Prayer Request ────────────────────────────────────────────────────────────

class PrayerRequest {
  const PrayerRequest({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.body,
    required this.createdAt,
    this.prayerCount = 0,
    this.messageCount = 0,
    this.visibility = PrayerVisibility.public,
    this.userHasPrayed = false,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String body;
  final DateTime createdAt;
  final int prayerCount;
  final int messageCount;
  final PrayerVisibility visibility;
  final bool userHasPrayed;

  String get initials {
    final parts = authorName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }

  PrayerRequest copyWith({
    int? prayerCount,
    int? messageCount,
    bool? userHasPrayed,
  }) {
    return PrayerRequest(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      body: body,
      createdAt: createdAt,
      prayerCount: prayerCount ?? this.prayerCount,
      messageCount: messageCount ?? this.messageCount,
      visibility: visibility,
      userHasPrayed: userHasPrayed ?? this.userHasPrayed,
    );
  }
}

// ── Inspiration Message ────────────────────────────────────────────────────────

class InspirationMessage {
  const InspirationMessage({
    required this.id,
    required this.requestId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.body,
    required this.createdAt,
    this.bibleVerse,
  });

  final String id;
  final String requestId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String body;
  final DateTime createdAt;
  final String? bibleVerse;

  String get initials {
    final parts = authorName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }
}

// ── Group Prayer Session ──────────────────────────────────────────────────────

class GroupPrayerSession {
  const GroupPrayerSession({
    required this.id,
    required this.hostId,
    required this.hostName,
    this.hostAvatar,
    required this.title,
    this.description,
    required this.scheduledAt,
    required this.visibility,
    this.status = PrayerSessionStatus.scheduled,
    this.participantCount = 0,
    this.requestIds = const [],
    this.isRecorded = false,
    this.recordingPath,
  });

  final String id;
  final String hostId;
  final String hostName;
  final String? hostAvatar;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final PrayerVisibility visibility;
  final PrayerSessionStatus status;
  final int participantCount;
  final List<String> requestIds;
  final bool isRecorded;
  final String? recordingPath;

  String get hostInitials {
    final parts = hostName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return hostName.isNotEmpty ? hostName[0].toUpperCase() : '?';
  }

  bool get isLive => status == PrayerSessionStatus.live;
  bool get isEnded => status == PrayerSessionStatus.ended;

  GroupPrayerSession copyWith({
    PrayerSessionStatus? status,
    int? participantCount,
    String? recordingPath,
  }) {
    return GroupPrayerSession(
      id: id,
      hostId: hostId,
      hostName: hostName,
      hostAvatar: hostAvatar,
      title: title,
      description: description,
      scheduledAt: scheduledAt,
      visibility: visibility,
      status: status ?? this.status,
      participantCount: participantCount ?? this.participantCount,
      requestIds: requestIds,
      isRecorded: isRecorded,
      recordingPath: recordingPath ?? this.recordingPath,
    );
  }
}
