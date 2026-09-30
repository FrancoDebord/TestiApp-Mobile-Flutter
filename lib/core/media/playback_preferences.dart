// lib/core/media/playback_preferences.dart
//
// Préférences de lecture et d'affichage, persistées localement :
//   • qualité vidéo / audio par défaut (Auto = selon le réseau)
//   • économiseur de données
//   • lecture automatique du suivant, répétition
//   • type d'affichage du fil (grandes cartes / liste compacte)

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_service.dart';

// ── Enums ────────────────────────────────────────────────────────────────────

/// Qualité vidéo préférée. [height] = hauteur maximale en pixels (0 = Auto).
enum VideoQuality {
  auto(0),
  p1080(1080),
  p720(720),
  p480(480),
  p360(360),
  p240(240),
  p144(144);

  const VideoQuality(this.height);
  final int height;

  String get label => this == auto ? 'Auto' : '${height}p';

  String get hint => switch (this) {
        auto => "S'adapte à votre connexion",
        p1080 || p720 => 'Haute qualité · plus de données',
        p480 => 'Qualité standard',
        p360 => 'Économique',
        p240 || p144 => 'Très économique',
      };
}

/// Qualité audio préférée. [maxKbps] = débit maximal (0 = Auto / illimité).
enum AudioQuality {
  auto(0),
  high(320),
  standard(128),
  low(64),
  veryLow(32);

  const AudioQuality(this.maxKbps);
  final int maxKbps;

  String get label => switch (this) {
        auto => 'Auto',
        high => 'Haute',
        standard => 'Standard',
        low => 'Faible',
        veryLow => 'Très faible',
      };

  String get hint => switch (this) {
        auto => "S'adapte à votre connexion",
        high => 'Meilleur son · plus de données',
        standard => 'Bon compromis (≈128 kbps)',
        low => 'Économique (≈64 kbps)',
        veryLow => 'Minimum de données (≈32 kbps)',
      };
}

/// Répétition : aucune, le média en cours, ou toute la liste.
enum RepeatMode {
  off,
  one,
  all;

  String get label => switch (this) {
        off => 'Pas de répétition',
        one => 'Répéter ce témoignage',
        all => 'Répéter la liste',
      };

  RepeatMode get next => RepeatMode.values[(index + 1) % 3];
}

/// Affichage du fil de témoignages.
enum FeedLayout {
  cards,
  compact;

  String get label => this == cards ? 'Grandes cartes' : 'Liste compacte';
}

// ── State ────────────────────────────────────────────────────────────────────

class PlaybackPreferences {
  const PlaybackPreferences({
    this.videoQuality = VideoQuality.auto,
    this.audioQuality = AudioQuality.auto,
    this.dataSaver = false,
    this.autoplayNext = true,
    this.repeatMode = RepeatMode.off,
    this.feedLayout = FeedLayout.cards,
    this.offlineMode = false,
  });

  final VideoQuality videoQuality;
  final AudioQuality audioQuality;

  /// Économiseur de données : force la plus basse qualité sur données mobiles.
  final bool dataSaver;

  /// Enchaîne automatiquement le témoignage suivant à la fin de la lecture.
  final bool autoplayNext;

  final RepeatMode repeatMode;
  final FeedLayout feedLayout;

  /// Mode hors ligne : lire uniquement les témoignages téléchargés, sans
  /// consommer de données (Paramètres › Mode hors ligne).
  final bool offlineMode;

  PlaybackPreferences copyWith({
    VideoQuality? videoQuality,
    AudioQuality? audioQuality,
    bool? dataSaver,
    bool? autoplayNext,
    RepeatMode? repeatMode,
    FeedLayout? feedLayout,
    bool? offlineMode,
  }) =>
      PlaybackPreferences(
        videoQuality: videoQuality ?? this.videoQuality,
        audioQuality: audioQuality ?? this.audioQuality,
        dataSaver: dataSaver ?? this.dataSaver,
        autoplayNext: autoplayNext ?? this.autoplayNext,
        repeatMode: repeatMode ?? this.repeatMode,
        feedLayout: feedLayout ?? this.feedLayout,
        offlineMode: offlineMode ?? this.offlineMode,
      );

