// Pages de lecture d'un témoignage (maquette, écran 8 « Lecture ») :
//   • détail d'un témoignage texte (carte « Écouter ce témoignage »), audio,
//     vidéo ;
//   • zone d'informations du lecteur vidéo ;
//   • lecteur audio plein écran.
// Aucun débordement sur un petit écran (320 / 390 px), police ×1.0 et ×1.3,
// textes longs. Aucun réseau : fil, suggestions, téléchargements, audio et
// synthèse vocale sont remplacés par des doublures.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import 'package:testi_app/features/downloads/providers/downloads_provider.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/testimony/providers/recommendations_provider.dart';
import 'package:testi_app/features/testimony/providers/tts_provider.dart';
import 'package:testi_app/features/testimony/screens/audio_player_screen.dart';
import 'package:testi_app/features/testimony/screens/testimony_detail_screen.dart';
import 'package:testi_app/features/testimony/screens/video_player_screen.dart';
import 'package:testi_app/features/testimony/widgets/testimony_info.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/services/audio_player_service.dart';
import 'package:testi_app/services/tts_service.dart';
import 'package:testi_app/shared/widgets/guest_gate.dart';

const _longName =
    'Ministère International Lumière du Monde pour la Restauration';
const _longTitle = 'Un très long titre de témoignage pour vérifier le retour '
    'à la ligne dans la page de lecture du témoignage';

const _author = TestimonyAuthor(
  uid: 'u1',
  displayName: _longName,
  isOrganization: true,
  isVerified: true,
);

const _stats = TestimonyStats(
    views: 12400, comments: 98765, likes: 1234567, prayers: 45678);

const _verse = 'Je suis l’Éternel qui te guérit ; ta foi t’a sauvé, va en paix '
    'et sois guéri de ton mal.';

final _text = TextTestimony(
  id: 't1',
  author: _author,
  title: _longTitle,
  category: TestimonyCategory.protection,
  createdAt: DateTime.now().subtract(const Duration(days: 5)),
  stats: _stats,
  preview: 'Après plusieurs mois de prière, Dieu a **touché** notre famille. '
      'J’étais dans un état très critique, mais Dieu a agi au-delà de tout '
      'ce que je pouvais imaginer. Gloire à Lui !',
  bibleVerse: _verse,
  bibleVerseRef: 'Exode 15:26',
);

final _audio = AudioTestimony(
  id: 'a1',
  author: _author,
  title: _longTitle,
  category: TestimonyCategory.delivrance,
  createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  stats: _stats,
  durationSeconds: 312,
  transcriptPreview: 'J’étais dans un état très critique, mais Dieu a agi '
      'au-delà de tout ce que je pouvais imaginer.',
  mediaPath: 'https://example.org/a1.mp3',
  bibleVerse: _verse,
  bibleVerseRef: 'Psaume 23:1',
);

final _video = VideoTestimony(
  id: 'v1',
  author: _author,
  title: _longTitle,
  category: TestimonyCategory.guerison,
  createdAt: DateTime.now().subtract(const Duration(days: 2)),
  stats: _stats,
  durationSeconds: 312,
  thumbnailUrl: '',
  bibleVerse: _verse,
);

final _related = VideoTestimony(
  id: 'v2',
  author: _author,
  title: _longTitle,
  category: TestimonyCategory.miracles,
  createdAt: DateTime.now().subtract(const Duration(days: 9)),
  stats: _stats,
  durationSeconds: 165,
  thumbnailUrl: '',
);

final _items = <Testimony>[_text, _audio, _video, _related];

class _FakeFeed extends FeedNotifier {
  @override
  List<Testimony> build() => _items;

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

class _FakeDownloads extends DownloadsNotifier {
  @override
  DownloadsState build() =>
      const DownloadsState(loaded: true, supported: true);
}

/// Lecteur audio sans plateforme : rien n'est joué.
class _FakeAudio extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => AudioPlayerState(
        currentTestimony: _audio,
        duration: const Duration(minutes: 5, seconds: 12),
        position: const Duration(minutes: 2, seconds: 45),
        qualityLabel: '64 kbps',
      );

  @override
  Future<void> setTestimonyQueue(List<AudioTestimony> testimonies,
          {int startIndex = 0}) async {}

  @override
  Future<void> play(String source) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}
}

/// Réseau coupé : toute requête échoue (les écrans gèrent l'erreur).
class _OfflineApi implements ApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('pas de réseau dans les tests');
}

class _SilentTts implements TtsEngine {
  @override
  Future<bool> configure({required String language, required double rate}) async =>
      true;

  @override
  Future<bool> speak(String text) => Completer<bool>().future;

  @override
  Future<void> stop() async {}
}

