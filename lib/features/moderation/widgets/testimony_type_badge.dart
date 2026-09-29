import 'package:flutter/material.dart';

import '../models/moderation_models.dart';

// =============================================================================
// TestimonyTypeBadge
// Small pill badge showing TEXT / AUDIO / VIDEO with a matching icon.
// =============================================================================

class TestimonyTypeBadge extends StatelessWidget {
  const TestimonyTypeBadge({required this.type, super.key});

  final TestimonyType type;

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = switch (type) {
      TestimonyType.text => (
          'TEXTE',
          Icons.article_rounded,
          const Color(0xFFEAF1FC),
          const Color(0xFF2B5DB0),
        ),
      TestimonyType.audio => (
          'AUDIO',
          Icons.headphones_rounded,
          const Color(0xFFFFF1E2),
          const Color(0xFFF79009),
        ),
      TestimonyType.video => (
          'VIDEO',
          Icons.play_circle_rounded,
          const Color(0xFFECFDF3),
          const Color(0xFF12B76A),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
