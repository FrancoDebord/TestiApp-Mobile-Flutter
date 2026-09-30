// Mise en page de « Mes téléchargements » (320 / 390 px, ×1.0 / ×1.3) et
// états du bouton DownloadButton.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/core/media/media_quality.dart';
import 'package:testi_app/features/downloads/providers/downloads_provider.dart';
import 'package:testi_app/features/downloads/screens/downloads_screen.dart';
import 'package:testi_app/features/downloads/widgets/download_button.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';

/// Notifier figé : pas d'accès disque ni réseau.
class _FakeDownloads extends DownloadsNotifier {
  _FakeDownloads(this.initial);
  final DownloadsState initial;
  final downloaded = <String>[];
  final cancelled = <String>[];

  @override
  DownloadsState build() => initial;

  @override
  Future<DownloadOutcome> download(Testimony t) async {
    downloaded.add(t.id);
    return DownloadOutcome.done;
  }

  @override
  void cancel(String id) => cancelled.add(id);
}

const _longTitle = 'Un très long titre de témoignage pour vérifier que la '
    'ligne est coupée proprement avec des points de suspension';

DownloadEntry _entry(String id, TestimonyType type, int size) => DownloadEntry(
      id: id,
      type: type,
      title: _longTitle,
      authorName: 'Ministère International Lumière du Monde',
      category: TestimonyCategory.guerison,
      downloadedAt: DateTime(2026, 9, 1),
      sizeBytes: size,
      textBody: type == TestimonyType.text ? 'Texte' : null,
      filePath: type == TestimonyType.text ? null : '/tmp/$id.mp4',
    );

final _state = DownloadsState(
  loaded: true,
  entries: {
    'v1': _entry('v1', TestimonyType.video, 3565158),
    'a1': _entry('a1', TestimonyType.audio, 2400000),
    'i1': _entry('i1', TestimonyType.video, 800000),
    't1': _entry('t1', TestimonyType.text, 4000),
  },
  tasks: {
    'v9': DownloadTask(
      entry: _entry('v9', TestimonyType.video, 0),
      status: DownloadStatus.downloading,
      progress: 0.42,
    ),
    'a9': DownloadTask(
      entry: _entry('a9', TestimonyType.audio, 0),
      status: DownloadStatus.failed,
      error: 'Téléchargement impossible. Vérifiez votre connexion.',
    ),
  },
);

Widget _app(Widget child,
        {required DownloadsState state,
        double textScale = 1.0,
        bool online = true,
        _FakeDownloads? fake}) =>
    ProviderScope(
      overrides: [
        downloadsProvider.overrideWith(() => fake ?? _FakeDownloads(state)),
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
      ],
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
  tester.view.physicalSize = Size(width * 2, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

VideoTestimony _video(String id) => VideoTestimony(
      id: id,
      author: const TestimonyAuthor(uid: 'u', displayName: 'Marie'),
      title: 'Vidéo',
      category: TestimonyCategory.miracles,
      createdAt: DateTime(2026),
      stats: TestimonyStats.zero,
      durationSeconds: 10,
      thumbnailUrl: '',
      mediaPath: 'https://cdn.test/$id.mp4',
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => OfflineMedia.lookup = null);

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Mes téléchargements sans débordement ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(const DownloadsScreen(),
            state: _state, textScale: scale, online: false));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Mes téléchargements'), findsOneWidget);
        expect(find.textContaining('hors ligne'), findsOneWidget); // bandeau
        expect(find.text('Vidéo · 3,4 Mo'), findsOneWidget);
        expect(find.textContaining('Stockage utilisé'), findsOneWidget);
        expect(find.text('Gérer le stockage'), findsOneWidget);

        // Filtre « Textes »
        await tester.ensureVisible(find.text('Textes'));
        await tester.pump();
        await tester.tap(find.text('Textes'));
        await tester.pump();
        expect(find.text('Vidéo · 3,4 Mo'), findsNothing);
        expect(find.textContaining('Texte ·'), findsOneWidget);

        // Feuille « Gérer le stockage »
        await tester.ensureVisible(find.text('Tous'));
        await tester.pump();
        await tester.tap(find.text('Tous'));
        await tester.pump();
        await tester.ensureVisible(find.text('Gérer le stockage'));
        await tester.pump();
        await tester.tap(find.text('Gérer le stockage'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Tout supprimer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('état vide ($width px, ×$scale)', (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(const DownloadsScreen(),
            state: const DownloadsState(loaded: true), textScale: scale));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Explorer les témoignages'), findsOneWidget);
      });
    }
  }

  group('DownloadButton', () {
    Future<_FakeDownloads> pumpButton(
        WidgetTester tester, DownloadsState state,
        {bool label = true}) async {
      final fake = _FakeDownloads(state);
      await tester.pumpWidget(_app(
        Scaffold(
          body: Center(
            child: DownloadButton(testimony: _video('x'), label: label),
          ),
        ),
        state: state,
        fake: fake,
      ));
      await tester.pump();
      return fake;
    }

    testWidgets('à télécharger → lance le téléchargement', (tester) async {
      final fake =
          await pumpButton(tester, const DownloadsState(loaded: true));
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.text('Télécharger'), findsOneWidget);
      await tester.tap(find.text('Télécharger'));
      await tester.pump();
      expect(fake.downloaded, ['x']);
      expect(find.textContaining('disponible hors ligne'), findsOneWidget);
    });

    testWidgets('en cours → progression, appui = annuler', (tester) async {
      final fake = await pumpButton(
        tester,
        DownloadsState(loaded: true, tasks: {
          'x': DownloadTask(
            entry: DownloadEntry.fromTestimony(_video('x')),
            status: DownloadStatus.downloading,
            progress: 0.5,
          ),
        }),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('50 %'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(fake.cancelled, ['x']);
      expect(find.text('Téléchargement annulé'), findsOneWidget);
    });

    testWidgets('téléchargé → menu Lire hors ligne / Supprimer',
        (tester) async {
      await pumpButton(
        tester,
        DownloadsState(loaded: true, entries: {
          'x': DownloadEntry.fromTestimony(_video('x'))
              .copyWith(filePath: '/tmp/x.mp4', sizeBytes: 10),
        }),
      );
      expect(find.text('Téléchargé'), findsOneWidget);
      await tester.tap(find.text('Téléchargé'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Lire hors ligne'), findsOneWidget);
      expect(find.text('Supprimer le téléchargement'), findsOneWidget);
    });

    testWidgets('échec → réessayer', (tester) async {
      await pumpButton(
        tester,
        DownloadsState(loaded: true, tasks: {
          'x': DownloadTask(
            entry: DownloadEntry.fromTestimony(_video('x')),
            status: DownloadStatus.failed,
            error: 'Téléchargement impossible.',
          ),
        }),
        label: false,
      );
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('vidéo YouTube : bouton masqué', (tester) async {
      final yt = VideoTestimony(
        id: 'y',
        author: const TestimonyAuthor(uid: 'u', displayName: 'M'),
        title: 'YT',
        category: TestimonyCategory.salut,
        createdAt: DateTime(2026),
        stats: TestimonyStats.zero,
        durationSeconds: 0,
        thumbnailUrl: '',
        youtubeId: 'abcdefghijk',
      );
      await tester.pumpWidget(_app(
        Scaffold(body: DownloadButton(testimony: yt)),
        state: const DownloadsState(loaded: true),
      ));
      expect(find.byType(IconButton), findsNothing);
    });
  });
}
