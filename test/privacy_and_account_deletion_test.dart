// Politique de confidentialité (liens sans compte, case obligatoire à
// l'inscription, mention Google) et suppression du compte (double
// confirmation, DELETE /me, retour au mode invité).
// Serveur : docs/fonctionnalites/confidentialite-et-suppression.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/auth/screens/login_screen.dart';
import 'package:testi_app/features/auth/screens/register_screen.dart';
import 'package:testi_app/features/auth/services/local_account_data.dart';
import 'package:testi_app/features/profile/screens/about_screen.dart';
import 'package:testi_app/features/profile/screens/delete_account_screen.dart';
import 'package:testi_app/features/profile/screens/profile_screen.dart';
import 'package:testi_app/l10n/app_localizations.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/shared/models/models.dart';
import 'package:testi_app/shared/widgets/guest_gate.dart' show isGuestProvider;
import 'package:testi_app/shared/widgets/privacy_policy.dart';

/// Navigateur intégré et réseau simulés.
class _Browser {
  _Browser({this.locale = L10n.fr});
  final Locale locale;
  final opened = <Uri>[];
  bool online = true;

  List<Override> get overrides => [
        inAppBrowserLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
        networkAvailableProvider.overrideWithValue(() async => online),
        localeProvider.overrideWithValue(locale),
      ];
}

Future<void> _phone(WidgetTester tester, {double width = 390, double height = 844}) async {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

// ── Inscription : notifier qui enregistre l'appel ────────────────────────────

class _RecordingAuth extends AuthNotifier {
  final registered = <bool>[];

  @override
  Future<AuthState> build() async => const AuthStateUnauthenticated();

  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? country,
    String? phoneCountry,
    String? phone,
    AccountType accountType = AccountType.individual,
    String? organizationName,
    OrganizationType? organizationType,
    String? organizationCity,
    String? organizationWebsite,
    bool acceptedPrivacy = false,
  }) async {
    registered.add(acceptedPrivacy);
  }
}

// ── Suppression : session connectée, API et effacement simulés ───────────────

const _me = UserModel(id: 'u1', displayName: 'Awa Kossou', hasPassword: false);

class _SignedIn extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthStateAuthenticated(_me);
}

class _Api implements ApiService {
  final deletes = <(String, Object?)>[];

