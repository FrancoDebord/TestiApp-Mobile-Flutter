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
import '../../l10n/app_localizations.dart';

// ── Enums ────────────────────────────────────────────────────────────────────

/// Qualité vidéo. [height] = hauteur de la version MP4 forcée (0 = Auto).
///
/// Auto lit le flux HLS adaptatif (Bunny Stream) ; les autres choix lisent la
/// version MP4 correspondante (`mp4_urls`), video_player ne permettant pas de
/// choisir une variante HLS.
enum VideoQuality {
  auto(0),
  p720(720),
  p360(360),
  p240(240);

  const VideoQuality(this.height);
  final int height;

  /// Libellé court (bouton du lecteur).
  String get label => switch (this) {
        auto => L10n.current.qualityAuto,
        p720 => L10n.current.qualityVideoHd,
        p360 => L10n.current.qualityVideoStandard,
        p240 => L10n.current.qualityVideoDataSaver,
      };

  /// Libellé complet (menus) : « Économie (240p) ».
  String get fullLabel => this == auto ? L10n.current.qualityAuto : L10n.current.qualityVideoFullLabel(label, height);

  String get hint => switch (this) {
        auto => L10n.current.qualityAutoHint,
        p720 => L10n.current.qualityVideoHdHint,
        p360 => L10n.current.qualityVideoStandardHint,
        p240 => L10n.current.qualityVideoDataSaverHint,
      };

  /// Choix proposés sur données mobiles (jamais Auto ni HD).
  static const mobileChoices = [p360, p240];

  /// Choix proposés en Wi-Fi.
  static const wifiChoices = [auto, p720, p360, p240];
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
        auto => L10n.current.qualityAuto,
        high => L10n.current.qualityAudioHigh,
        standard => L10n.current.qualityAudioStandard,
        low => L10n.current.qualityAudioLow,
        veryLow => L10n.current.qualityAudioVeryLow,
      };

  String get hint => switch (this) {
        auto => L10n.current.qualityAutoHint,
        high => L10n.current.qualityAudioHighHint,
        standard => L10n.current.qualityAudioStandardHint,
        low => L10n.current.qualityAudioLowHint,
        veryLow => L10n.current.qualityAudioVeryLowHint,
      };
}

/// Répétition : aucune, le média en cours, ou toute la liste.
enum RepeatMode {
  off,
  one,
  all;

  String get label => switch (this) {
        off => L10n.current.mediaRepeatOff,
        one => L10n.current.mediaRepeatOne,
        all => L10n.current.mediaRepeatAll,
      };

  RepeatMode get next => RepeatMode.values[(index + 1) % 3];
}

/// Affichage du fil de témoignages.
enum FeedLayout {
  cards,
  compact;

  String get label => this == cards ? L10n.current.mediaFeedLayoutCards : L10n.current.mediaFeedLayoutCompact;
}

// ── State ────────────────────────────────────────────────────────────────────

class PlaybackPreferences {
  const PlaybackPreferences({
    this.videoQualityMobile = VideoQuality.p360,
    this.videoQualityWifi = VideoQuality.auto,
    this.audioQuality = AudioQuality.auto,
    this.dataSaver = false,
    this.autoplayNext = true,
    this.repeatMode = RepeatMode.off,
    this.feedLayout = FeedLayout.cards,
    this.offlineMode = false,
  });

  /// Qualité vidéo sur données mobiles : Standard (360p) ou Économie (240p).
  final VideoQuality videoQualityMobile;

  /// Qualité vidéo en Wi-Fi (Auto par défaut).
  final VideoQuality videoQualityWifi;

  /// Qualité vidéo par défaut pour le réseau en cours.
  VideoQuality videoQualityFor({required bool metered}) =>
      metered ? videoQualityMobile : videoQualityWifi;

  final AudioQuality audioQuality;

  /// Économiseur de données : force la plus basse qualité audio (et vidéo des
  /// anciens témoignages sans flux adaptatif) sur données mobiles.
  final bool dataSaver;

  /// Enchaîne automatiquement le témoignage suivant à la fin de la lecture.
  final bool autoplayNext;

  final RepeatMode repeatMode;
  final FeedLayout feedLayout;

  /// Mode hors ligne : lire uniquement les témoignages téléchargés, sans
  /// consommer de données (Paramètres › Mode hors ligne).
  final bool offlineMode;

  PlaybackPreferences copyWith({
    VideoQuality? videoQualityMobile,
    VideoQuality? videoQualityWifi,
    AudioQuality? audioQuality,
    bool? dataSaver,
    bool? autoplayNext,
    RepeatMode? repeatMode,
    FeedLayout? feedLayout,
    bool? offlineMode,
  }) =>
      PlaybackPreferences(
        videoQualityMobile: videoQualityMobile ?? this.videoQualityMobile,
        videoQualityWifi: videoQualityWifi ?? this.videoQualityWifi,
        audioQuality: audioQuality ?? this.audioQuality,
        dataSaver: dataSaver ?? this.dataSaver,
        autoplayNext: autoplayNext ?? this.autoplayNext,
        repeatMode: repeatMode ?? this.repeatMode,
        feedLayout: feedLayout ?? this.feedLayout,
        offlineMode: offlineMode ?? this.offlineMode,
      );

  Map<String, dynamic> toJson() => {
        'video_quality_mobile': videoQualityMobile.name,
        'video_quality_wifi': videoQualityWifi.name,
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
      // L'ancienne clé « video_quality » (une seule qualité) est ignorée.
      videoQualityMobile: pick(VideoQuality.mobileChoices,
          j['video_quality_mobile'], VideoQuality.p360),
      videoQualityWifi: pick(VideoQuality.wifiChoices,
          j['video_quality_wifi'], VideoQuality.auto),
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

  void setVideoQualityMobile(VideoQuality q) {
    if (VideoQuality.mobileChoices.contains(q)) {
      _update(state.copyWith(videoQualityMobile: q));
    }
  }

  void setVideoQualityWifi(VideoQuality q) =>
      _update(state.copyWith(videoQualityWifi: q));
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
