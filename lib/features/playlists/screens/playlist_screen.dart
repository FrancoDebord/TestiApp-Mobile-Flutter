// Page d'une liste de témoignages : auteur, description, Tout lire, Partager,
// témoignages numérotés. Propriétaire : Modifier, Supprimer (confirmation),
// ordre par glisser-déposer, Retirer (confirmation), ajout d'un de ses témoignages.
// Docs serveur : fonctionnalites/listes-de-temoignages.md

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/network_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/models/user_testimony_model.dart';
import '../../profile/providers/profile_provider.dart' show myTestimoniesNotifierProvider;
import '../data/playlist_api.dart';
import '../models/playlist_models.dart';
import '../playlist_navigation.dart';
import '../providers/playlist_providers.dart';
import '../widgets/playlist_panel.dart' show PlaylistItemTile;
import '../widgets/playlist_sheets.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({required this.playlistId, super.key});

  final String playlistId;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  /// Ordre affiché pendant l'enregistrement d'un glisser-déposer.
  List<PlaylistItem>? _localOrder;
  bool _busy = false;

  String get _id => widget.playlistId;

  void _snack(String text) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));

  /// Exécute une modification ; rechargement des listes, message, ou erreur affichée.
  Future<Playlist?> _run(Future<Playlist?> Function(PlaylistApi api) action, {String? success}) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      final p = await action(ref.read(playlistApiProvider));
      if (!mounted) return p;
      refreshPlaylists(ref.invalidate, playlistId: _id, ownerId: p?.owner.id);
      if (success != null) _snack(success);
      return p;
    } catch (e) {
      if (mounted) _snack(playlistErrorMessage(e));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Playlist p) async {
    final form = await showPlaylistFormDialog(context, initial: p);
    if (form == null || !mounted) return;
    await _run((api) => api.update(_id, title: form.title, description: form.description),
        success: context.l10n.playlistSaved);
  }

  Future<void> _delete(Playlist p) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.playlistDeleteTitle(p.title)),
        content: Text(l10n.playlistDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(
            key: const ValueKey('playlist-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(playlistApiProvider).delete(_id);
      refreshPlaylists(ref.invalidate, ownerId: p.owner.id);
      if (!mounted) return;
      _snack(l10n.playlistDeleted);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(playlistErrorMessage(e));
      }
    }
  }

  Future<void> _remove(PlaylistItem item) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.playlistRemoveItemTitle),
        content: Text(l10n.playlistRemoveItemBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(
            key: const ValueKey('playlist-remove-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _localOrder = null);
    await _run((api) => api.remove(_id, item.id), success: l10n.playlistRemoved);
  }

  /// Glisser-déposer : ordre affiché tout de suite, puis PUT avec l'ordre complet.
  Future<void> _reorder(List<PlaylistItem> items, int oldIndex, int newIndex) async {
    final next = [...items];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
    setState(() => _localOrder = next);
    final saved = await _run(
      (api) => api.update(_id, testimonyIds: [for (final i in next) i.id]),
      success: context.l10n.playlistOrderSaved,
    );
    // Ordre du serveur (échec : ordre d'avant, relu de la liste).
    if (mounted) setState(() => _localOrder = saved?.items);
  }

  Future<void> _addMine(Playlist p) async {
    final inList = {for (final i in p.items ?? const <PlaylistItem>[]) i.id};
    final picked = await showModalBottomSheet<UserTestimony>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _MyTestimoniesPicker(exclude: inList),
    );
    if (picked == null || !mounted) return;
    setState(() => _localOrder = null);
    await _run((api) => api.add(_id, picked.id), success: context.l10n.playlistAdded(p.title));
  }

  Future<void> _share(Playlist p) async {
    final url = p.shareUrl;
    if (url == null) return;
    await SharePlus.instance.share(ShareParams(text: '${p.title}\n$url', subject: p.title));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(playlistProvider(_id));
    final p = async.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(p?.title ?? l10n.playlistsTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (p?.shareUrl != null)
            IconButton(
              tooltip: l10n.playlistShare,
              onPressed: () => _share(p!),
              icon: const Icon(Icons.share_outlined),
            ),
          if (p?.isMine ?? false)
            PopupMenuButton<String>(
              key: const ValueKey('playlist-menu'),
              tooltip: l10n.playlistMoreActions,
              enabled: !_busy,
              onSelected: (v) => v == 'edit' ? _edit(p!) : _delete(p!),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l10n.commonEdit)),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: Text(l10n.playlistDelete, style: const TextStyle(color: AppColors.danger)),
                  ),
                ),
              ],
            ),
        ],
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: switch (async) {
        AsyncValue(:final value?) => _body(value),
        AsyncValue(:final error?) => _ErrorView(
            message: error is PlaylistFailure && error.statusCode == 404
                ? l10n.playlistNotFound
                : isNetworkFailure(error)
                    ? l10n.commonErrorNetwork
                    : l10n.playlistLoadError,
            onRetry: () => ref.invalidate(playlistProvider(_id)),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(Playlist p) {
    final l10n = context.l10n;
    final items = _localOrder ?? p.items ?? const <PlaylistItem>[];
    final header = _Header(
      playlist: p,
      onPlayAll: items.isEmpty ? null : () => openPlaylistItem(context, items.first, p.id),
      onShare: p.shareUrl == null ? null : () => _share(p),
      onAdd: p.isMine && !_busy ? () => _addMine(p) : null,
    );
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          header,
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(l10n.playlistEmptyItems,
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(playlistProvider(_id)),
      child: ReorderableListView.builder(
        key: const ValueKey('playlist-items'),
        header: header,
        padding: const EdgeInsets.only(bottom: 32),
        buildDefaultDragHandles: false,
        itemCount: items.length,
        onReorder: p.isMine && !_busy ? (a, b) => _reorder(items, a, b) : (_, _) {},
        itemBuilder: (_, i) {
          final item = items[i];
          return Material(
            key: ValueKey('playlist-item-${item.id}'),
            color: AppColors.surface,
            child: PlaylistItemTile(
              item: item,
              index: i + 1,
              note: p.isMine && item.publishedAt == null ? l10n.playlistOnlyYou : null,
              onTap: () => openPlaylistItem(context, item, p.id),
              trailing: p.isMine
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        key: ValueKey('playlist-remove-${item.id}'),
                        tooltip: l10n.playlistRemoveItem,
                        onPressed: _busy ? null : () => _remove(item),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        color: AppColors.textSecondary,
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle_rounded, color: AppColors.textSecondary),
                        ),
                      ),
                    ])
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.playlist, this.onPlayAll, this.onShare, this.onAdd});

  final Playlist playlist;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShare;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = playlist;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.coverUrl != null)
            ClipRRect(
              borderRadius: AppRadius.cardRadius,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: p.coverUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const ColoredBox(color: AppColors.primarySoft),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(p.title, style: AppTextStyles.h3),
          const SizedBox(height: 4),
          InkWell(
            onTap: p.owner.id.isEmpty ? null : () => context.push('/users/${p.owner.id}'),
            child: Text(
              [p.owner.displayName, l10n.playlistCount(p.count)].where((s) => s.isNotEmpty).join(' · '),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (p.description != null) ...[
            const SizedBox(height: 8),
            Text(p.description!, style: AppTextStyles.bodyMedium.copyWith(height: 1.45)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('playlist-play-all'),
                  onPressed: onPlayAll,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.playlistPlayAll),
                ),
              ),
              if (onShare != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: Text(l10n.playlistShare, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ],
          ),
          if (p.isMine) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('playlist-add-mine'),
              onPressed: onAdd,
              icon: const Icon(Icons.playlist_add_rounded),
              label: Text(l10n.playlistAddMine),
            ),
            if ((p.items?.length ?? 0) > 1) ...[
              const SizedBox(height: 8),
              Text(l10n.playlistReorderHint, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            ],
          ],
        ],
      ),
    );
  }
}

/// Mes témoignages (hors carnet privé) qui ne sont pas encore dans la liste.
class _MyTestimoniesPicker extends ConsumerWidget {
  const _MyTestimoniesPicker({required this.exclude});
  final Set<String> exclude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(myTestimoniesNotifierProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(l10n.playlistAddMine, style: AppTextStyles.h4),
            ),
            Flexible(
              child: switch (async) {
                AsyncValue(:final value?) when value.where((t) => !exclude.contains(t.id)).isEmpty => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.playlistNothingToAdd,
                        textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                AsyncValue(:final value?) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final t in value.where((t) => !exclude.contains(t.id)))
                        ListTile(
                          key: ValueKey('playlist-pick-${t.id}'),
                          leading: Icon(PlaylistItemTile.iconFor(PlaylistItemType.parse(t.type)), color: AppColors.primary),
                          title: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(t.statusLabel),
                          onTap: () => Navigator.of(context).pop(t),
                        ),
                    ],
                  ),
                AsyncValue(hasError: true) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.commonErrorNetwork, textAlign: TextAlign.center),
                  ),
                _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.playlist_remove_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
          ]),
        ),
      );
}
