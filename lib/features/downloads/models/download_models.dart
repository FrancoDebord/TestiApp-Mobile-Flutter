// Modèles de la fonctionnalité « Mes téléchargements ».
//
// [DownloadEntry] : un témoignage disponible hors ligne (métadonnées + chemin
// des fichiers locaux), persisté dans l'index JSON.
// [DownloadTask] : téléchargement en attente / en cours / en échec.

import '../../home/models/testimony_model.dart';

/// État d'un témoignage vis-à-vis des téléchargements.
enum DownloadStatus { none, queued, downloading, done, failed }

/// Taille lisible en français : « 820 Ko », « 3,4 Mo », « 1,2 Go ».
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 Mo';
  const ko = 1024;
  const mo = ko * 1024;
  const go = mo * 1024;
  String dec(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
  if (bytes < mo) return '${(bytes / ko).ceil()} Ko';
  if (bytes < go) {
    final v = bytes / mo;
    return v >= 100 ? '${v.round()} Mo' : '${dec(v)} Mo';
  }
  return '${dec(bytes / go)} Go';
}

String typeLabel(TestimonyType t) => switch (t) {
      TestimonyType.video => 'Vidéo',
      TestimonyType.audio => 'Audio',
      TestimonyType.text => 'Texte',
    };

/// Témoignage téléchargé.
class DownloadEntry {
  const DownloadEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.authorName,
    required this.category,
    required this.downloadedAt,
    this.authorUid = '',
    this.authorAvatarUrl,
    this.createdAt,
    this.durationSeconds = 0,
    this.thumbnailUrl,
    this.thumbnailPath,
    this.bibleVerse,
    this.bibleVerseRef,
    this.textBody,
    this.filePath,
    this.sourceUrls = const [],
    this.sizeBytes = 0,
    this.qualityLabel,
  });

  final String id;
  final TestimonyType type;
  final String title;
  final String authorUid;
  final String authorName;
  final String? authorAvatarUrl;
  final TestimonyCategory category;
  final DateTime? createdAt;
  final int durationSeconds;

  /// Vignette d'origine (réseau) et copie locale.
  final String? thumbnailUrl;
  final String? thumbnailPath;
  final String? bibleVerse;
  final String? bibleVerseRef;

  /// Texte complet (témoignages écrits) ou transcription (audio).
  final String? textBody;

  /// Fichier média local (audio / vidéo) ; `null` pour un texte.
  final String? filePath;

  /// Adresses d'origine (fichier original + versions) : permet de retrouver
  /// le fichier local à partir de l'URL qu'un lecteur s'apprête à lire.
  final List<String> sourceUrls;

  /// Espace occupé (média + vignette + texte), en octets.
  final int sizeBytes;
  final DateTime downloadedAt;

  /// Version téléchargée (« 360p », « 64 kbps », « Originale », « Texte »).
  final String? qualityLabel;

  String get typeName => typeLabel(type);

  /// « Vidéo · 3,4 Mo »
  String get subtitle => '$typeName · ${formatBytes(sizeBytes)}';

  DownloadEntry copyWith({
    String? thumbnailPath,
    String? filePath,
    int? sizeBytes,
    String? qualityLabel,
    DateTime? downloadedAt,
  }) =>
      DownloadEntry(
        id: id,
        type: type,
        title: title,
        authorUid: authorUid,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        category: category,
        createdAt: createdAt,
        durationSeconds: durationSeconds,
        thumbnailUrl: thumbnailUrl,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        bibleVerse: bibleVerse,
        bibleVerseRef: bibleVerseRef,
        textBody: textBody,
        filePath: filePath ?? this.filePath,
        sourceUrls: sourceUrls,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        downloadedAt: downloadedAt ?? this.downloadedAt,
        qualityLabel: qualityLabel ?? this.qualityLabel,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'author_uid': authorUid,
        'author_name': authorName,
        if (authorAvatarUrl != null) 'author_avatar_url': authorAvatarUrl,
        'category': category.name,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        'duration': durationSeconds,
        if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
        if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
        if (bibleVerse != null) 'bible_verse': bibleVerse,
        if (bibleVerseRef != null) 'bible_verse_ref': bibleVerseRef,
        if (textBody != null) 'text': textBody,
        if (filePath != null) 'file_path': filePath,
        'source_urls': sourceUrls,
        'size_bytes': sizeBytes,
        'downloaded_at': downloadedAt.toIso8601String(),
        if (qualityLabel != null) 'quality': qualityLabel,
      };

  /// `null` si l'entrée est illisible.
  static DownloadEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    int toInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    String? str(String k) => raw[k]?.toString();

    return DownloadEntry(
      id: id,
      type: pick(TestimonyType.values, raw['type'], TestimonyType.text),
      title: str('title') ?? '',
      authorUid: str('author_uid') ?? '',
      authorName: str('author_name') ?? '',
      authorAvatarUrl: str('author_avatar_url'),
      category: pick(
          TestimonyCategory.values, raw['category'], TestimonyCategory.miracles),
      createdAt: DateTime.tryParse(str('created_at') ?? ''),
      durationSeconds: toInt(raw['duration']),
      thumbnailUrl: str('thumbnail_url'),
      thumbnailPath: str('thumbnail_path'),
      bibleVerse: str('bible_verse'),
      bibleVerseRef: str('bible_verse_ref'),
      textBody: str('text'),
      filePath: str('file_path'),
      sourceUrls: raw['source_urls'] is List
          ? [for (final u in raw['source_urls'] as List) u.toString()]
          : const [],
      sizeBytes: toInt(raw['size_bytes']),
      downloadedAt:
          DateTime.tryParse(str('downloaded_at') ?? '') ?? DateTime.now(),
      qualityLabel: str('quality'),
    );
  }

  /// Métadonnées d'un témoignage (sans fichiers locaux).
  factory DownloadEntry.fromTestimony(Testimony t, {List<String>? sources}) {
    final (thumb, verse, verseRef, text, duration, urls) = switch (t) {
      VideoTestimony v => (
          v.thumbnailUrl.isEmpty ? null : v.thumbnailUrl,
          v.bibleVerse,
          v.bibleVerseRef,
          null,
          v.durationSeconds,
          [?v.mediaPath, ...v.renditions.map((r) => r.url)],
        ),
      AudioTestimony a => (
          a.coverImageUrl,
          a.bibleVerse,
          a.bibleVerseRef,
          a.transcriptPreview.isEmpty ? null : a.transcriptPreview,
          a.durationSeconds,
          [?a.mediaPath, ...a.renditions.map((r) => r.url)],
        ),
      TextTestimony x => (
          x.coverImageUrl,
          x.bibleVerse,
          x.bibleVerseRef,
          x.preview,
          0,
          <String>[],
        ),
    };
    return DownloadEntry(
      id: t.id,
      type: t.type,
      title: t.title,
      authorUid: t.author.uid,
      authorName: t.author.displayName,
      authorAvatarUrl: t.author.avatarUrl,
      category: t.category,
      createdAt: t.createdAt,
      durationSeconds: duration,
      thumbnailUrl: (thumb?.isEmpty ?? true) ? null : thumb,
      bibleVerse: verse,
      bibleVerseRef: verseRef,
      textBody: text,
      sourceUrls: sources ?? [for (final u in urls) if (u.isNotEmpty) u],
      downloadedAt: DateTime.now(),
    );
  }

  /// Témoignage reconstruit pour la lecture hors ligne : le média pointe sur
  /// le fichier local, la vignette sur sa copie locale si elle existe.
  Testimony toTestimony() {
    final author = TestimonyAuthor(
      uid: authorUid,
      displayName: authorName,
      avatarUrl: authorAvatarUrl,
    );
    final date = createdAt ?? downloadedAt;
    final thumb = thumbnailPath ?? thumbnailUrl;
    return switch (type) {
      TestimonyType.video => VideoTestimony(
          id: id,
          author: author,
          title: title,
          category: category,
          createdAt: date,
          stats: TestimonyStats.zero,
          durationSeconds: durationSeconds,
          thumbnailUrl: thumb ?? '',
          mediaPath: filePath,
          bibleVerse: bibleVerse,
          bibleVerseRef: bibleVerseRef,
        ),
      TestimonyType.audio => AudioTestimony(
          id: id,
          author: author,
          title: title,
          category: category,
          createdAt: date,
          stats: TestimonyStats.zero,
          durationSeconds: durationSeconds,
          transcriptPreview: textBody ?? '',
          mediaPath: filePath,
          coverImageUrl: thumb,
          bibleVerse: bibleVerse,
          bibleVerseRef: bibleVerseRef,
        ),
      TestimonyType.text => TextTestimony(
          id: id,
          author: author,
          title: title,
          category: category,
          createdAt: date,
          stats: TestimonyStats.zero,
          preview: textBody ?? '',
          coverImageUrl: thumb,
          bibleVerse: bibleVerse,
          bibleVerseRef: bibleVerseRef,
        ),
    };
  }
}

