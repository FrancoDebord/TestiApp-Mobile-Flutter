// lib/core/media/media_quality.dart
//
// Choix de la version (qualité) d'un média à lire, selon :
//   • la préférence de l'utilisateur (Auto / 720p / 64 kbps…)
//   • le type de connexion (Wi-Fi ou données mobiles)
//   • l'économiseur de données
//
// Si le serveur ne fournit pas de versions, on lit le fichier original.
//
// Téléchargements (« Mes téléchargements ») : si le témoignage a été
// téléchargé, on lit le fichier local (libellé « Hors ligne »). En mode hors
// ligne (préférence), on ne lit QUE les fichiers locaux.

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../features/home/models/testimony_model.dart';
import 'playback_preferences.dart';

/// Résultat du choix : URL à lire + libellé de la version choisie.
class ResolvedMedia {
  const ResolvedMedia({
    required this.url,
    required this.label,
    this.rendition,
  });

  /// URL réseau, ou chemin de fichier local (label « Hors ligne »).
  final String url;

  /// « 360p », « 64 kbps », « Originale » ou « Hors ligne ».
  final String label;

  /// `null` quand on lit le fichier original ou un fichier local.
  final MediaRendition? rendition;

  /// `true` quand [url] est un fichier téléchargé sur l'appareil.
  bool get isLocal => label == OfflineMedia.label;
}

// ── Fichiers téléchargés ─────────────────────────────────────────────────────

/// Recherche d'un fichier téléchargé par identifiant de témoignage ou par
/// adresse d'origine (fichier original ou version). Renvoie un chemin local.
typedef LocalMediaLookup = String? Function({String? id, String? url});

/// Registre global des médias téléchargés, renseigné par la fonctionnalité
/// « Mes téléchargements » (DownloadsNotifier) dès que son index est chargé.
abstract final class OfflineMedia {
  static LocalMediaLookup? lookup;

  /// Libellé de la version lue quand le fichier est local.
  static const String label = 'Hors ligne';

  /// `true` pour un chemin de fichier local absolu (pas une URL réseau).
  static bool isLocalPath(String? source) {
    if (kIsWeb || source == null || source.isEmpty) return false;
    return source.startsWith('/') ||
        source.startsWith('file://') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(source);
  }

  /// Fichier local à lire pour ce média, ou `null`.
  static String? find({
    String? id,
    String? original,
    List<MediaRendition> renditions = const [],
  }) {
    if (kIsWeb) return null;
    if (isLocalPath(original)) return original;
    final f = lookup;
    if (f == null) return null;
    if (id != null && id.isNotEmpty) {
      final byId = f(id: id);
      if (byId != null) return byId;
    }
    for (final u in [original, ...renditions.map((r) => r.url)]) {
      if (u == null || u.isEmpty) continue;
      final byUrl = f(url: u);
      if (byUrl != null) return byUrl;
    }
    return null;
  }
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
  required bool offlineOnly,
  String? testimonyId,
}) {
  // 1. Fichier téléchargé : prioritaire (aucune donnée consommée).
  final local = OfflineMedia.find(
    id: testimonyId,
    original: original,
    renditions: renditions,
  );
  if (local != null) {
    return ResolvedMedia(url: local, label: OfflineMedia.label);
  }
  // 2. Mode hors ligne : pas de lecture en streaming.
  if (offlineOnly) return null;
  final r = _bestUnder(renditions, cap);
  if (r != null) return ResolvedMedia(url: r.url, label: r.label, rendition: r);
  if (original == null || original.isEmpty) return null;
  return ResolvedMedia(url: original, label: 'Originale');
}

// ── Vidéo ────────────────────────────────────────────────────────────────────

/// Choisit la version vidéo à lire. [override] = choix manuel ponctuel
/// (menu « Qualité » du lecteur), prioritaire sur la préférence.
/// [testimonyId] permet de retrouver un fichier téléchargé (à défaut, la
/// recherche se fait par adresse d'origine).
ResolvedMedia? resolveVideo({
  required String? original,
  required List<MediaRendition> renditions,
  required PlaybackPreferences prefs,
  required bool metered,
  VideoQuality? override,
  String? testimonyId,
}) {
  final q = override ?? prefs.videoQuality;
  final cap = q == VideoQuality.auto
      ? autoVideoHeight(metered: metered, dataSaver: prefs.dataSaver)
      : q.height;
  return _resolve(
    original: original,
    renditions: renditions,
    cap: cap,
    offlineOnly: prefs.offlineMode,
    testimonyId: testimonyId,
  );
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
      testimonyId: t.id,
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
  String? testimonyId,
}) {
  final q = override ?? prefs.audioQuality;
  final cap = q == AudioQuality.auto
      ? autoAudioKbps(metered: metered, dataSaver: prefs.dataSaver)
      : q.maxKbps;
  return _resolve(
    original: original,
    renditions: renditions,
    cap: cap,
    offlineOnly: prefs.offlineMode,
    testimonyId: testimonyId,
  );
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
      testimonyId: t.id,
    );
