// Profil d'un compte : section « Listes » (GET /users/{id}/playlists), masquée
// s'il n'y en a aucune ou si elles n'ont pas pu être lues.
// Docs serveur : fonctionnalites/listes-de-temoignages.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../playlist_navigation.dart';
import '../providers/playlist_providers.dart';
import 'playlist_card.dart';

class ProfilePlaylistsSection extends ConsumerWidget {
  const ProfilePlaylistsSection({required this.userId, this.padding = EdgeInsets.zero, super.key});

  final String userId;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(userPlaylistsProvider(userId)).value ?? const [];
    if (lists.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('profile-playlists'),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.l10n.playlistsTab,
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 16), // i18n-ignore
            ),
          ),
          for (final p in lists) ...[
            PlaylistCard(playlist: p, onTap: () => openPlaylist(context, p.id)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
