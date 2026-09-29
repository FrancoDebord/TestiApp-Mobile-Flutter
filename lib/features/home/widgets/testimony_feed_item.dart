// lib/features/home/widgets/testimony_feed_item.dart
//
// Élément de liste de témoignages qui respecte le type d'affichage choisi
// par l'utilisateur (grandes cartes ou liste compacte dépliable).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/playback_preferences.dart';
import '../models/testimony_model.dart';
import 'audio_testimony_card.dart';
import 'compact_testimony_tile.dart';
import 'text_testimony_card.dart';
import 'video_testimony_card.dart';

class TestimonyFeedItem extends ConsumerWidget {
  const TestimonyFeedItem({required this.testimony, super.key});

  final Testimony testimony;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(feedLayoutProvider);
    if (layout == FeedLayout.compact) {
      return CompactTestimonyTile(testimony: testimony);
    }
    return switch (testimony) {
      TextTestimony t => TextTestimonyCard(testimony: t),
      AudioTestimony a => AudioTestimonyCard(testimony: a),
      VideoTestimony v => VideoTestimonyCard(testimony: v),
    };
  }
}

/// Espacement vertical conseillé entre deux éléments selon l'affichage.
double feedItemGap(FeedLayout layout) =>
    layout == FeedLayout.compact ? 8 : 12;
