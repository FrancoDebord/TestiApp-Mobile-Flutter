// Localisation privée de la personne, pour classer « Pour vous » et « Mon fil » par zone
// (village/quartier, ville, région, pays, continent) puis selon ses goûts.
// Serveur : GET/PUT/DELETE /users/me/location ; meta.place et meta.nearby des fils.
// Doc serveur : docs/fonctionnalites/localisation.md

/// Réglage et zone utilisée (réponse de GET /users/me/location, jamais publique).
class UserLocationSettings {
  const UserLocationSettings({
    this.useGps = false,
    this.source,
    this.label,
    this.locality,
    this.city,
    this.region,
    this.countryCode,
    this.country,
    this.homeCity,
    this.hasCoordinates = false,
    this.updatedAt,
  });

  /// « Utiliser ma position pour personnaliser mes fils ».
  final bool useGps;

  /// gps | profile | phone | language | null (aucune zone connue).
  final String? source;

  /// Zone la plus précise connue (« Cotonou », « Bénin »).
  final String? label;
  final String? locality;
  final String? city;
  final String? region;
  final String? countryCode;
  final String? country;

  /// « Ma ville » saisie (sans GPS).
  final String? homeCity;
  final bool hasCoordinates;
  final DateTime? updatedAt;

  bool get usesGps => useGps && source == 'gps';

  /// Position trop ancienne : rafraîchie en silence (permission déjà accordée).
  bool isStale(DateTime now, {Duration maxAge = const Duration(days: 3)}) =>
      usesGps && (updatedAt == null || now.difference(updatedAt!) > maxAge);

  factory UserLocationSettings.fromJson(Object? json) {
    if (json is! Map) return const UserLocationSettings();
    String? s(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    return UserLocationSettings(
      useGps: json['useGps'] == true,
      source: s(json['source']),
      label: s(json['label']),
      locality: s(json['locality']),
      city: s(json['city']),
      region: s(json['region']),
      countryCode: s(json['countryCode']),
      country: s(json['country']),
      homeCity: s(json['homeCity']),
      hasCoordinates: json['latitude'] is num && json['longitude'] is num,
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
    );
  }

  /// Phrase affichée dans le réglage : « Cotonou, Bénin (position de l'appareil) ».
  String describe() {
    if (label == null) {
      return 'Aucune zone connue : vos fils restent classés selon vos goûts.';
    }
    final parts = <String>[];
    for (final p in [locality, label, country]) {
      if (p != null && !parts.contains(p)) parts.add(p);
    }
    final where = parts.join(', ');
    final from = switch (source) {
      'gps' => 'position de l’appareil',
      'profile' => 'ville et pays du profil',
      'phone' => 'indicatif du téléphone',
      'language' => 'langue de l’appareil',
      _ => 'profil',
    };
    return '$where ($from)';
  }
}

/// Zone utilisée pour classer un fil (meta.place) : « Près de chez vous · Cotonou ».
class FeedPlace {
  const FeedPlace({required this.label, this.precision, this.source});

  final String label;

  /// locality | city | region | country | continent
  final String? precision;

  /// gps | profile | phone | language
  final String? source;

  bool get fromGps => source == 'gps';

  static FeedPlace? fromMeta(Object? meta) {
    if (meta is! Map) return null;
    final p = meta['place'];
    if (p is! Map) return null;
    final label = p['label'];
    if (label is! String || label.trim().isEmpty) return null;
    return FeedPlace(
      label: label.trim(),
      precision: p['precision'] is String ? p['precision'] as String : null,
      source: p['source'] is String ? p['source'] as String : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FeedPlace &&
      other.label == label &&
      other.precision == precision &&
      other.source == source;

  @override
  int get hashCode => Object.hash(label, precision, source);
}

/// Étiquettes discrètes des cartes proches (meta.nearby) : { id : « À Cotonou » | « Au Bénin » }.
Map<String, String> parseNearbyLabels(Object? meta) {
  if (meta is! Map) return const {};
  final raw = meta['nearby'];
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      if (e.value is String && (e.value as String).isNotEmpty)
        '${e.key}': e.value as String,
  };
}
