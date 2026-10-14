// Badges de confiance et gestion des témoignages (lot A du serveur) :
//   • label « Témoignage approuvé » (badges: verified) et « À la une » (badges:
//     featured, jamais pour featured_source = recent) ;
//   • badge « Approuvé » des comptes (approval_badge : deux styles) ;
//   • filtre « Approuvés » et tri du fil (paramètres envoyés à l'API) ;
//   • « Mes publications » : statuts, « Modifier et renvoyer » ;
//   • vue comptée une fois par session.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/home/widgets/feed_filter_bar.dart';
import 'package:testi_app/features/home/widgets/testimony_labels.dart';
import 'package:testi_app/features/profile/models/user_testimony_model.dart';
import 'package:testi_app/features/profile/screens/my_testimonies_screen.dart';
import 'package:testi_app/features/publish/upload/video_upload_controller.dart';
import 'package:testi_app/features/publish/upload/video_upload_models.dart';
import 'package:testi_app/features/testimony/providers/view_tracker.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/services/push_service.dart' show PushService;
import 'package:testi_app/shared/models/models.dart' show UserModel;
import 'package:testi_app/shared/models/account_approval.dart';
import 'package:testi_app/shared/widgets/approval_badges.dart';
import 'package:testi_app/shared/widgets/organization_badge.dart';

// ── Données ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _json({
  String id = 't1',
  String status = 'approved',
  List<String>? badges,
  String? featuredSource,
  Map<String, dynamic>? user,
  Object? isVerified,
  String? rejectionReason,
}) =>
    {
      'id': id,
      'title': 'Guérie après des années',
      'type': 'text',
      'bodyText': 'Dieu m’a guérie.',
      'status': status,
      'badges': ?badges,
      'featured_source': ?featuredSource,
      'isVerified': ?isVerified,
      'rejectionReason': ?rejectionReason,
      'createdAt': '2026-10-10T08:00:00Z',
      'stats': {'viewsCount': 12},
      'user': user ?? {'id': 'u1', 'display_name': 'Église Lumière'},
    };

// ── Faux services ────────────────────────────────────────────────────────────

