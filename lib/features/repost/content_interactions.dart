// Réactions (j'aime, je prie…) et partage interne des événements, requêtes et sessions de prière,
// comme pour les témoignages : une réaction « j'aime » et une « je prie » au plus par personne,
// un partage par personne (avec commentaire facultatif), visible dans « Mon fil » des abonnés.
// API : POST|DELETE {publication}/reactions, POST|DELETE {publication}/repost
// Doc serveur : fonctionnalites/reactions.md, partage-interne.md

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../prayer/screens/prayer_focus_screen.dart' show PrayerFocusSubject, openPrayerFocusFor;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/guest_gate.dart';
import '../home/providers/home_providers.dart' show ReactionType, ReactionTypeInfo, reactionTypeFromApi;
import '../home/widgets/testimony_action_bar.dart' show formatCount;
import '../../l10n/app_localizations.dart';

/// Type de publication (segment d'URL de l'API).
enum ContentKind {
  event('/events'),
  prayerRequest('/prayer/requests'),
  prayerSession('/prayer/sessions');

  const ContentKind(this.prefix);
  final String prefix;

  /// « cet événement » (feuilles et messages).
  String get thisLabel => switch (this) {
        ContentKind.event => L10n.current.repostKindEventThis,
        ContentKind.prayerRequest => L10n.current.repostKindPrayerRequestThis,
        ContentKind.prayerSession => L10n.current.repostKindPrayerSessionThis,
      };

  /// « L'événement » (début de phrase).
  String get theLabel => switch (this) {
        ContentKind.event => L10n.current.repostKindEventThe,
        ContentKind.prayerRequest => L10n.current.repostKindPrayerRequestThe,
        ContentKind.prayerSession => L10n.current.repostKindPrayerSessionThe,
      };

  String path(String id, String action) => '$prefix/$id/$action';
}

/// Compteurs et état de la personne connectée (champ `reactions` de l'API).
class ContentReactions {
  const ContentReactions({
    this.likesCount = 0,
    this.prayersCount = 0,
    this.repostsCount = 0,
    this.myReaction,
    this.myPrayerReaction,
    this.isRepostedByMe = false,
    this.canRepost = false,
  });

  final int likesCount;
  final int prayersCount;
  final int repostsCount;
  final String? myReaction;
  final String? myPrayerReaction;
  final bool isRepostedByMe;
  final bool canRepost;

  bool get isLiked => myReaction != null;
  bool get isPrayed => myPrayerReaction != null;

  static ContentReactions fromJson(Object? raw) {
    if (raw is! Map) return const ContentReactions();
    int n(Object? v) => v is num ? v.toInt() : 0;
    return ContentReactions(
      likesCount: n(raw['likesCount']),
      prayersCount: n(raw['prayersCount']),
      repostsCount: n(raw['repostsCount']),
      myReaction: raw['myReaction'] as String?,
      myPrayerReaction: raw['myPrayerReaction'] as String?,
      isRepostedByMe: raw['isRepostedByMe'] == true,
      canRepost: raw['canRepost'] == true,
    );
  }

  ContentReactions copyWith({
    int? likesCount,
    int? prayersCount,
    String? Function()? myReaction,
    String? Function()? myPrayerReaction,
  }) =>
      ContentReactions(
        likesCount: likesCount ?? this.likesCount,
        prayersCount: prayersCount ?? this.prayersCount,
        repostsCount: repostsCount,
        myReaction: myReaction != null ? myReaction() : this.myReaction,
        myPrayerReaction: myPrayerReaction != null ? myPrayerReaction() : this.myPrayerReaction,
        isRepostedByMe: isRepostedByMe,
        canRepost: canRepost,
      );
}

/// État à jour par publication (réponse du serveur ou mise à jour optimiste), au-dessus de
/// l'état reçu avec la publication. Clé : `kind:id`.
class ContentInteractionsNotifier extends Notifier<Map<String, ContentReactions>> {
  final _requests = <String, int>{};

  @override
  Map<String, ContentReactions> build() => const {};

  static String key(ContentKind kind, String id) => '${kind.name}:$id';

  ContentReactions of(ContentKind kind, String id, ContentReactions initial) => state[key(kind, id)] ?? initial;

