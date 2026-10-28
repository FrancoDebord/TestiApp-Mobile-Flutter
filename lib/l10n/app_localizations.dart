// lib/l10n/app_localizations.dart
//
// Traductions FR / EN de l'application (flutter_localizations + ARB).
//
//   • Textes : lib/l10n/arb/app_fr.arb (modèle) et app_en.arb, générés en Dart
//     dans lib/l10n/gen/ par `flutter gen-l10n` (l10n.yaml). Voir README.md.
//   • Dans un widget : `context.l10n.navHome` (ou `AppLocalizations.of(context)`).
//   • Hors widget (modèles, services, enums) : `L10n.current.navHome`.
//   • Langue : « Langue du système » par défaut, ou Français / English
//     (Paramètres › Langue) ; envoyée au serveur (PUT /me { locale }) et dans
//     l'en-tête Accept-Language de chaque requête.

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' show FlutterSecureStorage;

import '../core/app_constants.dart';
import '../services/api_service.dart'
    show LaravelApiException, apiServiceProvider, secureStorageProvider;
import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';
export 'formatters.dart';

// ── Langue courante (accès sans BuildContext) ────────────────────────────────

abstract final class L10n {
  static const fr = Locale('fr');
  static const en = Locale('en');
  static const supported = [fr, en];

  /// Langue affichée. Mise à jour par [localeProvider] ; le français tant que
  /// rien n'est choisi (tests, démarrage).
  static Locale locale = fr;

  /// Pays de l'appareil (« BJ ») : complète l'en-tête Accept-Language, que le
  /// serveur utilise aussi pour deviner le pays.
  static String? deviceCountry;

  static AppLocalizations get current => lookupAppLocalizations(locale);

  /// « fr » ou « en ».
  static String get languageCode => locale.languageCode;

  /// Code pour intl (DateFormat, NumberFormat).
  static String get intlLocale => languageCode;

  /// Valeur de l'en-tête Accept-Language : « fr-BJ,fr;q=0.9 » ou « en ».
  static String get acceptLanguage {
    final cc = deviceCountry;
    return cc == null || cc.isEmpty
        ? languageCode
        : '$languageCode-$cc,$languageCode;q=0.9';
  }

  /// Langue du système ramenée aux langues de l'application : la première
  /// langue française ou anglaise de la liste du téléphone ; aucune des deux
  /// → anglais (liste vide → français).
  static Locale resolveSystem(List<Locale> systemLocales) {
    for (final l in systemLocales) {
      if (l.languageCode == 'fr') return fr;
      if (l.languageCode == 'en') return en;
    }
    return systemLocales.isEmpty ? fr : en;
  }
}

extension AppLocalizationsContext on BuildContext {
  /// Traductions de la langue affichée (repli : [L10n.current], par exemple
  /// dans un test qui monte un widget sans délégués de localisation).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? L10n.current;
}

extension AppLocalizationsExtras on AppLocalizations {
  bool get isFr => localeName.startsWith('fr');

  /// « Membre depuis 3 mois » calculé depuis la date d'inscription.
  String profileMemberSince(DateTime since, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final months = (n.year - since.year) * 12 + n.month - since.month;
    if (months >= 12) return profileMemberSinceYears(months ~/ 12);
    if (months >= 1) return profileMemberSinceMonths(months);
    final days = n.difference(since).inDays;
    return profileMemberSinceDays(days < 1 ? 1 : days);
  }
}

// ── Choix de la langue ───────────────────────────────────────────────────────

/// Choix de l'utilisateur : langue du système (par défaut), français, anglais.
enum AppLanguage {
  system,
  fr,
  en;

  static AppLanguage parse(String? code) =>
      values.firstWhere((v) => v.name == code, orElse: () => system);
}

const _kLocaleKey = 'app_locale';

class AppLanguageNotifier extends Notifier<AppLanguage> {
  /// Choix relu par [preload] avant le premier écran (null : non relu, ex. tests).
  static AppLanguage? _preloaded;

  /// Au démarrage (main), avant `runApp` : relit le choix enregistré et fixe
  /// [L10n.locale]. À la première installation, rien n'est enregistré : langue
  /// du système. Le premier écran et les premières requêtes (Accept-Language,
  /// dont l'inscription, qui fixe la langue du compte côté serveur) sont donc
  /// dans la bonne langue, sans passage par le français.
  static Future<void> preload(FlutterSecureStorage storage) async {
    var choice = AppLanguage.system;
    try {
      choice = AppLanguage.parse(await storage.read(key: _kLocaleKey));
    } catch (_) {}
    _preloaded = choice;
    final system = PlatformDispatcher.instance.locales;
    L10n.locale = resolveLanguage(choice, system);
    L10n.deviceCountry = system.isEmpty ? null : system.first.countryCode;
  }

