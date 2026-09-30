import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/testimony_model.dart';
import 'feed_card_frame.dart';

class AudioTestimonyCard extends StatelessWidget {
  const AudioTestimonyCard({required this.testimony, super.key});

  final AudioTestimony testimony;

  @override
  Widget build(BuildContext context) {
    final transcript = testimony.transcriptPreview.trim();
    return FeedCardFrame(
      testimony: testimony,
      media: _WaveformPlayer(testimony: testimony),
      mediaPadded: true,
      shareExcerpt: transcript,
      preview: transcript.isEmpty
          ? null
          : Text(
              transcript,
              style: feedPreviewStyle().copyWith(fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

// ── Waveform player ────────────────────────────────────────────────────────────

class _WaveformPlayer extends StatelessWidget {
  const _WaveformPlayer({required this.testimony});
  final AudioTestimony testimony;

  static const List<double> _bars = [
    0.3, 0.6, 0.4, 0.9, 0.7, 0.5, 0.8, 0.4, 0.6, 0.3,
    0.7, 0.5, 0.9, 0.4, 0.6, 0.8, 0.3, 0.7, 0.5, 0.4,
    0.9, 0.6, 0.3, 0.8, 0.5, 0.7, 0.4, 0.6, 0.3, 0.9,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Row(
              children: [
                _PlayButton(onTap: () => context.push('/testimony/${testimony.id}')),
                const SizedBox(width: 12),
                Expanded(child: _WaveformBars(bars: _bars)),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 10,
            child: _DurationBadge(duration: testimony.formattedDuration),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

class _WaveformBars extends StatelessWidget {
  const _WaveformBars({required this.bars});
  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: bars.asMap().entries.map((e) {
        final played = e.key / bars.length < 0.40;
        return Container(
          width: 3,
          height: 40 * e.value,
          decoration: BoxDecoration(
            color: played
                ? AppColors.primary
                : AppColors.primary.withAlpha(55),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.duration});
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        duration,
        style: TextStyle(
          fontFamily: AppFonts.family,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
