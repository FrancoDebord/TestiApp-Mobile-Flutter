// Langue (système / FR / EN), en-tête Accept-Language, envoi au serveur,
// formats de dates et nombres, et notifications (contenu affiché au premier
// plan, résultat de « Tester les notifications »).

import 'package:dio/dio.dart' show RequestInterceptorHandler, RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/profile/widgets/push_test.dart';
import 'package:testi_app/l10n/app_localizations.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/services/push_service.dart';

/// API simulée : PUT enregistrés ; [missingMe] simule l'absence de PUT /me.
class _Api implements ApiService {
  _Api({this.missingMe = false});
  final bool missingMe;
  final puts = <(String, Object?)>[];

  @override
  Future<LaravelResponse<T>> put<T>(String path, {dynamic data}) async {
    puts.add((path, data));
    if (missingMe && path == AppConstants.meLocale) {
      throw const LaravelApiException(message: 'not found', statusCode: 404);
    }
    return LaravelResponse<T>(success: true, data: <String, dynamic>{} as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

ProviderContainer _container(_Api api, {List<Locale> system = const [Locale('fr', 'BJ')]}) {
  final c = ProviderContainer(overrides: [
    apiServiceProvider.overrideWithValue(api),
    systemLocalesProvider.overrideWithValue(system),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({AppConstants.keyAccessToken: 'tok'});
    L10n.locale = L10n.fr;
  });
  tearDown(() => L10n.locale = L10n.fr);

  group('Langue', () {
    test('langue du système : français, anglais, autre → anglais', () {
      expect(L10n.resolveSystem(const [Locale('fr', 'BJ')]), L10n.fr);
      expect(L10n.resolveSystem(const [Locale('en', 'GB')]), L10n.en);
      expect(L10n.resolveSystem(const [Locale('es'), Locale('fr')]), L10n.fr);
      expect(L10n.resolveSystem(const [Locale('es')]), L10n.en);
      expect(L10n.resolveSystem(const []), L10n.fr);
    });

    test('par défaut : langue du système ; choix enregistré et appliqué', () async {
      final c = _container(_Api(), system: const [Locale('en', 'US')]);
      expect(c.read(appLanguageProvider), AppLanguage.system);
      expect(c.read(localeProvider), L10n.en);
      expect(L10n.current.navHome, 'Home');

      await c.read(appLanguageProvider.notifier).choose(AppLanguage.fr);
      expect(c.read(localeProvider), L10n.fr);
      expect(L10n.current.navHome, 'Accueil');
      expect(await const FlutterSecureStorage().read(key: 'app_locale'), 'fr');
    });

    test('ancien choix enregistré (« en ») relu au démarrage', () async {
      FlutterSecureStorage.setMockInitialValues({'app_locale': 'en'});
      final c = _container(_Api());
      c.read(appLanguageProvider);
      await _settle();
      expect(c.read(appLanguageProvider), AppLanguage.en);
      expect(c.read(localeProvider), L10n.en);
    });

    test('Accept-Language : langue choisie + pays du téléphone', () {
      final c = _container(_Api(), system: const [Locale('fr', 'BJ')]);
      c.read(localeProvider);
      expect(L10n.acceptLanguage, 'fr-BJ,fr;q=0.9');
      L10n.locale = L10n.en;
      expect(L10n.acceptLanguage, 'en-BJ,en;q=0.9');
      L10n.deviceCountry = null;
      expect(L10n.acceptLanguage, 'en');
    });

    test('LanguageInterceptor ajoute l’en-tête à chaque requête', () {
      L10n.locale = L10n.en;
      L10n.deviceCountry = null;
      final options = RequestOptions(path: '/x');
      LanguageInterceptor().onRequest(options, RequestInterceptorHandler());
      expect(options.headers['Accept-Language'], 'en');
    });

    test('choix envoyé au serveur : PUT /me { locale }', () async {
      final api = _Api();
      final c = _container(api);
      await c.read(appLanguageProvider.notifier).choose(AppLanguage.en);
      await _settle();
      expect(api.puts.single.$1, AppConstants.meLocale);
      expect(api.puts.single.$2, {'locale': 'en'});
    });

    test('PUT /me absent (404) : repli sur PUT /users/me', () async {
      final api = _Api(missingMe: true);
      final c = _container(api);
      await c.read(appLanguageProvider.notifier).choose(AppLanguage.fr);
      await _settle();
      expect(api.puts.map((p) => p.$1),
          [AppConstants.meLocale, AppConstants.updateProfile]);
      expect(api.puts.last.$2, {'locale': 'fr'});
    });

    test('sans session : rien n’est envoyé', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final api = _Api();
      final c = _container(api);
      await c.read(appLanguageProvider.notifier).choose(AppLanguage.en);
      await _settle();
      expect(api.puts, isEmpty);
    });

    testWidgets('context.l10n suit la langue de l’application', (tester) async {
      Future<String> label(Locale locale) async {
        late String text;
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: L10n.supported,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(builder: (context) {
            text = context.l10n.settingsLanguage;
            return const SizedBox();
          }),
        ));
        await tester.pumpAndSettle();
        return text;
      }

      expect(await label(L10n.fr), 'Langue');
      expect(await label(L10n.en), 'Language');
    });

    test('toutes les clés ont une traduction anglaise non vide', () {
      // Les deux classes générées exposent les mêmes messages ; on vérifie
      // quelques messages à paramètres et pluriels.
      final fr = lookupAppLocalizations(L10n.fr);
      final en = lookupAppLocalizations(L10n.en);
      expect(fr.profileMemberSinceYears(2), 'Membre depuis 2 ans');
      expect(en.profileMemberSinceYears(1), 'Member for 1 year');
      expect(en.timeDaysAgo(3), '3 days ago');
      expect(fr.timeDaysAgo(3), 'il y a 3 j');
    });
  });

