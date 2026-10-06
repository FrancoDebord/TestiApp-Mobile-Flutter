// Lieu d'un événement : repère GPS sur une carte OpenStreetMap (formulaire),
// bloc « Lieu » avec mini-carte, « Itinéraire » et « Copier l'adresse » (page détail).
// Doc backend : docs/fonctionnalites/evenements.md

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/event_models.dart';

/// Identifiant de l'application, exigé par la politique des tuiles OpenStreetMap
/// (https://operations.osmfoundation.org/policies/tiles/).
const String osmUserAgentPackage = 'com.airid.testi_app';

/// Tests : désactive le chargement des tuiles (pas de réseau).
@visibleForTesting
bool debugDisableEventMapTiles = false;

/// Vue large par défaut (Afrique de l'Ouest) quand aucun repère n'est placé.
const LatLng _defaultCenter = LatLng(8.5, 2.3);

Widget _osmTiles() {
  if (debugDisableEventMapTiles) return const SizedBox.shrink();
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: osmUserAgentPackage,
    maxZoom: 19,
  );
}

/// Attribution OpenStreetMap, obligatoire sur toute carte.
Widget _osmAttribution() => SimpleAttributionWidget(
      source: const Text('© contributeurs OpenStreetMap', style: TextStyle(fontSize: 10)),
      onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'),
          mode: LaunchMode.externalApplication),
    );

Marker _pin(LatLng point) => Marker(
      point: point,
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: const Icon(Icons.location_on_rounded, size: 44, color: AppColors.secondaryDark,
          semanticLabel: "Lieu de l'événement"),
    );

String formatCoordinates(double lat, double lng) =>
    '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

// ── Position et géocodage ───────────────────────────────────────────────────

/// Échec de la localisation, avec un message lisible.
class LocationFailure implements Exception {
  const LocationFailure(this.message, {this.canOpenSettings = false});

  final String message;

  /// Refus définitif : proposer d'ouvrir les réglages de l'application.
  final bool canOpenSettings;

  @override
  String toString() => message;
}

abstract final class EventLocationService {
  /// Position actuelle de l'appareil (demande la permission si besoin).
  static Future<LatLng> currentPosition() async {
    if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
          'La localisation est désactivée. Activez-la dans les réglages du téléphone, '
          'ou touchez la carte pour placer le repère.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
          'Accès à la position refusé. Touchez la carte pour placer le repère.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationFailure(
          kIsWeb
              ? 'Accès à la position bloqué : autorisez la localisation pour ce site dans '
                  'les réglages du navigateur, ou touchez la carte.'
              : "Accès à la position refusé. Autorisez-le dans les réglages de l'application, "
                  'ou touchez la carte pour placer le repère.',
          canOpenSettings: !kIsWeb);
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      throw const LocationFailure(
          'Position introuvable pour le moment. Touchez la carte pour placer le repère.');
    }
  }

  static final Dio _nominatim = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    // Politique Nominatim : application identifiée (le navigateur envoie son propre en-tête sur le web).
    headers: kIsWeb ? null : {'User-Agent': 'TestiApp/1.0 ($osmUserAgentPackage)'},
  ));

  /// Géocodage d'une adresse (Nominatim / OpenStreetMap) : à n'appeler que sur une action
  /// explicite (bouton), jamais à chaque frappe. Null si l'adresse est introuvable.
  static Future<LatLng?> geocode(String query) async {
    final res = await _nominatim.get<List<dynamic>>('/search', queryParameters: {
      'q': query,
      'format': 'jsonv2',
      'limit': 1,
      'accept-language': 'fr',
    });
    final found = res.data ?? const [];
    if (found.isEmpty || found.first is! Map) return null;
    final m = found.first as Map;
    final lat = double.tryParse('${m['lat']}');
    final lng = double.tryParse('${m['lon']}');
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }
}

// ── Itinéraire ──────────────────────────────────────────────────────────────

abstract final class EventDirections {
  /// Liens d'itinéraire à essayer dans l'ordre, selon la plateforme :
  /// Android → application de navigation (`geo:`), iOS → Plans, puis Google Maps (web).
  static List<Uri> candidates(
    ChristianEvent e, {
    required TargetPlatform platform,
    bool isWeb = false,
  }) {
    final web = googleMapsUrl(e);
    if (web == null) return const [];
    final out = <Uri>[];
    final label = e.location ?? e.title;
    final address = e.fullAddress;
    if (!isWeb) {
      if (platform == TargetPlatform.android) {
        out.add(e.hasCoordinates
            ? Uri.parse('geo:${e.latitude},${e.longitude}'
                '?q=${e.latitude},${e.longitude}(${Uri.encodeComponent(label)})')
            : Uri.parse('geo:0,0?q=${Uri.encodeComponent(address!)}'));
      } else if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
        out.add(Uri.https('maps.apple.com', '/', {
          'daddr': e.hasCoordinates ? '${e.latitude},${e.longitude}' : address!,
          if (e.hasCoordinates) 'q': label,
        }));
      }
    }
    out.add(web);
    return out;
  }

  /// Lien Google Maps : celui du serveur, sinon construit (repère, à défaut adresse).
  static Uri? googleMapsUrl(ChristianEvent e) {
    final server = e.directionsUrl;
    if (server != null) {
      final u = Uri.tryParse(server);
      if (u != null) return u;
    }
    final destination = e.hasCoordinates ? '${e.latitude},${e.longitude}' : e.fullAddress;
    if (destination == null) return null;
    return Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destination});
  }

  /// Ouvre l'itinéraire ; false si aucune application n'a pu l'ouvrir.
  static Future<bool> open(ChristianEvent e) async {
    for (final uri in candidates(e, platform: defaultTargetPlatform, isWeb: kIsWeb)) {
      try {
        final ok = await launchUrl(
          uri,
          mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        );
        if (ok) return true;
      } catch (_) {
        // Pas d'application pour ce lien : on essaie le suivant.
      }
    }
    return false;
  }
}

