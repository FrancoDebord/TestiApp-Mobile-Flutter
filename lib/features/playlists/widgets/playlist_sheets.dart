// Listes de témoignages : dialogue « Nouvelle liste / Modifier la liste » et
// feuille « Ajouter à une liste » (menu de ses propres témoignages).
// Docs serveur : fonctionnalites/listes-de-temoignages.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../data/playlist_api.dart';
import '../models/playlist_models.dart';
import '../providers/playlist_providers.dart';

const kPlaylistTitleMax = 120;
const kPlaylistDescriptionMax = 1000;

/// Titre et description saisis.
typedef PlaylistFormResult = ({String title, String description});

/// Création ([initial] null) ou modification d'une liste ; null si annulé.
Future<PlaylistFormResult?> showPlaylistFormDialog(BuildContext context, {Playlist? initial}) =>
    showDialog<PlaylistFormResult>(context: context, builder: (_) => _PlaylistFormDialog(initial: initial));

class _PlaylistFormDialog extends StatefulWidget {
  const _PlaylistFormDialog({this.initial});
  final Playlist? initial;

  @override
  State<_PlaylistFormDialog> createState() => _PlaylistFormDialogState();
}

class _PlaylistFormDialogState extends State<_PlaylistFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _description = TextEditingController(text: widget.initial?.description ?? '');

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((title: _title.text.trim(), description: _description.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.initial == null ? l10n.playlistNew : l10n.playlistEditTitle),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('playlist-form-title'),
                controller: _title,
                autofocus: widget.initial == null,
                maxLength: kPlaylistTitleMax,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.playlistTitleLabel),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.playlistTitleRequired : null,
              ),
              TextFormField(
                key: const ValueKey('playlist-form-description'),
                controller: _description,
                minLines: 2,
                maxLines: 5,
                maxLength: kPlaylistDescriptionMax,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.playlistDescriptionLabel, alignLabelWithHint: true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        FilledButton(
          key: const ValueKey('playlist-form-submit'),
          onPressed: _submit,
          child: Text(widget.initial == null ? l10n.playlistCreate : l10n.commonSave),
        ),
      ],
    );
  }
}

/// Message d'une erreur des listes (hors connexion compris).
String playlistErrorMessage(Object e) => isNetworkFailure(e)
    ? L10n.current.commonErrorNetwork
    : e is PlaylistFailure
        ? e.message
        : L10n.current.commonErrorGeneric;

void _snack(ScaffoldMessengerState? m, String text) =>
    m?..hideCurrentSnackBar()..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));

/// « Ajouter à une liste » : ses listes, ou une nouvelle liste contenant [testimonyId].
Future<void> showAddToPlaylistSheet(BuildContext context, {required String testimonyId}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _AddToPlaylistSheet(testimonyId: testimonyId),
    );

class _AddToPlaylistSheet extends ConsumerStatefulWidget {
  const _AddToPlaylistSheet({required this.testimonyId});
  final String testimonyId;

  @override
  ConsumerState<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends ConsumerState<_AddToPlaylistSheet> {
  bool _busy = false;

  Future<void> _run(Future<Playlist> Function(PlaylistApi api) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      final p = await action(ref.read(playlistApiProvider));
      refreshPlaylists(ref.invalidate, playlistId: p.id, ownerId: p.owner.id);
      if (mounted) Navigator.of(context).pop();
      _snack(messenger, l10n.playlistAdded(p.title));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _snack(messenger, playlistErrorMessage(e));
    }
  }

  Future<void> _create() async {
    final form = await showPlaylistFormDialog(context);
    if (form == null || !mounted) return;
    await _run((api) => api.create(
          title: form.title,
          description: form.description,
          testimonyIds: [widget.testimonyId],
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(myPlaylistsProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(l10n.playlistAddTo, style: AppTextStyles.h4),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(l10n.playlistAddToHint, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            ListTile(
              key: const ValueKey('playlist-sheet-new'),
              enabled: !_busy,
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.add_rounded, color: AppColors.primary),
              ),
              title: Text(l10n.playlistNew, style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
              onTap: _create,
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: switch (async) {
                AsyncValue(:final value?) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in value)
                        ListTile(
                          key: ValueKey('playlist-sheet-${p.id}'),
                          enabled: !_busy,
                          leading: const Icon(Icons.playlist_add_rounded, color: AppColors.primary),
                          title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(l10n.playlistCount(p.count)),
                          onTap: () => _run((api) => api.add(p.id, widget.testimonyId)),
                        ),
                    ],
                  ),
                AsyncValue(:final error?) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(playlistErrorMessage(error),
                          textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () => ref.invalidate(myPlaylistsProvider),
                        child: Text(l10n.commonRetry),
                      ),
                    ]),
                  ),
                _ => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
