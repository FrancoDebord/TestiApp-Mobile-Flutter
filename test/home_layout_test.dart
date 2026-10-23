// Vérifie que l'accueil, l'explorer (découverte + recherche & filtres),
// l'écran de résultats, l'écran catégorie et la barre du bas ne débordent pas
// sur un petit écran, avec une grande taille de police et des textes longs.
// Flutter signale tout débordement (RenderFlex overflowed) comme une erreur.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/events/models/event_models.dart';
import 'package:testi_app/features/events/providers/events_providers.dart';
import 'package:testi_app/features/community/models/suggested_account.dart' show SuggestedAccount;
import 'package:testi_app/features/community/providers/suggestions_provider.dart' show suggestedAccountsProvider;
import 'package:testi_app/core/media/playback_preferences.dart';
import 'package:testi_app/core/providers/categories_provider.dart';
import 'package:testi_app/features/downloads/providers/downloads_provider.dart';
import 'package:testi_app/features/explore/providers/explore_providers.dart';
import 'package:testi_app/features/explore/screens/category_screen.dart';
import 'package:testi_app/features/explore/screens/explore_screen.dart';
import 'package:testi_app/features/explore/screens/search_results_screen.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/home/screens/home_screen.dart';
import 'package:testi_app/features/home/widgets/compact_testimony_tile.dart';
import 'package:testi_app/features/live/data/live_repository.dart' show livesIndexProvider;
import 'package:testi_app/features/live/models/live_models.dart' show LivesIndex;
import 'package:testi_app/features/prayer/models/prayer_models.dart' show PrayerPage, PrayerRequest, PrayerSession;
import 'package:testi_app/features/prayer/widgets/upcoming_prayer_sessions_strip.dart' show upcomingPrayerSessionsProvider;
import 'package:testi_app/features/prayer/providers/prayer_providers.dart' show prayerRequestsPageProvider;
import 'package:testi_app/features/notifications/providers/notifications_provider.dart';
import 'package:testi_app/shared/widgets/guest_gate.dart';
import 'package:testi_app/shared/widgets/scaffold_with_bottom_nav.dart';
import 'package:testi_app/features/conversion/providers/conversion_providers.dart';

const _longName =
    'Ministère International Lumière du Monde pour la Restauration';
const _longTitle = 'Un très long titre de témoignage pour vérifier le retour '
    'à la ligne dans les cartes du fil principal';

final _author = const TestimonyAuthor(
  uid: 'u1',
  displayName: _longName,
  isOrganization: true,
  isVerified: true,
);

const _stats =
    TestimonyStats(views: 123456, comments: 98765, likes: 1234567, prayers: 45678);

final _items = <Testimony>[
  VideoTestimony(
    id: 'v1',
    author: _author,
    title: _longTitle,
    category: TestimonyCategory.guerison,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    stats: _stats,
    durationSeconds: 225,
    thumbnailUrl: '',
    bibleVerse: 'Je suis l’Éternel qui te guérit, et ta foi t’a sauvé.',
    isFeatured: true,
  ),
  AudioTestimony(
    id: 'a1',
    author: _author,
    title: _longTitle,
    category: TestimonyCategory.protection,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    stats: _stats,
    durationSeconds: 312,
    transcriptPreview: 'J’étais dans un état très critique, mais Dieu a agi '
        'au-delà de tout ce que je pouvais imaginer.',
  ),
  TextTestimony(
    id: 't1',
    author: _author,
    title: _longTitle,
    category: TestimonyCategory.delivrance,
    createdAt: DateTime.now().subtract(const Duration(days: 40)),
    stats: _stats,
    preview: 'Le Seigneur a **transformé** ma vie. Voici mon histoire, '
        'longue et pleine de rebondissements, pour Sa gloire.',
    bibleVerseRef: 'Jean 3:16',
  ),
];