class _Api implements ApiService {
  final gets = <(String, Map<String, dynamic>?)>[];
  final posts = <(String, Object?)>[];
  final puts = <(String, Object?)>[];
  List<Map<String, dynamic>> feed = [_json(badges: ['verified']), _json(id: 't2', badges: [])];
  List<Map<String, dynamic>> mine = [];
  Map<String, dynamic>? putResponse;
  Object? postError;

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    gets.add((path, query));
    if (path == AppConstants.testimonies) {
      return LaravelResponse<T>(success: true, data: feed as T, meta: {'currentPage': 1, 'lastPage': 1});
    }
    if (path == AppConstants.myTestimonies) {
      return LaravelResponse<T>(success: true, data: mine as T, meta: {'currentPage': 1, 'lastPage': 1});
    }
    throw StateError('GET $path');
  }

  @override
  Future<LaravelResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query}) async {
    posts.add((path, data));
    if (postError != null) throw postError!;
    return LaravelResponse<T>(success: true, data: <String, dynamic>{'counted': true} as T);
  }

  @override
  Future<LaravelResponse<T>> put<T>(String path, {dynamic data}) async {
    puts.add((path, data));
    return LaravelResponse<T>(success: true, data: putResponse as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

const _me = UserModel(id: 'u1', displayName: 'Awa');

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthStateAuthenticated(_me);
}

class _NoUpload extends VideoUploadController {
  @override
  VideoUploadState? build() => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async => null);
  });

  group('Lecture de l’API', () {
    test('label « Témoignage approuvé » et « À la une » depuis badges', () {
      final t = testimonyFromApiJson(_json(badges: ['verified', 'featured'], featuredSource: 'manual'))!;
      expect(t.hasApprovedLabel, isTrue);
      expect(t.isFeaturedBadge, isTrue);
      expect(t.featuredSource, 'manual');
    });

    test('complément « recent » de la une : pas de badge', () {
      final t = testimonyFromApiJson(_json(badges: [], featuredSource: 'recent'))!;
      expect(t.isFeaturedBadge, isFalse);
      expect(t.featuredSource, 'recent');
    });

    test('statut approved seul (publié) : aucun label', () {
      expect(testimonyFromApiJson(_json(badges: []))!.hasApprovedLabel, isFalse);
    });

    test('sans tableau badges : repli sur isVerified, jamais de « À la une »', () {
      final t = testimonyFromApiJson(_json(isVerified: true))!;
      expect(t.hasApprovedLabel, isTrue);
      expect(t.isFeaturedBadge, isFalse);
      expect(testimonyFromApiJson(_json())!.hasApprovedLabel, isFalse);
    });

    test('approval_badge de l’auteur (prioritaire), repli sur la vérification', () {
      AccountApprovalBadge? badgeOf(Map<String, dynamic> user) =>
          testimonyFromApiJson(_json(user: {'id': 'u1', 'display_name': 'X', ...user}))!.author.approvalBadge;
      expect(badgeOf({'approval_badge': 'approved_organization', 'account_type': 'organization'}),
          AccountApprovalBadge.organization);
      expect(badgeOf({'approval_badge': 'approved_personal'}), AccountApprovalBadge.personal);
      // approval_badge présent mais null : pas de badge, même si is_verified.
      expect(badgeOf({'approval_badge': null, 'is_verified': true}), isNull);
      // Champ absent : repli sur la vérification (le badge EST la vérification).
      expect(badgeOf({'is_verified': true, 'account_type': 'individual'}), AccountApprovalBadge.personal);
      expect(badgeOf({}), isNull);
    });

    test('UserModel : approval_badge et isApproved', () {
      final u = UserModel.fromJson({
        'id': 'u1',
        'display_name': 'Église',
        'account_type': 'organization',
        'is_approved': true,
        'approval_badge': 'approved_organization',
        'approval_source': 'organization_review',
      });
      expect(u.approvalBadge, AccountApprovalBadge.organization);
      expect(u.isApproved, isTrue);
      expect(UserModel.fromJson(u.toJson()).approvalBadge, AccountApprovalBadge.organization);
    });

    test('UserModel : approved_at (date du badge), conservée dans le cache', () {
      final u = UserModel.fromJson({
        'id': 'u1',
        'display_name': 'Marie',
        'approval_badge': 'approved_personal',
        'approved_at': '2026-10-14T09:12:00+01:00',
      });
      expect(u.approvedAt, DateTime.utc(2026, 10, 14, 8, 12));
      expect(UserModel.fromJson(u.toJson()).approvedAt, u.approvedAt);
      expect(UserModel.fromJson({'id': 'u2', 'display_name': 'X', 'approved_at': null}).approvedAt, isNull);
    });

    test('badge retiré : type de push dédié, profil rechargé', () {
      expect(PushService.accountBadgeTypes, contains('account_approval_revoked'));
      expect(PushService.accountBadgeTypes, containsAll(['account_verified', 'organization_verified']));
    });

    test('Mes publications : statuts, motif, label', () {
      final rejected = UserTestimony.fromJson(_json(status: 'rejected', rejectionReason: 'Contenu incomplet'));
      expect(rejected.statusLabel, 'Refusé');
      expect(rejected.rejectionReason, 'Contenu incomplet');
      expect(UserTestimony.fromJson(_json(status: 'pending')).statusLabel, 'En attente');
      final published = UserTestimony.fromJson(_json(badges: ['verified']));
      expect(published.statusLabel, 'Publié');
      expect(published.hasApprovedLabel, isTrue);
    });
  });

  group('Badges (widgets)', () {
    Future<void> pump(WidgetTester tester, Widget child) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));

    testWidgets('« Témoignage approuvé » : libellé, info-bulle, accessibilité', (tester) async {
      final t = testimonyFromApiJson(_json(badges: ['verified']))!;
      await pump(tester, TestimonyLabels(testimony: t));
      expect(find.text('Témoignage approuvé'), findsOneWidget);
      expect(find.byTooltip('Vérifié par l\'équipe de modération'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Témoignage approuvé')), findsOneWidget);
      expect(find.text('À la une'), findsNothing);
    });

    testWidgets('« À la une » seulement pour une mise à la une manuelle', (tester) async {
      await pump(tester, TestimonyLabels(testimony: testimonyFromApiJson(_json(badges: ['featured']))!));
      expect(find.text('À la une'), findsOneWidget);
      await pump(tester, TestimonyLabels(testimony: testimonyFromApiJson(_json(featuredSource: 'recent', badges: []))!));
      expect(find.text('À la une'), findsNothing);
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('badge de compte : deux styles distincts', (tester) async {
      await pump(
        tester,
        const Row(mainAxisSize: MainAxisSize.min, children: [
          AccountApprovalIcon(badge: AccountApprovalBadge.personal),
          AccountApprovalIcon(badge: AccountApprovalBadge.organization),
        ]),
      );
      final personal = tester.widget<Icon>(find.byKey(const ValueKey('approval-personal')));
      final org = tester.widget<Icon>(find.byKey(const ValueKey('approval-organization')));
      expect(personal.icon, Icons.verified_rounded);
      expect(personal.color, AppColors.primary);
      expect(org.icon, Icons.verified_user_rounded);
      expect(org.color, AppColors.secondaryDark);
      expect(find.byTooltip('Compte approuvé'), findsOneWidget);
      expect(find.byTooltip('Organisation approuvée'), findsOneWidget);
    });

    testWidgets('OrganizationBadge : approval_badge prioritaire, organisation non approuvée discrète', (tester) async {
      await pump(
        tester,
        const Row(mainAxisSize: MainAxisSize.min, children: [
          // Le serveur dit « organisation approuvée » même si l'ancien champ est faux.
          OrganizationBadge(isOrganization: true, isVerified: false, approvalBadge: AccountApprovalBadge.organization),
          OrganizationBadge(isOrganization: true, isVerified: false),
          OrganizationBadge(isOrganization: false, isVerified: false),
        ]),
      );
      expect(find.byKey(const ValueKey('approval-organization')), findsOneWidget);
      expect(find.byTooltip('Organisation'), findsOneWidget);
      expect(find.byType(AccountApprovalIcon), findsOneWidget);
    });
  });

  group('Filtre « Approuvés » et tri', () {
    test('paramètres de GET /testimonies', () {
      expect(const FeedQuery().toQuery(page: 1), {'sort': 'for_you', 'limit': 20, 'page': 1});
      expect(
        const FeedQuery(sort: FeedSort.mostViewed, verifiedOnly: true).toQuery(page: 2),
        {'sort': 'most_viewed', 'limit': 20, 'page': 2, 'verified': 1},
      );
      expect(FeedSort.popular.apiValue, 'popular');
      expect(FeedSort.recent.apiValue, 'recent');
    });

    testWidgets('puce « Approuvés » et menu de tri : rechargement avec les bons paramètres', (tester) async {
      final api = _Api();
      await tester.pumpWidget(ProviderScope(
        overrides: [apiServiceProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              final feed = ref.watch(feedProvider);
              return Column(children: [
                const FeedFilterBar(),
                Text('${feed.length} témoignages', key: const ValueKey('count')),
              ]);
            }),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(api.gets.last.$2?['sort'], 'for_you');
      expect(api.gets.last.$2?.containsKey('verified'), isFalse);
      expect(find.text('2 témoignages'), findsOneWidget);

      await tester.tap(find.text('Approuvés'));
      await tester.pumpAndSettle();
      expect(api.gets.last.$2?['verified'], 1);
      // Repli local : seul le témoignage avec le label reste, même si le serveur ignore le filtre.
      expect(find.text('1 témoignages'), findsOneWidget);
      final chip = tester.widget<FilterChip>(find.byKey(const ValueKey('feed-filter-verified')));
      expect(chip.selected, isTrue);

      await tester.tap(find.byKey(const ValueKey('feed-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plus vus').last);
      await tester.pumpAndSettle();
      expect(api.gets.last.$2?['sort'], 'most_viewed');
      expect(api.gets.last.$2?['verified'], 1);
      expect(find.text('Tri : Plus vus'), findsOneWidget);
    });
  });

  group('Mes publications', () {
    Future<_Api> pumpScreen(WidgetTester tester, List<Map<String, dynamic>> mine) async {
      final api = _Api()..mine = mine;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(api),
        authStateProvider.overrideWith(_Auth.new),
        videoUploadProvider.overrideWith(_NoUpload.new),
      ]);
      addTearDown(c.dispose);
      // Session prête avant l'écran, comme dans l'application.
      await tester.runAsync(() => c.read(authStateProvider.future));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: MyTestimoniesScreen()),
      ));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('GET /testimonies/my ; refusé : motif et « Modifier et renvoyer »', (tester) async {
      final api = await pumpScreen(tester, [
        _json(id: 'r1', status: 'rejected', rejectionReason: 'Merci de préciser les faits.'),
        _json(id: 'p1', status: 'pending'),
      ]);
      expect(api.gets.any((g) => g.$1 == AppConstants.myTestimonies), isTrue);
      expect(find.text('Refusé'), findsOneWidget);
      // « En attente » : onglet + badge de statut.
      expect(find.text('En attente'), findsNWidgets(2));
      expect(find.text('Merci de préciser les faits.'), findsOneWidget);
      expect(find.byKey(const ValueKey('resubmit-button')), findsOneWidget);
    });

    testWidgets('renvoi : PUT /testimonies/{id}, statut mis à jour d’après le serveur', (tester) async {
      final api = await pumpScreen(tester, [
        _json(id: 'r1', status: 'rejected', rejectionReason: 'Merci de préciser les faits.'),
      ]);
      api.putResponse = _json(id: 'r1', status: 'pending');
      await tester.tap(find.byKey(const ValueKey('resubmit-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Titre'), 'Guérie : les faits');
      await tester.tap(find.byKey(const ValueKey('resubmit-save')));
      await tester.pumpAndSettle();
      expect(api.puts.single.$1, AppConstants.testimonyById('r1'));
      expect((api.puts.single.$2 as Map)['title'], 'Guérie : les faits');
      expect(find.text('Renvoyé en modération'), findsOneWidget);
      // Statut repris de la réponse : badge « En attente » (en plus de l'onglet).
      expect(find.text('En attente'), findsNWidgets(2));
      expect(find.text('Refusé'), findsNothing);
    });

    test('publié : confirmation, et mention du label s’il l’avait', () {
      final plain = UserTestimony.fromJson(_json(badges: []));
      final verified = UserTestimony.fromJson(_json(badges: ['verified']));
      expect(publishedEditWarning(plain),
          'Votre témoignage repassera en modération et ne sera plus visible jusqu\'à sa validation. Continuer ?');
      expect(publishedEditWarning(plain), isNot(contains('label')));
      expect(publishedEditWarning(verified), contains('Il perdra aussi son label Témoignage approuvé.'));
    });

    testWidgets('publié avec label : confirmation avant d’enregistrer', (tester) async {
      final api = await pumpScreen(tester, [_json(id: 'a1', badges: ['verified'])]);
      api.putResponse = _json(id: 'a1', status: 'pending');
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('resubmit-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Il perdra aussi son label Témoignage approuvé.'), findsOneWidget);
      expect(api.puts, isEmpty, reason: 'rien n’est envoyé avant la confirmation');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(api.puts, hasLength(1));
      expect(find.text('Renvoyé en modération'), findsOneWidget);
    });
  });

  group('Vue comptée', () {
    test('une seule fois par témoignage et par session ; réessai après un échec', () async {
      final api = _Api();
      final c = ProviderContainer(overrides: [apiServiceProvider.overrideWithValue(api)]);
      addTearDown(c.dispose);
      final tracker = c.read(testimonyViewTrackerProvider.notifier);
      await tracker.record('t1');
      await tracker.record('t1');
      expect(api.posts.where((p) => p.$1 == AppConstants.testimonyView('t1')), hasLength(1));
      expect((api.posts.single.$2 as Map)['device_id'], isNotEmpty);

      api.postError = Exception('hors connexion');
      await tracker.record('t2');
      api.postError = null;
      await tracker.record('t2');
      expect(api.posts.where((p) => p.$1 == AppConstants.testimonyView('t2')), hasLength(2));
    });
  });
}