// ── Formulaire : position sur la carte ──────────────────────────────────────

/// Carte OpenStreetMap où l'on touche pour placer le repère du lieu, avec
/// « Ma position », « Chercher l'adresse » (Nominatim, sur clic) et « Effacer ».
class EventMapPicker extends StatefulWidget {
  const EventMapPicker({
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    this.addressQuery,
    super.key,
  });

  final double? latitude;
  final double? longitude;

  /// Nouveau repère, ou (null, null) quand il est effacé.
  final void Function(double? latitude, double? longitude) onChanged;

  /// Texte à géocoder (adresse, lieu, ville, pays) ; null : pas de recherche d'adresse.
  final String Function()? addressQuery;

  @override
  State<EventMapPicker> createState() => _EventMapPickerState();
}

class _EventMapPickerState extends State<EventMapPicker> {
  final _map = MapController();
  LatLng? _point;
  bool _locating = false;
  bool _searching = false;
  DateTime _lastSearch = DateTime.fromMillisecondsSinceEpoch(0);
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.latitude != null && widget.longitude != null) {
      _point = LatLng(widget.latitude!, widget.longitude!);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _place(LatLng p, {double? zoom, String? message}) {
    setState(() {
      _point = p;
      _message = message;
    });
    widget.onChanged(p.latitude, p.longitude);
    if (zoom != null) _map.move(p, zoom);
  }

  void _clear() {
    setState(() {
      _point = null;
      _message = null;
    });
    widget.onChanged(null, null);
  }

  void _snack(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(text), action: action),
    );
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final p = await EventLocationService.currentPosition();
      if (mounted) _place(p, zoom: 17, message: 'Repère placé sur votre position.');
    } on LocationFailure catch (e) {
      _snack(e.message,
          action: e.canOpenSettings
              ? SnackBarAction(label: 'Réglages', onPressed: Geolocator.openAppSettings)
              : null);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search() async {
    final q = widget.addressQuery?.call().trim() ?? '';
    if (q.isEmpty) {
      _snack("Saisissez d'abord le lieu, l'adresse ou la ville.");
      return;
    }
    // Politique Nominatim : une requête par seconde au plus.
    if (DateTime.now().difference(_lastSearch) < const Duration(milliseconds: 1500)) return;
    _lastSearch = DateTime.now();
    setState(() => _searching = true);
    try {
      final p = await EventLocationService.geocode(q);
      if (!mounted) return;
      if (p == null) {
        _snack('Adresse introuvable sur la carte : touchez la carte pour placer le repère.');
      } else {
        _place(p, zoom: 16, message: 'Adresse trouvée : ajustez le repère si besoin.');
      }
    } catch (_) {
      _snack('Recherche impossible pour le moment : touchez la carte pour placer le repère.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _point;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: _locating ? null : _locate,
              icon: _locating
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('Ma position'),
            ),
            if (widget.addressQuery != null)
              OutlinedButton.icon(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.travel_explore_rounded, size: 18),
                label: const Text("Chercher l'adresse"),
              ),
            if (p != null)
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Effacer le repère'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: 240,
            child: Semantics(
              label: "Carte : touchez pour placer le repère du lieu de l'événement",
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: p ?? _defaultCenter,
                  initialZoom: p != null ? 16 : 5,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, point) => _place(point),
                ),
                children: [
                  _osmTiles(),
                  if (p != null) MarkerLayer(markers: [_pin(p)]),
                  _osmAttribution(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          p == null
              ? 'Aucun repère placé. Touchez la carte pour indiquer le lieu.'
              : '${_message ?? 'Repère placé'} (${formatCoordinates(p.latitude, p.longitude)})',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ── Page détail : bloc « Lieu » ─────────────────────────────────────────────

/// Adresse, mini-carte non interactive avec repère, « Itinéraire » et « Copier l'adresse ».
class EventPlaceCard extends StatelessWidget {
  const EventPlaceCard({required this.event, super.key});

  final ChristianEvent event;

  Future<void> _directions(BuildContext context) async {
    final ok = await EventDirections.open(event);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text("Impossible d'ouvrir l'itinéraire sur cet appareil."),
      ));
    }
  }

  Future<void> _copy(BuildContext context) async {
    final e = event;
    final text = e.fullAddress ?? formatCoordinates(e.latitude!, e.longitude!);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Adresse copiée.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = event;
    final point = e.hasCoordinates ? LatLng(e.latitude!, e.longitude!) : null;
    final cityCountry = [e.city, e.country].whereType<String>().join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Text('Lieu',
                  style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          if (e.location != null)
            Text(e.location!,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (e.address != null)
            Text(e.address!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
          if (cityCountry.isNotEmpty)
            Text(cityCountry, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          if (point != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: 170,
                child: Semantics(
                  label: "Carte du lieu de l'événement",
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      _osmTiles(),
                      MarkerLayer(markers: [_pin(point)]),
                      _osmAttribution(),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.icon(
                onPressed: () => _directions(context),
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Itinéraire'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text("Copier l'adresse"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
