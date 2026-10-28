// Actions faites sans réseau, gardées dans SQLite (table `outbox`) puis envoyées
// au retour de la connexion. Voir outbox_controller.dart.

import 'dart:convert';
import 'dart:math';

/// Sorte d'action (icône, libellé et listes à recharger une fois envoyée).
enum OutboxKind {
  testimony,
  videoTestimony,
  prayerRequest,
  prayerSession,
  event,
  testimonyComment,
  eventComment,
  verseComment,
  prayerMessage,
  reaction,
  save,

  /// Requête quelconque (reprise de l'ancienne file `pending_operations`).
  request;

  static OutboxKind fromName(String? name) =>
      OutboxKind.values.where((k) => k.name == name).firstOrNull ?? OutboxKind.request;

  /// Contenu créé par l'utilisateur (montré en premier, jamais fusionné).
  bool get isCreation => switch (this) {
        testimony || videoTestimony || prayerRequest || prayerSession || event => true,
        _ => false,
      };
}

enum OutboxStatus {
  /// En attente du réseau (ou d'une nouvelle tentative).
  pending,

  /// Refusé par le serveur : à corriger, renvoyer ou supprimer depuis « À envoyer ».
  failed,
}

/// Fichier envoyé en multipart (copié dans le dossier de l'action).
class OutboxFile {
  const OutboxFile({
    required this.path,
    required this.file,
    this.field = 'file',
    this.fields = const {},
    this.into,
    this.urlKey = 'url',
  });

  /// Route d'envoi ; `{id}` = identifiant renvoyé par la requête principale.
  final String path;

  /// Chemin du fichier sur le téléphone.
  final String file;
  final String field;
  final Map<String, dynamic> fields;

  /// Étape « avant » : champ du corps principal qui reçoit l'URL renvoyée (`cover_url`…).
  final String? into;
  final String urlKey;

  factory OutboxFile.fromJson(Map<String, dynamic> j) => OutboxFile(
        path: j['path'] as String,
        file: j['file'] as String,
        field: j['field'] as String? ?? 'file',
        fields: Map<String, dynamic>.from(j['fields'] as Map? ?? const {}),
        into: j['into'] as String?,
        urlKey: j['urlKey'] as String? ?? 'url',
      );

  Map<String, dynamic> toJson() => {
        'path': path,
        'file': file,
        'field': field,
        'fields': fields,
        'into': ?into,
        'urlKey': urlKey,
      };

  OutboxFile withFile(String newFile) => OutboxFile(
        path: path,
        file: newFile,
        field: field,
        fields: fields,
        into: into,
        urlKey: urlKey,
      );
}

/// Requête JSON principale.
class OutboxRequest {
  const OutboxRequest(this.method, this.path, {this.body, this.query});

  final String method;
  final String path;
  final Map<String, dynamic>? body;
  final Map<String, dynamic>? query;

  factory OutboxRequest.fromJson(Map<String, dynamic> j) => OutboxRequest(
        j['method'] as String? ?? 'POST',
        j['path'] as String,
        body: j['body'] is Map ? Map<String, dynamic>.from(j['body'] as Map) : null,
        query: j['query'] is Map ? Map<String, dynamic>.from(j['query'] as Map) : null,
      );

  Map<String, dynamic> toJson() => {
        'method': method,
        'path': path,
        'body': ?body,
        'query': ?query,
      };
}

/// Ce qu'il reste à faire pour une action (mis à jour après chaque étape réussie,
/// pour reprendre là où l'envoi s'est arrêté).
class OutboxPayload {
  OutboxPayload({
    this.request,
    List<OutboxFile>? before,
    List<OutboxFile>? after,
    this.createdId,
    this.video,
    this.preview = const {},
  })  : before = before ?? [],
        after = after ?? [];

  OutboxRequest? request;

  /// Fichiers à envoyer avant la requête (couverture, audio).
  final List<OutboxFile> before;

  /// Fichiers rattachés après la création (preuves, images d'un événement).
  final List<OutboxFile> after;

  /// Identifiant renvoyé par la requête principale (déjà faite).
  String? createdId;

