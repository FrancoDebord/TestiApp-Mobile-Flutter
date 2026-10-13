// lib/features/home/widgets/testimony_feed_item.dart
//
// Élément de liste de témoignages qui respecte le type d'affichage choisi
// par l'utilisateur (grandes cartes ou liste compacte dépliable).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/playback_preferences.dart';
import '../../repost/repost_widgets.dart' show RepostHeader;
import '../../testimony/testimony_delete.dart';
import '../models/testimony_model.dart';
import 'audio_testimony_card.dart';
import 'compact_testimony_tile.dart';
import 'text_testimony_card.dart';
import 'video_testimony_card.dart';

/// Carte d'un témoignage dans toutes les listes (accueil, Mon fil, explorer, profils…),
/// précédée de « X a partagé » quand un compte (suivi d'abord) l'a partagé.
/// Masquée dès que le témoignage est supprimé (auteur ou modération).
class TestimonyFeedItem extends ConsumerWidget {
  const TestimonyFeedItem({required this.testimony, this.showRepost = true, super.key});

  final Testimony testimony;

  /// Faux quand la liste affiche déjà son propre en-tête de partage (onglet « Partages »).
  final bool showRepost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(deletedTestimoniesProvider).contains(testimony.id)) {
      return const SizedBox.shrink();
    }
    final layout = ref.watch(feedLayoutProvider);
    final Widget card = layout == FeedLayout.compact
        ? CompactTestimonyTile(testimony: testimony)
        : switch (testimony) {
            TextTestimony t => TextTestimonyCard(testimony: t),
            AudioTestimony a => AudioTestimonyCard(testimony: a),
            VideoTestimony v => VideoTestimonyCard(testimony: v),
          };
    final repost = showRepost ? testimony.repost : null;
    if (repost == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepostHeader(repost: repost),
        const SizedBox(height: 8),
        card,
      ],
    );
  }
}

/// Espacement vertical conseillé entre deux éléments selon l'affichage.
double feedItemGap(FeedLayout layout) =>
    layout == FeedLayout.compact ? 8 : 12;
