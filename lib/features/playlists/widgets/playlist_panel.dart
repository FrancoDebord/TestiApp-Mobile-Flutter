// Panneau de la liste en cours, sous le lecteur : titre (ouvre la liste),
// « auteur · 2 sur 5 », Précédent / Suivant, lecture auto de la liste et
// témoignages de la liste (celui en cours en surbrillance).
// Docs serveur : fonctionnalites/listes-de-temoignages.md

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../models/playlist_models.dart';
import '../playlist_navigation.dart';
import '../providers/playlist_providers.dart';

/// Panneau de la liste de [testimonyId] (liste [listId], sinon celle choisie
/// par le serveur) ; rien hors liste, pendant le chargement ou en cas d'erreur.
class PlaylistPanelFor extends ConsumerWidget {
  const PlaylistPanelFor({
    required this.testimonyId,
    this.listId,
    this.showAutoplay = true,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String testimonyId;
  final String? listId;

  /// Interrupteur « Lecture auto de la liste » (vidéo, audio ; pas pour un écrit).
  final bool showAutoplay;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(playlistContextProvider((testimonyId: testimonyId, listId: listId))).value;
    if (ctx == null) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: PlaylistPanel(playlist: ctx, currentId: testimonyId, showAutoplay: showAutoplay),
    );
  }
}

class PlaylistPanel extends ConsumerStatefulWidget {
  const PlaylistPanel({
    required this.playlist,
    required this.currentId,
    this.showAutoplay = true,
    this.onOpenItem,
    super.key,
  });

  final PlaylistContext playlist;
  final String currentId;
  final bool showAutoplay;

  /// Remplace l'ouverture du témoignage (par défaut : remplace la page en cours).
  final ValueChanged<PlaylistItem>? onOpenItem;

  @override
  ConsumerState<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends ConsumerState<PlaylistPanel> {
  bool _expanded = true;

  void _open(PlaylistItem item) {
    if (widget.onOpenItem != null) return widget.onOpenItem!(item);
    openPlaylistItem(context, item, widget.playlist.id, replace: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = widget.playlist;
    final autoplay = ref.watch(playlistAutoplayProvider);
    final subtitle = [
      if (p.owner.displayName.isNotEmpty) p.owner.displayName,
      l10n.playlistPosition(p.position, p.count),
    ].join(' · ');

    return Container(
      key: const ValueKey('playlist-panel'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Titre (ouvre la liste) · auteur · position ──────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
            onTap: () => openPlaylist(context, p.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 6),
              child: Row(
                children: [
                  const Icon(Icons.playlist_play_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _expanded ? l10n.commonSeeLess : l10n.playlistOpen,
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // ── Précédent / Suivant ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('playlist-previous'),
                    onPressed: p.previous == null ? null : () => _open(p.previous!),
                    icon: const Icon(Icons.skip_previous_rounded, size: 20),
                    label: Text(l10n.playlistPrevious, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('playlist-next'),
                    onPressed: p.next == null ? null : () => _open(p.next!),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.skip_next_rounded, size: 20),
                    label: Text(l10n.playlistNext, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ),
          if (widget.showAutoplay)
            SwitchListTile.adaptive(
              key: const ValueKey('playlist-autoplay'),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              value: autoplay,
              onChanged: (v) => ref.read(playlistAutoplayProvider.notifier).set(v),
              activeThumbColor: AppColors.primary,
              title: Text(l10n.playlistAutoplay, style: AppTextStyles.bodyMedium),
            ),
          // ── Témoignages de la liste ─────────────────────────────────────
          if (_expanded && p.items.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.border),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: p.items.length,
                itemBuilder: (_, i) => PlaylistItemTile(
                  item: p.items[i],
                  index: i + 1,
                  current: p.items[i].id == widget.currentId,
                  onTap: p.items[i].id == widget.currentId ? null : () => _open(p.items[i]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ligne d'un témoignage de liste : rang (ou « en cours »), miniature, titre,
/// type et durée. Réutilisée par l'écran d'une liste.
class PlaylistItemTile extends StatelessWidget {
  const PlaylistItemTile({
    required this.item,
    required this.index,
    this.current = false,
    this.onTap,
    this.trailing,
    this.note,
    super.key,
  });

  final PlaylistItem item;
  final int index;
  final bool current;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Mention sous le titre (« Visible par vous seulement »).
  final String? note;

  static IconData iconFor(PlaylistItemType t) => switch (t) {
        PlaylistItemType.video => Icons.play_circle_outline_rounded,
        PlaylistItemType.audio => Icons.graphic_eq_rounded,
        PlaylistItemType.text => Icons.article_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = switch (item.type) {
      PlaylistItemType.video => l10n.playlistItemTypeVideo,
      PlaylistItemType.audio => l10n.playlistItemTypeAudio,
      PlaylistItemType.text => l10n.playlistItemTypeText,
    };
    final meta = [type, ?item.durationLabel].join(' · ');
    return Material(
      color: current ? AppColors.primarySoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: current
                    ? const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 20)
                    : Text('$index', textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
              ),
              const SizedBox(width: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 72,
                  height: 42,
                  child: item.coverUrl == null
                      ? ColoredBox(
                          color: AppColors.primarySoft,
                          child: Icon(iconFor(item.type), color: AppColors.primary, size: 20),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.coverUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => ColoredBox(
                            color: AppColors.primarySoft,
                            child: Icon(iconFor(item.type), color: AppColors.primary, size: 20),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: current ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    Text(meta, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    if (note != null)
                      Text(note!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryDark)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
