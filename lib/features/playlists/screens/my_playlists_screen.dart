// « Mes listes » : mes listes de témoignages (titre, nombre, couverture),
// création ; chaque liste s'ouvre pour la modifier, la réordonner ou la supprimer.
// Docs serveur : fonctionnalites/listes-de-temoignages.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/playlist_api.dart' show playlistApiProvider;
import '../playlist_navigation.dart';
import '../providers/playlist_providers.dart';
import '../widgets/playlist_card.dart';
import '../widgets/playlist_sheets.dart';

class MyPlaylistsScreen extends ConsumerStatefulWidget {
  const MyPlaylistsScreen({super.key});

  @override
  ConsumerState<MyPlaylistsScreen> createState() => _MyPlaylistsScreenState();
}

class _MyPlaylistsScreenState extends ConsumerState<MyPlaylistsScreen> {
  bool _busy = false;

  Future<void> _create() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final form = await showPlaylistFormDialog(context);
    if (form == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final p = await ref.read(playlistApiProvider).create(title: form.title, description: form.description);
      refreshPlaylists(ref.invalidate, ownerId: p.owner.id);
      messenger?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(l10n.playlistCreated)));
      if (mounted) await openPlaylist(context, p.id);
    } catch (e) {
      messenger?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(playlistErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(myPlaylistsProvider);
    return Scaffold(
      key: const ValueKey('my-playlists'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(l10n.playlistsMine),
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('my-playlists-new'),
        onPressed: _busy ? null : _create,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.playlistNew),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myPlaylistsProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 96),
          children: [
            Text(l10n.playlistsMineIntro, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            ...switch (async) {
              AsyncValue(:final value?) when value.isEmpty => [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      const Icon(Icons.playlist_add_rounded, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(l10n.playlistsEmptyMine,
                          textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                    ]),
                  ),
                ],
              AsyncValue(:final value?) => [
                  for (final p in value) ...[
                    PlaylistCard(playlist: p, onTap: () => openPlaylist(context, p.id)),
                    const SizedBox(height: 10),
                  ],
                ],
              AsyncValue(:final error?) => [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      Text(playlistsLoadErrorText(error),
                          textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                      TextButton(onPressed: () => ref.invalidate(myPlaylistsProvider), child: Text(l10n.commonRetry)),
                    ]),
                  ),
                ],
              _ => const [Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))],
            },
          ],
        ),
      ),
    );
  }
}
