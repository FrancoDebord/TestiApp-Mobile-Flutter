// lib/services/audio_player_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../features/home/models/testimony_model.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class AudioPlayerState {
  const AudioPlayerState({
    this.url,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isLoading = false,
    this.speed = 1.0,
    this.error,
    this.queueIndex = 0,
    this.queueLength = 0,
  });

  final String? url;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isLoading;
  final double speed;
  final String? error;

  /// Index of the currently playing item inside the active queue.
  final int queueIndex;

  /// Total number of items in the active queue.
  final int queueLength;

  AudioPlayerState copyWith({
    String? url,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isLoading,
    double? speed,
    String? error,
    bool clearError = false,
    int? queueIndex,
    int? queueLength,
  }) {
    return AudioPlayerState(
      url: url ?? this.url,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      speed: speed ?? this.speed,
      error: clearError ? null : (error ?? this.error),
      queueIndex: queueIndex ?? this.queueIndex,
      queueLength: queueLength ?? this.queueLength,
    );
  }

  /// Progress from 0.0 to 1.0. Returns 0 when duration is zero.
  double get progress {
    if (duration == Duration.zero) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Remaining playback time.
  Duration get remaining => duration - position;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  late final AudioPlayer _player;

  /// Ordered list of audio source paths / URLs.
  List<String> _queue = [];

  /// Index of the currently active item in [_queue].
  int _queueIndex = 0;

  @override
  AudioPlayerState build() {
    _player = AudioPlayer();
    _setupListeners();

    // Dispose player when the provider is disposed.
    ref.onDispose(_player.dispose);

    return const AudioPlayerState();
  }

  void _setupListeners() {
    // Position updates
    _player.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    // Duration updates
    _player.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    // Playing state
    _player.playingStream.listen((isPlaying) {
      state = state.copyWith(isPlaying: isPlaying);
    });

    // Loading / buffering / completion state
    _player.processingStateStream.listen((processingState) {
      final isLoading = processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering;
      state = state.copyWith(isLoading: isLoading);

      if (processingState == ProcessingState.completed) {
        if (_queue.length > 1) {
          // Auto-advance to the next track in the queue.
          playNext();
        } else {
          // Single track — reset to start and stop.
          state = state.copyWith(
            isPlaying: false,
            position: Duration.zero,
          );
          _player.seek(Duration.zero);
          _player.pause();
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Loads [source] (network URL or local file path) and starts playback.
  /// If [source] is already loaded, simply resumes.
  Future<void> play(String source) async {
    try {
      if (state.url == source) {
        await _player.play();
        return;
      }

      state = state.copyWith(
        url: source,
        isLoading: true,
        position: Duration.zero,
        duration: Duration.zero,
        clearError: true,
      );

      final isNetwork =
          source.startsWith('http://') || source.startsWith('https://');
      if (isNetwork) {
        await _player.setUrl(source);
      } else {
        await _player.setFilePath(source);
      }
      await _player.play();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        error: e.toString(),
      );
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    if (state.url != null) {
      await _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Seeks to a fraction of total duration (0.0 – 1.0).
  Future<void> seekToFraction(double fraction) async {
    if (state.duration == Duration.zero) return;
    final target = Duration(
      milliseconds: (state.duration.inMilliseconds * fraction).round(),
    );
    await _player.seek(target);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  Future<void> stop() async {
    await _player.stop();
    _queue = [];
    _queueIndex = 0;
    state = const AudioPlayerState();
  }

  Future<void> skipForward({int seconds = 15}) async {
    final target = state.position + Duration(seconds: seconds);
    await seek(target > state.duration ? state.duration : target);
  }

  Future<void> skipBackward({int seconds = 15}) async {
    final target = state.position - Duration(seconds: seconds);
    await seek(target < Duration.zero ? Duration.zero : target);
  }

  // ---------------------------------------------------------------------------
  // Playlist / Queue API
  // ---------------------------------------------------------------------------

  /// Replaces the current queue with [sources] and starts playing from
  /// [startIndex]. Clamps [startIndex] to a valid range.
  Future<void> setQueue(List<String> sources, {int startIndex = 0}) async {
    if (sources.isEmpty) return;

    _queue = List<String>.unmodifiable(sources);
    _queueIndex = startIndex.clamp(0, _queue.length - 1);

    state = state.copyWith(
      queueIndex: _queueIndex,
      queueLength: _queue.length,
    );

    await play(_queue[_queueIndex]);
  }

  /// Advances to the next track, wrapping back to index 0 at the end of the
  /// queue.
  Future<void> playNext() async {
    if (_queue.isEmpty) return;

    _queueIndex = (_queueIndex + 1) % _queue.length;
    state = state.copyWith(queueIndex: _queueIndex);
    await play(_queue[_queueIndex]);
  }

  /// Goes back to the previous track, wrapping to the last item when already
  /// at index 0.
  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;

    _queueIndex = (_queueIndex - 1 + _queue.length) % _queue.length;
    state = state.copyWith(queueIndex: _queueIndex);
    await play(_queue[_queueIndex]);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Main provider — exposes full [AudioPlayerState].
final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  AudioPlayerNotifier.new,
);

/// Convenience selector — true while audio is playing.
final isAudioPlayingProvider = Provider<bool>(
  (ref) => ref.watch(audioPlayerProvider).isPlaying,
);

/// Convenience selector — current playback progress (0.0 – 1.0).
final audioProgressProvider = Provider<double>(
  (ref) => ref.watch(audioPlayerProvider).progress,
);

/// Current queue index of the active track.
final currentQueueIndexProvider = Provider<int>(
  (ref) => ref.watch(audioPlayerProvider).queueIndex,
);

/// Total number of tracks in the active queue.
final queueLengthProvider = Provider<int>(
  (ref) => ref.watch(audioPlayerProvider).queueLength,
);

// ---------------------------------------------------------------------------
// Queue helper
// ---------------------------------------------------------------------------

/// Builds a flat list of audio source strings from a list of [Testimony]
/// objects. Only [AudioTestimony] items that carry a non-null [mediaPath] are
/// included; all other testimony types are skipped.
List<String> testimoniesToQueue(List<Testimony> list) {
  final sources = <String>[];
  for (final testimony in list) {
    if (testimony is AudioTestimony) {
      final path = testimony.mediaPath;
      if (path != null && path.isNotEmpty) {
        sources.add(path);
      }
    }
  }
  return sources;
}
