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
import '../../l10n/app_localizations.dart';

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
  static String get label => L10n.current.mediaOffline;

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
  return ResolvedMedia(url: original, label: L10n.current.mediaOriginal);
}

// ── Vidéo ────────────────────────────────────────────────────────────────────

/// Libellé de la version lue quand c'est le flux HLS adaptatif (mode Auto).
String get kAdaptiveLabel => L10n.current.qualityAuto;

/// Choisit la version vidéo à lire. [override] = choix manuel ponctuel
/// (menu « Qualité » du lecteur), prioritaire sur la préférence du réseau en
/// cours (Paramètres › Qualité vidéo).
///
/// Vidéos Bunny Stream ([hlsUrl] renseigné) :
///   • Auto → flux HLS (qualité adaptative) ;
///   • qualité forcée → version MP4 de cette hauteur (`mp4_urls`), sinon la plus
///     haute en dessous, sinon le flux HLS.
/// Anciennes vidéos (fichier original + versions) : Auto plafonne la hauteur
/// selon le réseau (autoVideoHeight).
/// [testimonyId] permet de retrouver un fichier téléchargé (à défaut, la
/// recherche se fait par adresse d'origine).
ResolvedMedia? resolveVideo({
  required String? original,
  required List<MediaRendition> renditions,
  required PlaybackPreferences prefs,
  required bool metered,
  String? hlsUrl,
  VideoQuality? override,
  String? testimonyId,
}) {
  final q = override ?? prefs.videoQualityFor(metered: metered);
  final hls = (hlsUrl == null || hlsUrl.isEmpty) ? null : hlsUrl;

  if (hls != null) {
    final local = OfflineMedia.find(
      id: testimonyId,
      original: original,
      renditions: renditions,
    );
    if (local != null) {
      return ResolvedMedia(url: local, label: OfflineMedia.label);
    }
    if (prefs.offlineMode) return null;
    if (q != VideoQuality.auto) {
      final exact = renditions.where((r) => r.height == q.height).firstOrNull;
      final r = exact ??
          renditions.lastWhereOrNull((r) => r.height > 0 && r.height <= q.height);
      if (r != null) return ResolvedMedia(url: r.url, label: r.label, rendition: r);
    }
    return ResolvedMedia(url: hls, label: kAdaptiveLabel);
  }

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
      hlsUrl: t.hlsUrl,
      prefs: prefs,
      metered: metered,
      override: override,
      testimonyId: t.id,
    );

/// Qualités proposables dans le menu du lecteur : Auto + chaque qualité dont
/// la version MP4 existe réellement (les absentes sont masquées).
List<VideoQuality> availableVideoQualities(List<MediaRendition> renditions) {
  final heights = renditions.map((r) => r.height).toSet();
  return [
    VideoQuality.auto,
    ...VideoQuality.values
        .where((q) => q != VideoQuality.auto && heights.contains(q.height)),
  ];
}

extension<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    return null;
  }
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
