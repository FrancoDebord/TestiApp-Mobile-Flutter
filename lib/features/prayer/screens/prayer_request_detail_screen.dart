import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/guest_gate.dart' show requireAccount;
import '../../../shared/widgets/mention_text.dart';
import '../../../shared/widgets/mention_text_field.dart';
import '../../../shared/widgets/organization_badge.dart';
import '../data/prayer_repository.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';
import '../widgets/prayer_widgets.dart';

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
    if (!await requireAccount(context, ref, reason: 'prier pour cette requête')) return;
    ref.read(prayerRequestProvider(_id).notifier).replace(r.withPrayed(!r.hasPrayed));
    await _run(() => _repo.pray(_id, prayed: !r.hasPrayed));
  }

  Future<void> _markAnswered() async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elle est exaucée !'),
        content: TextField(
          controller: note,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(hintText: "Ce que Dieu a fait (facultatif)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => _repo.setAnswered(_id, true, note: note.text), 'Gloire à Dieu ! Pensez à témoigner de cet exaucement.');
    }
    note.dispose();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la requête ?'),
        content: const Text("La requête et ses messages d'encouragement seront supprimés."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteRequest(_id);
      ref.invalidate(prayerRequestListProvider);
      ref.invalidate(prayerRequestsPageProvider);
      if (!mounted) return;
      _snack('Requête supprimée.');
      context.pop();
    } on PrayerFailure catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _report() async {
    if (!await requireAccount(context, ref, reason: 'signaler un contenu')) return;
    if (!mounted) return;
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
    }, 'Signalement enregistré. Merci pour votre vigilance.');
  }

  Future<void> _sendMessage() async {
    if (_message.text.trim().length < 2) return;
    final text = _message.encodedText;
    if (!await requireAccount(context, ref, reason: 'encourager cette personne')) return;
    await _run(() async {
      await _repo.addMessage(_id, text, bibleReference: _verse.text);
      _message.clear();
      _verse.clear();
      ref.invalidate(prayerMessagesProvider(_id));
      return _repo.request(_id); // compteur à jour
    }, 'Merci pour votre encouragement !');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(prayerRequestProvider(_id));
    final r = async.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Requête de prière'),
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
                  const PopupMenuItem(value: 'report', child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Signaler'))),
                if (r.canDelete)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(leading: Icon(Icons.delete_outline, color: AppColors.danger), title: Text('Supprimer')),
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
                    onReopen: () => _run(() => _repo.setAnswered(_id, false), 'Requête remise en attente.'),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text('Encouragements (${value.messageCount})', style: AppTextStyles.h4),
                const SizedBox(height: AppSpacing.md),
                _Messages(requestId: _id),
                if (value.canMessage) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _Composer(message: _message, verse: _verse, busy: _busy, onSend: _sendMessage),
                ] else if (!value.isHidden && value.visibility != PrayerVisibility.private) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => requireAccount(context, ref, reason: 'encourager cette personne'),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Laisser un encouragement'),
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
                Text(error is PrayerFailure ? error.message : 'Impossible de charger la requête.',
                    textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
                TextButton(onPressed: () => ref.invalidate(prayerRequestProvider(_id)), child: const Text('Réessayer')),
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
                  if (r.author?.isVerified ?? false) const OrganizationBadge(isOrganization: true, isVerified: true, size: 14),
                ]),
                Text(
                  [prayerTimeAgo(r.createdAt), r.visibility.label, if (r.isAnonymous) 'anonyme'].join(' · '),
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
              child: Text("${r.hiddenReason ?? 'Retirée par la modération.'} Elle n'est plus visible des autres.",
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SelectableText(r.body, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary, height: 1.5)),
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
                Text('Exaucée — gloire à Dieu !', style: AppTextStyles.labelMedium.copyWith(color: AppColors.success)),
                if (r.answerNote != null) ...[
                  const SizedBox(height: 4),
                  Text(r.answerNote!, style: AppTextStyles.bodyMedium),
                ],
                if (r.testimonyId != null)
                  TextButton(
                    onPressed: () => context.push('/testimony/${r.testimonyId}'),
                    child: const Text('Lire le témoignage'),
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
                r.prayerCount > 1 ? '${r.prayerCount} personnes prient' : (r.prayerCount == 1 ? '1 personne prie' : 'Soyez le premier à prier'),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
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
        Text(answered ? 'Témoignez de cet exaucement' : 'Dieu a répondu ?', style: AppTextStyles.h4),
        const SizedBox(height: 4),
        Text(
          answered
              ? 'Racontez ce que Dieu a fait : votre témoignage fortifiera ceux qui prient encore.'
              : 'Marquez la requête exaucée : ceux qui ont prié avec vous le verront.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          if (!answered)
            FilledButton.icon(
              onPressed: busy ? null : onAnswered,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Elle est exaucée'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            )
          else ...[
            if (request.testimonyId == null)
              FilledButton.icon(
                onPressed: () => context.go('/publish'),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Témoigner'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
              ),
            if (request.testimonyId == null)
              TextButton(onPressed: busy ? null : onReopen, child: const Text('Remettre en attente')),
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
          "Aucun message pour le moment. Un verset, une parole d'encouragement peuvent fortifier.",
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
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary, semanticLabel: 'Supprimer le message'),
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
      AsyncValue(:final error?) => Text(error is PrayerFailure ? error.message : 'Messages indisponibles.'),
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
            decoration: const InputDecoration(hintText: 'Je prie avec vous… (@ pour mentionner)', labelText: "Message d'encouragement"),
          ),
          TextField(
            controller: verse,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Verset (facultatif)', hintText: 'Ex. : Philippiens 4:6-7'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: busy ? null : onSend,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Envoyer'),
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
          Text('Signaler la requête', style: AppTextStyles.h4),
          const SizedBox(height: 4),
          Text('Au 3e signalement, la requête est retirée en attendant la modération.',
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
            decoration: const InputDecoration(hintText: 'Précisions (facultatif)'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, (_reason, _comment.text)),
              child: const Text('Envoyer le signalement'),
            ),
          ),
        ]),
      ),
    );
  }
}
