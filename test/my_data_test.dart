// Suppression de ses données sans supprimer son compte (Google Play) :
// suppression par élément (témoignage, de conversion compris ; sujet de prière ;
// parole prophétique), interrupteur des notifications, écran « Mes données ».
// Serveur : docs/fonctionnalites/confidentialite-et-suppression.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/conversion/widgets/conversion_widgets.dart' show ConversionFeaturedCard;
import 'package:testi_app/features/home/providers/home_providers.dart' show testimonyFromApiJson;
import 'package:testi_app/features/notifications/providers/push_device_provider.dart';
import 'package:testi_app/features/prayer/models/prayer_models.dart';
import 'package:testi_app/features/prayer/widgets/prayer_widgets.dart' show PrayerRequestFeedCard;
import 'package:testi_app/features/profile/screens/my_data_screen.dart';
import 'package:testi_app/features/profile/screens/settings_screen.dart' show PushReceiveTile;
import 'package:testi_app/features/prophecies/models/prophecy.dart';
import 'package:testi_app/features/prophecies/providers/prophecies_providers.dart' show propheciesListProvider;
import 'package:testi_app/features/prophecies/screens/prophecies_screen.dart';
import 'package:testi_app/l10n/app_localizations.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/shared/content_deletion.dart';
import 'package:testi_app/shared/widgets/privacy_policy.dart';

class _Api implements ApiService {
  _Api({this.fail = false});
  final bool fail;
  final deletes = <String>[];

  @override
  Future<LaravelResponse<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? query}) async {
    if (fail) throw const LaravelApiException(message: 'Vous ne pouvez pas supprimer cet élément.', statusCode: 403);
    deletes.add(path);
    return LaravelResponse<T>(success: true, data: null as T);
  }

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async =>
      LaravelResponse<T>(success: true, data: const [] as T);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

Future<void> _pump(WidgetTester tester, Widget home, {List<Override> overrides = const []}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [localeProvider.overrideWithValue(L10n.fr), ...overrides],
    child: MaterialApp(home: Scaffold(body: home)),
  ));
  await tester.pump();
}

/// Ouvre le menu « ⋮ », choisit « Supprimer » puis confirme.
Future<void> _deleteFromMenu(WidgetTester tester, Finder menu) async {
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Supprimer').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('confirm-delete')));
  await tester.pumpAndSettle();
}

final _conversion = testimonyFromApiJson({
  'id': 't1',
  'title': "Comment j'ai rencontré Jésus",
  'type': 'text',
  'bodyText': "J'avais 17 ans…",
  'category': 'conversion',
  'createdAt': '2026-10-15T10:00:00+00:00',
  'status': 'approved',
  'kind': 'conversion',
  'isConversion': true,
  'user': {'id': 'u1', 'displayName': 'Afi Mensah'},
})!;

/// Carte de conversion branchée comme dans le profil (mon témoignage).
class _MyConversion extends ConsumerWidget {
  const _MyConversion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (watchIsDeleted(ref, DeletableContent.testimony, _conversion.id)) return const Text('SUPPRIMÉ');
    return ConversionFeaturedCard(
      testimony: _conversion,
      onEdit: () {},
      onDelete: () => deleteTestimonyContent(context, ref, _conversion.id),
    );
  }
}