class _FakeFeed extends FeedNotifier {
  @override
  List<Testimony> build() => _items;

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

class _FakeVerse extends DailyVerseNotifier {
  @override
  Future<DailyVerse> build() async => const DailyVerse(
        text: '« Car je connais les projets que j’ai formés sur vous. »',
        reference: 'Jérémie 29 : 11',
      );
}

class _FakeDownloads extends DownloadsNotifier {
  @override
  DownloadsState build() =>
      const DownloadsState(loaded: true, supported: true);
}

/// Événement passé avec témoignages (bande « Revivre les événements »).
final _pastEvent = ChristianEvent.fromJson({
  'id': 'p1',
  'title': 'Grande croisade de guérison et de délivrance de Cotonou 2025, trois soirées',
  'type': 'crusade',
  'status': 'published',
  'phase': 'past',
  'startsAt': '2025-08-12T17:00:00+00:00',
  'endsAt': '2025-08-14T21:00:00+00:00',
  'city': 'Cotonou',
  'country': 'Bénin',
  'organizer': {'id': 'o1', 'displayName': 'Église de la Grâce'},
  'stats': {'testimonies': 12},
});

List<Override> get _overrides => [
      feedNotifierProvider.overrideWith(_FakeFeed.new),
      feedIsLoadingProvider.overrideWithBuild((ref, notifier) => false),
      dailyVerseProvider.overrideWith(_FakeVerse.new),
      unreadCountProvider.overrideWithValue(128),
      isGuestProvider.overrideWithValue(false),
      categoriesListProvider.overrideWithValue(const [
        CategoryModel(id: '1', name: 'Guérison', slug: 'guerison'),
        CategoryModel(id: '2', name: 'Délivrance', slug: 'delivrance'),
        CategoryModel(
            id: '3', name: 'Protection divine et délivrance', slug: 'protection'),
        CategoryModel(id: '4', name: 'Emploi & Carrière', slug: 'emploi'),
      ]),
      downloadsProvider.overrideWith(_FakeDownloads.new),
      // Bandeau « Comptes à suivre » : pas d'appel réseau.
      suggestedAccountsProvider.overrideWith((ref) async => const <SuggestedAccount>[]),
      // « À la une » du serveur : pas d'appel réseau (repli sur le fil chargé).
      featuredFromApiProvider.overrideWith((ref) async => const <Testimony>[]),
      // Bandeau « Sessions de prière à venir » : titre et hôte longs, inscrit, réservé aux abonnés.
      upcomingPrayerSessionsProvider.overrideWith((ref) async => [
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
          ]),
      // Bandeau « Événements à venir » : pas d'appel réseau.
      upcomingEventsProvider.overrideWith((ref) async => const <ChristianEvent>[]),
      pastEventsHomeProvider.overrideWith((ref) async => [_pastEvent]),
      latestConversionsProvider.overrideWith((ref) async => const <Testimony>[]),
      myConversionProvider.overrideWith((ref) async => null),
      // Requêtes de prière insérées dans le fil : auteur au nom long, une anonyme.
      prayerRequestsPageProvider(homePrayerRequests).overrideWith((ref) async => PrayerPage(items: [
            for (final (i, anonymous) in [(1, false), (2, true)])
              PrayerRequest.fromJson({
                'id': 'pr$i',
                'body': 'Priez pour la guérison de ma mère et pour notre famille. ' * 4,
                'visibility': 'public',
                'isAnonymous': anonymous,
                'author': anonymous ? null : {'id': 'u$i', 'displayName': _longName, 'isVerified': true},
                'prayerCount': 1520,
                'messageCount': 37,
                'event': {'id': 'e1', 'title': 'Croisade $_longName'},
                'createdAt': DateTime.now().toIso8601String(),
              }),
          ])),
      // Bandeau « En direct » : un direct à l'antenne au titre long (débordement).
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
      for (final c in TestimonyCategory.values)
        categoryApiProvider(c).overrideWith(
            (ref) async => _items.where((t) => t.category == c).toList()),
    ];

Widget _app(Widget child, {double textScale = 1.0, List<Override>? extra}) =>
    ProviderScope(
      overrides: [..._overrides, ...?extra],
      child: MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: child,
      ),
    );

