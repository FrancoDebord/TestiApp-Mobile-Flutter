import 'package:flutter/material.dart';
import 'prayer_focus_screen.dart' show openPrayerFocus;
import '../../repost/content_interactions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/guest_gate.dart' show requireAccount;
import '../../../shared/widgets/mention_text.dart';
import '../../../shared/widgets/mention_text_field.dart';
import '../../../shared/widgets/organization_badge.dart';
import '../data/prayer_repository.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';
import '../widgets/prayer_widgets.dart';
import '../../../shared/content_deletion.dart' show deletePrayerRequestContent;

/// Détail d'une requête : « Je prie », encouragements, exaucement (auteur), signalement.
class PrayerRequestDetailScreen extends ConsumerStatefulWidget {
  const PrayerRequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<PrayerRequestDetailScreen> createState() => _PrayerRequestDetailScreenState();
}

class _PrayerRequestDetailScreenState extends ConsumerState<PrayerRequestDetailScreen> {
  final _message = MentionEditingController(); // mentions « @ » (fonctionnalites/mentions.md)
  final _verse = TextEditingController();
  bool _busy = false;

  String get _id => widget.requestId;
  PrayerRepository get _repo => ref.read(prayerRepositoryProvider);

  @override
  void dispose() {
    _message.dispose();
    _verse.dispose();
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Lance une action ; la requête à jour (si renvoyée) remplace l'affichage.
  Future<void> _run(Future<PrayerRequest?> Function() action, [String? success]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (updated != null) ref.read(prayerRequestProvider(_id).notifier).replace(updated);
      ref.invalidate(prayerRequestListProvider);
      if (success != null && mounted) _snack(success);
    } on PrayerFailure catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePray(PrayerRequest r) async {
    if (!await requireAccount(context, ref, reason: context.l10n.prayerReasonPray)) return;
    // Prier : temps de prière immersif de 5 minutes, puis validation.
    if (!r.hasPrayed && (!mounted || !await openPrayerFocus(context, r, onStart: () => _repo.startPrayer(_id)))) return;
    if (!mounted) return;
    ref.read(prayerRequestProvider(_id).notifier).replace(r.withPrayed(!r.hasPrayed));
    await _run(() => _repo.pray(_id, prayed: !r.hasPrayed));
  }

  Future<void> _markAnswered() async {
    final note = TextEditingController();
    final success = context.l10n.prayerAnsweredSuccess;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.prayerAnsweredDialogTitle),
        content: TextField(
          controller: note,
          maxLines: 4,
          maxLength: 1000,
          decoration: InputDecoration(hintText: context.l10n.prayerAnsweredNoteHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.commonSave)),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => _repo.setAnswered(_id, true, note: note.text), success);
    }
    note.dispose();
  }

  Future<void> _delete() async {
    if (await deletePrayerRequestContent(context, ref, _id) && mounted) context.pop();
  }

  Future<void> _report() async {
    if (!await requireAccount(context, ref, reason: context.l10n.prayerReasonReport)) return;
    if (!mounted) return;
    final saved = context.l10n.prayerReportSaved;
    final result = await showModalBottomSheet<(PrayerReportReason, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _ReportSheet(),
    );
    if (result == null) return;
    await _run(() async {
      await _repo.report(_id, result.$1, comment: result.$2);
      return null;
    }, saved);
  }

  Future<void> _sendMessage() async {
    if (_message.text.trim().length < 2) return;
    final text = _message.encodedText;
    if (!await requireAccount(context, ref, reason: context.l10n.prayerReasonEncourage)) return;
    if (!mounted) return;
    final thanks = context.l10n.prayerEncouragementThanks;
    await _run(() async {
      await _repo.addMessage(_id, text, bibleReference: _verse.text);
      _message.clear();
      _verse.clear();
      ref.invalidate(prayerMessagesProvider(_id));
      return _repo.request(_id); // compteur à jour
    }, thanks);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(prayerRequestProvider(_id));
    final r = async.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.l10n.prayerRequestLabel),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (r != null && (r.canDelete || r.canReport))
            PopupMenuButton<String>(
              onSelected: (v) => v == 'delete' ? _delete() : _report(),
              itemBuilder: (_) => [
                if (r.canReport && !r.isHidden)
                  PopupMenuItem(
                      value: 'report',
                      child: ListTile(leading: const Icon(Icons.flag_outlined), title: Text(context.l10n.commonReport))),
                if (r.canDelete)
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                        leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                        title: Text(context.l10n.commonDelete)),
                  ),
              ],
            ),
        ],
      ),
      body: switch (async) {
        AsyncValue(:final value?) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(prayerMessagesProvider(_id));
              return ref.refresh(prayerRequestProvider(_id).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, 40),
              children: [
                _RequestBody(request: value, onPray: _busy ? null : () => _togglePray(value)),
                if (value.isMine) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _AnswerCard(
                    request: value,
                    busy: _busy,
                    onAnswered: _markAnswered,
                    onReopen: () => _run(() => _repo.setAnswered(_id, false), context.l10n.prayerRequestReopened),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(context.l10n.prayerEncouragementsCount(value.messageCount), style: AppTextStyles.h4),
                const SizedBox(height: AppSpacing.md),
                _Messages(requestId: _id),
                if (value.canMessage) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _Composer(message: _message, verse: _verse, busy: _busy, onSend: _sendMessage),
                ] else if (!value.isHidden && value.visibility != PrayerVisibility.private) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => requireAccount(context, ref, reason: context.l10n.prayerReasonEncourage),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(context.l10n.prayerLeaveEncouragement),
                  ),
                ],
              ],
            ),
          ),
        AsyncValue(:final error?) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.search_off_rounded, size: 56, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(error is PrayerFailure ? error.message : context.l10n.prayerLoadRequestError,
                    textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
                TextButton(
                    onPressed: () => ref.invalidate(prayerRequestProvider(_id)), child: Text(context.l10n.commonRetry)),
              ]),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _RequestBody extends StatelessWidget {
  const _RequestBody({required this.request, this.onPray});
  final PrayerRequest request;
  final VoidCallback? onPray;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppShadows.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            PrayerAvatar(person: r.author, radius: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: InkWell(
                      onTap: r.author == null ? null : () => context.push('/users/${r.author!.id}'),
                      child: Text(r.authorName, style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary)),
                    ),
                  ),
                  if (r.author?.isVerified ?? false) OrganizationBadge(isOrganization: r.author!.isOrganization, isVerified: true, size: 14),
                ]),
                Text(
                  [prayerTimeAgo(r.createdAt), r.visibility.label, if (r.isAnonymous) context.l10n.prayerAnonymousLower]
                      .join(' · '),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ]),
            ),
            if (r.isAnswered) const PrayerAnsweredBadge(),
          ]),
          if (r.isHidden) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text(context.l10n.prayerHiddenNotice(r.hiddenReason ?? context.l10n.prayerHiddenByModeration),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // Mentions « @Nom » cliquables (profil).
          SelectionArea(
            child: MentionText(r.body,
                mentions: r.mentions, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary, height: 1.5)),
          ),
          if (r.event != null) ...[
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () => context.push('/events/${r.event!.id}'),
              child: Row(children: [
                const Icon(Icons.event_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(r.event!.title,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
          if (r.isAnswered) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.l10n.prayerAnsweredGlory, style: AppTextStyles.labelMedium.copyWith(color: AppColors.success)),
                if (r.answerNote != null) ...[
                  const SizedBox(height: 4),
                  Text(r.answerNote!, style: AppTextStyles.bodyMedium),
                ],
                if (r.testimonyId != null)
                  TextButton(
                    onPressed: () => context.push('/testimony/${r.testimonyId}'),
                    child: Text(context.l10n.prayerReadTestimony),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // Wrap : le bouton et le texte passent l'un sous l'autre sur un petit écran.
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PrayButton(prayed: r.hasPrayed, count: r.prayerCount, onPressed: r.isHidden ? null : onPray, large: true),
              Text(
                context.l10n.prayerPeoplePraying(r.prayerCount < 0 ? 0 : r.prayerCount),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          // J'aime et partager (« Je prie » : bouton ci-dessus) — docs serveur fonctionnalites/reactions.md.
          if (!r.isHidden) ...[
            const SizedBox(height: AppSpacing.sm),
            ContentReactionBar(
              kind: ContentKind.prayerRequest,
              id: r.id,
              initial: r.reactions,
              title: context.l10n.prayerShareTitle(r.authorName),
              webUrl: r.webUrl,
              showPray: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.request, required this.busy, required this.onAnswered, required this.onReopen});
  final PrayerRequest request;
  final bool busy;
  final VoidCallback onAnswered;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final answered = request.isAnswered;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppShadows.cardDecoration,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(answered ? context.l10n.prayerTestifyAnswer : context.l10n.prayerGodAnswered, style: AppTextStyles.h4),
        const SizedBox(height: 4),
        Text(
          answered ? context.l10n.prayerTestifyAnswerDesc : context.l10n.prayerMarkAnsweredDesc,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          if (!answered)
            FilledButton.icon(
              onPressed: busy ? null : onAnswered,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(context.l10n.prayerItIsAnswered),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            )
          else ...[
            if (request.testimonyId == null)
              FilledButton.icon(
                onPressed: () => context.go('/publish'),
                icon: const Icon(Icons.edit_rounded),
                label: Text(context.l10n.prayerTestify),
                style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
              ),
            if (request.testimonyId == null)
              TextButton(onPressed: busy ? null : onReopen, child: Text(context.l10n.prayerSetPending)),
          ],
        ]),
      ]),
    );
  }
}

