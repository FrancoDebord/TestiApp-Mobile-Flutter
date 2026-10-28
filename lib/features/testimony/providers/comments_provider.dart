import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/network/network_failure.dart';
import '../../../features/auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../../features/home/providers/home_providers.dart' show feedNotifierProvider;
import '../../../services/api_service.dart';
import '../../../shared/models/comment_model.dart';
import '../../../shared/models/user_model.dart';
import '../../offline/outbox_controller.dart';

/// Commentaire d'un témoignage gardé hors connexion (envoyé au retour du réseau).
OutboxDraft testimonyCommentDraft(String testimonyId, String text, {String? parentId}) => OutboxDraft(
      kind: OutboxKind.testimonyComment,
      label: text,
      targetId: testimonyId,
      localId: newLocalId(),
      request: OutboxRequest('POST', AppConstants.testimonyComments(testimonyId),
          body: {'text': text, 'parent_id': ?parentId}),
      preview: {'text': text, 'parentId': ?parentId},
    );

/// Commentaires de [testimonyId] encore dans la file d'envoi, plus récents d'abord
/// (affichés « en attente d'envoi » jusqu'à leur envoi).
List<CommentModel> pendingTestimonyComments(OutboxState outbox, String testimonyId, UserModel? me) => [
      for (final i in outbox.pendingFor(OutboxKind.testimonyComment, testimonyId).reversed)
        if (!i.isFailed)
          CommentModel(
            id: i.localId ?? 'local_${i.id}',
            testimonyId: testimonyId,
            userId: me?.id ?? '',
            user: me,
            text: i.payload.preview['text'] as String? ?? i.label,
            parentId: i.payload.preview['parentId'] as String?,
            createdAt: i.createdAt.toIso8601String(),
          ),
    ];

// ── CommentsNotifier (family par testimonyId) ─────────────────────────────────
//
// Riverpod 3: FamilyAsyncNotifier n'existe plus.
// L'arg est capturé dans le constructeur → CommentsNotifier.new est
// String → CommentsNotifier, ce qu'attend AsyncNotifierProvider.family.

class CommentsNotifier extends AsyncNotifier<List<CommentModel>> {
  CommentsNotifier(this.testimonyId);

  final String testimonyId;

  @override
  Future<List<CommentModel>> build() => _fetch();

  Future<List<CommentModel>> _fetch() async {
    final api = ref.read(apiServiceProvider);
    final res =
        await api.get<dynamic>(AppConstants.testimonyComments(testimonyId));
    final raw = res.data is List
        ? res.data as List
        : (res.data is Map ? (res.data['data'] as List? ?? []) : []);
    final fetched = raw
        .whereType<Map<String, dynamic>>()
        .map(CommentModel.fromJson)
        .toList();
    // Écrits hors connexion, pas encore envoyés : gardés en tête de liste.
    return [
      ...pendingTestimonyComments(ref.read(outboxProvider), testimonyId, ref.read(currentUserProvider)),
      ...fetched,
    ];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> addComment(String text, {String? parentId}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Optimistic : préfixer un commentaire temporaire
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempComment = CommentModel(
      id:          tempId,
      testimonyId: testimonyId,
      userId:      user.id,
      user:        user,
      text:        text,
      parentId:    parentId,
      createdAt:   DateTime.now().toIso8601String(),
    );
    final current = state.value ?? [];
    state = AsyncValue.data([tempComment, ...current]);

    // Incrémenter le compteur dans le feed (top-level uniquement)
    if (parentId == null) {
      ref
          .read(feedNotifierProvider.notifier)
          .applyOptimisticDelta(testimonyId, comments: 1);
    }

    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post<Map<String, dynamic>>(
        AppConstants.testimonyComments(testimonyId),
        data: {
          'text': text,
          'parent_id': ?parentId,
        },
      );
      final real = CommentModel.fromJson(res.data);
      // Remplacer le temporaire par le vrai
      state = AsyncValue.data([
        for (final c in state.value ?? [])
          if (c.id == tempId) real else c,
      ]);
    } catch (e) {
      // Hors connexion : gardé dans la file d'envoi, affiché « en attente d'envoi ».
      final outbox = ref.read(outboxProvider.notifier);
      final draft = testimonyCommentDraft(testimonyId, text, parentId: parentId);
      if (isNetworkFailure(e) && outbox.canQueue(draft)) {
        await outbox.enqueue(draft);
        state = AsyncValue.data([
          for (final c in state.value ?? [])
            if (c.id == tempId)
              CommentModel(
                id: draft.localId!,
                testimonyId: testimonyId,
                userId: user.id,
                user: user,
                text: text,
                parentId: parentId,
                createdAt: c.createdAt,
              )
            else
              c,
        ]);
        return;
      }
      // Annuler l'optimistic sur erreur
      state = AsyncValue.data(
        (state.value ?? []).where((c) => c.id != tempId).toList(),
      );
      if (parentId == null) {
        ref
            .read(feedNotifierProvider.notifier)
            .applyOptimisticDelta(testimonyId, comments: -1);
      }
    }
  }

  Future<void> deleteComment(String commentId) async {
    final comment =
        (state.value ?? []).where((c) => c.id == commentId).firstOrNull;
    final current = state.value ?? [];

    // Optimistic : retirer le commentaire
    state = AsyncValue.data(current.where((c) => c.id != commentId).toList());
    if (comment != null && !comment.isReply) {
      ref
          .read(feedNotifierProvider.notifier)
          .applyOptimisticDelta(testimonyId, comments: -1);
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.delete<void>(AppConstants.commentById(commentId));
    } catch (_) {
      // Annuler sur erreur
      if (comment != null) {
        state = AsyncValue.data(current);
        if (!comment.isReply) {
          ref
              .read(feedNotifierProvider.notifier)
              .applyOptimisticDelta(testimonyId, comments: 1);
        }
      }
    }
  }
}

final commentsProvider = AsyncNotifierProvider.family<CommentsNotifier,
    List<CommentModel>, String>(CommentsNotifier.new);
