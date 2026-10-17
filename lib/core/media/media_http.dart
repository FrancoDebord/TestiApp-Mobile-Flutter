// lib/core/media/media_http.dart
//
// Chargement des médias (photos de profil et de couverture, images des
// témoignages et des événements, miniatures…) :
//
// - anciennes adresses : des fichiers enregistrés avant le changement de
//   domaine pointent encore vers `testi.airid-africa.com`, qui n'existe plus ;
//   on les redirige vers le domaine actuel du serveur (mêmes chemins /storage/…) ;
// - Bunny Stream : la zone refuse toute requête sans en-tête `Referer` (403),
//   que les navigateurs envoient mais pas Image.network / cached_network_image.
//
// [MediaHttpOverrides] (installé dans main.dart) applique les deux règles à
// toutes les requêtes dart:io de l'application ; [fixMediaUrl] sert aux
// lecteurs natifs (vidéo, audio) qui n'utilisent pas dart:io.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../app_constants.dart';
import 'video_source.dart' show isBunnyCdnUrl;

/// Anciens domaines du serveur (fichiers enregistrés avant le changement de domaine).
const Set<String> legacyMediaHosts = {'testi.airid-africa.com'}; // i18n-ignore

/// Adresse corrigée : ancien domaine → domaine actuel ; inchangée sinon.
String fixMediaUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !legacyMediaHosts.contains(uri.host)) return url;
  return fixMediaUri(uri).toString();
}

Uri fixMediaUri(Uri uri) {
  if (!legacyMediaHosts.contains(uri.host)) return uri;
  final current = Uri.parse(AppConstants.webBaseUrl);
  return uri.replace(scheme: current.scheme, host: current.host, port: current.hasPort ? current.port : null);
}

/// Toutes les requêtes HTTP de l'application passent par [_MediaHttpClient].
class MediaHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _MediaHttpClient(super.createHttpClient(context));

  /// À appeler au démarrage (sans effet sur le web).
  static void install() {
    if (!kIsWeb) HttpOverrides.global = MediaHttpOverrides();
  }
}

class _MediaHttpClient implements HttpClient {
  _MediaHttpClient(this._inner);
  final HttpClient _inner;

  static final _referer = '${AppConstants.webBaseUrl}/'; // i18n-ignore

  Future<HttpClientRequest> _prepare(Future<HttpClientRequest> request, Uri url) async {
    final r = await request;
    if (isBunnyCdnUrl(url.toString()) && r.headers.value(HttpHeaders.refererHeader) == null) {
      r.headers.set(HttpHeaders.refererHeader, _referer);
    }
    return r;
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    final fixed = fixMediaUri(url);
    return _prepare(_inner.openUrl(method, fixed), fixed);
  }

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) =>
      openUrl(method, Uri(scheme: 'http', host: host, port: port).resolve(path)); // i18n-ignore

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url); // i18n-ignore
  @override
  Future<HttpClientRequest> get(String host, int port, String path) => open('GET', host, port, path); // i18n-ignore
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url); // i18n-ignore
  @override
  Future<HttpClientRequest> post(String host, int port, String path) => open('POST', host, port, path); // i18n-ignore
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url); // i18n-ignore
  @override
  Future<HttpClientRequest> put(String host, int port, String path) => open('PUT', host, port, path); // i18n-ignore
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url); // i18n-ignore
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => open('DELETE', host, port, path); // i18n-ignore
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url); // i18n-ignore
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => open('PATCH', host, port, path); // i18n-ignore
  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url); // i18n-ignore
  @override
  Future<HttpClientRequest> head(String host, int port, String path) => open('HEAD', host, port, path); // i18n-ignore

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool v) => _inner.autoUncompress = v;
  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? v) => _inner.connectionTimeout = v;
  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration v) => _inner.idleTimeout = v;
  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? v) => _inner.maxConnectionsPerHost = v;
  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? v) => _inner.userAgent = v;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) =>
      _inner.addCredentials(url, realm, credentials);
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) =>
      _inner.addProxyCredentials(host, port, realm, credentials);
  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _inner.authenticate = f;
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) =>
      _inner.authenticateProxy = f;
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) =>
      _inner.badCertificateCallback = callback;
  @override
  set connectionFactory(
          Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) =>
      _inner.connectionFactory = f;
  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;
  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;
}