  /// Témoignage vidéo : confié à l'envoi Bunny Stream (sourcePath, title, body, proofs).
  final Map<String, dynamic>? video;

  /// Données d'affichage en attendant l'envoi (texte du commentaire, réaction…).
  final Map<String, dynamic> preview;

  factory OutboxPayload.fromJson(Map<String, dynamic> j) => OutboxPayload(
        request: j['request'] is Map ? OutboxRequest.fromJson(Map<String, dynamic>.from(j['request'] as Map)) : null,
        before: [
          for (final f in (j['before'] as List? ?? const []))
            if (f is Map) OutboxFile.fromJson(Map<String, dynamic>.from(f)),
        ],
        after: [
          for (final f in (j['after'] as List? ?? const []))
            if (f is Map) OutboxFile.fromJson(Map<String, dynamic>.from(f)),
        ],
        createdId: j['createdId'] as String?,
        video: j['video'] is Map ? Map<String, dynamic>.from(j['video'] as Map) : null,
        preview: j['preview'] is Map ? Map<String, dynamic>.from(j['preview'] as Map) : const {},
      );

  Map<String, dynamic> toJson() => {
        'request': ?request?.toJson(),
        if (before.isNotEmpty) 'before': [for (final f in before) f.toJson()],
        if (after.isNotEmpty) 'after': [for (final f in after) f.toJson()],
        'createdId': ?createdId,
        'video': ?video,
        if (preview.isNotEmpty) 'preview': preview,
      };

  String encode() => jsonEncode(toJson());
}

/// Une action de la file.
class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.userId,
    required this.kind,
    required this.payload,
    required this.label,
    required this.status,
    required this.createdAt,
    this.actAs,
    this.targetId,
    this.localId,
    this.dedupeKey,
    this.attempts = 0,
    this.error,
    this.nextTryAt,
  });

  /// Identifiant de l'action, aussi envoyé comme `Idempotency-Key`.
  final String id;
  final String userId;

  /// Compte administré au nom duquel l'action a été faite (`X-Act-As`).
  final String? actAs;
  final OutboxKind kind;

  /// Contenu visé (témoignage commenté, événement…).
  final String? targetId;

  /// Identifiant provisoire de ce qui est créé (« local_… »).
  final String? localId;
  final String? dedupeKey;
  final OutboxPayload payload;

  /// Texte court montré dans « À envoyer » (titre, début du commentaire…).
  final String label;
  final OutboxStatus status;
  final int attempts;

  /// Message du serveur quand l'action a été refusée.
  final String? error;
  final DateTime? nextTryAt;
  final DateTime createdAt;

  bool get isFailed => status == OutboxStatus.failed;

  factory OutboxItem.fromRow(Map<String, dynamic> r) => OutboxItem(
        id: r['id'] as String,
        userId: r['user_id'] as String? ?? '',
        actAs: r['act_as'] as String?,
        kind: OutboxKind.fromName(r['kind'] as String?),
        targetId: r['target_id'] as String?,
        localId: r['local_id'] as String?,
        dedupeKey: r['dedupe_key'] as String?,
        payload: OutboxPayload.fromJson(_decode(r['payload'] as String?)),
        label: r['label'] as String? ?? '',
        status: r['status'] == 'failed' ? OutboxStatus.failed : OutboxStatus.pending,
        attempts: (r['attempts'] as num?)?.toInt() ?? 0,
        error: r['error'] as String?,
        nextTryAt: DateTime.tryParse(r['next_try_at'] as String? ?? ''),
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  static Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final v = jsonDecode(raw);
      return v is Map ? Map<String, dynamic>.from(v) : const {};
    } catch (_) {
      return const {};
    }
  }
}

/// Identifiant aléatoire (action de la file, identifiant local).
String outboxRandomId() {
  final rand = Random.secure();
  return List.generate(16, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Identifiant provisoire d'un contenu créé hors connexion.
String newLocalId() => 'local_${outboxRandomId()}';

/// Identifiants provisoires présents dans une route ou un corps JSON.
final localIdPattern = RegExp(r'local_[0-9a-f]{32}');
