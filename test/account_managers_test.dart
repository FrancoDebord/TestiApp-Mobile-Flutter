// Administrateurs de compte : en-tête X-Act-As (ajouté / exclu selon les chemins),
// refus acting_as_forbidden, lecture de GET /users/me/accounts, bandeau « Vous
// agissez au nom de X » sans débordement (320 px, ×1.3), feuille « Mes comptes ».

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/accounts/data/accounts_repository.dart';
import 'package:testi_app/features/accounts/models/account_models.dart';
import 'package:testi_app/features/accounts/providers/acting_account_provider.dart';
import 'package:testi_app/features/accounts/widgets/account_widgets.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/notifications/models/notification_models.dart';
import 'package:testi_app/features/notifications/providers/notifications_provider.dart';
import 'package:testi_app/services/acting_as_interceptor.dart';
import 'package:testi_app/services/api_service.dart' show actingAsStoreProvider;
import 'package:testi_app/shared/models/user_model.dart';

// ── Intercepteur ─────────────────────────────────────────────────────────────

/// Adaptateur HTTP factice : mémorise les en-têtes et répond [status] / [body].
class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 200, this.body = const {'success': true, 'data': {}}});

  final int status;
  final Map<String, dynamic> body;
  final sent = <String, Object?>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    sent['${options.method} ${options.path}'] = options.headers[kActingAsHeader];
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(ActingAsStore store, _Adapter adapter) => Dio(BaseOptions(baseUrl: 'https://example.org/api/v1'))
  ..httpClientAdapter = adapter
  ..interceptors.add(ActingAsInterceptor(store));

// ── Comptes ──────────────────────────────────────────────────────────────────

const _accountsJson = {
  'accounts': [
    {
      'id': 'me',
      'displayName': 'Awa Kossou',
      'username': 'awa',
      'initials': 'AK',
      'avatarUrl': null,
      'isOrganization': false,
      'isVerified': false,
      'role': 'owner',
      'since': null,
    },
    {
      'id': 'org-1',
      'displayName': 'Ministère International Lumière du Monde pour la Restauration des Nations',
      'username': 'lumiere',
      'initials': 'ML',
      'avatarUrl': null,
      'isOrganization': true,
      'isVerified': true,
      'role': 'manager',
      'since': '2026-10-01T09:00:00+00:00',
    },
  ],
  'actingAs': null,
};

class _FakeRepo implements AccountsRepository {
  final calls = <String>[];

  @override
  Future<AccountsSnapshot> accounts() async {
    calls.add('accounts');
    return AccountsSnapshot.fromJson(_accountsJson);
  }