  /// Pose la réaction [type] (remplace la précédente) ou retire la réaction « j'aime » si null.
  /// Renvoie le message d'erreur à afficher, ou null si le serveur a accepté.
  Future<String?> react(ContentKind kind, String id, ContentReactions current, ReactionType? type) {
    final was = current.isLiked;
    final likes = current.likesCount + (was == (type != null) ? 0 : (type != null ? 1 : -1));
    return _send(
      kind,
      id,
      current.copyWith(likesCount: likes < 0 ? 0 : likes, myReaction: () => type?.apiValue),
      (api) => type != null
          ? api.post<Map<String, dynamic>>(kind.path(id, 'reactions'), data: {'type': type.apiValue})
          : api.delete<Map<String, dynamic>>(kind.path(id, 'reactions'), query: const {'group': 'appreciation'}),
    );
  }

  /// « Je prie » (événements et sessions ; les requêtes ont leur propre bouton).
  Future<String?> togglePray(ContentKind kind, String id, ContentReactions current) {
    final prayed = !current.isPrayed;
    final prayers = current.prayersCount + (prayed ? 1 : -1);
    return _send(
      kind,
      id,
      current.copyWith(prayersCount: prayers < 0 ? 0 : prayers, myPrayerReaction: () => prayed ? 'pray' : null),
      (api) => prayed
          ? api.post<Map<String, dynamic>>(kind.path(id, 'reactions'), data: const {'type': 'pray'})
          : api.delete<Map<String, dynamic>>(kind.path(id, 'reactions'), query: const {'group': 'prayer'}),
    );
  }

  /// Partager avec ses abonnés (ou changer le commentaire). Renvoie le message du serveur.
  Future<String> repost(ContentKind kind, String id, {String? comment}) async {
    final res = await ref.read(apiServiceProvider).post<Map<String, dynamic>>(
          kind.path(id, 'repost'),
          data: {if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim()},
        );
    _apply(kind, id, res.data);
    return res.message ?? L10n.current.repostSharedWithFollowers;
  }

  /// Annuler son partage. Renvoie le message du serveur.
  Future<String> unrepost(ContentKind kind, String id) async {
    final res = await ref.read(apiServiceProvider).delete<Map<String, dynamic>>(kind.path(id, 'repost'));
    _apply(kind, id, res.data);
    return res.message ?? L10n.current.repostCancelled;
  }

  void _apply(ContentKind kind, String id, Map<String, dynamic> data) {
    if (data['reactions'] is Map) {
      state = {...state, key(kind, id): ContentReactions.fromJson(data['reactions'])};
    }
  }

  Future<String?> _send(
    ContentKind kind,
    String id,
    ContentReactions optimistic,
    Future<LaravelResponse<Map<String, dynamic>>> Function(ApiService api) call,
  ) async {
    final k = key(kind, id);
    final before = state[k];
    state = {...state, k: optimistic};
    final request = (_requests[k] ?? 0) + 1;
    _requests[k] = request;
    try {
      final res = await call(ref.read(apiServiceProvider));
      if (_requests[k] == request) _apply(kind, id, res.data);
      return null;
    } catch (e) {
      debugPrint('réaction ✗ $e');
      if (_requests[k] == request) {
        final next = {...state};
        if (before == null) {
          next.remove(k);
        } else {
          next[k] = before;
        }
        state = next;
      }
      // Route absente (serveur pas à jour) ou refus : on le dit au lieu d'annuler en silence.
      if (e is LaravelApiException && e.statusCode == 404) {
        return L10n.current.repostServerUnsupported;
      }
      return e is LaravelApiException && e.message.isNotEmpty ? e.message : L10n.current.repostReactionFailed;
    }
  }
}

final contentInteractionsProvider =
    NotifierProvider<ContentInteractionsNotifier, Map<String, ContentReactions>>(ContentInteractionsNotifier.new);

/// Rangée « ❤ J'aime · 🙏 Je prie · ↗ Partager » d'un événement, d'une requête ou d'une session.
/// Appui long sur ❤ : choisir une autre réaction (une seule à la fois).
class ContentReactionBar extends ConsumerWidget {
  const ContentReactionBar({
    required this.kind,
    required this.id,
    required this.initial,
    required this.title,
    this.webUrl,
    this.showPray = true,
    this.dense = false,
    super.key,
  });

