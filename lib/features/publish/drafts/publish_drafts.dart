// Brouillons de témoignage gardés sur le téléphone (table SQLite `drafts`).
//
// Le formulaire « Publier » s'enregistre tout seul pendant la saisie (et quand on
// le quitte) : un retour par mégarde ou la fermeture de l'application ne perd rien.
// Les fichiers choisis (couverture, audio, vidéo, preuves) sont copiés dans le
// dossier du brouillon : le dossier temporaire du sélecteur peut être vidé.
// Liste et reprise : écran « Publier » ; suppression : liste ou en quittant.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/local_db/database_schema.dart';
import '../../../core/local_db/database_service.dart';
import '../../auth/providers/auth_notifier.dart' show realUserProvider;
import '../models/publish_models.dart';

/// Brouillon enregistré.
class SavedPublishDraft {
  const SavedPublishDraft({required this.id, required this.draft, required this.updatedAt});

  final String id;
  final PublishDraft draft;
  final DateTime updatedAt;
}

/// Lecture et écriture des brouillons (remplacé dans les tests).
class PublishDraftsStore {
  const PublishDraftsStore();

  static const _t = DatabaseSchema.tDrafts;
  DatabaseService get _db => DatabaseService();

  Future<List<SavedPublishDraft>> list(String userId) async {
    final rows = await _db.query(_t,
        where: 'user_id = ? AND payload IS NOT NULL', whereArgs: [userId], orderBy: 'updated_at DESC');
    return [
      for (final r in rows)
        if (_decode(r['payload'] as String?) case final j?)
          SavedPublishDraft(
            id: r['id'] as String,
            draft: PublishDraft.fromDraftJson(j, draftId: r['id'] as String),
            updatedAt: DateTime.tryParse(r['updated_at'] as String? ?? '') ?? DateTime.now(),
          ),
    ];
  }

  Future<SavedPublishDraft?> byId(String id) async {
    final rows = await _db.query(_t, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final j = _decode(rows.first['payload'] as String?);
    if (j == null) return null;
    return SavedPublishDraft(
      id: id,
      draft: PublishDraft.fromDraftJson(j, draftId: id),
      updatedAt: DateTime.tryParse(rows.first['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Enregistre [draft] (nouveau ou mis à jour) ; renvoie le brouillon avec son
  /// identifiant et les chemins de ses fichiers copiés.
  Future<PublishDraft> save(String userId, PublishDraft draft) async {
    final id = draft.draftId ?? 'draft_${DateTime.now().microsecondsSinceEpoch}';
    final kept = await _keepFiles(id, draft.copyWith(draftId: id));
    final now = DateTime.now().toIso8601String();
    final existing = await _db.query(_t, where: 'id = ?', whereArgs: [id], limit: 1);
    await _db.insert(_t, {
      'id': id,
      'user_id': userId,
      'type': kept.format?.name ?? 'text',
      'title': kept.effectiveTitle,
      'body_text': kept.format == TestimonyFormat.audio ? kept.audioTranscript : kept.bodyText,
      'status': 'draft',
      'payload': jsonEncode(kept.toDraftJson()),
      'created_at': existing.isEmpty ? now : existing.first['created_at'],
      'updated_at': now,
    });
    return kept;
  }

  Future<void> delete(String id) async {
    await _db.delete(_t, where: 'id = ?', whereArgs: [id]);
    if (kIsWeb) return;
    try {
      final dir = Directory(await _dirPath(id));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  static Map<String, dynamic>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _dirPath(String id) async =>
      '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}drafts${Platform.pathSeparator}$id';

  /// Copie chaque fichier du brouillon dans son dossier (une seule fois).
  Future<PublishDraft> _keepFiles(String id, PublishDraft d) async {
    if (kIsWeb) return d;
    final dir = await _dirPath(id);
    Future<String?> keep(String? path) async {
      if (path == null || path.isEmpty || path.startsWith(dir)) return path;
      try {
        final src = File(path);
        if (!await src.exists()) return path;
        await Directory(dir).create(recursive: true);
        final name = path.split(RegExp(r'[\\/]')).last;
        return (await src.copy('$dir${Platform.pathSeparator}$name')).path;
      } catch (e) {
        debugPrint('Brouillon ✗ copie de $path : $e');
        return path;
      }
    }

    final proofs = <int, ProofAttachment>{};
    for (final e in d.proofs.entries) {
      proofs[e.key] = ProofAttachment(path: await keep(e.value.path) ?? e.value.path, name: e.value.name, size: e.value.size);
    }
    return d.copyWith(
      coverImagePath: await keep(d.coverImagePath),
      audioPath: await keep(d.audioPath),
      videoPath: await keep(d.videoPath),
      proofs: proofs,
    );
  }
}

final publishDraftsStoreProvider = Provider<PublishDraftsStore>((_) => const PublishDraftsStore());

/// Brouillons de la personne connectée, plus récents d'abord.
class PublishDraftsNotifier extends AsyncNotifier<List<SavedPublishDraft>> {
  @override
  Future<List<SavedPublishDraft>> build() async {
    final uid = ref.watch(realUserProvider.select((u) => u?.id));
    if (uid == null) return const [];
    try {
      return await ref.read(publishDraftsStoreProvider).list(uid);
    } catch (e) {
      debugPrint('Brouillons ✗ lecture : $e');
      return const [];
    }
  }

  Future<void> delete(String id) async {
    await ref.read(publishDraftsStoreProvider).delete(id);
    ref.invalidateSelf();
  }
}

final publishDraftsProvider =
    AsyncNotifierProvider<PublishDraftsNotifier, List<SavedPublishDraft>>(PublishDraftsNotifier.new);