  @override
  Future<LaravelResponse<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? query}) async {
    deletes.add((path, data));
    return LaravelResponse<T>(success: true, data: null as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

class _Wiper implements LocalAccountData {
  final wiped = <String?>[];

  @override
  Future<void> wipe({String? userId}) async => wiped.add(userId);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('adresse de la politique selon la langue', () {
    expect(privacyPolicyUrl('fr'), '${AppConstants.webBaseUrl}/confidentialite');
    expect(privacyPolicyUrl('en'), '${AppConstants.webBaseUrl}/privacy');
    expect(AppConstants.deleteAccount, '/me');
  });

  group('Liens accessibles sans compte', () {
    testWidgets('connexion : lien et mention sous Google ; ouverture dans l\'app', (tester) async {
      await _phone(tester);
      final browser = _Browser();
      await tester.pumpWidget(ProviderScope(
        overrides: browser.overrides,
        child: const MaterialApp(locale: Locale('fr'), home: LoginScreen()),
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey('google-privacy-notice')), findsOneWidget);
      expect(find.textContaining('En continuant, vous acceptez la'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('privacy-policy-link')));
      expect(browser.opened.single.toString(), '${AppConstants.webBaseUrl}/confidentialite');
    });

    testWidgets('sans réseau : message clair, rien n\'est ouvert', (tester) async {
      await _phone(tester);
      final browser = _Browser()..online = false;
      await tester.pumpWidget(ProviderScope(
        overrides: browser.overrides,
        child: const MaterialApp(locale: Locale('fr'), home: LoginScreen()),
      ));
      await tester.pump();
      await _tapVisible(tester, find.byKey(const ValueKey('privacy-policy-link')));
      expect(browser.opened, isEmpty);
      expect(find.textContaining('Pas de connexion Internet'), findsOneWidget);
    });

    testWidgets('mode invité : lien dans le profil invité', (tester) async {
      await _phone(tester);
      final browser = _Browser();
      await tester.pumpWidget(ProviderScope(
        overrides: [...browser.overrides, isGuestProvider.overrideWithValue(true)],
        child: const MaterialApp(locale: Locale('fr'), home: ProfileScreen()),
      ));
      await tester.pump();
      await _tapVisible(tester, find.byKey(const ValueKey('guest-privacy-policy')));
      expect(browser.opened.single.path, '/confidentialite');
    });

    testWidgets('Paramètres › À propos : lien (anglais → /privacy)', (tester) async {
      await _phone(tester);
      // Langue de l'application : anglais.
      L10n.locale = L10n.en;
      addTearDown(() => L10n.locale = L10n.fr);
      final browser = _Browser(locale: L10n.en);
      await tester.pumpWidget(ProviderScope(
        overrides: browser.overrides,
        child: const MaterialApp(locale: Locale('en'), home: AboutScreen()),
      ));
      await tester.pump();
      expect(find.text('Privacy policy'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('about-privacy-policy')));
      expect(browser.opened.single.path, '/privacy');
    });
  });

  group('Inscription', () {
    Future<_RecordingAuth> fillForm(WidgetTester tester) async {
      await _phone(tester, height: 900);
      final auth = _RecordingAuth();
      await tester.pumpWidget(ProviderScope(
        overrides: [..._Browser().overrides, authStateProvider.overrideWith(() => auth)],
        child: const MaterialApp(locale: Locale('fr'), home: RegisterScreen()),
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey('google-privacy-notice')), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Awa');
      await tester.enterText(fields.at(1), 'Kossou');
      await tester.enterText(fields.at(2), 'awa@example.com');
      // Pays : liste avec recherche.
      await _tapVisible(tester, find.text('Sélectionnez votre pays'));
      await tester.enterText(find.byType(TextField).last, 'Bénin');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bénin').last);
      await tester.pumpAndSettle();
      final pwd = find.byType(TextFormField);
      final n = tester.widgetList(pwd).length;
      await tester.enterText(pwd.at(n - 2), 'MotDePasse123!');
      await tester.enterText(pwd.at(n - 1), 'MotDePasse123!');
      await tester.pump();
      return auth;
    }

    testWidgets('la case « J\'accepte la politique » est obligatoire', (tester) async {
      final auth = await fillForm(tester);
      await _tapVisible(tester, find.text("S'inscrire").last);
      expect(auth.registered, isEmpty);
      expect(find.text('Veuillez accepter la politique de confidentialité pour créer votre compte.'), findsOneWidget);

      // Cochée : consentement envoyé (accepted_privacy).
      await _tapVisible(tester, find.descendant(
          of: find.byKey(const ValueKey('privacy-consent')), matching: find.byType(Checkbox)));
      await _tapVisible(tester, find.text("S'inscrire").last);
      expect(auth.registered, [true]);
    });

    testWidgets('le lien de la case ouvre la politique', (tester) async {
      await _phone(tester, height: 900);
      final browser = _Browser();
      await tester.pumpWidget(ProviderScope(
        overrides: browser.overrides,
        child: const MaterialApp(locale: Locale('fr'), home: RegisterScreen()),
      ));
      await tester.pump();
      await _tapVisible(tester, find.byKey(const ValueKey('privacy-consent-link')));
      expect(browser.opened.single.path, '/confidentialite');
    });
  });

  group('Suppression du compte', () {
    testWidgets('double confirmation, DELETE /me, données effacées, mode invité', (tester) async {
      await _phone(tester, height: 1000);
      final api = _Api();
      final wiper = _Wiper();
      final container = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(api),
        localAccountDataProvider.overrideWithValue(wiper),
        authStateProvider.overrideWith(_SignedIn.new),
        localeProvider.overrideWithValue(L10n.fr),
      ]);
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      final router = GoRouter(initialLocation: '/settings/delete-account', routes: [
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('ACCUEIL'))),
        GoRoute(path: '/settings/delete-account', builder: (_, _) => const DeleteAccountScreen()),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(locale: const Locale('fr'), routerConfig: router),
      ));
      await tester.pump();

      // Ce qui est supprimé est expliqué.
      expect(find.text('Ce qui sera supprimé'), findsOneWidget);

      // 1re confirmation : le mot à saisir ; sans lui, le bouton est inactif.
      await tester.enterText(find.byKey(const ValueKey('delete-account-word')), 'SUPPRIMER');
      await tester.pump();
      await _tapVisible(tester, find.byKey(const ValueKey('delete-account-submit')));
      // 2e confirmation : fenêtre finale ; « Annuler » ne supprime rien.
      expect(find.text('Supprimer définitivement votre compte ?'), findsOneWidget);
      await tester.tap(find.text('Annuler').last);
      await tester.pumpAndSettle();
      expect(api.deletes, isEmpty);

      await _tapVisible(tester, find.byKey(const ValueKey('delete-account-submit')));
      await tester.tap(find.byKey(const ValueKey('delete-account-final')));
      await tester.pumpAndSettle();

      expect(api.deletes.single.$1, '/me');
      expect(api.deletes.single.$2, {'confirm': true});
      expect(wiper.wiped, ['u1']);
      expect(container.read(authStateProvider).value, isA<AuthStateGuest>());
      expect(find.text('ACCUEIL'), findsOneWidget);
      expect(find.textContaining('Votre compte a été supprimé'), findsOneWidget);
    });
  });
}
