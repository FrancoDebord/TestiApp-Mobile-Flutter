// Administration : types (catégories) d'événements — ajouter, modifier, activer,
// supprimer (avec type de remplacement si des événements l'utilisent), réordonner.
// Mêmes réglages que la page « Types d'événements » du site.
// Backend : docs/fonctionnalites/types-evenements.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/models/event_models.dart';
import '../../events/providers/event_types_providers.dart';
import '../../events/widgets/event_widgets.dart' show eventTypeIconFor, kEventTypeIcons;

class AdminEventTypesScreen extends ConsumerWidget {
  const AdminEventTypesScreen({super.key});

  void _snack(BuildContext context, String text) => ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on EventTypeFailure catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, [EventType? t]) async {
    final result = await showDialog<({String fr, String en, String icon})>(
      context: context,
      builder: (_) => _EventTypeDialog(type: t),
    );
    if (result == null || !context.mounted) return;
    final n = ref.read(adminEventTypesProvider.notifier);
    await _run(context, () => t == null
        ? n.create(nameFr: result.fr, nameEn: result.en, icon: result.icon)
        : n.edit(t, nameFr: result.fr, nameEn: result.en, icon: result.icon));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, EventType t, List<EventType> all) async {
    final l10n = context.l10n;
    final n = ref.read(adminEventTypesProvider.notifier);
    final others = all.where((o) => o.apiValue != t.apiValue && o.isActive).toList();
    // Des événements l'utilisent : choisir le type qui les reprend.
    if (t.eventsCount > 0) {
      final replace = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.adminEventTypeReplaceTitle(t.label, t.eventsCount)),
          children: [
            for (final o in others)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, o.apiValue),
                child: Row(
                  children: [
                    Icon(eventTypeIconFor(o.icon), size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(o.label)),
                  ],
                ),
              ),
          ],
        ),
      );
      if (replace == null || !context.mounted) return;
      await _run(context, () => n.delete(t, replaceWith: replace));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminEventTypeDeleteTitle(t.label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await _run(context, () => n.delete(t));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(adminEventTypesProvider);
    return Stack(
      children: [
        switch (async) {
          AsyncValue(:final value?) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminEventTypesProvider),
              child: ReorderableListView.builder(
                key: const ValueKey('admin-event-types'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                header: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(l10n.adminEventTypesIntro,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ),
                itemCount: value.length,
                onReorder: (from, to) {
                  final list = [...value];
                  final item = list.removeAt(from);
                  list.insert(to > from ? to - 1 : to, item);
                  _run(context, () => ref.read(adminEventTypesProvider.notifier).reorder(list));
                },
                itemBuilder: (_, i) {
                  final t = value[i];
                  return Card(
                    key: ValueKey('event-type-${t.apiValue}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: t.isActive ? AppColors.primarySoft : AppColors.border,
                        child: Icon(eventTypeIconFor(t.icon),
                            color: t.isActive ? AppColors.primary : AppColors.textSecondary),
                      ),
                      title: Text(t.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: t.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                          )),
                      subtitle: Text(
                        [
                          l10n.adminEventTypeCount(t.eventsCount),
                          if (!t.isActive) l10n.adminEventTypeInactive,
                        ].join(' · '),
                        style: AppTextStyles.bodySmall,
                      ),
                      onTap: () => _edit(context, ref, t),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: t.isActive,
                            onChanged: (v) => _run(
                                context, () => ref.read(adminEventTypesProvider.notifier).edit(t, isActive: v)),
                          ),
                          IconButton(
                            tooltip: l10n.commonDelete,
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                            onPressed: () => _delete(context, ref, t, value),
                          ),
                          const Icon(Icons.drag_handle_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          AsyncValue(:final error?) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$error', textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () => ref.invalidate(adminEventTypesProvider),
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            key: const ValueKey('add-event-type'),
            onPressed: () => _edit(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.adminEventTypeAdd),
          ),
        ),
      ],
    );
  }
}

/// Ajouter / modifier un type : nom FR, nom EN (facultatif), icône.
class _EventTypeDialog extends StatefulWidget {
  const _EventTypeDialog({this.type});
  final EventType? type;

  @override
  State<_EventTypeDialog> createState() => _EventTypeDialogState();
}

class _EventTypeDialogState extends State<_EventTypeDialog> {
  late final _fr = TextEditingController(text: widget.type?.nameFr ?? widget.type?.name ?? '');
  late final _en = TextEditingController(text: widget.type?.nameEn ?? '');
  late String _icon = widget.type?.icon ?? 'calendar';

  @override
  void dispose() {
    _fr.dispose();
    _en.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final valid = _fr.text.trim().length >= 2;
    return AlertDialog(
      title: Text(widget.type == null ? l10n.adminEventTypeAdd : l10n.adminEventTypeEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _fr,
              maxLength: 80,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.adminEventTypeNameFr),
            ),
            TextField(
              controller: _en,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.adminEventTypeNameEn),
            ),
            const SizedBox(height: 8),
            Text(l10n.adminEventTypeIcon, style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in kEventTypeIcons.entries)
                  InkWell(
                    key: ValueKey('icon-${e.key}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _icon = e.key),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _icon == e.key ? AppColors.primary : AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(e.value, color: _icon == e.key ? Colors.white : AppColors.primary),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, (fr: _fr.text.trim(), en: _en.text.trim(), icon: _icon))
              : null,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
