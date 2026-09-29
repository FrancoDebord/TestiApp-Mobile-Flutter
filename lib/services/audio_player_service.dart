// lib/services/audio_player_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../core/media/media_quality.dart';
import '../core/media/playback_preferences.dart';
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
    this.currentTestimony,
    this.qualityLabel,
    this.qualityOverride,
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

  /// Témoignage en cours quand la file a été créée via
  /// [AudioPlayerNotifier.setTestimonyQueue].
  final AudioTestimony? currentTestimony;

  /// Libellé de la version lue (« 64 kbps », « Originale »…).
  final String? qualityLabel;

  /// Qualité choisie manuellement dans le lecteur (null = préférence).
  final AudioQuality? qualityOverride;

  bool get hasNext => queueIndex < queueLength - 1;
  bool get hasPrevious => queueIndex > 0;

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
    AudioTestimony? currentTestimony,
    String? qualityLabel,
    AudioQuality? qualityOverride,
    bool clearQualityOverride = false,
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
      currentTestimony: currentTestimony ?? this.currentTestimony,
      qualityLabel: qualityLabel ?? this.qualityLabel,
      qualityOverride: clearQualityOverride
          ? null
          : (qualityOverride ?? this.qualityOverride),
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

  /// Témoignages correspondant à [_queue] (vide si file d'URLs brutes).
  List<AudioTestimony> _testimonies = [];

  @override
  AudioPlayerState build() {
    _player = AudioPlayer();
    _setupListeners();

    // Dispose player when the provider is disposed.
    ref.onDispose(_player.dispose);

    // Changement de réseau (Wi-Fi ⇄ données mobiles) : en mode Auto, on
    // bascule sur la version adaptée sans perdre la position.
    ref.listen<AsyncValue<bool>>(isMeteredConnectionProvider, (prev, next) {
      final was = prev?.value;
      final now = next.value;
      if (now == null || was == null || was == now) return;
      _onNetworkChanged();
    });

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
        _onCompleted();
      }
    });
  }

  /// Fin de piste — règle commune à tous les lecteurs :
  ///   • répéter ce témoignage → on relance ;
  ///   • lecture auto → suivant (ou retour au premier en fin de liste si
  ///     « Répéter la liste ») ;
  ///   • sinon → arrêt.
  Future<void> _onCompleted() async {
    final prefs = ref.read(playbackPreferencesProvider);
    final isLast = _queueIndex >= _queue.length - 1;
    final repeatAll = prefs.repeatMode == RepeatMode.all;

    if (prefs.repeatMode == RepeatMode.one ||
        (prefs.autoplayNext && repeatAll && _queue.length <= 1)) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    if (prefs.autoplayNext && _queue.length > 1) {
      if (!isLast) {
        await _playAt(_queueIndex + 1);
        return;
      }
      if (repeatAll) {
        await _playAt(0);
        return;
      }
    }
    // Arrêt : on revient au début sans relancer.
    state = state.copyWith(isPlaying: false, position: Duration.zero);
    await _player.seek(Duration.zero);
    await _player.pause();
  }

  bool get _metered => ref.read(isMeteredConnectionProvider).value ?? true;

  ResolvedMedia? _resolveFor(AudioTestimony t, {AudioQuality? override}) =>
      resolveAudioTestimony(
        t,
        prefs: ref.read(playbackPreferencesProvider),
        metered: _metered,
        override: override,
      );

  Future<void> _playAt(int index) async {
    if (_queue.isEmpty) return;
    _queueIndex = index.clamp(0, _queue.length - 1);
    if (_testimonies.isNotEmpty) {
      final t = _testimonies[_queueIndex];
      final r = _resolveFor(t, override: state.qualityOverride);
      if (r != null) _queue[_queueIndex] = r.url;
      state = state.copyWith(
        queueIndex: _queueIndex,
        currentTestimony: t,
        qualityLabel: r?.label,
      );
    } else {
      state = state.copyWith(queueIndex: _queueIndex);
    }
    await play(_queue[_queueIndex]);
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
    _testimonies = [];
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

    _queue = List<String>.of(sources);
    _testimonies = [];
    state = state.copyWith(queueLength: _queue.length);
    await _playAt(startIndex);
  }

  /// File de témoignages audio : la qualité de chacun est choisie selon les
  /// préférences et le réseau.
  Future<void> setTestimonyQueue(
    List<AudioTestimony> testimonies, {
    int startIndex = 0,
  }) async {
    final start = testimonies.isEmpty
        ? null
        : testimonies[startIndex.clamp(0, testimonies.length - 1)];
    final list = testimonies
        .where((t) =>
            (t.mediaPath?.isNotEmpty ?? false) || t.renditions.isNotEmpty)
        .toList();
    if (list.isEmpty) return;
    _testimonies = list;
    _queue = [for (final t in list) _resolveFor(t)?.url ?? t.mediaPath ?? ''];
    state = state.copyWith(
      queueLength: _queue.length,
      clearQualityOverride: true,
    );
    final idx = start == null ? 0 : list.indexWhere((t) => t.id == start.id);
    await _playAt(idx < 0 ? 0 : idx);
  }

  /// Témoignage suivant. En fin de liste : revient au début seulement si la
  /// répétition de la liste est active.
  Future<void> playNext() async {
    if (_queue.isEmpty) return;
    if (_queueIndex >= _queue.length - 1) {
      if (ref.read(playbackPreferencesProvider).repeatMode == RepeatMode.all) {
        await _playAt(0);
      }
      return;
    }
    await _playAt(_queueIndex + 1);
  }

  /// Témoignage précédent — ou retour au début si > 3 s de lecture.
  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    if (state.position > const Duration(seconds: 3) || _queueIndex == 0) {
      await seek(Duration.zero);
      return;
    }
    await _playAt(_queueIndex - 1);
  }

  /// Change la qualité de la piste en cours sans perdre la position.
  /// `null` = revenir à la préférence par défaut.
  Future<void> setQuality(AudioQuality? quality) async {
    final t = state.currentTestimony;
    final r = t == null ? null : _resolveFor(t, override: quality);
    state = quality == null
        ? state.copyWith(clearQualityOverride: true, qualityLabel: r?.label)
        : state.copyWith(qualityOverride: quality, qualityLabel: r?.label);
    if (r == null || r.url == state.url) return;
    await _switchSource(r.url);
  }

  /// Réseau changé : si la qualité effective est Auto (aucun choix manuel
  /// dans le lecteur, préférence Auto), on relit la version adaptée.
  Future<void> _onNetworkChanged() async {
    final t = state.currentTestimony;
    if (t == null || state.url == null) return; // rien en cours
    if (state.qualityOverride != null) return;
    if (ref.read(playbackPreferencesProvider).audioQuality !=
        AudioQuality.auto) {
      return;
    }
    final r = _resolveFor(t);
    if (r == null || r.url == state.url) return;
    state = state.copyWith(qualityLabel: r.label);
    await _switchSource(r.url);
  }

  /// Remplace la source en cours par [url] en gardant position et état.
  Future<void> _switchSource(String url) async {
    final pos = _player.position;
    final wasPlaying = _player.playing;
    if (_queue.isNotEmpty) _queue[_queueIndex] = url;
    try {
      state = state.copyWith(url: url, isLoading: true, clearError: true);
      await _player.setUrl(url, initialPosition: pos);
      if (wasPlaying) await _player.play();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
