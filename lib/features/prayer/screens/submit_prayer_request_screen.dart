import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/mention_text_field.dart';
import '../../offline/outbox_controller.dart';
import '../data/prayer_repository.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';

/// Confier une requête de prière : publiée tout de suite (pas de relecture préalable).
/// [eventId] : requête rattachée à un événement (elle apparaît sur sa page).
/// [testimonyId] / [testimonyTitle] : confiée depuis le témoignage de quelqu'un (elle y renvoie).
class SubmitPrayerRequestScreen extends ConsumerStatefulWidget {
  const SubmitPrayerRequestScreen({this.eventId, this.testimonyId, this.testimonyTitle, super.key});

  final String? eventId;
  final String? testimonyId;
  final String? testimonyTitle;

  @override
  ConsumerState<SubmitPrayerRequestScreen> createState() => _SubmitPrayerRequestScreenState();
}

class _SubmitPrayerRequestScreenState extends ConsumerState<SubmitPrayerRequestScreen> {
  final _form = GlobalKey<FormState>();
  /// Texte avec mentions « @ » (les personnes qui peuvent voir la requête sont prévenues).
  final _body = MentionEditingController();
  late final _draft = PrayerRequestDraft(eventId: widget.eventId, sourceTestimonyId: widget.testimonyId);
  bool _sending = false;

  static String _hint(PrayerVisibility v) => switch (v) {
        PrayerVisibility.public => L10n.current.prayerHintPublic,
        PrayerVisibility.followers => L10n.current.prayerHintFollowers,
        PrayerVisibility.private => L10n.current.prayerHintPrivate,
      };

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    _draft.body = _body.encodedText;
    try {
      // Sans réseau : gardée sur le téléphone, publiée au retour de la connexion.
      final created = await ref.read(outboxProvider.notifier).sendOrQueue(
            () => ref.read(prayerRepositoryProvider).create(_draft),
            () => OutboxDraft(
              kind: OutboxKind.prayerRequest,
              label: _body.text,
              localId: newLocalId(),
              request: OutboxRequest('POST', AppConstants.prayerRequests, body: _draft.toJson()),
            ),
          );
      if (!mounted) return;
      if (created == null) {
        showQueuedSnack(context);
        context.pop();
        return;
      }
      ref.invalidate(prayerRequestListProvider);
      ref.invalidate(prayerRequestsPageProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.prayerRequestPublished)),
      );
      context.pop(created);
    } on PrayerFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.l10n.prayerEntrustRequest),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            if (widget.eventId != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(children: [
                  const Icon(Icons.event_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.l10n.prayerRequestLinkedToEvent,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                  ),
                ]),
              ),
            if (widget.testimonyId != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(children: [
                  const Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.l10n.prayerRequestLinkedToTestimony(widget.testimonyTitle ?? ''),
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                  ),
                ]),
              ),
            Text(context.l10n.prayerYourRequest, style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            // « @ » : mentionner quelqu'un (prévenu s'il peut voir la requête ; jamais pour « Moi seul »).
            FormField<String>(
              validator: (_) {
                final t = _body.text.trim();
                if (t.isEmpty) return context.l10n.prayerRequestEmptyError;
                if (t.length < 10) return context.l10n.prayerRequestTooShort;
                return null;
              },
              builder: (field) => MentionTextField(
                controller: _body,
                minLines: 5,
                maxLines: 10,
                maxLength: 2000,
                keyboardType: TextInputType.multiline,
                onChanged: (_) {
                  if (field.hasError) field.validate();
                },
                decoration: InputDecoration(
                  hintText: context.l10n.prayerRequestHint,
                  helperText: _draft.visibility == PrayerVisibility.private
                      ? context.l10n.prayerRequestHelperPrivate
                      : context.l10n.prayerRequestHelper,
                  helperMaxLines: 3,
                  errorText: field.errorText,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(context.l10n.prayerWhoCanSee, style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            RadioGroup<PrayerVisibility>(
              groupValue: _draft.visibility,
              onChanged: (v) => setState(() => _draft.visibility = v ?? PrayerVisibility.public),
              child: Column(children: [
                for (final v in PrayerVisibility.values)
                  RadioListTile<PrayerVisibility>(
                    value: v,
                    contentPadding: EdgeInsets.zero,
                    title: Text(v.label),
                    subtitle: Text(_hint(v)),
                  ),
              ]),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _draft.isAnonymous,
              onChanged: (v) => setState(() => _draft.isAnonymous = v),
              title: Text(context.l10n.prayerPostAnonymously),
              subtitle: Text(context.l10n.prayerPostAnonymouslyDesc),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(context.l10n.prayerPublishMyRequest),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
