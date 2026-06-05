import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/core/theme/app_text_styles.dart';

// ── State model ────────────────────────────────────────────────────────────────

enum AudioPlayerStatus { idle, loading, playing, paused }

class AudioPlayerState {
  const AudioPlayerState({
    this.status = AudioPlayerStatus.idle,
    this.testimonyId,
    this.title,
    this.authorName,
    this.audioUrl,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.thumbnailUrl,
  });

  final AudioPlayerStatus status;
  final String? testimonyId;
  final String? title;
  final String? authorName;
  final String? audioUrl;
  final Duration position;
  final Duration duration;
  final String? thumbnailUrl;

  bool get isVisible => status != AudioPlayerStatus.idle;
  bool get isPlaying => status == AudioPlayerStatus.playing;
  bool get isLoading => status == AudioPlayerStatus.loading;

  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  AudioPlayerState copyWith({
    AudioPlayerStatus? status,
    String? testimonyId,
    String? title,
    String? authorName,
    String? audioUrl,
    Duration? position,
    Duration? duration,
    String? thumbnailUrl,
  }) {
    return AudioPlayerState(
      status: status ?? this.status,
      testimonyId: testimonyId ?? this.testimonyId,
      title: title ?? this.title,
      authorName: authorName ?? this.authorName,
      audioUrl: audioUrl ?? this.audioUrl,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  AudioPlayerState get dismissed => const AudioPlayerState();
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  Timer? _ticker;

  @override
  AudioPlayerState build() {
    // Cancel any running ticker when the provider is disposed / rebuilt.
    ref.onDispose(() => _ticker?.cancel());
    return const AudioPlayerState();
  }

  /// Load and play a new audio testimony.
  Future<void> play({
    required String testimonyId,
    required String title,
    required String authorName,
    required String audioUrl,
    required Duration duration,
    String? thumbnailUrl,
  }) async {
    _ticker?.cancel();

    state = AudioPlayerState(
      status: AudioPlayerStatus.loading,
      testimonyId: testimonyId,
      title: title,
      authorName: authorName,
      audioUrl: audioUrl,
      duration: duration,
      thumbnailUrl: thumbnailUrl,
    );

    // In production, initialise your audio_player package here.
    // We simulate load with a short delay then start a position ticker.
    await Future.delayed(const Duration(milliseconds: 600));

    state = state.copyWith(status: AudioPlayerStatus.playing);
    _startTicker();
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      _ticker?.cancel();
      state = state.copyWith(status: AudioPlayerStatus.paused);
    } else if (state.status == AudioPlayerStatus.paused) {
      state = state.copyWith(status: AudioPlayerStatus.playing);
      _startTicker();
    }
  }

  void seekTo(double progress) {
    final ms = (state.duration.inMilliseconds * progress).round();
    state = state.copyWith(position: Duration(milliseconds: ms));
  }

  void dismiss() {
    _ticker?.cancel();
    state = state.dismissed;
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isPlaying) return;
      final next = state.position + const Duration(seconds: 1);
      if (next >= state.duration) {
        _ticker?.cancel();
        state = state.copyWith(
          position: state.duration,
          status: AudioPlayerStatus.paused,
        );
      } else {
        state = state.copyWith(position: next);
      }
    });
  }

}

/// Global provider — import this wherever you need audio control.
final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  AudioPlayerNotifier.new,
);

// ── Mini player widget ─────────────────────────────────────────────────────────

/// Persistent mini player that sits above the bottom navigation bar.
/// Wrap inside an [AnimatedSlide] or place it directly above the [BottomNavigationBar].
///
/// Usage in your scaffold:
/// ```dart
/// bottomNavigationBar: Column(
///   mainAxisSize: MainAxisSize.min,
///   children: [
///     MiniAudioPlayer(),
///     BottomNavBar(),
///   ],
/// )
/// ```
class MiniAudioPlayer extends ConsumerWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioPlayerProvider);

    return AnimatedSlide(
      offset: audio.isVisible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: audio.isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: audio.isVisible
            ? _MiniPlayerContent(
                audio: audio,
                onToggle: () =>
                    ref.read(audioPlayerProvider.notifier).togglePlayPause(),
                onDismiss: () =>
                    ref.read(audioPlayerProvider.notifier).dismiss(),
                onSeek: (v) =>
                    ref.read(audioPlayerProvider.notifier).seekTo(v),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  const _MiniPlayerContent({
    required this.audio,
    required this.onToggle,
    required this.onDismiss,
    required this.onSeek,
  });

  final AudioPlayerState audio;
  final VoidCallback onToggle;
  final VoidCallback onDismiss;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar (tap to seek)
          _SeekBar(progress: audio.progress, onSeek: onSeek),

          // Content row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 10),
            child: Row(
              children: [
                // Artwork / waveform icon
                _Artwork(thumbnailUrl: audio.thumbnailUrl),
                const SizedBox(width: 10),

                // Title & author
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        audio.title ?? '',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        audio.authorName ?? '',
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Rewind 10s
                _IconBtn(
                  icon: Icons.replay_10_rounded,
                  size: 22,
                  onTap: () => onSeek(
                    (audio.progress -
                            10 / audio.duration.inSeconds.toDouble())
                        .clamp(0.0, 1.0),
                  ),
                ),

                // Play / Pause
                _PlayPauseButton(
                  status: audio.status,
                  onTap: onToggle,
                ),

                // Forward 10s
                _IconBtn(
                  icon: Icons.forward_10_rounded,
                  size: 22,
                  onTap: () => onSeek(
                    (audio.progress +
                            10 / audio.duration.inSeconds.toDouble())
                        .clamp(0.0, 1.0),
                  ),
                ),

                // Close
                _IconBtn(
                  icon: Icons.close_rounded,
                  size: 20,
                  onTap: onDismiss,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.progress, required this.onSeek});
  final double progress;
  final ValueChanged<double> onSeek;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value = _dragging ?? widget.progress;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withAlpha(30),
      ),
      child: SizedBox(
        height: 18,
        child: Slider(
          value: value.clamp(0.0, 1.0),
          onChanged: (v) => setState(() => _dragging = v),
          onChangeEnd: (v) {
            setState(() => _dragging = null);
            widget.onSeek(v);
          },
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({this.thumbnailUrl});
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        image: thumbnailUrl != null
            ? DecorationImage(
                image: NetworkImage(thumbnailUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: thumbnailUrl == null
          ? const Icon(Icons.headphones_rounded,
              color: AppColors.primary, size: 20)
          : null,
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.status,
    required this.onTap,
  });

  final AudioPlayerStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (status == AudioPlayerStatus.loading) {
      child = const SizedBox(
        key: ValueKey('loading'),
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    } else {
      child = Icon(
        status == AudioPlayerStatus.playing
            ? Icons.pause_circle_filled_rounded
            : Icons.play_circle_filled_rounded,
        key: ValueKey(status),
        color: AppColors.primary,
        size: 36,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap, this.size = 24});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Icon(icon, size: size, color: AppColors.textSecondary),
      ),
    );
  }
}
