// « Mon fil » : partages (« X a partagé »), suggestions et tous les types d'éléments insérés
// (événement, session de prière, requête de prière, parole prophétique) sans débordement
// sur un petit écran avec une grande police ; feuille « Partager sur TestiApp ».

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/core/providers/categories_provider.dart';
import 'package:testi_app/features/community/data/community_repository.dart';
import 'package:testi_app/features/community/models/suggested_account.dart';
import 'package:testi_app/features/community/providers/suggestions_provider.dart';
import 'package:testi_app/features/downloads/providers/downloads_provider.dart';
import 'package:testi_app/features/events/models/event_models.dart';
import 'package:testi_app/features/feed/feed_inserts.dart';
import 'package:testi_app/features/feed/personal_feed_screen.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/live/data/live_repository.dart' show livesIndexProvider;
import 'package:testi_app/features/live/models/live_models.dart' show LivesIndex;
import 'package:testi_app/features/prayer/models/prayer_models.dart';
import 'package:testi_app/features/prophecies/models/public_prophecy.dart';
import 'package:testi_app/features/repost/repost.dart';
import 'package:testi_app/features/repost/repost_widgets.dart';
import 'package:testi_app/shared/widgets/guest_gate.dart';

const _longName = 'Ministère International Lumière du Monde pour la Restauration';
const _longTitle = 'Un très long titre de témoignage pour vérifier le retour à la ligne dans le fil';

const _author = TestimonyAuthor(uid: 'u1', displayName: _longName, isOrganization: true, isVerified: true);
const _stats = TestimonyStats(views: 123456, comments: 98765, likes: 1234567, prayers: 45678);

TextTestimony _text(String id, {int days = 1}) => TextTestimony(
      id: id,
      author: _author,
      title: _longTitle,
      category: TestimonyCategory.guerison,
      createdAt: DateTime.now().subtract(Duration(days: days)),
      stats: _stats,
      preview: 'Le Seigneur a **transformé** ma vie. Voici mon histoire, longue et pleine de rebondissements.',
    );

final _repost = RepostInfo.fromFeedItem({
  'feedReason': 'repost',
  'repostId': 'rp1',
  'repostedBy': {'id': 'u9', 'display_name': _longName},
  'repostComment': 'Ce témoignage m’a beaucoup touché, lisez-le jusqu’au bout ! ' * 3,
  'repostedAt': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
})!;

final _entries = [
  PersonalFeedEntry(_text('t1'), suggested: false, repost: _repost),
  PersonalFeedEntry(_text('t2'), suggested: false),
  PersonalFeedEntry(_text('t3'), suggested: true),
  for (var i = 4; i <= 24; i++) PersonalFeedEntry(_text('t$i', days: i), suggested: i.isOdd),
];

class _FakePersonalFeed extends PersonalFeedNotifier {
  @override
  Future<PersonalFeedState> build() async =>
      PersonalFeedState(items: _entries, followingCount: 3, hasMore: false);

  @override
  Future<void> loadMore() async {}
}

