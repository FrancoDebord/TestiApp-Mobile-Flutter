// « Mes abonnés » : onglet Abonnés, « Suivre en retour », passage à l'onglet Abonnements.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart' show currentUserProvider;
import 'package:testi_app/features/community/data/community_repository.dart';
import 'package:testi_app/features/community/models/community_account.dart';
import 'package:testi_app/features/community/screens/following_screen.dart';
import 'package:testi_app/shared/models/user_model.dart';

class _FakeRepo implements CommunityRepository {
  final calls = <String>[];
  List<CommunityAccount> followerList = const [];

  @override
  Future<Set<String>> followingIds() async => {'church'};

  @override
  Future<CommunityPage> followers({String? query, int page = 1}) async {
    calls.add('followers:${query ?? ''}:$page');
    return CommunityPage(followerList, currentPage: 1, lastPage: 1, total: followerList.length);
  }

  @override
  Future<CommunityPage> following({String? query, int page = 1}) async {
    calls.add('following:${query ?? ''}:$page');
    return CommunityPage(
      [CommunityAccount.fromJson(const {'id': 'church', 'display_name': 'Église Lumière', 'is_following': true})],
      currentPage: 1,
      lastPage: 1,
      total: 1,
    );
  }

  @override
  Future<FollowResult> follow(String id) async {
    calls.add('follow:$id');
    return const FollowResult(following: true, followerCount: 1);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _app(_FakeRepo repo, {FollowsTab tab = FollowsTab.followers}) => ProviderScope(
      overrides: [
        communityRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(const UserModel(id: 'me', displayName: 'Moi')),
      ],
      child: MaterialApp(home: FollowsScreen(initialTab: tab)),
    );

void main() {
  testWidgets('abonnés : « Suivre en retour » pour ceux que je ne suis pas, puis « Abonné »', (tester) async {
    final repo = _FakeRepo()
      ..followerList = [
        CommunityAccount.fromJson(const {'id': 'paul', 'display_name': 'Paul Martin', 'is_following': false}),
        CommunityAccount.fromJson(const {'id': 'church', 'display_name': 'Église Lumière', 'is_following': true}),
      ];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('followers::1'));
    expect(find.text('2 comptes vous suivent'), findsOneWidget);
    expect(find.text('Suivre en retour'), findsOneWidget);
    expect(find.text('Abonné'), findsOneWidget);

    await tester.tap(find.text('Suivre en retour'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('follow:paul'));
    expect(find.text('Suivre en retour'), findsNothing);
    expect(find.text('Abonné'), findsNWidgets(2));

    // Onglet Abonnements : la seconde liste se charge.
    await tester.tap(find.text('Abonnements'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('following::1'));
    expect(find.text('Vous suivez 1 compte'), findsOneWidget);
  });

  testWidgets('aucun abonné : message et lien vers la Communauté', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('Personne ne vous suit encore.'), findsOneWidget);
    expect(find.text('Découvrir la Communauté'), findsOneWidget);
  });

  testWidgets('/following ouvre l’onglet Abonnements', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(repo, tab: FollowsTab.following));
    await tester.pumpAndSettle();
    expect(repo.calls.first, 'following::1');
    expect(find.text('Église Lumière'), findsOneWidget);
  });
}
