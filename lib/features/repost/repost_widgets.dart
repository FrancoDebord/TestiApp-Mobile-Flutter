import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/app_constants.dart';
import '../../services/api_service.dart';
import '../home/models/testimony_model.dart';
import '../home/providers/home_providers.dart' show testimonyFromApiJson;
import '../home/widgets/testimony_feed_item.dart';
import '../../shared/widgets/guest_gate.dart';
import 'repost.dart';
import '../../l10n/app_localizations.dart';

/// En-tête « X a partagé » au-dessus de la carte du témoignage d'origine (qui garde son auteur).
class RepostHeader extends StatelessWidget {
  const RepostHeader({required this.repost, super.key});

  final RepostInfo repost;

  static String _ago(DateTime at) {
    final d = DateTime.now().difference(at);
    final l = L10n.current;
    if (d.inMinutes < 1) return l.repostJustNow;
    if (d.inHours < 1) return l.timeMinutesAgo(d.inMinutes);
    if (d.inDays < 1) return l.timeHoursAgo(d.inHours);
    if (d.inDays < 30) return l.timeDaysAgo(d.inDays);
    return l.repostOnDate('${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}/${at.year}');
  }

  @override
  Widget build(BuildContext context) {
    final r = repost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: r.byId.isEmpty ? null : () => context.push('/users/${r.byId}'),
          child: Row(
            children: [
              const Icon(Icons.repeat_rounded, size: 15, color: AppColors.secondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: r.byName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: context.l10n.repostHasShared),
                    if (r.at != null) TextSpan(text: ' · ${_ago(r.at!)}', style: const TextStyle(fontWeight: FontWeight.w400)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondaryDark, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (r.comment != null) ...[
          const SizedBox(height: 4),
          Text(
            r.comment!,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.4),
          ),
        ],
      ],
    );
  }
}

/// Feuille « Partager sur TestiApp » : commentaire facultatif, partager / mettre à jour,
/// annuler le partage. Demande un compte aux invités.
Future<void> showRepostSheet(
  BuildContext context,
  WidgetRef ref, {
  required String testimonyId,
  required String authorName,
}) async {
  if (ref.read(isGuestProvider) &&
      !await requireAccount(context, ref, reason: context.l10n.repostReasonShareTestimony)) {
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RepostSheet(testimonyId: testimonyId, authorName: authorName),
  );
}

class RepostSheet extends ConsumerStatefulWidget {
  const RepostSheet({required this.testimonyId, required this.authorName, super.key});

  final String testimonyId;
  final String authorName;

  @override
  ConsumerState<RepostSheet> createState() => _RepostSheetState();
}

class _RepostSheetState extends ConsumerState<RepostSheet> {
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _run(Future<RepostResult> Function(RepostRepository repo) action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await action(ref.read(repostRepositoryProvider));
      ref.read(repostedByMeProvider.notifier).set(widget.testimonyId, r.reposted);
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(r.message), behavior: SnackBarBehavior.floating));
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
    final reposted = ref.watch(repostedByMeProvider)[widget.testimonyId] ?? false;
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
                  context.l10n.repostTestimonyExplain(widget.authorName),
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
                    hintText: context.l10n.repostCommentHintTestimony,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run((repo) => repo.repost(widget.testimonyId, comment: _comment.text)),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.repeat_rounded),
                  label: Text(reposted ? context.l10n.repostUpdate : context.l10n.repostShareWithFollowers),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _busy ? null : () => _run((repo) => repo.remove(widget.testimonyId)),
                  child: Text(context.l10n.repostUndo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Partages d'un compte (GET /users/{id}/reposts), les plus récents d'abord : un témoignage
/// partagé et son auteur d'origine.
final userRepostsProvider = FutureProvider.autoDispose.family<List<({RepostInfo repost, Testimony testimony})>, String>(
  (ref, userId) async {
    try {
      final res = await ref.read(apiServiceProvider).get<dynamic>(AppConstants.userReposts(userId), query: {'limit': 10});
      final list = res.data is List ? res.data as List : const [];
      return [
        for (final raw in list)
          if ((RepostInfo.fromFeedItem(raw), testimonyFromApiJson(raw)) case (final r?, final t?)) (repost: r, testimony: t),
      ];
    } catch (_) {
      return const [];
    }
  },
);

/// Section « Partages » du profil public (masquée s'il n'y en a aucun).
class UserRepostsSection extends ConsumerWidget {
  const UserRepostsSection({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(userRepostsProvider(userId)).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(children: [
            const Icon(Icons.repeat_rounded, size: 18, color: AppColors.secondary),
            const SizedBox(width: 6),
            Expanded(child: Text(context.l10n.repostSharesTitle, style: AppTextStyles.h4)),
          ]),
        ),
        for (final e in items)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepostHeader(repost: e.repost),
                const SizedBox(height: 8),
                TestimonyFeedItem(testimony: e.testimony, showRepost: false),
              ],
            ),
          ),
      ],
    );
  }
}
