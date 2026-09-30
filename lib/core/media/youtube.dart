// lib/core/media/youtube.dart
//
// Liens YouTube : même règles que le serveur (app/Support/YouTube.php).
// Formats reconnus : youtube.com/watch?v=, youtu.be/, /shorts/, /live/,
// /embed/, ou directement l'identifiant de 11 caractères.

final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

const Set<String> _hosts = {
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'youtube-nocookie.com',
  'www.youtube-nocookie.com',
  'youtu.be',
  'www.youtu.be',
};

/// Identifiant YouTube extrait de [input], ou `null` si le lien n'est pas reconnu.
String? extractYouTubeId(String? input) {
  final raw = input?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (_idPattern.hasMatch(raw)) return raw;

  final withScheme = raw.contains('://') ? raw : 'https://$raw';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !_hosts.contains(uri.host.toLowerCase())) return null;

  String? candidate;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (uri.host.toLowerCase().endsWith('youtu.be')) {
    candidate = segments.isNotEmpty ? segments.first : null;
  } else if (segments.isNotEmpty && segments.first == 'watch') {
    candidate = uri.queryParameters['v'];
  } else if (segments.length >= 2 &&
      const {'shorts', 'live', 'embed', 'v'}.contains(segments.first)) {
    candidate = segments[1];
  }
  if (candidate == null || !_idPattern.hasMatch(candidate)) return null;
  return candidate;
}

/// Miniature publique d'une vidéo YouTube.
String youTubeThumbnailUrl(String id) =>
    'https://i.ytimg.com/vi/$id/hqdefault.jpg';

/// Lecteur intégré sans cookies (repli si le lecteur natif n'est pas disponible).
String youTubeEmbedUrl(String id) =>
    'https://www.youtube-nocookie.com/embed/$id?playsinline=1';
