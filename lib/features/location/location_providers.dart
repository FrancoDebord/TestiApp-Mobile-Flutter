// Réglage « Utiliser ma position pour personnaliser mes fils », zone des fils et étiquettes
// des cartes proches. La position de l'appareil n'est lue qu'avec le consentement explicite
// de la personne (réglage activé) ; le serveur l'arrondit (~1 km) et la géocode (Nominatim, en cache).
// Doc serveur : docs/fonctionnalites/localisation.md

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/app_constants.dart';
import '../../services/api_service.dart';
import '../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../events/widgets/event_location_widgets.dart'
    show EventLocationService, LocationFailure;
import '../feed/feed_inserts.dart' show feedInsertsProvider;
import '../home/providers/home_providers.dart' show feedNotifierProvider;
import 'user_location.dart';
import '../../l10n/app_localizations.dart';

/// Lecture de la position de l'appareil (remplaçable dans les tests).
typedef PositionReader =
    Future<({double latitude, double longitude})> Function();

final positionReaderProvider = Provider<PositionReader>(
  (ref) => () async {
    final p = await EventLocationService.currentPosition();
    return (latitude: p.latitude, longitude: p.longitude);
  },
);

class UserLocationNotifier extends AsyncNotifier<UserLocationSettings> {
  @override
  Future<UserLocationSettings> build() async {
    if (ref.watch(currentUserProvider) == null) {
      return const UserLocationSettings();
    }
    final res = await ref
        .read(apiServiceProvider)
        .get<dynamic>(AppConstants.myLocation);
    return UserLocationSettings.fromJson(res.data);
  }

  Future<void> _put(Map<String, dynamic> body) async {
    final res = await ref
        .read(apiServiceProvider)
        .put<dynamic>(AppConstants.myLocation, data: body);
    state = AsyncData(UserLocationSettings.fromJson(res.data));
    _refreshFeeds();
  }

  /// Active le réglage et envoie la position actuelle (demande la permission si besoin).
  /// Lève [LocationFailure] (message lisible) si la position est refusée ou introuvable.
  Future<void> enableAndLocate() async {
    final ({double latitude, double longitude}) p;
    try {
      p = await ref.read(positionReaderProvider)();
    } on LocationFailure catch (e) {
      throw LocationFailure(
        e.canOpenSettings
            ? L10n.current.locationDeniedCity
            : L10n.current.locationUnavailableCity,
        canOpenSettings: e.canOpenSettings,
      );
    }
    await _put({
      'use_gps': true,
      'latitude': p.latitude,
      'longitude': p.longitude,
    });
  }

  /// Désactive le réglage : la position est effacée tout de suite sur le serveur.
  Future<void> disable() => _put({'use_gps': false});

  /// « Ma ville » (sans GPS) ; vide pour l'enlever.
  Future<void> setHomeCity(String city) => _put({'home_city': city.trim()});

  /// « Supprimer ma position » : effacement immédiat (position, ville saisie, copies GPS).
  Future<void> erase() async {
    final res = await ref
        .read(apiServiceProvider)
        .delete<dynamic>(AppConstants.myLocation);
    state = AsyncData(UserLocationSettings.fromJson(res.data));
    _refreshFeeds();
  }

  /// Position consentie mais ancienne : rafraîchie en silence, sans jamais demander la permission.
  Future<void> refreshIfStale() async {
    final s =
        state.value ??
        await future.catchError((_) => const UserLocationSettings());
    if (!s.isStale(DateTime.now())) return;
    try {
      if (!kIsWeb) {
        final permission = await Geolocator.checkPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          return;
        }
      }
      final p = await ref.read(positionReaderProvider)();
      await _put({
        'use_gps': true,
        'latitude': p.latitude,
        'longitude': p.longitude,
      });
    } catch (_) {
      // Silencieux : la zone précédente reste utilisée.
    }
  }

  void _refreshFeeds() {
    ref.invalidate(feedNotifierProvider);
    ref.invalidate(feedInsertsProvider);
    ref.read(nearbyLabelsProvider.notifier).clear();
    ref.invalidate(locationChangeProvider);
  }
}

final userLocationProvider =
    AsyncNotifierProvider<UserLocationNotifier, UserLocationSettings>(
      UserLocationNotifier.new,
    );

/// Signal « la zone a changé » : écouté par les fils à recharger (Mon fil).
final locationChangeProvider = Provider<Object>((ref) => Object());

// ── Zone et étiquettes renvoyées par les fils ──────────────────────────────

class _FeedPlaceNotifier extends Notifier<FeedPlace?> {
  @override
  FeedPlace? build() => null;
  void set(FeedPlace? place) {
    if (state != place) state = place;
  }
}

/// Zone du fil « Pour vous » (meta.place) : « Près de chez vous · Cotonou ».
final homeFeedPlaceProvider = NotifierProvider<_FeedPlaceNotifier, FeedPlace?>(
  _FeedPlaceNotifier.new,
);

class NearbyLabelsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void merge(Map<String, String> labels) {
    if (labels.isEmpty) return;
    state = {...state, ...labels};
  }

  void clear() => state = const {};
}

/// Étiquettes discrètes des cartes proches (« À Cotonou », « Au Bénin »), réunies depuis les fils.
final nearbyLabelsProvider =
    NotifierProvider<NearbyLabelsNotifier, Map<String, String>>(
      NearbyLabelsNotifier.new,
    );

// ── Invitation « Activez votre position » (une fois, refermable) ───────────

class LocationPromptNotifier extends Notifier<bool> {
  static const storageKey = 'location_prompt_dismissed';

  @override
  bool build() {
    _load();
    return true; // masquée tant que la préférence n'est pas lue
  }

  Future<void> _load() async {
    try {
      final v = await ref.read(secureStorageProvider).read(key: storageKey);
      state = v == '1';
    } catch (_) {
      state = false;
    }
  }

  Future<void> dismiss() async {
    state = true;
    try {
      await ref.read(secureStorageProvider).write(key: storageKey, value: '1');
    } catch (_) {}
  }
}

/// `true` quand l'invitation a été refermée (ou pas encore lue).
final locationPromptDismissedProvider =
    NotifierProvider<LocationPromptNotifier, bool>(LocationPromptNotifier.new);
