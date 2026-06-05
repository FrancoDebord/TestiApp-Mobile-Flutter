import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../models/testimony_model.dart';

/// Full stats section for a testimony card.
///
/// Widget tree:
/// Column
///   ├─ _ReactionAvatarRow   ← [M][J][A] ❤️🙏 234 · et 231 autres
///   └─ stats Row            ← 👁 1.2k · 💬 34 · ❤️ 89 · 🙏 156

/// Compact stats row: 👁 1.2k · 💬 34 · ❤️ 89 · 🙏 156
///
/// Widget tree:
/// Column
///   ├─ _ReactionAvatarRow (when likes + prayers > 0)
///   └─ Row
///        ├─ _StatItem (views)
///        ├─ _Dot
///        ├─ _StatItem (comments)
///        ├─ _Dot
///        ├─ _StatItem (likes)
///        ├─ _Dot
///        └─ _StatItem (prayers)
class TestimonyStatsRow extends StatelessWidget {
  const TestimonyStatsRow({required this.stats, super.key});

  final TestimonyStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Reaction avatar row (Facebook/LinkedIn style) ──────────────────
        if (stats.likes + stats.prayers > 0)
          _ReactionAvatarRow(stats: stats),

        // ── Compact stats row ──────────────────────────────────────────────
        Row(
          children: [
            Flexible(child: _StatItem(icon: '👁', count: stats.views)),
            const _Dot(),
            Flexible(child: _StatItem(icon: '💬', count: stats.comments)),
            const _Dot(),
            Flexible(child: _StatItem(icon: '❤️', count: stats.likes)),
            const _Dot(),
            Flexible(child: _StatItem(icon: '🙏', count: stats.prayers)),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// Reaction avatar row — shown above the compact stats row
// ============================================================================

/// Shows stacked avatar initials, top-reaction emojis, and total reaction count.
///
/// Example:  [M] [J] [A]  ❤️🙏  234 · et 231 autres
class _ReactionAvatarRow extends StatelessWidget {
  const _ReactionAvatarRow({required this.stats});

  final TestimonyStats stats;

  static const List<Color> _avatarColors = [
    Color(0xFF6B21A8), // purple
    Color(0xFF1E3A8A), // dark blue
    Color(0xFF065F46), // dark green
    Color(0xFF9D174D), // dark pink
  ];

  static const List<String> _letters = ['M', 'J', 'A', 'S'];

  String _format(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final total  = stats.likes + stats.prayers;
    final count  = total.clamp(0, 3); // min(3, total)
    final others = total > 3 ? total - 3 : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // ── Overlapping avatar circles ──────────────────────────────────
          SizedBox(
            width:  count * 20.0 + 12,
            height: 26,
            child: Stack(
              children: List.generate(count, (i) {
                return Positioned(
                  left: i * 20.0,
                  top:  3, // vertically centre the 20-px circle in 26-px height
                  child: _AvatarCircle(
                    initial: _letters[i % _letters.length],
                    color:   _avatarColors[i % _avatarColors.length],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 6),

          // ── Reaction emojis ─────────────────────────────────────────────
          const Text('❤️🙏', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),

          // ── Total count (+ "· et X autres" when total > 3) ──────────────
          Flexible(
            child: Text(
              others > 0
                  ? '${_format(total)} · et ${_format(others)} autres'
                  : _format(total),
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar circle ─────────────────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.initial, required this.color});

  final String initial;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  20,
      height: 20,
      decoration: BoxDecoration(
        color:  color,
        shape:  BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initial.isNotEmpty ? initial[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize:   8,
          color:      Colors.white,
          fontWeight: FontWeight.w700,
          height:     1,
        ),
      ),
    );
  }
}

// ============================================================================
// Internal helpers (unchanged)
// ============================================================================

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.count});

  final String icon;
  final int count;

  String _format(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            _format(count),
            style: AppTextStyles.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('·',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
    );
  }
}
