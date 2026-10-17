// Témoignage de conversion : un seul par compte personnel, mis en avant sur le
// profil et dans la section « Témoignages de conversion ».
// Backend : docs/fonctionnalites/temoignage-de-conversion.md
//
//   POST /testimonies        { …, kind: conversion, conversion_year?, conversion_place?, conversion_verse? }
//   PUT  /testimonies/{id}   { title?, body_text?, conversion_year?, conversion_place?, conversion_verse? }
//   GET  /testimonies?kind=conversion        (publiés, paginés)
//   GET  /users/{id}/conversion-testimony    (publié ; 404 sinon)
//   GET  /me/conversion-testimony            (le mien, tous statuts ; can_create)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart' show testimonyFromApiJson, parsePageMeta;

/// Première année de conversion acceptée par le serveur (jusqu'à l'année en cours).
const int conversionMinYear = 1900;

bool isValidConversionYear(int year) => year >= conversionMinYear && year <= DateTime.now().year;

/// Erreur lisible (403 organisation, 409 déjà existant, 422 validation…).
class ConversionFailure implements Exception {
  const ConversionFailure(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// Mon témoignage de conversion, quel que soit son statut.
class MyConversion {
  const MyConversion({this.testimony, this.status, this.canCreate = false, this.available = true});

  /// Serveur sans le module (route absente, 404) : impossible d'enregistrer un
  /// témoignage de conversion tant que le serveur n'est pas mis à jour.
  const MyConversion.unavailable({required this.canCreate})
      : testimony = null,
        status = null,
        available = false;

  /// null : pas encore de témoignage de conversion.
  final Testimony? testimony;

  /// pending | approved | rejected | … (statut de modération du serveur).
  final String? status;

  /// Compte personnel sans témoignage de conversion.
  final bool canCreate;

  /// Le serveur gère les témoignages de conversion.
  final bool available;

  bool get exists => testimony != null;
  bool get isPublished => status == 'approved' || status == 'published';
  bool get isPending => status == 'pending' || status == 'in_review';
  bool get isRejected => status == 'rejected';
}

/// Page de la section « Témoignages de conversion ».
class ConversionPage {
  const ConversionPage({required this.items, required this.page, required this.lastPage});

  final List<Testimony> items;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;
}

/// Valeurs modifiables d'un témoignage de conversion (titre, texte et champs propres).
class ConversionEdit {
  const ConversionEdit({
    required this.title,
    this.bodyText,
    this.year,
    this.place,
    this.verse,
  });

  final String title;

  /// Texte du témoignage (témoignage écrit) ; null : inchangé.
  final String? bodyText;
  final int? year;
  final String? place;
  final String? verse;

  Map<String, dynamic> toJson() => {
        'title': title.trim(),
        if (bodyText != null) 'body_text': bodyText,
        'kind': 'conversion',
        // Toujours envoyés : null efface le champ.
        'conversion_year': year,
        'conversion_place': (place ?? '').trim().isEmpty ? null : place!.trim(),
        'conversion_verse': (verse ?? '').trim().isEmpty ? null : verse!.trim(),
      };
}

class ConversionRepository {
  ConversionRepository(this._api);
  final ApiService _api;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on LaravelApiException catch (e) {
      final fields = e.allFieldErrors;
      throw ConversionFailure(fields.isNotEmpty ? fields : e.message, statusCode: e.statusCode);
    } on ConversionFailure {
      rethrow;
    } catch (_) {
      throw ConversionFailure(L10n.current.conversionLoadError);
    }
  }

  static Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

  /// Le mien (`data: null` s'il n'existe pas ; `can_create` à la racine de la réponse).
  /// [isOrganization] : sert au repli quand le serveur n'a pas encore la route.
  Future<MyConversion> mine({bool isOrganization = false}) => _guard(() async {
        final LaravelResponse<dynamic> res;
        try {
          res = await _api.get<dynamic>(AppConstants.myConversionTestimony);
        } on LaravelApiException catch (e) {
          if (e.statusCode == 404) return MyConversion.unavailable(canCreate: !isOrganization);
          rethrow;
        }
        final data = _map(res.data);
        return MyConversion(
          testimony: data == null ? null : testimonyFromApiJson(data),
          status: data?['status']?.toString(),
          canCreate: res.body['can_create'] == true,
        );
      });

  /// Témoignage de conversion publié d'un compte ; null s'il n'en a pas (404).
  Future<Testimony?> ofUser(String userId) async {
    try {
      final res = await _api.get<dynamic>(AppConstants.userConversionTestimony(userId));
      final data = _map(res.data);
      return data == null ? null : testimonyFromApiJson(data);
    } on LaravelApiException catch (e) {
      if (e.statusCode == 404) return null;
      throw ConversionFailure(e.message, statusCode: e.statusCode);
    }
  }

  /// Section « Témoignages de conversion » : publiés, du plus récent au plus ancien.
  Future<ConversionPage> list({int page = 1, int limit = 20}) => _guard(() async {
        final res = await _api.get<dynamic>(AppConstants.testimonies,
            query: {'kind': 'conversion', 'page': page, 'limit': limit});
        // Un serveur sans le module ignore `kind` et renvoie tous les témoignages :
        // on ne garde que ceux marqués conversion.
        final raw = res.data is List ? res.data as List : const [];
        // Pas de champ `kind` : serveur sans le module, inutile de parcourir les pages suivantes.
        final supported = raw.isEmpty || raw.any((m) => m is Map && m.containsKey('kind'));
        final items = raw
            .map(testimonyFromApiJson)
            .whereType<Testimony>()
            .where((t) => t.isConversion)
            .toList();
        final meta = parsePageMeta(res.meta);
        return ConversionPage(
            items: items, page: meta.currentPage, lastPage: supported ? meta.lastPage : meta.currentPage);
      });

  /// Modifier mon témoignage de conversion (il repasse en modération).
  Future<void> update(String testimonyId, ConversionEdit edit) => _guard(() async {
        await _api.put<dynamic>('${AppConstants.testimonies}/$testimonyId', data: edit.toJson());
      });
}

final conversionRepositoryProvider =
    Provider<ConversionRepository>((ref) => ConversionRepository(ref.watch(apiServiceProvider)));
