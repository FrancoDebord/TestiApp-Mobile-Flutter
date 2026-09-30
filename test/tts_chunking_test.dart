// Lecture vocale : découpage des longs textes en morceaux courts (le web et
// Android limitent la longueur d'un énoncé) et enchaînement par le contrôleur.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/testimony/providers/tts_provider.dart';
import 'package:testi_app/features/testimony/widgets/tts_listen_card.dart';
import 'package:testi_app/services/tts_service.dart';

/// Moteur factice : chaque énoncé se termine quand le test le décide.
class FakeTtsEngine implements TtsEngine {
  FakeTtsEngine({this.available = true});

  final bool available;
  final spoken = <String>[];
  final rates = <double>[];
  String? language;
  Completer<bool>? _current;

  @override
  Future<bool> configure({required String language, required double rate}) async {
    this.language = language;
    rates.add(rate);
    return available;
  }

  @override
  Future<bool> speak(String text) {
    spoken.add(text);
    _current = Completer<bool>();
    return _current!.future;
  }

  /// Termine l'énoncé en cours.
  Future<void> finish() async {
    final c = _current;
    _current = null;
    c?.complete(true);
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> stop() async {
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete(false);
  }
}

void main() {
  group('splitIntoSpeechChunks', () {
    test('découpe par phrases et ignore les espaces superflus', () {
      final chunks = splitIntoSpeechChunks(
          'Dieu m’a guéri.   Gloire à Lui !\n\nJe témoigne?  Oui…  Amen');
      expect(chunks, [
        'Dieu m’a guéri.',
        'Gloire à Lui !',
        'Je témoigne?',
        'Oui…',
        'Amen',
      ]);
    });

    test('texte vide ou blanc → aucun morceau', () {
      expect(splitIntoSpeechChunks(''), isEmpty);
      expect(splitIntoSpeechChunks('  \n \t '), isEmpty);
    });

    test('aucun morceau ne dépasse la longueur maximale', () {
      final long = List.filled(120, 'mot').join(' ');
      final text = 'Début. $long, suite, encore une virgule, fin. '
          '${'x' * 500}';
      final chunks = splitIntoSpeechChunks(text, maxLength: 100);
      expect(chunks, isNotEmpty);
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(100), reason: c);
        expect(c.trim(), isNotEmpty);
      }
      // Rien n'est perdu : tous les mots sont conservés, dans l'ordre.
      final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      final rebuilt = chunks.join(' ').replaceAll(' ', '');
      expect(rebuilt, words.join().replaceAll(' ', ''));
    });

    test('longue phrase coupée de préférence aux virgules', () {
      final part = List.filled(12, 'bénédiction').join(' '); // ~143 car.
      final chunks =
          splitIntoSpeechChunks('$part, $part, $part.', maxLength: 160);
      expect(chunks.length, 3);
      expect(chunks.first, '$part,');
    });

    test('langue de la voix selon la langue de l’application', () {
      expect(ttsLanguageFor('fr'), 'fr-FR');
      expect(ttsLanguageFor('en'), 'en-US');
      expect(ttsLanguageFor('en_GB'), 'en-US');
      expect(ttsLanguageFor('xx'), 'fr-FR');
    });
  });

  group('ttsTextFor', () {
    test('titre, corps sans balises, puis verset', () {
      final t = TextTestimony(
        id: 't1',
        author: const TestimonyAuthor(uid: 'u', displayName: 'Marie'),
        title: 'Un miracle dans ma famille',
        category: TestimonyCategory.guerison,
        createdAt: DateTime(2026),
        stats: const TestimonyStats(views: 0, comments: 0, likes: 0, prayers: 0),
        preview: 'Le Seigneur a **transformé** ma vie.',
        bibleVerse: 'Je suis l’Éternel qui te guérit',
        bibleVerseRef: 'Exode 15:26',
      );
      final text = ttsTextFor(t);
      expect(text, startsWith('Un miracle dans ma famille.'));
      expect(text, contains('Le Seigneur a transformé ma vie.'));
      expect(text, isNot(contains('**')));
      expect(text, endsWith('Exode 15:26.'));
    });
  });

  group('TtsController', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );
    });

    ProviderContainer container(FakeTtsEngine engine) {
      final c = ProviderContainer(overrides: [
        ttsEngineProvider.overrideWithValue(engine),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('lit les morceaux dans l’ordre, pause / reprise, fin', () async {
      final engine = FakeTtsEngine();
      final c = container(engine);
      final ctl = c.read(ttsControllerProvider.notifier);

      final ok = await ctl.play(
        testimonyId: 't1',
        text: 'Première phrase. Deuxième phrase. Troisième.',
        languageCode: 'en',
      );
      await Future<void>.delayed(Duration.zero);
      expect(ok, isTrue);
      expect(engine.language, 'en-US');
      expect(c.read(ttsControllerProvider).status, TtsStatus.playing);
      expect(c.read(ttsControllerProvider).currentChunk, 'Première phrase.');

      await engine.finish();
      expect(c.read(ttsControllerProvider).index, 1);

      await ctl.pause();
      expect(c.read(ttsControllerProvider).status, TtsStatus.paused);

      await ctl.resume();
      await Future<void>.delayed(Duration.zero);
      // La phrase interrompue est reprise depuis son début.
      expect(engine.spoken, [
        'Première phrase.',
        'Deuxième phrase.',
        'Deuxième phrase.',
      ]);

      await engine.finish();
      await engine.finish();
      expect(c.read(ttsControllerProvider).status, TtsStatus.idle);
      expect(engine.spoken.last, 'Troisième.');
    });

    test('vitesse et arrêt ; un autre témoignage remplace le précédent',
        () async {
      final engine = FakeTtsEngine();
      final c = container(engine);
      final ctl = c.read(ttsControllerProvider.notifier);

      await ctl.setSpeed(TtsSpeed.fast);
      await ctl.play(testimonyId: 'a', text: 'Un. Deux.', languageCode: 'fr');
      await Future<void>.delayed(Duration.zero);
      expect(engine.rates.last, 1.25);
      expect(engine.language, 'fr-FR');

      await ctl.play(testimonyId: 'b', text: 'Autre.', languageCode: 'fr');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(ttsControllerProvider).testimonyId, 'b');
      expect(c.read(ttsControllerProvider).isFor('a'), isFalse);

      await ctl.stopFor('a'); // sans effet : c'est « b » qui est lu
      expect(c.read(ttsControllerProvider).isActive, isTrue);
      await ctl.stopFor('b');
      expect(c.read(ttsControllerProvider).status, TtsStatus.idle);
    });

    test('voix indisponible → false, reste à l’arrêt', () async {
      final engine = FakeTtsEngine(available: false);
      final c = container(engine);
      final ok = await c
          .read(ttsControllerProvider.notifier)
          .play(testimonyId: 't', text: 'Bonjour.', languageCode: 'fr');
      expect(ok, isFalse);
      expect(c.read(ttsControllerProvider).status, TtsStatus.idle);
      expect(engine.spoken, isEmpty);
    });

    test('lecture automatique : préférence désactivée par défaut', () async {
      final c = container(FakeTtsEngine());
      final ctl = c.read(ttsControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(ttsControllerProvider).autoRead, isFalse);
      ctl.setAutoRead(true);
      expect(c.read(ttsControllerProvider).autoRead, isTrue);
    });
  });
}
