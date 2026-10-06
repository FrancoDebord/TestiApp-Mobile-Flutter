// Caméra IP d'un direct en mode « Adresse du flux » : composition et lecture
// de l'adresse (rtsp://, rtmp://, http(s)://, srt://), préréglages de marques,
// détection des adresses privées. Pur Dart : testé dans test/ip_camera_test.dart.
// Doc backend : docs/fonctionnalites/lives-camera-ip.md
//
// L'adresse est composée ici puis envoyée telle quelle dans `camera_url`
// (API inchangée). Le mot de passe n'est jamais mémorisé sur l'appareil.

import 'dart:convert' show utf8;

/// Protocole du flux lu par le service vidéo (LiveKit Ingress, entrée URL).
enum IpCameraProtocol {
  rtsp('rtsp', 'RTSP', 554),
  rtsps('rtsps', 'RTSPS (chiffré)', 322),
  rtmp('rtmp', 'RTMP', 1935),
  rtmps('rtmps', 'RTMPS (chiffré)', 443),
  http('http', 'HTTP (HLS)', 80),
  https('https', 'HTTPS (HLS)', 443),
  srt('srt', 'SRT', 9000);

  const IpCameraProtocol(this.scheme, this.label, this.defaultPort);

  final String scheme;
  final String label;
  final int defaultPort;

  /// SRT : pas d'identifiant / mot de passe dans l'adresse, mais `streamid`
  /// et `passphrase` en paramètres.
  bool get isSrt => this == IpCameraProtocol.srt;

  static IpCameraProtocol? fromScheme(String? scheme) {
    final s = scheme?.toLowerCase();
    for (final p in values) {
      if (p.scheme == s) return p;
    }
    return null;
  }
}

/// Flux proposé par la caméra : principal (pleine qualité) ou secondaire (réduit).
enum IpCameraStream { main, sub }

/// Préréglage d'un modèle de caméra : protocole, port et chemins usuels
/// (documentation publique des fabricants).
class IpCameraPreset {
  const IpCameraPreset({
    required this.id,
    required this.label,
    this.protocol = IpCameraProtocol.rtsp,
    this.port,
    this.mainPath,
    this.subPath,
    this.hint,
  });

  final String id;
  final String label;
  final IpCameraProtocol protocol;

  /// null : port par défaut du protocole.
  final int? port;
  final String? mainPath;
  final String? subPath;
  final String? hint;

  bool get hasSubStream => subPath != null;

  String? pathFor(IpCameraStream stream) =>
      stream == IpCameraStream.sub && subPath != null ? subPath : mainPath;

  static const hikvision = IpCameraPreset(
    id: 'hikvision',
    label: 'Hikvision (et HiLook)',
    mainPath: '/Streaming/Channels/101',
    subPath: '/Streaming/Channels/102',
    hint: 'Canal 1 : 101 (principal), 102 (secondaire). Canal 2 : 201, 202…',
  );
  static const dahua = IpCameraPreset(
    id: 'dahua',
    label: 'Dahua (et Imou)',
    mainPath: '/cam/realmonitor?channel=1&subtype=0',
    subPath: '/cam/realmonitor?channel=1&subtype=1',
    hint: 'subtype=0 : flux principal, subtype=1 : flux secondaire.',
  );
  static const amcrest = IpCameraPreset(
    id: 'amcrest',
    label: 'Amcrest',
    mainPath: '/cam/realmonitor?channel=1&subtype=0',
    subPath: '/cam/realmonitor?channel=1&subtype=1',
    hint: 'Même format que Dahua.',
  );
  static const reolink = IpCameraPreset(
    id: 'reolink',
    label: 'Reolink',
    mainPath: '/h264Preview_01_main',
    subPath: '/h264Preview_01_sub',
    hint: 'Activez RTSP dans Réglages → Réseau → Avancé → Ports. '
        'Modèles 4K / H.265 : /h265Preview_01_main.',
  );
  static const axis = IpCameraPreset(
    id: 'axis',
    label: 'Axis',
    mainPath: '/axis-media/media.amp',
    subPath: '/axis-media/media.amp?resolution=640x360',
    hint: 'Paramètres possibles : ?videocodec=h264&resolution=1280x720.',
  );
  static const tapo = IpCameraPreset(
    id: 'tapo',
    label: 'TP-Link Tapo',
    mainPath: '/stream1',
    subPath: '/stream2',
    hint: "Créez d'abord un « Compte de la caméra » dans l'application Tapo "
        '(Paramètres avancés) : ce sont cet identifiant et ce mot de passe.',
  );
  static const foscam = IpCameraPreset(
    id: 'foscam',
    label: 'Foscam',
    port: 88,
    mainPath: '/videoMain',
    subPath: '/videoSub',
    hint: 'Port RTSP 88 sur la plupart des modèles récents (vérifiez dans Réglages → Réseau → Port).',
  );
  static const onvif = IpCameraPreset(
    id: 'onvif',
    label: 'ONVIF générique',
    hint: "Le chemin dépend du modèle : lisez-le dans l'interface de la caméra "
        'ou avec ONVIF Device Manager (profil de flux).',
  );
  static const other = IpCameraPreset(
    id: 'other',
    label: 'Autre',
    hint: 'Indiquez le chemin donné par la documentation de la caméra.',
  );

