import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart' show currentUserProvider;
import 'package:testi_app/features/community/data/community_repository.dart';
import 'package:testi_app/features/community/models/community_account.dart';
import 'package:testi_app/features/community/providers/follow_provider.dart';
import 'package:testi_app/features/live/controllers/live_room_controller.dart';
import 'package:testi_app/features/live/data/live_repository.dart';
import 'package:testi_app/features/live/models/live_models.dart';
import 'package:testi_app/services/api_service.dart' show LaravelApiException;
import 'package:testi_app/shared/models/user_model.dart';

/// Faux dépôt « Communauté » : échoue quand on le lui demande.
class _FakeCommunityRepo implements CommunityRepository {
  bool fail = false;
  final calls = <String>[];

  @override
  Future<Set<String>> followingIds() async => {'already'};

  @override
  Future<FollowResult> follow(String id) async {
    calls.add('follow:$id');
    if (fail) throw const LaravelApiException(message: 'Refusé par le serveur', statusCode: 422);
    return const FollowResult(following: true, followerCount: 5);
  }

  @override
  Future<FollowResult> unfollow(String id) async {
    calls.add('unfollow:$id');
    return const FollowResult(following: false, followerCount: 4);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeLiveRepo implements LiveRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ProviderContainer _container(_FakeCommunityRepo repo, {String? me = 'me'}) => ProviderContainer(overrides: [
      communityRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(me == null ? null : UserModel(id: me, displayName: 'Moi')),
    ]);

void main() {
  test('compte de la Communauté (UserResource)', () {
    final a = CommunityAccount.fromJson({
      'id': 'o1', 'display_name': 'Église de la Grâce', 'account_type': 'organization',
      'organization_type': 'church', 'organization_city': 'Cotonou', 'country': 'Bénin',
      'is_verified': true, 'follower_count': 12, 'testimony_count': 3, 'is_following': true,
      'email': null,
    });
    expect(a.isOrganization, isTrue);
    expect(a.isVerified, isTrue);
    expect(a.subtitle, 'Église · Cotonou · Bénin');
    expect(a.isFollowing, isTrue);
    expect(a.initials, 'ÉD');

    final guestView = CommunityAccount.fromJson({'id': 'p1', 'display_name': 'Awa', 'country': 'Togo'});
    expect(guestView.isFollowing, isNull, reason: 'inconnu sans connexion');
    expect(guestView.subtitle, 'Togo');
  });

  test('Suivre : affiché tout de suite, confirmé par le serveur', () async {
    final repo = _FakeCommunityRepo();
    final c = _container(repo);
    addTearDown(c.dispose);
    c.read(followProvider);
    await Future<void>.delayed(Duration.zero); // chargement des comptes suivis
    expect(c.read(followProvider).isFollowing('already'), isTrue);

    final count = await c.read(followProvider.notifier).toggle('o1');
    expect(count, 5);
    expect(c.read(followProvider).isFollowing('o1'), isTrue);

    expect(await c.read(followProvider.notifier).toggle('o1'), 4);
    expect(c.read(followProvider).isFollowing('o1'), isFalse);
    expect(repo.calls, ['follow:o1', 'unfollow:o1']);
  });

  test('Suivre : erreur du serveur → état rétabli, message affichable', () async {
    final repo = _FakeCommunityRepo()..fail = true;
    final c = _container(repo);
    addTearDown(c.dispose);

    await expectLater(c.read(followProvider.notifier).toggle('o1'), throwsA(isA<FollowFailure>()));
    expect(c.read(followProvider).isFollowing('o1'), isFalse);
    expect(c.read(followProvider).pending, isEmpty);
  });

  test('on ne se suit pas soi-même ; sans connexion, invitation à se connecter', () async {
    final c = _container(_FakeCommunityRepo());
    addTearDown(c.dispose);
    await expectLater(c.read(followProvider.notifier).toggle('me'),
        throwsA(isA<FollowFailure>().having((e) => e.message, 'message', contains('vous-même'))));

    final guest = _container(_FakeCommunityRepo(), me: null);
    addTearDown(guest.dispose);
    await expectLater(guest.read(followProvider.notifier).toggle('o1'),
        throwsA(isA<FollowFailure>().having((e) => e.message, 'message', contains('Connectez-vous'))));
  });

  // ── Directs ──────────────────────────────────────────────────────────────

  final liveJson = {
    'id': 'l1', 'title': 'Direct', 'status': 'live', 'commentsEnabled': true,
    'host': {'id': 'h1', 'displayName': 'Pasteur', 'initials': 'P'},
    'stats': {'peakViewers': 0, 'commentCount': 0, 'reactions': {}},
    'isHost': false, 'canModerate': true,
  };
  Map<String, dynamic> comment(String id, String userId) => {
        'id': id, 'body': 'x', 'user': {'id': userId, 'displayName': 'X', 'initials': 'X'},
      };

  test('message épinglé du diffuseur : seul le diffuseur le retire', () {
    LiveRoomController ctrl({required bool host, required String pinnedBy}) => LiveRoomController(
          repository: _FakeLiveRepo(),
          live: LiveSession.fromJson({...liveJson, 'pinnedComment': comment('p', pinnedBy)}),
          isHostMode: host,
        );

    expect(ctrl(host: false, pinnedBy: 'h1').canChangePin, isFalse, reason: 'modérateur spectateur');
    expect(ctrl(host: true, pinnedBy: 'h1').canChangePin, isTrue);
    expect(ctrl(host: false, pinnedBy: 'u9').canChangePin, isTrue, reason: 'message d\'un spectateur');
  });

  test('qui regarde : comptes connectés et visiteurs', () {
    final v = LiveViewers.fromJson({
      'total': 3, 'anonymous': 1,
      'people': [
        {'id': 'u1', 'displayName': 'Awa', 'initials': 'A', 'avatarUrl': null},
        {'id': 'u2', 'displayName': 'Jean', 'initials': 'J'},
      ],
    });
    expect(v.total, 3);
    expect(v.anonymous, 1);
    expect(v.people.map((p) => p.displayName), ['Awa', 'Jean']);
  });
}