final _inserts = FeedInserts(
  following: FeedInsertGroup(
    events: [
      ChristianEvent.fromJson({
        'id': 'e1',
        'title': 'Grande croisade d’évangélisation $_longName',
        'type': 'crusade',
        'status': 'published',
        'phase': 'upcoming',
        'startsAt': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
        'endsAt': DateTime.now().add(const Duration(days: 6)).toIso8601String(),
        'city': 'Cotonou',
        'location': 'Stade de l’Amitié Général Mathieu Kérékou',
        'organizer': {'id': 'u1', 'displayName': _longName, 'isVerified': true},
      }),
    ],
    prayerSessions: [
      PrayerSession.fromJson({
        'id': 'ps1',
        'title': 'Veillée de prière pour la nation et pour $_longName',
        'description': 'Intercession, louange et témoignages. ' * 4,
        'startsAt': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'durationMinutes': 120,
        'visibility': 'followers',
        'phase': 'upcoming',
        'host': {'id': 'u1', 'displayName': _longName},
        'participantCount': 1520,
        'isRegistered': true,
      }),
    ],
    prophecies: [
      PublicProphecy.tryParse({
        'id': 'pp1',
        'title': 'Une maison pour ma famille avant la fin de l’année',
        'bodyText': 'Tu auras ta maison avant la fin de l’année, dit l’Éternel. ' * 5,
        'givenBy': 'Prophète $_longName',
        'receivedOn': '2025-01-12',
        'fulfilledOn': '2026-09-30',
        'user': {'id': 'u1', 'display_name': _longName},
        'testimony': {'id': 't99', 'title': _longTitle},
      })!,
    ],
  ),
  others: FeedInsertGroup(
    prayerRequests: [
      PrayerRequest.fromJson({
        'id': 'pr1',
        'body': 'Priez pour la guérison de ma mère et pour notre famille. ' * 4,
        'visibility': 'public',
        'isAnonymous': true,
        'prayerCount': 1520,
        'messageCount': 37,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    ],
  ),
);

class _FakeCommunity implements CommunityRepository {
  @override
  Future<Set<String>> followingIds() async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeDownloads extends DownloadsNotifier {
  @override
  DownloadsState build() => const DownloadsState(loaded: true, supported: true);
}

class _FakeRepostRepository implements RepostRepository {
  final calls = <String>[];

  @override
  Future<RepostResult> repost(String testimonyId, {String? comment}) async {
    calls.add('repost $testimonyId ${comment ?? ''}');
    return const RepostResult(message: 'Témoignage partagé avec vos abonnés.', reposted: true, count: 1);
  }

  @override
  Future<RepostResult> remove(String testimonyId) async {
    calls.add('remove $testimonyId');
    return const RepostResult(message: 'Partage annulé.', reposted: false, count: 0);
  }
}

Widget _app(Widget child, {double textScale = 1.0, List overrides = const []}) => ProviderScope(
      overrides: [
        personalFeedProvider.overrideWith(_FakePersonalFeed.new),
        feedInsertsProvider.overrideWith((ref) async => _inserts),
        livesIndexProvider.overrideWith((ref) async => LivesIndex.fromJson({
              'configured': true,
              'active': [
                {
                  'id': 'l1',
                  'title': 'Soirée de louange et de témoignages $_longName',
                  'status': 'live',
                  'host': {'id': 'u1', 'displayName': _longName},
                  'liveStats': {'status': 'live', 'viewers': 1240},
                },
              ],
            })),
        isGuestProvider.overrideWithValue(false),
        // Comptes à suivre (après les premiers éléments du fil) : nom long.
        communityRepositoryProvider.overrideWithValue(_FakeCommunity()),
        suggestedAccountsProvider.overrideWith((ref) async => [
              SuggestedAccount.fromJson({
                'id': 'o9',
                'display_name': _longName,
                'account_type': 'organization',
                'isOrganization': true,
                'isVerified': true,
                'followersCount': 12000,
                'isFollowing': false,
                'reason': 'Suivi par $_longName et 2 autres que vous suivez',
              }),
            ]),
        downloadsProvider.overrideWith(_FakeDownloads.new),
        categoriesListProvider.overrideWithValue(const [
          CategoryModel(id: '1', name: 'Guérison', slug: 'guerison'),
        ]),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: child,
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['plugin.csdcorp.com/speech_to_text', 'plugins.it_nomads.com/flutter_secure_storage']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
    }
  });

  test('ordre des insertions : comptes suivis d’abord, sources en alternance', () {
    expect(_inserts.mixed.map((o) => o.runtimeType.toString()).toList(),
        ['ChristianEvent', 'PrayerSession', 'PublicProphecy', 'PrayerRequest']);
  });

  test('un élément de Mon fil sans partage n’a pas de RepostInfo', () {
    expect(RepostInfo.fromFeedItem({'feedReason': 'following'}), isNull);
    expect(_repost.byName, _longName);
    expect(_repost.comment, isNotNull);
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Mon fil avec tous les types d’insertion sans débordement ($width px, ×$scale)', (tester) async {
        tester.view.physicalSize = Size(width * 2, 1800);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app(const PersonalFeedScreen(), textScale: scale));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('a partagé'), findsOneWidget);

        final seen = <String>{};
        final scrollable = find.byType(Scrollable).first;
        for (var i = 0; i < 70; i++) {
          for (final label in [
            'Suggestion pour vous',
            'Session de prière · $_longName',
            'Parole prophétique accomplie · $_longName',
            'Requête de prière',
            'Événement à venir · $_longName',
            'Comptes à suivre',
          ]) {
            if (find.text(label).evaluate().isNotEmpty) seen.add(label);
          }
          await tester.drag(scrollable, const Offset(0, -300));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        expect(seen, containsAll(<String>[
          'Suggestion pour vous',
          'Session de prière · $_longName',
          'Parole prophétique accomplie · $_longName',
          'Requête de prière',
          'Événement à venir · $_longName',
          'Comptes à suivre',
        ]));
      });
    }
  }

  testWidgets('feuille « Partager sur TestiApp » : commentaire, partage puis annulation', (tester) async {
    final repo = _FakeRepostRepository();
    final container = ProviderContainer(overrides: [
      repostRepositoryProvider.overrideWithValue(repo),
      isGuestProvider.overrideWithValue(false),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showRepostSheet(context, ref, testimonyId: 't1', authorName: _longName),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Partager sur TestiApp'), findsOneWidget);
    expect(find.textContaining('avec son auteur'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Dieu est fidèle');
    await tester.tap(find.text('Partager avec mes abonnés'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['repost t1 Dieu est fidèle']);
    expect(container.read(repostedByMeProvider)['t1'], isTrue);
    expect(find.text('Témoignage partagé avec vos abonnés.'), findsOneWidget);

    // Déjà partagé : « Mettre à jour », puis annulation.
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Mettre à jour mon partage'), findsOneWidget);
    await tester.tap(find.text('Annuler mon partage'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'remove t1');
    expect(container.read(repostedByMeProvider)['t1'], isFalse);
  });
}
