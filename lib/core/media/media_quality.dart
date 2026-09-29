// lib/core/media/media_quality.dart
//
// Choix de la version (qualité) d'un média à lire, selon :
//   • la préférence de l'utilisateur (Auto / 720p / 64 kbps…)
//   • le type de connexion (Wi-Fi ou données mobiles)
//   • l'économiseur de données
//
// Si le serveur ne fournit pas de versions, on lit le fichier original.

import '../../features/home/models/testimony_model.dart';
import 'playback_preferences.dart';

/// Résultat du choix : URL à lire + libellé de la version choisie.
class ResolvedMedia {
  const ResolvedMedia({
    required this.url,
    required this.label,
    this.rendition,
  });

  final String url;

  /// « 360p », « 64 kbps » ou « Originale ».
  final String label;

  /// `null` quand on lit le fichier original.
  final MediaRendition? rendition;
}

// ── Plafonds du mode Auto ────────────────────────────────────────────────────

int autoVideoHeight({required bool metered, required bool dataSaver}) {
  if (!metered) return dataSaver ? 480 : 720;
  return dataSaver ? 144 : 360;
}

int autoAudioKbps({required bool metered, required bool dataSaver}) {
  if (!metered) return dataSaver ? 64 : 320;
  return dataSaver ? 32 : 64;
}

/// Version la plus haute ≤ [cap] ; sinon la plus basse disponible.
MediaRendition? _bestUnder(List<MediaRendition> sorted, int cap) {
  if (sorted.isEmpty) return null;
  if (cap <= 0) return sorted.last;
  MediaRendition? best;
  for (final r in sorted) {
    if (r.rank <= cap) best = r;
  }
  return best ?? sorted.first;
}

ResolvedMedia? _resolve({
  required String? original,
  required List<MediaRendition> renditions,
  required int cap,
}) {
  final r = _bestUnder(renditions, cap);
  if (r != null) return ResolvedMedia(url: r.url, label: r.label, rendition: r);
  if (original == null || original.isEmpty) return null;
  return ResolvedMedia(url: original, label: 'Originale');
}

// ── Vidéo ────────────────────────────────────────────────────────────────────

/// Choisit la version vidéo à lire. [override] = choix manuel ponctuel
/// (menu « Qualité » du lecteur), prioritaire sur la préférence.
ResolvedMedia? resolveVideo({
  required String? original,
  required List<MediaRendition> renditions,
  required PlaybackPreferences prefs,
  required bool metered,
  VideoQuality? override,
}) {
  final q = override ?? prefs.videoQuality;
  final cap = q == VideoQuality.auto
      ? autoVideoHeight(metered: metered, dataSaver: prefs.dataSaver)
      : q.height;
  return _resolve(original: original, renditions: renditions, cap: cap);
}

ResolvedMedia? resolveVideoTestimony(
  VideoTestimony t, {
  required PlaybackPreferences prefs,
  required bool metered,
  VideoQuality? override,
}) =>
    resolveVideo(
      original: t.mediaPath,
      renditions: t.renditions,
      prefs: prefs,
      metered: metered,
      override: override,
    );

/// Qualités proposables dans le menu du lecteur pour ces versions :
/// Auto + chaque hauteur réellement disponible (ordre décroissant).
List<VideoQuality> availableVideoQualities(List<MediaRendition> renditions) {
  final heights = renditions.map((r) => r.height).toSet();
  return [
    VideoQuality.auto,
    ...VideoQuality.values
        .where((q) => q != VideoQuality.auto && heights.contains(q.height)),
  ];
}

// ── Audio ────────────────────────────────────────────────────────────────────

ResolvedMedia? resolveAudio({
  required String? original,
  required List<MediaRendition> renditions,
  required PlaybackPreferences prefs,
  required bool metered,
  AudioQuality? override,
}) {
  final q = override ?? prefs.audioQuality;
  final cap = q == AudioQuality.auto
      ? autoAudioKbps(metered: metered, dataSaver: prefs.dataSaver)
      : q.maxKbps;
  return _resolve(original: original, renditions: renditions, cap: cap);
}

ResolvedMedia? resolveAudioTestimony(
  AudioTestimony t, {
  required PlaybackPreferences prefs,
  required bool metered,
  AudioQuality? override,
}) =>
    resolveAudio(
      original: t.mediaPath,
      renditions: t.renditions,
      prefs: prefs,
      metered: metered,
      override: override,
    );