  @override
  Future<UserModel> me() async {
    calls.add('me');
    return const UserModel(
      id: 'org-1',
      displayName: 'Ministère Lumière',
      accountType: AccountType.organization,
      isVerified: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _me = UserModel(id: 'me', displayName: 'Awa Kossou');

class _FakeAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthStateAuthenticated(_me);
}

class _FixedActing extends ActingAccountNotifier {
  _FixedActing(this.value);
  final ActingAccount? value;

  @override
  ActingAccount? build() => value;
}

final _orgAccount = AccountSummary.fromJson(Map<String, dynamic>.from(
    (_accountsJson['accounts']! as List)[1] as Map));

Future<void> _setPhone(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * 2, 1400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Widget _scaled(Widget child, double scale) => MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: child,
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('en-tête X-Act-As', () {
    test('ajouté sur les requêtes ordinaires, jamais sur les chemins réservés au titulaire', () async {
      final store = ActingAsStore()..accountId = 'org-1';
      final adapter = _Adapter();
      final dio = _dio(store, adapter);

      final withHeader = [
        ('GET', '/testimonies'),
        ('POST', '/testimonies'),
        ('GET', '/users/me'),
        ('PUT', '/users/me'),
        ('GET', '/users/me/accounts'),
        ('POST', '/events'),
        ('POST', '/prayer-requests'),
        ('POST', '/users/42/follow'),
      ];
      final withoutHeader = [
        ('GET', '/auth/me'),
        ('POST', '/auth/refresh'),
        ('POST', '/auth/logout'),
        ('POST', '/devices/token'),
        ('DELETE', '/devices/token'),
        ('GET', '/users/me/managers'),
        ('POST', '/users/me/managers'),
        ('DELETE', '/users/me/managers/7'),
        ('GET', '/users/me/managers/activity'),
        ('GET', '/users/me/managed-organizations'),
        ('DELETE', '/users/me/managed-organizations/org-1'),
        ('GET', '/users/me/verification'),
        ('PUT', '/users/me/location'),
        ('PUT', '/users/me/settings'),
        ('GET', '/admin/users'),
        ('GET', '/moderation'),
        ('GET', '/journal'),
        ('GET', '/journal/3'),
        ('GET', '/prophecies/5/prayers'),
        ('DELETE', '/users/me'),
        ('POST', 'https://example.org/api/v1/auth/login'),
      ];
      for (final (m, p) in [...withHeader, ...withoutHeader]) {
        await dio.request<dynamic>(p, options: Options(method: m));
      }
      for (final (m, p) in withHeader) {
        expect(adapter.sent['$m $p'], 'org-1', reason: '$m $p');
      }
      for (final (m, p) in withoutHeader) {
        expect(adapter.sent['$m $p'], isNull, reason: '$m $p');
      }
    });

    test('aucun en-tête quand on agit pour son propre compte', () async {
      final adapter = _Adapter();
      await _dio(ActingAsStore(), adapter).get<dynamic>('/testimonies');
      expect(adapter.sent['GET /testimonies'], isNull);
    });

    test('403 acting_as_forbidden : retour sur son compte avec le message', () async {
      String? message;
      final store = ActingAsStore()
        ..accountId = 'org-1'
        ..onForbidden = (m) => message = m;
      final adapter = _Adapter(status: 403, body: {
        'success': false,
        'code': 'acting_as_forbidden',
        'message': "Vous n'administrez plus ce compte.",
      });
      await expectLater(_dio(store, adapter).get<dynamic>('/testimonies'), throwsA(isA<DioException>()));
      expect(message, "Vous n'administrez plus ce compte.");
    });

    test('403 owner_only : pas de retour automatique', () async {
      var called = false;
      final store = ActingAsStore()
        ..accountId = 'org-1'
        ..onForbidden = (_) => called = true;
      final adapter = _Adapter(status: 403, body: {'success': false, 'code': 'owner_only', 'message': 'Réservé'});
      await expectLater(_dio(store, adapter).get<dynamic>('/testimonies'), throwsA(isA<DioException>()));
      expect(called, isFalse);
    });
  });

  group('modèles', () {
    test('GET /users/me/accounts : son compte en premier, puis les comptes administrés', () {
      final snap = AccountsSnapshot.fromJson(_accountsJson);
      expect(snap.accounts, hasLength(2));
      expect(snap.owner!.id, 'me');
      expect(snap.owner!.isOwner, isTrue);
      expect(snap.managed.single.id, 'org-1');
      expect(snap.managed.single.isOrganization, isTrue);
      expect(snap.managed.single.isVerified, isTrue);
      expect(snap.managed.single.since, DateTime.parse('2026-10-01T09:00:00+00:00'));
      expect(snap.actingAs, isNull);

      final placeholder = snap.managed.single.toPlaceholderUser();
      expect(placeholder.id, 'org-1');
      expect(placeholder.isOrganization, isTrue);
    });

    test('compte actif : aller-retour JSON (persistance)', () {
      final acting = ActingAccount(ownerId: 'me', account: _orgAccount);
      final back = ActingAccount.fromJson(jsonDecode(jsonEncode(acting.toJson())) as Map<String, dynamic>)!;
      expect(back.ownerId, 'me');
      expect(back.id, 'org-1');
      expect(back.asUser.id, 'org-1');
      expect(ActingAccount.fromJson({'ownerId': '', 'account': {}}), isNull);
    });

    test('administrateurs et journal des actions', () {
      final m = AccountManagers.fromJson({
        'max': 2,
        'managers': [
          {'id': 'u-2', 'displayName': 'Paul Martin', 'initials': 'PM', 'since': '2026-09-01T00:00:00Z'},
        ],
      });
      expect(m.managers.single.displayName, 'Paul Martin');
      expect(m.isFull, isFalse);
      final a = ManagerActivity.fromJson(
          {'id': 1, 'actorId': 2, 'actorName': 'Paul', 'action': 'a publié un témoignage', 'createdAt': '2026-10-02T08:00:00Z'});
      expect(a.actorId, '2');
      expect(a.action, 'a publié un témoignage');
    });

    test('notifications account_manager_added / removed', () {
      final added = notificationFromJson(
          {'id': 'n1', 'type': 'account_manager_added', 'actorName': 'Awa', 'createdAt': '2026-10-06T10:00:00Z'})!;
      expect(added.type, NotificationType.accountManagerAdded);
      expect(added.isSystemType, isTrue);
      expect(added.opensAccountManagers, isTrue);
      expect(added.body, 'Awa vous a nommé administrateur de son compte');
      final removed = notificationFromJson(
          {'id': 'n2', 'type': 'account_manager_removed', 'actorName': 'Awa', 'createdAt': '2026-10-06T10:00:00Z'})!;
      expect(removed.type, NotificationType.accountManagerRemoved);
      expect(removed.title, 'Administration retirée');
    });
  });

  group('bandeau', () {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('sans débordement ($width px, ×$scale)', (tester) async {
          await _setPhone(tester, width);
          await tester.pumpWidget(ProviderScope(
            overrides: [
              actingAccountProvider.overrideWith(
                  () => _FixedActing(ActingAccount(ownerId: 'me', account: _orgAccount))),
            ],
            child: _scaled(const Scaffold(bottomNavigationBar: ActingAsBanner()), scale),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.textContaining('Vous agissez au nom de', findRichText: true), findsOneWidget);
          expect(find.text('Revenir à mon compte'), findsOneWidget);
        });
      }
    }

    testWidgets('masqué quand on agit pour son propre compte', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [actingAccountProvider.overrideWith(() => _FixedActing(null))],
        child: _scaled(const Scaffold(body: ActingAsBanner()), 1),
      ));
      expect(find.text('Revenir à mon compte'), findsNothing);
    });
  });

  group('feuille « Mes comptes »', () {
    testWidgets('liste les comptes, « Vous », coche, puis bascule', (tester) async {
      await _setPhone(tester, 320);
      final repo = _FakeRepo();
      final container = ProviderContainer(overrides: [
        accountsRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith(_FakeAuth.new),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: _scaled(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(onPressed: () => showAccountSwitcher(context), child: const Text('Ouvrir')),
              ),
            ),
          ),
          1.3,
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Ouvrir'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);

      expect(find.text('Mes comptes'), findsOneWidget);
      expect(find.text('Awa Kossou'), findsOneWidget);
      expect(find.text('Vous'), findsOneWidget);
      // Compte actif : le sien.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(find.textContaining('Ministère International'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('me'));
      final acting = container.read(actingAccountProvider);
      expect(acting?.id, 'org-1');
      expect(container.read(actingAsStoreProvider).accountId, 'org-1');
      // « Moi » est désormais le compte administré.
      expect(container.read(currentUserProvider)?.id, 'org-1');
      expect(container.read(realUserProvider)?.id, 'me');
      expect(find.text('Vous agissez au nom de Ministère Lumière'), findsOneWidget);

      // Retour à son compte.
      await container.read(actingAccountProvider.notifier).stopActing();
      expect(container.read(currentUserProvider)?.id, 'me');
      expect(container.read(actingAsStoreProvider).accountId, isNull);
    });
  });
}