  static const all = [hikvision, dahua, amcrest, reolink, axis, tapo, foscam, onvif, other];

  static IpCameraPreset byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => other);

  /// Modèle reconnu d'après le chemin (adresse collée), sinon [other].
  static (IpCameraPreset, IpCameraStream) detect(String path) {
    final p = path.toLowerCase();
    for (final preset in all) {
      if (preset.mainPath != null && p == preset.mainPath!.toLowerCase()) {
        return (preset, IpCameraStream.main);
      }
      if (preset.subPath != null && p == preset.subPath!.toLowerCase()) {
        return (preset, IpCameraStream.sub);
      }
    }
    return (other, IpCameraStream.main);
  }
}

/// Réglages d'une caméra IP. [password] et [passphrase] sont des secrets :
/// ni affichés ([maskedUrl]) ni mémorisés ([toStorage]).
class IpCameraConfig {
  const IpCameraConfig({
    this.protocol = IpCameraProtocol.rtsp,
    this.host = '',
    this.port,
    this.path = '',
    this.username = '',
    this.password = '',
    this.streamId = '',
    this.passphrase = '',
    this.presetId = 'other',
    this.stream = IpCameraStream.main,
  });

  final IpCameraProtocol protocol;
  final String host;

  /// null : port par défaut du protocole.
  final int? port;

  /// Chemin et paramètres (`/stream1`, `/cam/realmonitor?channel=1&subtype=0`).
  final String path;
  final String username;
  final String password;

  /// SRT seulement.
  final String streamId;
  final String passphrase;

  final String presetId;
  final IpCameraStream stream;

  IpCameraPreset get preset => IpCameraPreset.byId(presetId);
  int get effectivePort => port ?? protocol.defaultPort;

  /// Longueur maximale acceptée par le serveur pour `camera_url`.
  static const maxLength = 500;

  IpCameraConfig copyWith({
    IpCameraProtocol? protocol,
    String? host,
    int? port,
    bool clearPort = false,
    String? path,
    String? username,
    String? password,
    String? streamId,
    String? passphrase,
    String? presetId,
    IpCameraStream? stream,
  }) =>
      IpCameraConfig(
        protocol: protocol ?? this.protocol,
        host: host ?? this.host,
        port: clearPort ? null : (port ?? this.port),
        path: path ?? this.path,
        username: username ?? this.username,
        password: password ?? this.password,
        streamId: streamId ?? this.streamId,
        passphrase: passphrase ?? this.passphrase,
        presetId: presetId ?? this.presetId,
        stream: stream ?? this.stream,
      );

  /// Applique un préréglage : protocole, port et chemin du flux choisi.
  IpCameraConfig applyPreset(IpCameraPreset p, {IpCameraStream? stream}) {
    final s = p.hasSubStream ? (stream ?? this.stream) : IpCameraStream.main;
    final known = p.mainPath != null;
    return IpCameraConfig(
      protocol: known ? p.protocol : protocol,
      host: host,
      port: known ? (p.port ?? p.protocol.defaultPort) : port,
      path: known ? p.pathFor(s)! : path,
      username: username,
      password: password,
      streamId: streamId,
      passphrase: passphrase,
      presetId: p.id,
      stream: s,
    );
  }

  // ── Composition ─────────────────────────────────────────────────────────

  /// Adresse complète envoyée au serveur (`camera_url`).
  String toUrl() => _compose(maskSecrets: false);

  /// Adresse affichée : mot de passe et phrase secrète remplacés par `••••`.
  String maskedUrl() => _compose(maskSecrets: true);

  String _compose({required bool maskSecrets}) {
    final b = StringBuffer('${protocol.scheme}://');
    final user = username.trim();
    if (!protocol.isSrt && user.isNotEmpty) {
      b.write(encodeUserInfo(user));
      if (password.isNotEmpty) {
        b.write(':${maskSecrets ? '••••' : encodeUserInfo(password)}');
      }
      b.write('@');
    }
    b.write(formatHost(host.trim()));
    b.write(':$effectivePort');

    var p = path.trim();
    if (protocol.isSrt) {
      final params = <String>[
        if (streamId.trim().isNotEmpty) 'streamid=${encodeUserInfo(streamId.trim())}',
        if (passphrase.isNotEmpty)
          'passphrase=${maskSecrets ? '••••' : encodeUserInfo(passphrase)}',
      ];
      if (params.isNotEmpty) {
        if (p.contains('?')) {
          p = '$p&${params.join('&')}';
        } else {
          p = '$p?${params.join('&')}';
        }
      }
    }
    if (p.isNotEmpty && !p.startsWith('/') && !p.startsWith('?')) p = '/$p';
    b.write(p);
    return b.toString();
  }

