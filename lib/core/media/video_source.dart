// lib/core/media/video_source.dart
//
// Vidéos Bunny Stream : état de traitement et sources de lecture.
//
// L'objet « video » d'un témoignage (GET /testimonies/{id}) :
//   { status: processing | ready | failed, playback_url (HLS .m3u8),
//     mp4_url (MP4 de secours, peut être null), thumbnail_url, duration }
// Aucune URL tant que la vidéo n'est pas prête. Les anciens champs (hls_url,
// mp4_urls, mediaUrl) restent présents pour les versions déjà publiées.
//
// Lecture : la source choisie (HLS en Auto, sinon la qualité MP4 demandée),
// puis, si le lecteur ne s'initialise pas, le MP4 de secours, puis l'ancien
// mediaUrl (vidéos /storage/media/…mp4).

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:video_player/video_player.dart';

import '../app_constants.dart';
import '../../l10n/app_localizations.dart';

/// État de traitement d'une vidéo (`video.status`).
enum VideoProcessingState {
  /// Envoi terminé ou en cours, encodage chez Bunny : pas encore lisible.
  processing,

  /// Lisible (ancienne vidéo ou lien YouTube compris).
  ready,

  /// Encodage en échec (ou envoi abandonné).
  failed;

  /// `uploading` et `processing` → [processing] ; `failed`/`error` →
  /// [failed] ; tout le reste (`ready`, absent, inconnu) → [ready].
  static VideoProcessingState parse(Object? raw) =>
      switch (raw?.toString().trim().toLowerCase()) {
        'uploading' || 'processing' || 'queued' || 'encoding' => processing,
        'failed' || 'error' => failed,
        _ => ready,
      };
}

/// Libellés affichés (fil, détail, « Mes témoignages », modération).
abstract final class VideoStatusText {
  static String get processing => L10n.current.mediaVideoProcessing;
  static String get failed => L10n.current.mediaVideoFailed;
  static String get resend => L10n.current.mediaVideoResend;
}

bool _isUsable(String? url) => url != null && url.trim().isNotEmpty;

/// `true` pour une playlist HLS (`….m3u8`, paramètres éventuels compris).
bool isHlsUrl(String? url) =>
    url != null &&
    RegExp(r'\.m3u8($|[?#])', caseSensitive: false).hasMatch(url);

/// `true` pour le CDN de Bunny Stream (`vz-….b-cdn.net`, `….b-cdn.net`).
bool isBunnyCdnUrl(String? url) {
  final host = url == null ? null : Uri.tryParse(url)?.host;
  return host != null && host.endsWith('.b-cdn.net');
}

/// En-têtes des requêtes vers les médias Bunny Stream.
///
/// La zone Bunny refuse toute requête **sans** en-tête `Referer` (403 sur la
/// playlist, les variantes, les segments .ts, les MP4 et les miniatures) : les
/// navigateurs l'envoient, pas video_player, cached_network_image ni Dio. On
/// envoie donc la racine du site. Sur le web, le navigateur s'en charge (et
/// interdit de le fixer). Vide pour les autres hôtes.
Map<String, String> mediaHttpHeaders(String? url) {
  if (kIsWeb || !isBunnyCdnUrl(url)) return const {};
  return {'Referer': '${AppConstants.webBaseUrl}/'}; // i18n-ignore
}

/// Lecteur réseau ; une playlist `.m3u8` est signalée comme HLS (Android :
/// ExoPlayer/Media3 avec media3-exoplayer-hls ; iOS : AVPlayer, natif).
/// Les en-têtes ([mediaHttpHeaders]) s'appliquent aussi aux variantes et
/// segments : ExoPlayer les met sur toutes les requêtes de la source, AVPlayer
/// (AVURLAssetHTTPHeaderFieldsKey) sur celles de l'asset.
VideoPlayerController networkVideoController(String url) =>
    VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: isHlsUrl(url) ? VideoFormat.hls : null,
      httpHeaders: mediaHttpHeaders(url),
    );

/// Sources à essayer, dans l'ordre et sans doublon : [primary] (version
/// choisie selon la qualité / le réseau, ou fichier téléchargé), puis le flux
/// HLS [playbackUrl], le MP4 de secours [mp4Url] et l'ancien [legacyUrl].
List<String> videoPlaybackChain({
  String? primary,
  String? playbackUrl,
  String? mp4Url,
  String? legacyUrl,
}) {
  final out = <String>[];
  for (final u in [primary, playbackUrl, mp4Url, legacyUrl]) {
    if (_isUsable(u) && !out.contains(u)) out.add(u!);
  }
  return out;
}

/// Lecteur initialisé et source effectivement lue.
typedef PlayableVideo = ({VideoPlayerController controller, String url});

/// Initialise le premier lecteur qui fonctionne parmi [sources] (voir
/// [videoPlaybackChain]) ; chaque échec libère son lecteur avant d'essayer la
/// source suivante. `null` si aucune ne se lit.
Future<PlayableVideo?> initializeFirstPlayable(
  List<String> sources,
  VideoPlayerController Function(String url) create,
) async {
  for (final url in sources) {
    VideoPlayerController? ctrl;
    try {
      ctrl = create(url);
      await ctrl.initialize();
      return (controller: ctrl, url: url);
    } catch (e) {
      debugPrint('Vidéo ✗ $url : $e');
      try {
        await ctrl?.dispose();
      } catch (_) {}
    }
  }
  return null;
}