  final ContentKind kind;
  final String id;

  /// État reçu avec la publication.
  final ContentReactions initial;

  /// Titre partagé vers les autres applications.
  final String title;
  final String? webUrl;

  /// Faux pour les requêtes de prière : leur « Je prie » est un bouton dédié.
  final bool showPray;

  /// Rangée plus compacte (cartes des fils).
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(contentInteractionsProvider.notifier);
    final r = ref.watch(contentInteractionsProvider.select((m) => m[ContentInteractionsNotifier.key(kind, id)])) ?? initial;
    final mine = reactionTypeFromApi(r.myReaction);

    Future<bool> member() => requireAccount(context, ref, reason: context.l10n.repostReasonReactShare);

    void report(String? error) {
      if (error == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), behavior: SnackBarBehavior.floating));
    }

    Future<void> react(ReactionType? type) async {
      if (!await member()) return;
      report(await notifier.react(kind, id, ref.read(contentInteractionsProvider)[ContentInteractionsNotifier.key(kind, id)] ?? initial, type));
    }

    Future<void> pickReaction() async {
      if (!await member() || !context.mounted) return;
      final picked = await showModalBottomSheet<ReactionType>(
        context: context,
        useRootNavigator: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in ReactionType.values.where((t) => t != ReactionType.pray))
                  ChoiceChip(
                    label: Text('${t.emoji} ${t.label}'),
                    selected: t == mine,
                    onSelected: (_) => Navigator.of(sheet).pop(t),
                  ),
              ],
            ),
          ),
        ),
      );
      if (picked != null) {
        report(await notifier.react(kind, id, ref.read(contentInteractionsProvider)[ContentInteractionsNotifier.key(kind, id)] ?? initial, picked));
      }
    }

    Future<void> pray() async {
      if (!await member()) return;
      final current = ref.read(contentInteractionsProvider)[ContentInteractionsNotifier.key(kind, id)] ?? initial;
      // Prier : temps de prière immersif de 5 minutes d'abord (retirer reste immédiat).
      if (!current.isPrayed) {
        if (!context.mounted) return;
        final l10n = context.l10n;
        final api = ref.read(apiServiceProvider);
        final ok = await openPrayerFocusFor(
          context,
          PrayerFocusSubject(
            title: title,
            body: '',
            authorName: '',
            subtitle: l10n.prayerFocusContentSubtitle,
            label: switch (kind) {
              ContentKind.event => l10n.prayerFocusKindEvent,
              ContentKind.prayerRequest => l10n.prayerFocusSubject,
              ContentKind.prayerSession => l10n.prayerFocusKindSession,
            },
            confirmLabel: l10n.prayerFocusContentConfirm,
            onStart: () => api.post<dynamic>(kind.path(id, 'pray/start')),
          ),
        );
        if (!ok) return;
      }
      final latest = ref.read(contentInteractionsProvider)[ContentInteractionsNotifier.key(kind, id)] ?? initial;
      if (latest.isPrayed != current.isPrayed) return;
      report(await notifier.togglePray(kind, id, latest));
    }

    final likeIcon = (mine == null || mine == ReactionType.like)
        ? Icon(r.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 19, color: AppColors.danger)
        : Text(mine.emoji, style: const TextStyle(fontSize: 16));

    // Wrap : les boutons passent à la ligne sur un petit écran (320 px, grand texte).
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _BarButton(
          icon: likeIcon,
          label: r.likesCount > 0 ? formatCount(r.likesCount) : (dense ? '' : context.l10n.detailLike),
          tooltip: mine?.label ?? context.l10n.detailLike,
          onTap: () => react(r.isLiked ? null : ReactionType.like),
          onLongPress: pickReaction,
        ),
        if (showPray)
          _BarButton(
            icon: Icon(
              r.isPrayed ? Icons.volunteer_activism : Icons.volunteer_activism_outlined,
              size: 19,
              color: r.isPrayed ? AppColors.primary : AppColors.textSecondary,
            ),
            label: r.prayersCount > 0 ? formatCount(r.prayersCount) : (dense ? '' : context.l10n.detailPray),
            tooltip: context.l10n.detailPray,
            onTap: pray,
          ),
        _BarButton(
          icon: Icon(
            r.isRepostedByMe ? Icons.repeat_on_rounded : Icons.share_outlined,
            size: 19,
            color: r.isRepostedByMe ? AppColors.secondary : AppColors.textSecondary,
          ),
          label: r.repostsCount > 0 ? formatCount(r.repostsCount) : '',
          tooltip: context.l10n.commonShare,
          onTap: () => showContentShareSheet(context, ref,
              kind: kind, id: id, title: title, webUrl: webUrl, reactions: r),
        ),
      ],
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, required this.label, required this.tooltip, required this.onTap, this.onLongPress});

  final Widget icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Feuille « Partager » : sur TestiApp (avec ses abonnés), copier le lien, autres applications.