  Map<String, dynamic> toJson() => {
        'video_quality': videoQuality.name,
        'audio_quality': audioQuality.name,
        'data_saver': dataSaver,
        'autoplay_next': autoplayNext,
        'repeat_mode': repeatMode.name,
        'feed_layout': feedLayout.name,
        'offline_mode': offlineMode,
      };

  factory PlaybackPreferences.fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    return PlaybackPreferences(
      videoQuality:
          pick(VideoQuality.values, j['video_quality'], VideoQuality.auto),
      audioQuality:
          pick(AudioQuality.values, j['audio_quality'], AudioQuality.auto),
      dataSaver: j['data_saver'] as bool? ?? false,
      autoplayNext: j['autoplay_next'] as bool? ?? true,
      repeatMode: pick(RepeatMode.values, j['repeat_mode'], RepeatMode.off),
      feedLayout: pick(FeedLayout.values, j['feed_layout'], FeedLayout.cards),
      offlineMode: j['offline_mode'] as bool? ?? false,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class PlaybackPreferencesNotifier extends Notifier<PlaybackPreferences> {
  static const _key = 'playback_preferences';

  @override
  PlaybackPreferences build() {
    Future.microtask(_load);
    return const PlaybackPreferences();
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(secureStorageProvider).read(key: _key);
      if (raw == null || raw.isEmpty) return;
      final p = PlaybackPreferences.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
      // Anciennes préférences incohérentes : « Répéter la liste » implique
      // la lecture auto.
      state = p.repeatMode == RepeatMode.all && !p.autoplayNext
          ? p.copyWith(autoplayNext: true)
          : p;
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await ref
          .read(secureStorageProvider)
          .write(key: _key, value: jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void _update(PlaybackPreferences next) {
    state = next;
    unawaited(_save());
  }

  void setVideoQuality(VideoQuality q) =>
      _update(state.copyWith(videoQuality: q));
  void setAudioQuality(AudioQuality q) =>
      _update(state.copyWith(audioQuality: q));
  void setDataSaver(bool v) => _update(state.copyWith(dataSaver: v));

  /// Désactiver la lecture auto alors que « Répéter la liste » est actif
  /// désactive aussi la répétition de la liste (qui n'a de sens qu'en
  /// enchaînant les témoignages).
  void setAutoplayNext(bool v) => _update(state.copyWith(
        autoplayNext: v,
        repeatMode: !v && state.repeatMode == RepeatMode.all
            ? RepeatMode.off
            : null,
      ));

  /// « Répéter la liste » active automatiquement la lecture auto.
  void setRepeatMode(RepeatMode m) => _update(state.copyWith(
        repeatMode: m,
        autoplayNext: m == RepeatMode.all ? true : null,
      ));
  void cycleRepeatMode() => setRepeatMode(state.repeatMode.next);
  void setFeedLayout(FeedLayout l) => _update(state.copyWith(feedLayout: l));
  void setOfflineMode(bool v) => _update(state.copyWith(offlineMode: v));
}

final playbackPreferencesProvider =
    NotifierProvider<PlaybackPreferencesNotifier, PlaybackPreferences>(
  PlaybackPreferencesNotifier.new,
);

final feedLayoutProvider = Provider<FeedLayout>(
  (ref) => ref.watch(playbackPreferencesProvider).feedLayout,
);

// ── Réseau ───────────────────────────────────────────────────────────────────

/// `true` quand la connexion est « payante » (données mobiles) plutôt que
/// Wi-Fi / Ethernet. Par défaut `true` tant que l'état est inconnu : on
/// préfère économiser les données.
final isMeteredConnectionProvider = StreamProvider<bool>((ref) async* {
  bool metered(List<ConnectivityResult> r) =>
      !(r.contains(ConnectivityResult.wifi) ||
          r.contains(ConnectivityResult.ethernet));
  final c = Connectivity();
  try {
    yield metered(await c.checkConnectivity());
  } catch (_) {
    yield true;
  }
  yield* c.onConnectivityChanged.map(metered);
});

/// `true` quand le mode hors ligne est activé dans les paramètres.
final offlineModeProvider = Provider<bool>(
  (ref) => ref.watch(playbackPreferencesProvider).offlineMode,
);