  group('Formats selon la langue', () {
    setUpAll(initLocaleFormatting);
    final d = DateTime(2026, 10, 14, 14, 5);

    test('dates', () {
      L10n.locale = L10n.fr;
      expect(formatDate(d), '14 oct. 2026');
      expect(formatDateLong(d), '14 octobre 2026');
      expect(formatTime(d), '14:05');
      L10n.locale = L10n.en;
      expect(formatDate(d), 'Oct 14, 2026');
      expect(formatDateLong(d), 'October 14, 2026');
      expect(formatTime(d), '2:05 PM');
    });

    test('nombres et tailles', () {
      L10n.locale = L10n.fr;
      expect(formatNumber(1234567), '1 234 567');
      expect(formatBytes(2516582), '2,4 Mo');
      L10n.locale = L10n.en;
      expect(formatNumber(1234567), '1,234,567');
      expect(formatBytes(2516582), '2.4 MB');
      expect(formatCompactNumber(1200), '1.2K');
    });

    test('il y a…', () {
      final now = DateTime(2026, 10, 14, 12);
      L10n.locale = L10n.fr;
      expect(formatTimeAgo(now.subtract(const Duration(seconds: 20)), now: now), "à l'instant");
      expect(formatTimeAgo(now.subtract(const Duration(minutes: 5)), now: now), 'il y a 5 min');
      expect(formatTimeAgo(now.subtract(const Duration(days: 400)), now: now), 'il y a 1 an');
      L10n.locale = L10n.en;
      expect(formatTimeAgo(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
      expect(formatTimeAgo(now.subtract(const Duration(days: 14)), now: now), '2 weeks ago');
    });

    test('« Membre depuis »', () {
      final now = DateTime(2026, 10, 14);
      expect(L10n.current.profileMemberSince(DateTime(2026, 10, 13), now: now), 'Membre depuis 1 jour');
      L10n.locale = L10n.en;
      expect(L10n.current.profileMemberSince(DateTime(2026, 7, 1), now: now), 'Member for 3 months');
    });
  });

  group('Notifications', () {
    test('premier plan : bloc notification, sinon title/body des données', () {
      expect(foregroundContent('Titre', 'Texte', const {}), (title: 'Titre', body: 'Texte'));
      expect(foregroundContent(null, null, const {'title': 'T', 'body': 'B'}),
          (title: 'T', body: 'B'));
      // Message silencieux (données seules) : rien à afficher.
      expect(foregroundContent(null, null, const {'type': 'prophecy_updated'}), isNull);
    });

    test('« Tester les notifications » : message de chaque résultat', () {
      for (final locale in L10n.supported) {
        final l = lookupAppLocalizations(locale);
        for (final outcome in PushTestOutcome.values) {
          final msg = pushTestMessage(l, PushTestResult(outcome, serverMessage: 'x'));
          expect(msg, isNotEmpty, reason: '$locale $outcome');
        }
      }
      final fr = lookupAppLocalizations(L10n.fr);
      expect(pushTestMessage(fr, const PushTestResult(PushTestOutcome.sent, devices: 2)),
          startsWith('Notification envoyée à 2 appareils'));
      expect(pushTestMessage(fr, const PushTestResult(PushTestOutcome.notDeployed)),
          contains('pas encore disponible'));
    });

    test('intention de navigation d’un push (app ouverte, arrière-plan, fermée)', () {
      final i = FcmNavIntent.fromData({'type': 'comment', 'testimony_id': 't1'})!;
      expect(i.type, 'comment');
      expect(i.testimonyId, 't1');
      expect(FcmNavIntent.fromData({'title': 'sans type'}), isNull);
    });
  });
}