  /// Encodage « pourcent » d'un identifiant / mot de passe : seuls
  /// `A-Z a-z 0-9 - _ . ~` restent tels quels (`@ : / % #` … sont encodés),
  /// comme `encodeURIComponent` côté site.
  static final _unreserved = RegExp(r'^[A-Za-z0-9\-_.~]$');

  static String encodeUserInfo(String value) {
    final out = StringBuffer();
    for (final byte in utf8.encode(value)) {
      final c = String.fromCharCode(byte);
      if (byte < 128 && _unreserved.hasMatch(c)) {
        out.write(c);
      } else {
        out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  /// IPv6 entre crochets.
  static String formatHost(String host) =>
      host.contains(':') && !host.startsWith('[') ? '[$host]' : host;

  // ── Lecture d'une adresse collée ────────────────────────────────────────

  /// Remplit les champs à partir d'une adresse complète ; null si le protocole
  /// n'est pas reconnu ou s'il manque l'hôte. Tolère un mot de passe non
  /// encodé contenant `@` ou `/` (on coupe au dernier `@` avant les paramètres).
  static IpCameraConfig? parse(String raw) {
    final url = raw.trim();
    final m = RegExp(r'^([A-Za-z][A-Za-z0-9+.-]*)://(.*)$', dotAll: true).firstMatch(url);
    if (m == null) return null;
    final protocol = IpCameraProtocol.fromScheme(m.group(1));
    if (protocol == null) return null;
    var rest = m.group(2)!;

    final q = rest.indexOf('?');
    final beforeQuery = q < 0 ? rest : rest.substring(0, q);
    final at = beforeQuery.lastIndexOf('@');
    var username = '';
    var password = '';
    if (at >= 0) {
      final info = rest.substring(0, at);
      rest = rest.substring(at + 1);
      final colon = info.indexOf(':');
      username = _decode(colon < 0 ? info : info.substring(0, colon));
      password = colon < 0 ? '' : _decode(info.substring(colon + 1));
    }

    final end = rest.indexOf(RegExp(r'[/?#]'));
    final authority = end < 0 ? rest : rest.substring(0, end);
    var path = end < 0 ? '' : rest.substring(end);

    String host;
    int? port;
    if (authority.startsWith('[')) {
      final close = authority.indexOf(']');
      if (close < 0) return null;
      host = authority.substring(1, close);
      final after = authority.substring(close + 1);
      if (after.startsWith(':')) port = int.tryParse(after.substring(1));
    } else {
      final colon = authority.lastIndexOf(':');
      host = colon < 0 ? authority : authority.substring(0, colon);
      if (colon >= 0) port = int.tryParse(authority.substring(colon + 1));
    }
    if (host.isEmpty) return null;

    var streamId = '';
    var passphrase = '';
    if (protocol.isSrt && path.contains('?')) {
      final i = path.indexOf('?');
      final kept = <String>[];
      for (final pair in path.substring(i + 1).split('&')) {
        final eq = pair.indexOf('=');
        final key = (eq < 0 ? pair : pair.substring(0, eq)).toLowerCase();
        final value = eq < 0 ? '' : _decode(pair.substring(eq + 1));
        if (key == 'streamid') {
          streamId = value;
        } else if (key == 'passphrase') {
          passphrase = value;
        } else if (pair.isNotEmpty) {
          kept.add(pair);
        }
      }
      path = path.substring(0, i) + (kept.isEmpty ? '' : '?${kept.join('&')}');
    }

    final (preset, stream) = IpCameraPreset.detect(path);
    return IpCameraConfig(
      protocol: protocol,
      host: host,
      port: port ?? protocol.defaultPort,
      path: path,
      username: username,
      password: password,
      streamId: streamId,
      passphrase: passphrase,
      presetId: preset.id,
      stream: stream,
    );
  }

  static String _decode(String s) {
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s; // « % » isolé : laissé tel quel
    }
  }

  // ── Vérifications ───────────────────────────────────────────────────────

  static final _hostname = RegExp(
      r'^(?=.{1,253}$)[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.?$');

  /// Message d'erreur pour l'hôte, ou null.
  static String? validateHost(String value) {
    final h = value.trim();
    if (h.isEmpty) return "Indiquez l'adresse IP ou le nom d'hôte de la caméra.";
    if (h.contains('://')) return 'Indiquez seulement l\'adresse, sans « rtsp:// ».';
    if (h.contains(RegExp(r'[\s/@?#]'))) {
      return 'Adresse non valide (pas d\'espace, de « / », « @ » ni « ? »).';
    }
    final bare = h.startsWith('[') && h.endsWith(']') ? h.substring(1, h.length - 1) : h;
    if (bare.contains(':')) {
      return Uri.tryParse('http://[$bare]/') == null ? 'Adresse IPv6 non valide.' : null;
    }
    if (RegExp(r'^\d+(\.\d+){3}$').hasMatch(bare)) {
      return _ipv4(bare) == null ? 'Adresse IP non valide.' : null;
    }
    return _hostname.hasMatch(bare) ? null : "Nom d'hôte non valide.";
  }

  /// Message d'erreur pour le port, ou null (vide : port par défaut).
  static String? validatePort(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    final n = int.tryParse(v);
    if (n == null || n < 1 || n > 65535) return 'Port entre 1 et 65535.';
    return null;
  }

  /// Message d'erreur pour le chemin, ou null.
  static String? validatePath(String value) =>
      value.contains(RegExp(r'\s')) ? 'Le chemin ne doit pas contenir d\'espace.' : null;

  /// Phrase secrète SRT : 10 à 79 caractères si renseignée.
  static String? validatePassphrase(String value) =>
      value.isNotEmpty && (value.length < 10 || value.length > 79)
          ? 'La phrase secrète SRT compte 10 à 79 caractères.'
          : null;

  /// Toutes les erreurs de la configuration (vide : valide).
  List<String> errors() => [
        ?validateHost(host),
        ?validatePort(port?.toString() ?? ''),
        ?validatePath(path),
        if (protocol.isSrt) ?validatePassphrase(passphrase),
        if (toUrl().length > maxLength) 'Adresse trop longue (500 caractères au plus).',
      ];

  bool get isValid => errors().isEmpty;

  /// Adresse locale (192.168.x.x, 10.x.x.x, 172.16-31.x.x, 127.x, 169.254.x,
  /// 100.64-127.x (CGNAT), localhost, *.local, IPv6 locales) : le service
  /// vidéo, sur Internet, ne pourra pas la joindre.
  static bool isPrivateHost(String value) {
    var h = value.trim().toLowerCase();
    if (h.startsWith('[') && h.endsWith(']')) h = h.substring(1, h.length - 1);
    if (h.isEmpty) return false;
    if (h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local') ||
        h.endsWith('.lan') || h.endsWith('.home.arpa')) {
      return true;
    }
    final v4 = _ipv4(h);
    if (v4 != null) {
      final [a, b, _, _] = v4;
      return a == 10 ||
          a == 127 ||
          a == 0 ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 168) ||
          (a == 169 && b == 254) ||
          (a == 100 && b >= 64 && b <= 127);
    }
    if (h.contains(':')) {
      if (h == '::1' || h == '::') return true;
      final first = h.split(':').first;
      final n = int.tryParse(first.isEmpty ? '0' : first, radix: 16) ?? -1;
      return (n & 0xFE00) == 0xFC00 || (n & 0xFFC0) == 0xFE80; // fc00::/7, fe80::/10
    }
    return false;
  }

  static List<int>? _ipv4(String h) {
    final parts = h.split('.');
    if (parts.length != 4) return null;
    final out = <int>[];
    for (final p in parts) {
      if (!RegExp(r'^\d{1,3}$').hasMatch(p)) return null;
      final n = int.parse(p);
      if (n > 255) return null;
      out.add(n);
    }
    return out;
  }

  // ── Mémorisation (sans secret) ──────────────────────────────────────────

  /// Dernier réglage à mémoriser sur l'appareil : sans mot de passe ni
  /// phrase secrète.
  Map<String, Object?> toStorage() => {
        'protocol': protocol.scheme,
        'host': host,
        'port': port,
        'path': path,
        'username': username,
        'streamId': streamId,
        'preset': presetId,
        'stream': stream.name,
      };

  static IpCameraConfig fromStorage(Map<String, Object?> raw) => IpCameraConfig(
        protocol: IpCameraProtocol.fromScheme(raw['protocol']?.toString()) ??
            IpCameraProtocol.rtsp,
        host: raw['host']?.toString() ?? '',
        port: raw['port'] is int ? raw['port'] as int : int.tryParse('${raw['port']}'),
        path: raw['path']?.toString() ?? '',
        username: raw['username']?.toString() ?? '',
        streamId: raw['streamId']?.toString() ?? '',
        presetId: IpCameraPreset.byId(raw['preset']?.toString()).id,
        stream: raw['stream'] == 'sub' ? IpCameraStream.sub : IpCameraStream.main,
      );
}