  @override
  AppLanguage build() {
    // Utilisé une fois : une reconstruction ultérieure relit le stockage.
    final preloaded = _preloaded;
    _preloaded = null;
    if (preloaded != null) return preloaded;
    Future.microtask(_restore);
    return AppLanguage.system;
  }

  Future<void> _restore() async {
    try {
      final code = await ref.read(secureStorageProvider).read(key: _kLocaleKey);
      state = AppLanguage.parse(code);
    } catch (_) {}
  }

  /// Nouveau choix : enregistré sur l'appareil puis envoyé au serveur.
  Future<void> choose(AppLanguage language) async {
    state = language;
    try {
      await ref.read(secureStorageProvider).write(key: _kLocaleKey, value: language.name);
    } catch (_) {}
    // Langue calculée ici : ce notifier ne peut pas lire localeProvider, qui dépend de lui.
    final code = switch (language) {
      AppLanguage.fr => L10n.fr.languageCode,
      AppLanguage.en => L10n.en.languageCode,
      AppLanguage.system => L10n.resolveSystem(ref.read(systemLocalesProvider)).languageCode,
    };
    unawaited(syncLocaleToServer(ref.read, languageCode: code));
  }

  // Compatibilité avec les anciens appels.
  Future<void> setFrench() => choose(AppLanguage.fr);
  Future<void> setEnglish() => choose(AppLanguage.en);
}

final appLanguageProvider =
    NotifierProvider<AppLanguageNotifier, AppLanguage>(AppLanguageNotifier.new);

/// Langues du système, relues quand elles changent (main.dart, didChangeLocales).
final systemLocalesProvider = Provider<List<Locale>>(
  (ref) => PlatformDispatcher.instance.locales,
);

/// Recalcule l'appelant quand la langue affichée peut changer (contenu
/// localisé par le serveur via Accept-Language : verset du jour…). Ne lit pas
/// [localeProvider], qui fixe [L10n.locale] au passage.
void watchAppLanguage(Ref ref) {
  ref.watch(appLanguageProvider);
  ref.watch(systemLocalesProvider);
}

/// Langue correspondant au choix [choice] (langue du système : [system]).
Locale resolveLanguage(AppLanguage choice, List<Locale> system) => switch (choice) {
      AppLanguage.fr => L10n.fr,
      AppLanguage.en => L10n.en,
      AppLanguage.system => L10n.resolveSystem(system),
    };

/// Langue affichée : choix de l'utilisateur, sinon langue du système.
final localeProvider = Provider<Locale>((ref) {
  final choice = ref.watch(appLanguageProvider);
  final system = ref.watch(systemLocalesProvider);
  final locale = resolveLanguage(choice, system);
  L10n.locale = locale;
  L10n.deviceCountry = system.isEmpty ? null : system.first.countryCode;
  return locale;
});

/// Envoie la langue affichée au serveur (notifications, e-mails) :
/// PUT /me { locale }. Tant que cette route n'est pas déployée (404 / 405),
/// repli sur PUT /users/me. Jamais bloquant ; ignoré sans session.
/// [read] : `ref.read` d'un Ref ou d'un WidgetRef ; [languageCode] : langue à envoyer
/// (par défaut, celle de localeProvider).
Future<void> syncLocaleToServer(T Function<T>(ProviderListenable<T>) read, {String? languageCode}) async {
  final token = await read(secureStorageProvider).read(key: AppConstants.keyAccessToken);
  if (token == null || token.isEmpty || token == 'offline_mode' || token == 'local_auth') return;
  final body = {'locale': languageCode ?? read(localeProvider).languageCode};
  final api = read(apiServiceProvider);
  try {
    await api.put<dynamic>(AppConstants.meLocale, data: body);
  } on LaravelApiException catch (e) {
    if (e.statusCode != 404 && e.statusCode != 405) {
      debugPrint('Langue ✗ PUT ${AppConstants.meLocale} : ${e.displayMessage}');
      return;
    }
    try {
      await api.put<dynamic>(AppConstants.updateProfile, data: body);
    } catch (e) {
      debugPrint('Langue ✗ PUT ${AppConstants.updateProfile} : $e');
    }
  } catch (e) {
    debugPrint('Langue ✗ $e');
  }
}
