// lib/services/acting_as_interceptor.dart
//
// Administrateurs de compte : agir au nom d'un autre compte.
//
// Quand la personne agit pour un compte qu'elle administre, chaque requête
// authentifiée porte l'en-tête `X-Act-As: <id du compte>` ; le serveur la traite
// comme si ce compte était connecté (réponse avec l'en-tête `X-Acting-As`).
//
// Les chemins réservés au titulaire (identifiants, appareils, administration,
// carnet privé…) ne portent jamais l'en-tête : ces écrans restent sur le compte
// réel de la personne (le serveur les refuserait avec `403 owner_only`).
//
// Refus `403` avec `code: "acting_as_forbidden"` (« Vous n'administrez plus ce
// compte. ») : [ActingAsStore.onForbidden] ramène l'application sur le compte
// de la personne.

import 'package:dio/dio.dart';
import '../l10n/app_localizations.dart';

/// En-tête envoyé au serveur.
const kActingAsHeader = 'X-Act-As';

/// Codes d'erreur du serveur (`code` du corps JSON).
const kActingAsForbiddenCode = 'acting_as_forbidden';
const kOwnerOnlyCode = 'owner_only';

/// Clé de `RequestOptions.extra` : compte à utiliser pour cette requête (chaîne,
/// ou null pour son propre compte) au lieu du compte actif. Sert à la file hors
/// ligne, qui rejoue chaque écriture avec le compte choisi au moment de l'action.
const kActingAsOverride = 'actAs';

/// Compte actif partagé entre l'intercepteur (sans Riverpod) et le provider
/// du compte actif (lib/features/accounts/providers/acting_account_provider.dart).
class ActingAsStore {
  ActingAsStore();

  /// Compte pour lequel la personne agit (`null` : son propre compte).
  String? accountId;

  /// Compte mémorisé lu au démarrage (avant que la session soit connue) :
  /// JSON brut, interprété par le provider du compte actif.
  Map<String, dynamic>? snapshot;

  /// Appelé quand le serveur refuse d'agir pour [accountId] (message du serveur).
  void Function(String message)? onForbidden;
}

/// Chemin d'API sans le préfixe `/api/v1` (ex. `/users/me/managers`).
String normalizeApiPath(String path) {
  var p = path;
  if (p.startsWith('http://') || p.startsWith('https://')) {
    p = Uri.parse(p).path;
  }
  final i = p.indexOf('/api/v');
  if (i >= 0) {
    final rest = p.substring(i + 6);
    final slash = rest.indexOf('/');
    p = slash >= 0 ? rest.substring(slash) : '/';
  }
  if (!p.startsWith('/')) p = '/$p';
  return p;
}

/// Sections entières (`auth/*`, `devices/*`…) : le chemin ou ses sous-chemins.
const _ownerOnlySections = ['/auth', '/devices', '/admin', '/moderation'];

/// Préfixes libres (`users/me/managers*`, `journal*`…).
const _ownerOnlyPrefixes = [
  '/users/me/managers',
  '/users/me/managed-organizations',
  '/users/me/verification',
  '/users/me/location',
  '/users/me/settings',
  '/journal',
  '/prophecies',
];

/// Requête réservée au titulaire du compte : jamais d'en-tête `X-Act-As`.
bool isOwnerOnlyRequest(String method, String path) {
  var p = normalizeApiPath(path);
  final q = p.indexOf('?');
  if (q >= 0) p = p.substring(0, q);
  if (method.toUpperCase() == 'DELETE' && (p == '/users/me' || p == '/users/me/')) {
    return true;
  }
  if (_ownerOnlySections.any((s) => p == s || p.startsWith('$s/'))) return true;
  return _ownerOnlyPrefixes.any(p.startsWith);
}

class ActingAsInterceptor extends Interceptor {
  ActingAsInterceptor(this._store);
  final ActingAsStore _store;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id = options.extra.containsKey(kActingAsOverride)
        ? options.extra[kActingAsOverride] as String?
        : _store.accountId;
    if (id != null && id.isNotEmpty && !isOwnerOnlyRequest(options.method, options.path)) {
      options.headers[kActingAsHeader] = id;
    } else {
      options.headers.remove(kActingAsHeader);
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final res = err.response;
    if (res?.statusCode == 403) {
      final body = res?.data;
      final code = body is Map ? body['code'] : null;
      final sent = err.requestOptions.headers[kActingAsHeader];
      if (code == kActingAsForbiddenCode && sent != null && sent == _store.accountId) {
        final message = body is Map && body['message'] is String
            ? body['message'] as String
            : L10n.current.apiActingAsRevoked;
        _store.onForbidden?.call(message);
      }
    }
    handler.next(err);
  }
}