Future<void> _setPhone(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * 2, 1800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Parcourt la liste pour construire toutes les cartes.
Future<void> _scrollAll(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 8; i++) {
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    // speech_to_text / stockage sécurisé : pas de plateforme dans les tests.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'plugin.csdcorp.com/speech_to_text',
      'plugins.it_nomads.com/flutter_secure_storage',
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(name), (call) async => null);
    }
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('accueil sans débordement ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(const HomeScreen(), textScale: scale));
        await tester.pump();
        expect(tester.takeException(), isNull);

        expect(find.text('Tous'), findsOneWidget);
        expect(find.text('Vidéos'), findsOneWidget);
        expect(find.byTooltip('Rechercher'), findsOneWidget);
        expect(find.text('99+'), findsOneWidget);
        await _scrollAll(tester);
      });

      testWidgets('accueil en liste compacte dépliée ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(const HomeScreen(),
            textScale: scale,
            extra: [feedLayoutProvider.overrideWithValue(FeedLayout.compact)]));
        await tester.pump();
        for (final t in find.byType(CompactTestimonyTile).evaluate().toList()) {
          await tester.ensureVisible(find.byWidget(t.widget));
          await tester.pump();
          await tester.tap(find.byTooltip('Déplier').first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await _scrollAll(tester);
      });

      testWidgets('explorer (découverte) sans débordement ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(const ExploreScreen(), textScale: scale));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await _scrollAll(tester);
      });

      testWidgets('recherche & filtres sans débordement ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(const ExploreScreen(), textScale: scale));
        await tester.pump();
        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        expect(find.text('Filtres'), findsOneWidget);
        expect(find.text('Appliquer les filtres'), findsOneWidget);
        expect(find.text('Réinitialiser'), findsOneWidget);
        expect(find.text('Tous les types'), findsOneWidget);
        expect(find.text('Toutes les catégories'), findsOneWidget);
        await _scrollAll(tester);
      });

      testWidgets('résultats de recherche sans débordement ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(
            const SearchResultsScreen(query: 'témoignage'),
            textScale: scale));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('3 témoignages'), findsOneWidget);
        await _scrollAll(tester);
      });

      testWidgets('écran catégorie sans débordement ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(
            _app(const CategoryScreen(slug: 'guerison'), textScale: scale));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        await _scrollAll(tester);
      });

      testWidgets('barre du bas sans débordement ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_NavHarness(textScale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in [
          'Accueil',
          'Explorer',
          'Témoigner',
          'Prières',
          'Profil',
        ]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        await tester.tap(find.text('Prières'));
        await tester.pumpAndSettle();
        expect(find.text('page 4'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();
        expect(find.text('page 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('les onglets de type filtrent le fil', (tester) async {
    await _setPhone(tester, 390);
    late WidgetRef ref;
    await tester.pumpWidget(_app(Consumer(builder: (context, r, _) {
      ref = r;
      return const HomeScreen();
    })));
    await tester.pump();
    expect(ref.read(feedProvider), hasLength(3));

    await tester.ensureVisible(find.text('Audios'));
    await tester.pump();
    await tester.tap(find.text('Audios'));
    await tester.pump();
    expect(ref.read(selectedFeedTypeProvider), TestimonyType.audio);
    expect(ref.read(feedProvider).single.id, 'a1');

    await tester.ensureVisible(find.text('Tous'));
    await tester.pump();
    await tester.tap(find.text('Tous'));
    await tester.pump();
    expect(ref.read(feedProvider), hasLength(3));
  });

  testWidgets('les filtres de recherche sont appliqués et réinitialisés',
      (tester) async {
    await _setPhone(tester, 390);
    late WidgetRef ref;
    await tester.pumpWidget(_app(Consumer(builder: (context, r, _) {
      ref = r;
      return const ExploreScreen();
    })));
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // Onglet « Textes » : appliqué immédiatement.
    await tester.ensureVisible(find.text('Textes'));
    await tester.pump();
    await tester.tap(find.text('Textes'));
    await tester.pump();
    expect(ref.read(exploreResultsProvider).single.id, 't1');

    // Popularité → « Plus aimés », puis Appliquer.
    await tester.tap(find.text('Plus récents'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus aimés').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliquer les filtres'));
    await tester.pumpAndSettle();
    expect(ref.read(sortOrderProvider).name, 'liked');
    expect(ref.read(exploreFiltersActiveProvider), isTrue);

    // Réinitialiser (panneau replié après Appliquer → on le rouvre).
    await tester.tap(find.text('Filtres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réinitialiser'));
    await tester.pump();
    expect(ref.read(exploreFiltersActiveProvider), isFalse);
    expect(ref.read(exploreResultsProvider), hasLength(3));
  });
}

// ── Harnais de la barre du bas (6 branches, comme app_router) ───────────────

class _NavHarness extends StatelessWidget {
  _NavHarness({required this.textScale});
  final double textScale;

  late final GoRouter _router = GoRouter(
    initialLocation: '/b0',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            ScaffoldWithBottomNav(navigationShell: shell),
        branches: [
          for (var i = 0; i < 6; i++)
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/b$i',
                builder: (_, _) => Center(child: Text('page $i')),
              ),
            ]),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => ProviderScope(
        overrides: [isGuestProvider.overrideWithValue(false)],
        child: MaterialApp.router(
          routerConfig: _router,
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: c!,
          ),
        ),
      );
}
