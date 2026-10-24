// Politique de confidentialité (affichée dans l'app, liens sans compte, copie
// hors ligne, case obligatoire à l'inscription, mention Google) et suppression du compte (double
// confirmation, DELETE /me, retour au mode invité).
// Serveur : docs/fonctionnalites/confidentialite-et-suppression.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/core/router/app_routes.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/auth/screens/login_screen.dart';
import 'package:testi_app/features/auth/screens/register_screen.dart';
import 'package:testi_app/features/auth/services/local_account_data.dart';
import 'package:testi_app/features/profile/screens/about_screen.dart';
import 'package:testi_app/features/profile/screens/delete_account_screen.dart';
import 'package:testi_app/features/profile/screens/privacy_policy_screen.dart';
import 'package:testi_app/features/profile/screens/profile_screen.dart';
import 'package:testi_app/l10n/app_localizations.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/shared/models/models.dart';
import 'package:testi_app/shared/widgets/guest_gate.dart' show isGuestProvider;
import 'package:testi_app/shared/widgets/privacy_policy.dart';

/// Politique servie par un chargeur simulé (langue demandée enregistrée).
class _Policy {
  _Policy({this.locale = L10n.fr});
  final Locale locale;
  final langs = <String>[];
  bool fail = false;

  List<Override> get overrides => [
        privacyPolicyLoaderProvider.overrideWithValue((lang) async {
          langs.add(lang);
          if (fail) throw Exception('hors ligne');
          return PrivacyPolicyDoc(
            title: lang == 'en' ? 'My Testimony Privacy Policy' : 'Politique de confidentialité de My Testimony',
            html: _policyHtml,
            updatedAt: DateTime(2026, 10, 20),
          );
        }),
        localeProvider.overrideWithValue(locale),
      ];
}

const _policyHtml = '''
<h2>1. Qui sommes-nous ?</h2>
<p>Contact : <strong>arise.shinekrea@gmail.com</strong> et <a href="https://temoignage.as-krea.com">le site</a>.</p>
<ul><li>Vous pouvez consulter l'application <strong>sans compte</strong>.</li><li>Nous ne vendons pas vos données.</li></ul>
<table><thead><tr><th>Finalité</th><th>Base</th></tr></thead><tbody><tr><td>Créer votre compte</td><td>Exécution du service</td></tr></tbody></table>
''';

/// [home] dans un routeur qui connaît l'écran de la politique.
Widget _routed(Widget home, {Locale locale = const Locale('fr')}) => MaterialApp.router(
      locale: locale,
      routerConfig: GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(path: AppPaths.privacyPolicyPath, builder: (_, _) => const PrivacyPolicyScreen()),
      ]),
    );

/// L'écran de la politique est affiché, avec son contenu mis en forme.
void _expectPolicyShown(WidgetTester tester) {
  expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
  expect(find.byKey(const ValueKey('privacy-policy-content')), findsOneWidget);
  expect(find.text('1. Qui sommes-nous ?'), findsOneWidget);
  expect(find.text('Finalité'), findsOneWidget);
  expect(find.text('Exécution du service'), findsOneWidget);
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

class _PolicyApi implements ApiService {
  final queries = <Map<String, dynamic>?>[];
  bool offline = false;

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    expect(path, AppConstants.legalPrivacy);
    queries.add(query);
    if (offline) throw Exception('hors ligne');
    return LaravelResponse<T>(success: true, data: {
      'title': 'Politique de confidentialité de My Testimony',
      'updated_at': '2026-10-20',
      'html': _policyHtml,
      'url': '${AppConstants.webBaseUrl}/confidentialite',
    } as T);
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

  group('Politique affichée dans l\'application', () {
    testWidgets('connexion : lien et mention sous Google ; écran de l\'app, pas de navigateur', (tester) async {
      await _phone(tester);
      final policy = _Policy();
      await tester.pumpWidget(ProviderScope(overrides: policy.overrides, child: _routed(const LoginScreen())));
      await tester.pump();
      expect(find.byKey(const ValueKey('google-privacy-notice')), findsOneWidget);
      expect(find.textContaining('En continuant, vous acceptez la'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('privacy-policy-link')));
      _expectPolicyShown(tester);
      expect(find.text('Politique de confidentialité de My Testimony'), findsOneWidget);
      expect(find.text('Mise à jour le 20 octobre 2026'), findsOneWidget);
      expect(policy.langs, ['fr']);
    });

    testWidgets('échec sans copie enregistrée : message clair, puis Réessayer', (tester) async {
      await _phone(tester);
      final policy = _Policy()..fail = true;
      await tester.pumpWidget(ProviderScope(overrides: policy.overrides, child: _routed(const LoginScreen())));
      await tester.pump();
      await _tapVisible(tester, find.byKey(const ValueKey('privacy-policy-link')));
      expect(find.textContaining('Impossible d\'ouvrir la politique de confidentialité'), findsOneWidget);
      policy.fail = false;
      await _tapVisible(tester, find.byKey(const ValueKey('privacy-retry')));
      _expectPolicyShown(tester);
    });

    testWidgets('mode invité : lien dans le profil invité', (tester) async {
      await _phone(tester);
      final policy = _Policy();
      await tester.pumpWidget(ProviderScope(
        overrides: [...policy.overrides, isGuestProvider.overrideWithValue(true)],
        child: _routed(const ProfileScreen()),
      ));
      await tester.pump();
      await _tapVisible(tester, find.byKey(const ValueKey('guest-privacy-policy')));
      _expectPolicyShown(tester);
    });

    testWidgets('Paramètres › À propos : politique en anglais', (tester) async {
      await _phone(tester);
      // Langue de l'application : anglais.
      L10n.locale = L10n.en;
      addTearDown(() => L10n.locale = L10n.fr);
      final policy = _Policy(locale: L10n.en);
      await tester.pumpWidget(ProviderScope(
        overrides: policy.overrides,
        child: _routed(const AboutScreen(), locale: const Locale('en')),
      ));
      await tester.pump();
      expect(find.text('Privacy policy'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('about-privacy-policy')));
      expect(find.text('My Testimony Privacy Policy'), findsOneWidget);
      expect(policy.langs, ['en']);
    });

    test('hors ligne : la dernière version lue est relue depuis l\'appareil', () async {
      SharedPreferences.setMockInitialValues({});
      final api = _PolicyApi();
      final container = ProviderContainer(overrides: [apiServiceProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);
      final load = container.read(privacyPolicyLoaderProvider);

      final online = await load('fr');
      expect(online.savedCopy, isFalse);
      expect(api.queries.single, {'lang': 'fr'});

      api.offline = true;
      final offline = await load('fr');
      expect(offline.savedCopy, isTrue);
      expect(offline.title, 'Politique de confidentialité de My Testimony');
      expect(offline.updatedAt, DateTime(2026, 10, 20));
      // Aucune copie en anglais : l'erreur remonte.
      await expectLater(load('en'), throwsA(anything));
    });
  });

  group('Inscription', () {
    Future<_RecordingAuth> fillForm(WidgetTester tester) async {
      await _phone(tester, height: 900);
      final auth = _RecordingAuth();
      await tester.pumpWidget(ProviderScope(
        overrides: [..._Policy().overrides, authStateProvider.overrideWith(() => auth)],
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
      final policy = _Policy();
      await tester.pumpWidget(ProviderScope(overrides: policy.overrides, child: _routed(const RegisterScreen())));
      await tester.pump();
      await _tapVisible(tester, find.byKey(const ValueKey('privacy-consent-link')));
      _expectPolicyShown(tester);
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
