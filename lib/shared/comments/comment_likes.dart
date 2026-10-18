// « J'aime » sur les commentaires (témoignages, événements, verset du jour) :
// état partagé (même commentaire affiché à plusieurs endroits), mise à jour
// immédiate puis réponse du serveur, retour arrière en cas d'échec.
// Backend : docs/fonctionnalites/jaime-commentaires.md
//   POST · DELETE /comments/{id}/like
//   POST · DELETE /events/{eventId}/comments/{id}/like
//   POST · DELETE /daily-verse/{verseId}/comments/{id}/like
//   → { likesCount, isLikedByMe }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../widgets/guest_gate.dart' show requireAccount;

/// Commentaire visé : sorte, identifiant, et contenu parent (événement, verset).
class CommentRef {
  const CommentRef.testimony(this.id) : kind = 'testimony', parentId = null;
  const CommentRef.event(String eventId, this.id) : kind = 'event', parentId = eventId;
  const CommentRef.verse(String verseId, this.id) : kind = 'verse', parentId = verseId;

  final String kind;
  final String id;
  final String? parentId;

  String get key => '$kind:$id';

  String get likePath => switch (kind) {
        'event' => '/events/$parentId/comments/$id/like',
        'verse' => '/daily-verse/$parentId/comments/$id/like',
        _ => '/comments/$id/like',
      };

  /// Commentaire pas encore enregistré (envoi en cours) : pas de « J'aime ».
  bool get isPending => id.isEmpty || id.startsWith('temp_') || id.startsWith('local_');
}

typedef CommentLike = ({int count, bool liked});

class CommentLikesNotifier extends Notifier<Map<String, CommentLike>> {
  /// Dernière requête par commentaire : une réponse plus ancienne est ignorée.
  final _requests = <String, int>{};

  @override
  Map<String, CommentLike> build() => const {};

  CommentLike of(CommentRef c, {required int count, required bool liked}) =>
      state[c.key] ?? (count: count, liked: liked);

  /// Bascule « J'aime » ; renvoie le message d'erreur du serveur, ou null.
  Future<String?> toggle(CommentRef c, {required int count, required bool liked}) async {
    final before = of(c, count: count, liked: liked);
    final target = !before.liked;
    final next = (count: (before.count + (target ? 1 : -1)).clamp(0, 1 << 30), liked: target);
    state = {...state, c.key: next};
    final request = (_requests[c.key] ?? 0) + 1;
    _requests[c.key] = request;
    try {
      final api = ref.read(apiServiceProvider);
      final res = target
          ? await api.post<dynamic>(c.likePath)
          : await api.delete<dynamic>(c.likePath);
      if (_requests[c.key] != request) return null;
      final d = res.data;
      if (d is Map) {
        state = {
          ...state,
          c.key: (
            count: (d['likesCount'] as num?)?.toInt() ?? next.count,
            liked: d['isLikedByMe'] as bool? ?? next.liked,
          ),
        };
      }
      return null;
    } on LaravelApiException catch (e) {
      if (_requests[c.key] == request) state = {...state, c.key: before};
      return e.displayMessage;
    } catch (_) {
      if (_requests[c.key] == request) state = {...state, c.key: before};
      return L10n.current.commentLikeFailed;
    }
  }
}

final commentLikesProvider =
    NotifierProvider<CommentLikesNotifier, Map<String, CommentLike>>(CommentLikesNotifier.new);

/// Cœur + compteur d'un commentaire.
class CommentLikeButton extends ConsumerWidget {
  const CommentLikeButton({
    required this.comment,
    required this.initialCount,
    required this.initialLiked,
    this.iconSize = 15,
    this.color,
    super.key,
  });

  final CommentRef comment;
  final int initialCount;
  final bool initialLiked;
  final double iconSize;

  /// Couleur du cœur vide et du compteur (fond sombre : blanc).
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.watch(commentLikesProvider.select((m) => m[comment.key]));
    final like = ref.read(commentLikesProvider.notifier).of(comment, count: initialCount, liked: initialLiked);
    final idle = color ?? AppColors.textSecondary;
    return Semantics(
      button: true,
      toggled: like.liked,
      label: like.liked ? l10n.commentUnlike : l10n.commentLike,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('comment-like-${comment.key}'),
        borderRadius: BorderRadius.circular(16),
        onTap: comment.isPending
            ? null
            : () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                if (!await requireAccount(context, ref, reason: l10n.commentLikeReason)) return;
                final err = await ref
                    .read(commentLikesProvider.notifier)
                    .toggle(comment, count: initialCount, liked: initialLiked);
                if (err != null) {
                  messenger?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(err)));
                }
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                like.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: iconSize,
                color: like.liked ? AppColors.danger : idle,
              ),
              if (like.count > 0) ...[
                const SizedBox(width: 3),
                Text('${like.count}', style: AppTextStyles.bodySmall.copyWith(color: like.liked ? AppColors.danger : idle)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