Future<void> showContentShareSheet(
  BuildContext context,
  WidgetRef ref, {
  required ContentKind kind,
  required String id,
  required String title,
  required ContentReactions reactions,
  String? webUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) {
      final messenger = ScaffoldMessenger.of(context);
      void close() => Navigator.of(sheet).pop();
      final link = webUrl ?? '';

      Widget option(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  Icon(icon, color: color),
                  const SizedBox(height: 6),
                  Text(label, textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          );

      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.repostShareThis(kind.thisLabel), style: AppTextStyles.h4),
                if (link.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(link, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 18),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      option(Icons.repeat_rounded, context.l10n.repostOnTestiApp, AppColors.primary, () {
                        close();
                        if (!reactions.canRepost && !reactions.isRepostedByMe) {
                          messenger.showSnackBar(SnackBar(
                            content: Text(L10n.current.repostCannotShare(kind.thisLabel)),
                            behavior: SnackBarBehavior.floating,
                          ));
                          return;
                        }
                        showContentRepostSheet(context, ref, kind: kind, id: id, reposted: reactions.isRepostedByMe);
                      }),
                      if (link.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        option(Icons.copy_rounded, context.l10n.detailCopyLink, AppColors.primary, () {
                          Clipboard.setData(ClipboardData(text: link));
                          close();
                          messenger.showSnackBar(SnackBar(content: Text(L10n.current.repostLinkCopied), behavior: SnackBarBehavior.floating));
                        }),
                        const SizedBox(width: 10),
                        option(Icons.share_rounded, context.l10n.repostOtherApps, AppColors.secondary, () {
                          close();
                          SharePlus.instance.share(ShareParams(text: '$title\n\n$link'));
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Feuille « Partager sur TestiApp » : commentaire facultatif, partager / mettre à jour, annuler.
Future<void> showContentRepostSheet(
  BuildContext context,
  WidgetRef ref, {
  required ContentKind kind,
  required String id,
  required bool reposted,
}) async {
  if (!await requireAccount(context, ref, reason: context.l10n.repostReasonShare)) return;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContentRepostSheet(kind: kind, id: id, reposted: reposted),
  );
}

class _ContentRepostSheet extends ConsumerStatefulWidget {
  const _ContentRepostSheet({required this.kind, required this.id, required this.reposted});

  final ContentKind kind;
  final String id;
  final bool reposted;

  @override
  ConsumerState<_ContentRepostSheet> createState() => _ContentRepostSheetState();
}

class _ContentRepostSheetState extends ConsumerState<_ContentRepostSheet> {
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function(ContentInteractionsNotifier n) action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await action(ref.read(contentInteractionsProvider.notifier));
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(
        content: Text(e is LaravelApiException ? e.message : L10n.current.repostFailed),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.repeat_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.l10n.repostShareOnTestiApp, style: AppTextStyles.h4)),
                ]),
                const SizedBox(height: 8),
                Text(
                  context.l10n.repostContentExplain(widget.kind.theLabel),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _comment,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 5,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.l10n.repostCommentLabel,
                    hintText: context.l10n.repostCommentHintContent,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run((n) => n.repost(widget.kind, widget.id, comment: _comment.text)),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.repeat_rounded),
                  label: Text(widget.reposted ? context.l10n.repostUpdate : context.l10n.repostShareWithFollowers),
                ),
                if (widget.reposted) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _busy ? null : () => _run((n) => n.unrepost(widget.kind, widget.id)),
                    child: Text(context.l10n.repostUndo),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
