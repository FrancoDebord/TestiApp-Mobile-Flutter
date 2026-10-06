// Mentions « @ » : format d'échange avec le serveur (Dart pur).
// Backend : docs/fonctionnalites/mentions.md
//
// Le serveur enregistre `@[Nom affiché](user:uuid)` et renvoie le texte lisible (`@Nom affiché`)
// accompagné de `mentions: [{id, displayName}]`.

/// Compte mentionné dans un texte.
class MentionRef {
  const MentionRef({required this.id, required this.displayName});

  final String id;
  final String displayName;

  factory MentionRef.fromJson(Map<String, dynamic> j) => MentionRef(
        id: '${j['id'] ?? ''}',
        displayName: '${j['displayName'] ?? j['display_name'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {'id': id, 'displayName': displayName};

  /// Liste `mentions` d'une réponse JSON (absente ou mal formée : liste vide).
  static List<MentionRef> listFrom(Object? raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((e) => MentionRef.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.id.isNotEmpty && m.displayName.isNotEmpty)
          .toList()
      : const [];

  @override
  bool operator ==(Object other) => other is MentionRef && other.id == id && other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, displayName);
}

/// Conversion texte lisible ⇄ jetons `@[Nom](user:id)`.
class MentionCodec {
  MentionCodec._();

  static final RegExp token = RegExp(r'@\[([^\[\]\r\n]{1,100})\]\(user:([0-9a-fA-F-]{36})\)');

  /// Texte à jetons → (texte lisible, mentions).
  static ({String text, List<MentionRef> mentions}) decode(String raw) {
    if (!raw.contains('](user:')) return (text: raw, mentions: const []);
    final mentions = <MentionRef>[];
    final text = raw.replaceAllMapped(token, (m) {
      final ref = MentionRef(id: m.group(2)!.toLowerCase(), displayName: m.group(1)!);
      if (!mentions.any((e) => e.id == ref.id)) mentions.add(ref);
      return '@${ref.displayName}';
    });
    return (text: text, mentions: mentions);
  }

  /// Texte lisible + mentions → texte à jetons (pour l'envoi ou le cache local).
  static String encode(String text, Iterable<MentionRef> mentions) {
    var out = text;
    final sorted = [...mentions]..sort((a, b) => b.displayName.length.compareTo(a.displayName.length));
    for (final m in sorted) {
      if (m.displayName.isEmpty) continue;
      out = _segmentsOutsideTokens(out, (segment) => segment.replaceAllMapped(
            _plainPattern(m.displayName),
            (match) => '${match.group(1)}@[${m.displayName}](user:${m.id})',
          ));
    }
    return out;
  }

  /// « @Nom » précédé d'un début, d'un espace ou d'une ponctuation, et non suivi d'une lettre ou d'un chiffre.
  static RegExp _plainPattern(String name) =>
      RegExp('(^|[^\\p{L}\\p{N}_])@${RegExp.escape(name)}(?![\\p{L}\\p{N}_])', unicode: true);

  static String _segmentsOutsideTokens(String text, String Function(String) fn) {
    final buffer = StringBuffer();
    var last = 0;
    for (final m in token.allMatches(text)) {
      buffer
        ..write(fn(text.substring(last, m.start)))
        ..write(m.group(0));
      last = m.end;
    }
    buffer.write(fn(text.substring(last)));
    return buffer.toString();
  }

  /// Plages (début, fin, mention) des « @Nom » d'un texte lisible, sans chevauchement, dans l'ordre.
  static List<({int start, int end, MentionRef ref})> ranges(String text, Iterable<MentionRef> mentions) {
    final found = <({int start, int end, MentionRef ref})>[];
    final sorted = [...mentions]..sort((a, b) => b.displayName.length.compareTo(a.displayName.length));
    for (final m in sorted) {
      if (m.displayName.isEmpty) continue;
      for (final match in _plainPattern(m.displayName).allMatches(text)) {
        final start = match.start + match.group(1)!.length;
        final end = match.end;
        if (found.any((r) => start < r.end && end > r.start)) continue;
        found.add((start: start, end: end, ref: m));
      }
    }
    found.sort((a, b) => a.start.compareTo(b.start));
    return found;
  }
}