/// Téléchargement non terminé (en attente, en cours ou en échec).
class DownloadTask {
  const DownloadTask({
    required this.entry,
    required this.status,
    this.progress,
    this.error,
  });

  /// Métadonnées du témoignage (pour l'afficher pendant le téléchargement).
  final DownloadEntry entry;
  final DownloadStatus status;

  /// 0.0 – 1.0 ; `null` = progression inconnue.
  final double? progress;

  /// Message d'erreur (français) quand [status] vaut failed.
  final String? error;

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    String? error,
  }) =>
      DownloadTask(
        entry: entry,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        error: error ?? this.error,
      );
}

/// État par témoignage, exposé aux widgets.
class DownloadItemState {
  const DownloadItemState(this.status, {this.progress, this.error, this.entry});

  static const none = DownloadItemState(DownloadStatus.none);

  final DownloadStatus status;
  final double? progress;
  final String? error;
  final DownloadEntry? entry;

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;
}

/// État global des téléchargements.
class DownloadsState {
  const DownloadsState({
    this.entries = const {},
    this.tasks = const {},
    this.loaded = false,
    this.supported = true,
  });

  /// Téléchargements terminés, par identifiant de témoignage.
  final Map<String, DownloadEntry> entries;

  /// Téléchargements non terminés.
  final Map<String, DownloadTask> tasks;

  /// Index chargé depuis le disque.
  final bool loaded;

  /// `false` sur le web (pas d'accès aux fichiers).
  final bool supported;

  int get totalBytes => entries.values.fold(0, (s, e) => s + e.sizeBytes);

  /// Terminés, du plus récent au plus ancien.
  List<DownloadEntry> get sortedEntries => entries.values.toList()
    ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));

  int bytesOfType(TestimonyType t) => entries.values
      .where((e) => e.type == t)
      .fold(0, (s, e) => s + e.sizeBytes);

  DownloadItemState itemState(String id) {
    final task = tasks[id];
    if (task != null) {
      return DownloadItemState(task.status,
          progress: task.progress, error: task.error, entry: task.entry);
    }
    final e = entries[id];
    if (e != null) return DownloadItemState(DownloadStatus.done, entry: e);
    return DownloadItemState.none;
  }

  DownloadsState copyWith({
    Map<String, DownloadEntry>? entries,
    Map<String, DownloadTask>? tasks,
    bool? loaded,
    bool? supported,
  }) =>
      DownloadsState(
        entries: entries ?? this.entries,
        tasks: tasks ?? this.tasks,
        loaded: loaded ?? this.loaded,
        supported: supported ?? this.supported,
      );
}
