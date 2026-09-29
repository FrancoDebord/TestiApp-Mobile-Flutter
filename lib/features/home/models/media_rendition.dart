/// Une version (qualité) d'un média vidéo ou audio.
///
/// Contrat attendu du backend (champ `renditions` / `mediaRenditions`
/// d'un témoignage) — une liste :
///   [{ "quality": "720p", "height": 720, "bitrate": 1800, "url": "…" }, …]
/// ou, en forme courte, une map : { "360p": "…", "720p": "…", "64k": "…" }.
///
/// Pour la vidéo, `height` (px) sert au tri ; pour l'audio, `bitrate` (kbps).
library;

class MediaRendition {
  const MediaRendition({
    required this.url,
    required this.label,
    this.height = 0,
    this.bitrateKbps = 0,
  });

  final String url;

  /// Libellé affiché : « 720p », « 64 kbps »…
  final String label;

  /// Hauteur vidéo en pixels (0 pour l'audio / inconnu).
  final int height;

  /// Débit en kbps (0 si inconnu).
  final int bitrateKbps;

  /// Clé de tri : hauteur pour la vidéo, débit pour l'audio.
  int get rank => height > 0 ? height : bitrateKbps;

  Map<String, dynamic> toJson() => {
        'quality': label,
        if (height > 0) 'height': height,
        if (bitrateKbps > 0) 'bitrate': bitrateKbps,
        'url': url,
      };

  static int _int(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(RegExp(r'\d+').stringMatch(v?.toString() ?? '') ?? '') ??
        0;
  }

  /// Déduit hauteur / débit d'un libellé comme « 720p » ou « 64k ».
  static MediaRendition _fromLabel(String label, String url) {
    final l = label.toLowerCase();
    // « 720p », « 1080p60 », « 720p HD » → vidéo ; « 64k », « 128 kbps » → audio.
    final video = RegExp(r'(\d+)\s*p(?![a-z])|(\d+)\s*p\d').firstMatch(l);
    final isVideo = video != null;
    final n = isVideo ? _int(video.group(1) ?? video.group(2)) : _int(l);
    return MediaRendition(
      url: url,
      label: isVideo ? '${n}p' : (n > 0 ? '$n kbps' : label),
      height: isVideo ? n : 0,
      bitrateKbps: isVideo ? 0 : n,
    );
  }

  /// Parse la liste de versions, triée de la plus basse à la plus haute
  /// qualité. [absUrl] rend les URLs relatives absolues.
  static List<MediaRendition> parseList(
    dynamic raw, {
    String? Function(String?)? absUrl,
  }) {
    String? fix(String? u) => absUrl == null ? u : absUrl(u);
    final out = <MediaRendition>[];
    try {
      if (raw is List) {
        for (final e in raw) {
          if (e is! Map) continue;
          final url = fix((e['url'] ?? e['src'] ?? e['path'])?.toString());
          if (url == null || url.isEmpty) continue;
          final label = (e['quality'] ?? e['label'] ?? '').toString();
          final height = _int(e['height']);
          final bitrate = _int(e['bitrate'] ?? e['bitrate_kbps'] ?? e['bitrateKbps']);
          if (height == 0 && bitrate == 0 && label.isNotEmpty) {
            out.add(_fromLabel(label, url));
          } else {
            out.add(MediaRendition(
              url: url,
              label: label.isNotEmpty
                  ? label
                  : (height > 0 ? '${height}p' : '$bitrate kbps'),
              height: height,
              bitrateKbps: bitrate,
            ));
          }
        }
      } else if (raw is Map) {
        raw.forEach((k, v) {
          final url = fix(v?.toString());
          if (url != null && url.isNotEmpty) {
            out.add(_fromLabel(k.toString(), url));
          }
        });
      }
    } catch (_) {}
    out.sort((a, b) => a.rank.compareTo(b.rank));
    return out;
  }
}