class _Messages extends ConsumerWidget {
  const _Messages({required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(prayerMessagesProvider(requestId));
    return switch (async) {
      AsyncValue(:final value?) when value.isEmpty => Text(
          context.l10n.prayerNoMessages,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
      AsyncValue(:final value?) => Column(children: [
          for (final m in value)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PrayerAvatar(person: m.author, radius: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text('${m.author.displayName} · ${prayerTimeAgo(m.createdAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (m.canDelete)
                          InkWell(
                            onTap: () async {
                              try {
                                await ref.read(prayerRepositoryProvider).deleteMessage(requestId, m.id);
                                ref.invalidate(prayerMessagesProvider(requestId));
                                ref.invalidate(prayerRequestProvider(requestId));
                              } on PrayerFailure catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.textSecondary, semanticLabel: context.l10n.prayerDeleteMessage),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      MentionText(m.body, mentions: m.mentions, style: AppTextStyles.bodyMedium),
                      if (m.bibleReference != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.menu_book_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(m.bibleReference!,
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
        ]),
      AsyncValue(:final error?) => Text(error is PrayerFailure ? error.message : context.l10n.prayerMessagesUnavailable),
      _ => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
    };
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.message, required this.verse, required this.busy, required this.onSend});
  final MentionEditingController message;
  final TextEditingController verse;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: AppShadows.cardDecoration,
        child: Column(children: [
          MentionTextField(
            controller: message,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: InputDecoration(
                hintText: context.l10n.prayerMessageHintMention, labelText: context.l10n.prayerMessageLabel),
          ),
          TextField(
            controller: verse,
            maxLength: 100,
            decoration: InputDecoration(labelText: context.l10n.prayerVerseLabel, hintText: context.l10n.prayerVerseHint),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: busy ? null : onSend,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(context.l10n.commonSend),
            ),
          ),
        ]),
      );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  PrayerReportReason _reason = PrayerReportReason.inappropriateContent;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.l10n.prayerReportTitle, style: AppTextStyles.h4),
          const SizedBox(height: 4),
          Text(context.l10n.prayerReportInfo,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          RadioGroup<PrayerReportReason>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v ?? _reason),
            child: Column(children: [
              for (final r in PrayerReportReason.values)
                RadioListTile<PrayerReportReason>(value: r, contentPadding: EdgeInsets.zero, title: Text(r.label)),
            ]),
          ),
          TextField(
            controller: _comment,
            maxLength: 500,
            maxLines: 2,
            decoration: InputDecoration(hintText: context.l10n.prayerReportDetailsHint),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, (_reason, _comment.text)),
              child: Text(context.l10n.prayerReportSend),
            ),
          ),
        ]),
      ),
    );
  }
}
