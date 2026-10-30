// Listes de témoignages (comme les playlists YouTube).
// Docs serveur : fonctionnalites/listes-de-temoignages.md
//
// Liste (`GET /playlists/{id}`, `/playlists/mine`, `/users/{id}/playlists`) :
//   { id, title, description, owner: { id, displayName }, isMine, count, coverUrl,
//     shareUrl, updatedAt, items: [PlaylistItem] | null }
// Liste en cours d'un témoignage (`GET /testimonies/{id}?list=` → data.playlist) :
//   { id, title, description, owner, position (à partir de 1), count, previousId,
//     nextId, autoplay, items: [PlaylistItem] } ou null

/// Auteur d'une liste.
class PlaylistOwner {
  const PlaylistOwner({required this.id, required this.displayName});

  final String id;
  final String displayName;

  factory PlaylistOwner.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return PlaylistOwner(id: '${m['id'] ?? ''}', displayName: '${m['displayName'] ?? m['display_name'] ?? ''}');
  }
}

/// Type d'un témoignage de la liste.
enum PlaylistItemType {
  text,
  audio,
  video;

  static PlaylistItemType parse(Object? v) =>
      values.where((t) => t.name == v).firstOrNull ?? PlaylistItemType.text;
}

/// Témoignage d'une liste (forme compacte).
class PlaylistItem {
  const PlaylistItem({
    required this.id,
    required this.title,
    this.type = PlaylistItemType.text,
    this.isShort = false,
    this.coverUrl,
    this.durationSec = 0,
    this.viewsCount = 0,
    this.publishedAt,
  });

  final String id;
  final String title;
  final PlaylistItemType type;
  final bool isShort;
  final String? coverUrl;
  final int durationSec;
  final int viewsCount;

  /// Null : pas encore publié (visible par l'auteur seulement).
  final DateTime? publishedAt;

  /// « 5:12 », ou null sans durée (témoignage écrit).
  String? get durationLabel {
    if (durationSec <= 0) return null;
    final m = durationSec ~/ 60;
    final s = durationSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory PlaylistItem.fromJson(Map<String, dynamic> j) => PlaylistItem(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        type: PlaylistItemType.parse(j['type']),
        isShort: j['isShort'] == true,
        coverUrl: _str(j['coverUrl']),
        durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
        viewsCount: (j['viewsCount'] as num?)?.toInt() ?? 0,
        publishedAt: DateTime.tryParse('${j['publishedAt'] ?? ''}'),
      );

  static List<PlaylistItem> listFrom(Object? v) => v is List
      ? [
          for (final e in v)
            if (e is Map) PlaylistItem.fromJson(Map<String, dynamic>.from(e)),
        ].where((i) => i.id.isNotEmpty).toList()
      : const [];
}

/// Liste de témoignages.
class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    required this.owner,
    this.description,
    this.isMine = false,
    this.count = 0,
    this.coverUrl,
    this.shareUrl,
    this.updatedAt,
    this.items,
  });

  final String id;
  final String title;
  final String? description;
  final PlaylistOwner owner;
  final bool isMine;
  final int count;
  final String? coverUrl;
  final String? shareUrl;
  final DateTime? updatedAt;

  /// Témoignages dans l'ordre ; null dans les listes de listes.
  final List<PlaylistItem>? items;

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        description: _str(j['description']),
        owner: PlaylistOwner.fromJson(j['owner']),
        isMine: j['isMine'] == true,
        count: (j['count'] as num?)?.toInt() ?? 0,
        coverUrl: _str(j['coverUrl']),
        shareUrl: _str(j['shareUrl']),
        updatedAt: DateTime.tryParse('${j['updatedAt'] ?? ''}'),
        items: j['items'] is List ? PlaylistItem.listFrom(j['items']) : null,
      );

  static List<Playlist> listFrom(Object? v) => v is List
      ? [
          for (final e in v)
            if (e is Map) Playlist.fromJson(Map<String, dynamic>.from(e)),
        ].where((p) => p.id.isNotEmpty).toList()
      : const [];

  Playlist copyWith({String? title, Object? description = _keep, List<PlaylistItem>? items}) => Playlist(
        id: id,
        title: title ?? this.title,
        description: description == _keep ? this.description : description as String?,
        owner: owner,
        isMine: isMine,
        count: items?.length ?? count,
        coverUrl: items == null ? coverUrl : items.firstOrNull?.coverUrl,
        shareUrl: shareUrl,
        updatedAt: updatedAt,
        items: items ?? this.items,
      );
}

/// Liste en cours pendant la lecture d'un témoignage (`data.playlist`).
class PlaylistContext {
  const PlaylistContext({
    required this.id,
    required this.title,
    required this.owner,
    required this.position,
    required this.count,
    this.description,
    this.previousId,
    this.nextId,
    this.autoplay = true,
    this.items = const [],
  });

  final String id;
  final String title;
  final String? description;
  final PlaylistOwner owner;

  /// Rang du témoignage en cours, à partir de 1.
  final int position;
  final int count;
  final String? previousId;
  final String? nextId;

  /// Lecture automatique proposée par le serveur (activée par défaut).
  final bool autoplay;
  final List<PlaylistItem> items;

  /// Suivant / précédent (absent de [items] : témoignage minimal, ouvert par sa page).
  PlaylistItem? get next => _find(nextId);
  PlaylistItem? get previous => _find(previousId);

  PlaylistItem? _find(String? id) =>
      id == null ? null : items.where((i) => i.id == id).firstOrNull ?? PlaylistItem(id: id, title: '');

  /// `data.playlist` d'un témoignage ; null hors liste.
  static PlaylistContext? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    final id = '${j['id'] ?? ''}';
    if (id.isEmpty) return null;
    final items = PlaylistItem.listFrom(j['items']);
    return PlaylistContext(
      id: id,
      title: '${j['title'] ?? ''}',
      description: _str(j['description']),
      owner: PlaylistOwner.fromJson(j['owner']),
      position: (j['position'] as num?)?.toInt() ?? 1,
      count: (j['count'] as num?)?.toInt() ?? items.length,
      previousId: _str(j['previousId']),
      nextId: _str(j['nextId']),
      autoplay: j['autoplay'] != false,
      items: items,
    );
  }
}

/// Témoignage à lire après la fin de [current] : le suivant de la liste si la
/// lecture auto de la liste est active, sinon rien (comportement habituel).
PlaylistItem? playlistNextToAutoplay(PlaylistContext? context, {required bool enabled}) {
  if (context == null || !enabled || !context.autoplay) return null;
  return context.next;
}

String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

const Object _keep = Object();
