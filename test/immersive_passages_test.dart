// Mode immersif : paragraphes du texte lu, passages minutés d'un audio.

import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart' show testimonyFromApiJson;
import 'package:testi_app/features/testimony/immersive/reading_passages.dart';
import 'package:testi_app/services/tts_service.dart' show splitIntoSpeechChunks;

const _author = TestimonyAuthor(uid: 'u1', displayName: 'Afi');
const _stats = TestimonyStats(views: 0, comments: 0, likes: 0, prayers: 0);

TextTestimony _text(String body) => TextTestimony(
      id: 't1',
      author: _author,
      title: 'Guérie après dix ans',
      category: TestimonyCategory.guerison,
      createdAt: DateTime(2026),
      stats: _stats,
      preview: body,
      bibleVerse: "Je suis l'Éternel qui te guérit",
      bibleVerseRef: 'Exode 15:26',
    );

AudioTestimony _audio({String transcript = '', List<TranscriptSegment> segments = const []}) => AudioTestimony(
      id: 'a1',
      author: _author,
      title: 'Délivrée',
      category: TestimonyCategory.delivrance,
      createdAt: DateTime(2026),
      stats: _stats,
      durationSeconds: 100,
      transcriptPreview: '',
      transcript: transcript,
      transcriptSegments: segments,
    );

void main() {
  test('texte : titre, paragraphes et verset, chacun un passage', () {
    final p = textPassages(_text('Premier paragraphe. Deux phrases ici.\n\nSecond **paragraphe**.'));
    expect(p, [
      'Guérie après dix ans.',
      'Premier paragraphe. Deux phrases ici.',
      'Second paragraphe.',
      "Je suis l'Éternel qui te guérit — Exode 15:26.",
    ]);
  });

  test('texte : phrase lue → paragraphe, cohérent avec la lecture vocale', () {
    final passages = textPassages(_text('Un. Deux. Trois.\nQuatre.'));
    final starts = chunkStarts(passages)!;
    final total = splitIntoSpeechChunks(passages.join('\n')).length;
    expect(starts.first, 0);
    expect(passageForChunk(starts, 0), 0); // titre
    expect(passageForChunk(starts, 1), 1); // « Un. »
    expect(passageForChunk(starts, 3), 1); // « Trois. »
    expect(passageForChunk(starts, 4), 2); // « Quatre. »
    expect(passageForChunk(starts, total - 1), passages.length - 1);
  });

  test('audio sans horodatage : passages répartis selon la longueur', () {
    final a = _audio(transcript: '${'a' * 100}\n${'b' * 300}');
    final p = audioPassages(a, const Duration(seconds: 100));
    expect(p.map((e) => e.start), [Duration.zero, const Duration(seconds: 25)]);
    expect(passageAt(p, const Duration(seconds: 10)), 0);
    expect(passageAt(p, const Duration(seconds: 30)), 1);
  });

  test('audio : un très long paragraphe est découpé en passages de quelques phrases', () {
    final long = List.generate(20, (i) => 'Voici la phrase numéro $i du témoignage.').join(' ');
    final parts = transcriptParagraphs(long);
    expect(parts.length, greaterThan(1));
    expect(parts.join(' '), long);
  });

  test('audio : segments horodatés du serveur utilisés tels quels', () {
    final t = testimonyFromApiJson({
      'id': 'a1',
      'type': 'audio',
      'title': 'Délivrée',
      'bodyText': 'Texte complet',
      'createdAt': '2026-10-15T10:00:00+00:00',
      'user': {'id': 'u1', 'displayName': 'Afi'},
      'transcriptSegments': [
        {'start': 4.5, 'end': 9, 'text': 'Ensuite'},
        {'start': 0, 'end': 4.5, 'text': 'Au début'},
        {'start': 'x', 'end': 2, 'text': 'ignoré'},
      ],
    }) as AudioTestimony;
    expect(t.transcript, 'Texte complet');
    final p = audioPassages(t, const Duration(seconds: 9));
    expect(p.map((e) => e.text), ['Au début', 'Ensuite']);
    expect(passageAt(p, const Duration(seconds: 5)), 1);
  });
}