class _FakePush implements PushDeviceControl {
  _FakePush({this.fail = false});
  final bool fail;
  bool enabled = true;
  final calls = <bool>[];

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool v) async {
    calls.add(v);
    if (fail) throw Exception('réseau');
    enabled = v;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('Suppression par élément', () {
    testWidgets('témoignage de conversion : « ⋮ » › Supprimer, confirmation, « Supprimé »', (tester) async {
      final api = _Api();
      await _pump(tester, const _MyConversion(), overrides: [apiServiceProvider.overrideWithValue(api)]);
      await _deleteFromMenu(tester, find.byKey(const ValueKey('conversion-menu-t1')));
      expect(api.deletes, [AppConstants.testimonyById('t1')]);
      expect(find.text('SUPPRIMÉ'), findsOneWidget); // retiré des listes ouvertes
      expect(find.text('Supprimé'), findsOneWidget); // SnackBar
    });

    testWidgets('échec : message clair, l\'élément reste', (tester) async {
      await _pump(tester, const _MyConversion(), overrides: [apiServiceProvider.overrideWithValue(_Api(fail: true))]);
      await _deleteFromMenu(tester, find.byKey(const ValueKey('conversion-menu-t1')));
      expect(find.text('La suppression a échoué : Vous ne pouvez pas supprimer cet élément.'), findsOneWidget);
      expect(find.text('SUPPRIMÉ'), findsNothing);
    });

    testWidgets('« Annuler » ne supprime rien', (tester) async {
      final api = _Api();
      await _pump(tester, const _MyConversion(), overrides: [apiServiceProvider.overrideWithValue(api)]);
      await tester.tap(find.byKey(const ValueKey('conversion-menu-t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(api.deletes, isEmpty);
    });

    testWidgets('sujet de prière : menu de l\'auteur, carte retirée', (tester) async {
      final api = _Api();
      final mine = PrayerRequest.fromJson({
        'id': 'p1',
        'body': 'Priez pour la guérison de ma mère.',
        'createdAt': '2026-10-19T08:00:00+00:00',
        'author': {'id': 'u1', 'displayName': 'Awa'},
        'isMine': true,
        'canDelete': true,
      });
      final other = PrayerRequest.fromJson({'id': 'p2', 'body': 'Une autre requête', 'canDelete': false});
      await _pump(
        tester,
        ListView(children: [PrayerRequestFeedCard(request: mine), PrayerRequestFeedCard(request: other)]),
        overrides: [apiServiceProvider.overrideWithValue(api)],
      );
      // Pas de menu sur la requête d'un autre.
      expect(find.byKey(const ValueKey('prayer-menu-p2')), findsNothing);
      await _deleteFromMenu(tester, find.byKey(const ValueKey('prayer-menu-p1')));
      expect(api.deletes, [AppConstants.prayerRequestById('p1')]);
      expect(find.textContaining('guérison de ma mère'), findsNothing);
      expect(find.text('Une autre requête'), findsOneWidget);
      expect(find.text('Supprimé'), findsOneWidget);
    });

    testWidgets('parole prophétique : « ⋮ » dans le carnet, retirée de la liste', (tester) async {
      final api = _Api();
      final prophecy = Prophecy.fromJson({
        'id': '42',
        'title': 'Une porte va s’ouvrir',
        'receivedOn': '2026-09-01',
        'status': 'waiting',
      });
      await _pump(tester, const PropheciesScreen(), overrides: [
        apiServiceProvider.overrideWithValue(api),
        propheciesListProvider.overrideWith((ref) async => [prophecy]),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Une porte va s’ouvrir'), findsOneWidget);
      await _deleteFromMenu(tester, find.byKey(const ValueKey('prophecy-menu-42')));
      expect(api.deletes, [AppConstants.prophecyById('42')]);
      expect(find.text('Une porte va s’ouvrir'), findsNothing);
      expect(find.text('Supprimé'), findsOneWidget);
    });
  });

  group('Notifications', () {
    testWidgets('« Recevoir des notifications » : désactiver puis réactiver', (tester) async {
      final push = _FakePush();
      await _pump(tester, const PushReceiveTile(), overrides: [pushDeviceControlProvider.overrideWithValue(push)]);
      await tester.pumpAndSettle();
      expect(find.text('Recevoir des notifications'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('push-receive-switch')));
      await tester.pumpAndSettle();
      expect(push.calls, [false]);
      expect(find.textContaining('Désactivé'), findsOneWidget);
      expect(find.text('Notifications désactivées sur cet appareil.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('push-receive-switch')));
      await tester.pumpAndSettle();
      expect(push.calls, [false, true]);
      expect(find.text('Cet appareil reçoit les notifications de votre compte.'), findsOneWidget);
    });

    testWidgets('échec du serveur : l\'interrupteur reste activé, message clair', (tester) async {
      final push = _FakePush(fail: true);
      await _pump(tester, const PushReceiveTile(), overrides: [pushDeviceControlProvider.overrideWithValue(push)]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('push-receive-switch')));
      await tester.pumpAndSettle();
      expect(find.text('Cet appareil reçoit les notifications de votre compte.'), findsOneWidget);
      expect(find.textContaining('Impossible de modifier les notifications'), findsOneWidget);
    });
  });

  group('Mes données', () {
    Future<(List<Uri>, GoRouter)> pumpMyData(WidgetTester tester, {double width = 390, double scale = 1}) async {
      tester.view.physicalSize = Size(width * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final opened = <Uri>[];
      Widget page(String label) => Scaffold(body: Text(label));
      final router = GoRouter(initialLocation: '/settings/my-data', routes: [
        GoRoute(path: '/settings/my-data', builder: (_, _) => const MyDataScreen()),
        GoRoute(path: '/settings/delete-account', name: 'delete-account', builder: (_, _) => page('SUPPRESSION')),
        GoRoute(path: '/profile/my-testimonies', name: 'my-testimonies', builder: (_, _) => page('MES TÉMOIGNAGES')),
        GoRoute(path: '/prayer-requests', builder: (_, s) => page('PRIÈRES ${s.uri.queryParameters['tab']}')),
        GoRoute(path: '/prophecies', builder: (_, _) => page('PAROLES')),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          localeProvider.overrideWithValue(L10n.fr),
          inAppBrowserLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
          networkAvailableProvider.overrideWithValue(() async => true),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              MediaQuery.withClampedTextScaling(minScaleFactor: scale, maxScaleFactor: scale, child: child!),
        ),
      ));
      await tester.pumpAndSettle();
      return (opened, router);
    }

    testWidgets('liens, demande de suppression et suppression du compte', (tester) async {
      final (opened, router) = await pumpMyData(tester);
      expect(find.text('Mes données'), findsOneWidget);
      expect(find.text('Mes témoignages'), findsOneWidget);
      expect(find.text('Mes sujets de prière'), findsOneWidget);
      expect(find.text('Mes paroles prophétiques'), findsOneWidget);
      expect(find.text('Demander la suppression d\'autres données'), findsOneWidget);
      expect(find.text('Supprimer mon compte'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('my-data-prayers')));
      await tester.pumpAndSettle();
      expect(find.text('PRIÈRES mine'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('my-data-request-other')));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), '${AppConstants.webBaseUrl}/suppression-compte');

      await tester.ensureVisible(find.byKey(const ValueKey('my-data-delete-account')));
      await tester.tap(find.byKey(const ValueKey('my-data-delete-account')));
      await tester.pumpAndSettle();
      expect(find.text('SUPPRESSION'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('sans débordement (320 px, ×$scale)', (tester) async {
        await pumpMyData(tester, width: 320, scale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
