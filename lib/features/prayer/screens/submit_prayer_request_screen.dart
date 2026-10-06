import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/prayer_repository.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';

/// Confier une requête de prière : publiée tout de suite (pas de relecture préalable).
/// [eventId] : requête rattachée à un événement (elle apparaît sur sa page).
class SubmitPrayerRequestScreen extends ConsumerStatefulWidget {
  const SubmitPrayerRequestScreen({this.eventId, super.key});

  final String? eventId;

  @override
  ConsumerState<SubmitPrayerRequestScreen> createState() => _SubmitPrayerRequestScreenState();
}

class _SubmitPrayerRequestScreenState extends ConsumerState<SubmitPrayerRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _body = TextEditingController();
  late final _draft = PrayerRequestDraft(eventId: widget.eventId);
  bool _sending = false;

  static const _hints = {
    PrayerVisibility.public: 'Visible de tous, même sans compte.',
    PrayerVisibility.followers: 'Visible des personnes qui vous suivent.',
    PrayerVisibility.private: 'Visible de vous seul (carnet de prière personnel).',
  };

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    _draft.body = _body.text;
    try {
      final created = await ref.read(prayerRepositoryProvider).create(_draft);
      ref.invalidate(prayerRequestListProvider);
      ref.invalidate(prayerRequestsPageProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre requête est publiée. Que Dieu vous réponde !')),
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
        title: const Text('Confier une requête'),
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
                    child: Text("Rattachée à l'événement : elle apparaîtra sur sa page.",
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                  ),
                ]),
              ),
            Text('Votre requête', style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _body,
              minLines: 5,
              maxLines: 10,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: "Pour quoi souhaitez-vous que l'on prie ?",
                helperText: "Évitez les informations trop personnelles (adresse, téléphone…).",
                helperMaxLines: 2,
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Écrivez votre requête de prière.';
                if (t.length < 10) return 'Votre requête est trop courte (10 caractères au moins).';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Qui peut la voir ?', style: AppTextStyles.labelMedium),
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
                    subtitle: Text(_hints[v]!),
                  ),
              ]),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _draft.isAnonymous,
              onChanged: (v) => setState(() => _draft.isAnonymous = v),
              title: const Text('Publier anonymement'),
              subtitle: const Text("Votre nom est masqué pour les autres. Il reste visible de vous et de l'équipe de modération."),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: const Text('Publier ma requête'),
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
