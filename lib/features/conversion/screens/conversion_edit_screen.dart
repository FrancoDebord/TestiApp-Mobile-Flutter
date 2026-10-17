// Modifier mon témoignage de conversion : titre, texte (témoignage écrit), année,
// lieu, verset. Le témoignage repasse en modération (PUT /testimonies/{id}).
// Backend : docs/fonctionnalites/temoignage-de-conversion.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/models/testimony_model.dart';
import '../data/conversion_repository.dart';
import '../providers/conversion_providers.dart';
import '../widgets/conversion_widgets.dart';

class ConversionEditScreen extends ConsumerWidget {
  const ConversionEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myConversionProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(context.l10n.conversionEditTitle,
            style: AppTextStyles.h4.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
      ),
      body: switch (async) {
        AsyncValue(:final value?) when value.testimony != null =>
          _EditForm(testimony: value.testimony!),
        AsyncValue(:final value) when value != null || async.hasValue => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.conversionNoneYet, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  if (value?.canCreate ?? false) const ConversionInviteCard(),
                ],
              ),
            ),
          ),
        AsyncValue(:final error?) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error is ConversionFailure ? error.message : context.l10n.conversionLoadError,
                  textAlign: TextAlign.center),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.testimony});
  final Testimony testimony;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _year;
  late final TextEditingController _place;
  late final TextEditingController _verse;
  bool _saving = false;

  Testimony get _t => widget.testimony;
  bool get _isText => _t is TextTestimony;

  @override
  void initState() {
    super.initState();
    final c = _t.conversion;
    _title = TextEditingController(text: _t.title);
    _body = TextEditingController(text: _t is TextTestimony ? (_t as TextTestimony).preview : '');
    _year = TextEditingController(text: c?.year?.toString() ?? '');
    _place = TextEditingController(text: c?.place ?? '');
    _verse = TextEditingController(text: c?.verse ?? '');
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _year, _place, _verse]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(conversionRepositoryProvider).update(
            _t.id,
            ConversionEdit(
              title: _title.text,
              bodyText: _isText ? _body.text.trim() : null,
              year: int.tryParse(_year.text.trim()),
              place: _place.text,
              verse: _verse.text,
            ),
          );
      ref.invalidate(myConversionProvider);
      ref.invalidate(latestConversionsProvider);
      ref.invalidate(conversionListProvider);
      messenger.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating, content: Text(l10n.conversionSavedForReview)));
      if (mounted) context.pop();
    } on ConversionFailure catch (e) {
      messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxYear = DateTime.now().year;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sunSoft,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.sunBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.sunText),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.conversionEditReviewNotice, style: AppTextStyles.bodySmall)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _title,
            maxLength: 150,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.conversionTitleLabel),
            validator: (v) => (v ?? '').trim().length < 3 ? l10n.conversionTitleRequired : null,
          ),
          if (_isText) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _body,
              minLines: 6,
              maxLines: 16,
              maxLength: 5000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.conversionBodyLabel, alignLabelWithHint: true),
              validator: (v) => (v ?? '').trim().isEmpty ? l10n.conversionBodyRequired : null,
            ),
          ],
          const SizedBox(height: 8),
          Text(l10n.conversionFieldsHint, style: AppTextStyles.bodySmall),
          const SizedBox(height: 8),
          TextFormField(
            controller: _year,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: InputDecoration(
              labelText: l10n.conversionYear,
              hintText: l10n.conversionYearHint,
              prefixIcon: const Icon(Icons.event_rounded),
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return null;
              final y = int.tryParse(t);
              return y == null || !isValidConversionYear(y)
                  ? l10n.conversionYearInvalid(conversionMinYear, maxYear)
                  : null;
            },
          ),
          TextFormField(
            controller: _place,
            maxLength: 150,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.conversionPlace,
              hintText: l10n.conversionPlaceHint,
              prefixIcon: const Icon(Icons.place_outlined),
            ),
          ),
          TextFormField(
            controller: _verse,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: l10n.conversionVerse,
              hintText: l10n.conversionVerseHint,
              prefixIcon: const Icon(Icons.menu_book_rounded),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
