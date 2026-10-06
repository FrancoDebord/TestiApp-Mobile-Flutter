import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart' show currentUserProvider;
import 'package:testi_app/features/community/data/community_repository.dart';
import 'package:testi_app/features/community/models/suggested_account.dart';
import 'package:testi_app/features/community/providers/follow_provider.dart';
import 'package:testi_app/features/community/providers/suggestions_provider.dart';
import 'package:testi_app/features/community/widgets/suggested_accounts_strip.dart';
import 'package:testi_app/shared/models/user_model.dart';

class _FakeRepo implements CommunityRepository {
  @override
  Future<Set<String>> followingIds() async => {};

  @override
  Future<FollowResult> follow(String id) async => const FollowResult(following: true, followerCount: 1);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

SuggestedAccount _s(String id, String name, String reason, {bool org = false, bool verified = false}) =>
    SuggestedAccount.fromJson({
      'id': id,
      'display_name': name,
      'account_type': org ? 'organization' : 'individual',
      'is_verified': verified,
      'isVerified': verified,
      'isOrganization': org,
      'followersCount': 12,
      'testimonyCount': 4,
      'isFollowing': false,
      'reason': reason,
    });

final _items = [
  _s('o1', 'Église Évangélique de la Grâce Divine de Cotonou', 'Organisation vérifiée', org: true, verified: true),
  _s('p1', 'Awa Témoin', 'Suivi par Jean-Baptiste Kouassi et 2 autres que vous suivez'),
  _s('p2', 'Paul', 'Publie souvent des témoignages'),
];

Widget _app(Future<List<SuggestedAccount>> Function() load, {double scale = 1.0}) => ProviderScope(
      overrides: [
        suggestedAccountsProvider.overrideWith((ref) => load()),
        communityRepositoryProvider.overrideWithValue(_FakeRepo()),
        currentUserProvider.overrideWithValue(const UserModel(id: 'me', displayName: 'Moi')),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(320, 640), textScaler: TextScaler.linear(scale)),
          child: const Scaffold(body: SingleChildScrollView(child: SuggestedAccountsStrip())),
        ),
      ),
    );

void main() {
  test('suggestion : profil public, raison et indicateurs', () {
    final s = _items.first;
    expect(s.account.isOrganization, isTrue);
    expect(s.account.isVerified, isTrue);
    expect(s.account.followerCount, 12);
    expect(s.account.testimonyCount, 4);
    expect(s.account.isFollowing, isFalse);
    expect(s.reason, 'Organisation vérifiée');
  });

  testWidgets('320 px, texte à 130 % : aucun débordement', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(() async => _items, scale: 1.3));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Comptes à suivre'), findsOneWidget);
    expect(find.text('Voir plus'), findsOneWidget);
    expect(find.text('Organisation vérifiée'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(find.text('Suivre'), findsWidgets);
  });

  testWidgets('masqué si la liste est vide ou en erreur', (tester) async {
    await tester.pumpWidget(_app(() async => const []));
    await tester.pumpAndSettle();
    expect(find.text('Comptes à suivre'), findsNothing);

    await tester.pumpWidget(_app(() async => throw Exception('hors ligne')));
    await tester.pumpAndSettle();
    expect(find.text('Comptes à suivre'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la carte suivie disparaît, les autres restent', (tester) async {
    await tester.pumpWidget(_app(() async => _items));
    await tester.pumpAndSettle();
    expect(find.text('Paul'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(SuggestedAccountsStrip)));
    container.read(followProvider.notifier).remember('p2', true);
    await tester.pumpAndSettle();

    expect(find.text('Paul'), findsNothing);
    expect(find.text('Awa Témoin'), findsOneWidget);
  });
}