List<Override> get _overrides => [
      feedNotifierProvider.overrideWith(_FakeFeed.new),
      feedIsLoadingProvider.overrideWithBuild((ref, notifier) => false),
      downloadsProvider.overrideWith(_FakeDownloads.new),
      audioPlayerProvider.overrideWith(_FakeAudio.new),
      apiServiceProvider.overrideWithValue(_OfflineApi()),
      recommendationsProvider.overrideWith((ref, id) async => [_related]),
      currentUserProvider.overrideWithValue(null),
      isGuestProvider.overrideWithValue(false),
      ttsEngineProvider.overrideWithValue(_SilentTts()),
    ];

Widget _app(Widget child, {double textScale = 1.0}) => ProviderScope(
      overrides: _overrides,
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => child),
          GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
        ]),
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
      ),
    );

Future<void> _setPhone(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * 2, 1800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Parcourt la page pour construire toutes les sections.
Future<void> _scrollAll(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 8; i++) {
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
}

/// Laisse passer les chargements (réseau coupé, base locale absente).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    // Stockage sécurisé, base locale, lecteurs : pas de plateforme en test.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'com.tekartik.sqflite',
      'flutter.baseflow.com/permissions/methods',
      'dev.fluttercommunity.plus/connectivity',
      'dev.fluttercommunity.plus/connectivity_status',
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(name), (call) async => null);
    }
  });

  test('formatage des compteurs et de la date (maquette)', () {
    expect(formatCompactCount(12400), '12,4k');
    expect(formatCompactCount(12400, fr: false), '12.4k');
    expect(formatCompactCount(892), '892');
    expect(formatCompactCount(1500000), '1,5M');
    expect(formatCompactCount(12000), '12k');
    final now = DateTime(2026, 9, 30, 12);
    expect(formatTimeAgo(now.subtract(const Duration(days: 5)), now: now),
        'il y a 5 jours');
    expect(formatTimeAgo(now.subtract(const Duration(days: 1)), now: now),
        'il y a 1 jour');
    expect(
        formatTimeAgo(now.subtract(const Duration(days: 5)),
            fr: false, now: now),
        '5 days ago');
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('détail texte + carte « Écouter » ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(
            const TestimonyDetailScreen(testimonyId: 't1'),
            textScale: scale));
        await _settle(tester);
        expect(tester.takeException(), isNull);

        expect(find.text(_longTitle), findsWidgets);
        expect(find.text('Écouter ce témoignage'), findsOneWidget);
        expect(find.text('12,4k vues · il y a 5 jours'), findsOneWidget);
        expect(find.text(_text.category.label), findsWidgets);

        // Lecture vocale : la phrase en cours s'affiche, sans débordement.
        await tester.ensureVisible(find.byKey(const ValueKey('tts-play')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tts-play')));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('tts-current-sentence')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('tts-stop')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('tts-speed')));
        await _settle(tester);
        expect(find.text('1,25×'), findsOneWidget);

        // Menu : « Lecture automatique »
        await tester.tap(find.byKey(const ValueKey('tts-menu')));
        await _settle(tester);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Lecture automatique'), findsOneWidget);
        await tester.tap(find.byType(CheckedPopupMenuItem<String>));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        final container = ProviderScope.containerOf(
            tester.element(find.byKey(const ValueKey('tts-listen-card'))));
        expect(container.read(ttsControllerProvider).autoRead, isTrue);

        await _scrollAll(tester);
      });

      testWidgets('détail audio ($width px, ×$scale)', (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(
            const TestimonyDetailScreen(testimonyId: 'a1'),
            textScale: scale));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Écouter ce témoignage'), findsNothing);
        expect(find.text('Exode 15:26'), findsNothing);
        await _scrollAll(tester);
      });

      testWidgets('détail vidéo ($width px, ×$scale)', (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(
            const TestimonyDetailScreen(testimonyId: 'v1'),
            textScale: scale));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('05:12'), findsOneWidget);
        await _scrollAll(tester);
      });

      testWidgets('lecteur vidéo : zone d’informations ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(
            VideoPlayerScreen(testimonyId: 'v1', testimony: _video),
            textScale: scale));
        await _settle(tester);
        expect(tester.takeException(), isNull);

        expect(find.text(_longTitle), findsWidgets);
        expect(find.text('Lecture auto'), findsOneWidget);
        expect(find.text('12,4k vues · il y a 2 jours'), findsOneWidget);
        expect(find.text('1,2M'), findsOneWidget); // ❤
        await _scrollAll(tester);
      });

      testWidgets('lecteur audio ($width px, ×$scale)', (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(
            const AudioPlayerScreen(testimonyId: 'a1'),
            textScale: scale));
        await _settle(tester);
        expect(tester.takeException(), isNull);

        expect(find.text('02:45'), findsOneWidget);
        expect(find.text('05:12'), findsOneWidget);
        expect(find.text('Transcription'), findsOneWidget);
        await tester.ensureVisible(find.text('Transcription'));
        await tester.pump();
        await tester.tap(find.text('Transcription'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await _scrollAll(tester);
      });
    }
  }
}
