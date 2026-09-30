import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/utils/rich_text_utils.dart';
import '../models/testimony_model.dart';
import 'feed_card_frame.dart';

class TextTestimonyCard extends ConsumerStatefulWidget {
  const TextTestimonyCard({required this.testimony, super.key});

  final TextTestimony testimony;

  @override
  ConsumerState<TextTestimonyCard> createState() => _TextTestimonyCardState();
}

class _TextTestimonyCardState extends ConsumerState<TextTestimonyCard> {
  /// Extrait court et sans balises pour le message de partage (le lien mène
  /// au texte complet).
  static String _excerpt(String body) {
    final plain = stripFormatting(body).trim();
    if (plain.length <= 200) return plain;
    final cut = plain.lastIndexOf(' ', 200);
    return '${plain.substring(0, cut > 120 ? cut : 200).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    final testimony = widget.testimony;
    return FeedCardFrame(
      testimony: testimony,
      shareExcerpt: _excerpt(testimony.preview),
      // Texte mis en forme, dévoilé morceau par morceau.
      preview: ProgressiveRichText(
        text: testimony.preview,
        style: feedPreviewStyle(),
        initialChars: 220,
        stepChars: 500,
        // Non sélectionnable : le tap sur la carte ouvre le détail.
        selectable: false,
        linkStyle: TextStyle(
          fontFamily: AppFonts.family,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
