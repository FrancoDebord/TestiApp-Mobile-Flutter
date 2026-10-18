// Passages affichés par le mode immersif :
//
// - témoignage texte : un passage par paragraphe du texte lu à voix haute
//   (titre, paragraphes, verset), avec la correspondance « phrase lue par la
//   synthèse vocale → paragraphe » pour surligner et faire défiler ;
// - témoignage audio : la transcription découpée en passages minutés sur la
//   durée de l'audio (horodatage exact si le serveur fournit des segments,
//   sinon réparti selon la longueur du texte).

import '../../../services/tts_service.dart' show splitIntoSpeechChunks;
import '../../home/models/testimony_model.dart';
import '../widgets/tts_listen_card.dart' show ttsTextFor;

/// Paragraphes lus pour un témoignage texte (même texte que la lecture vocale).
List<String> textPassages(TextTestimony t) => ttsTextFor(t)
    .split('\n')
    .map((p) => p.trim())
    .where((p) => p.isNotEmpty)
    .toList();

/// Index de la première phrase (morceau de synthèse vocale) de chaque passage.
/// `null` si le découpage par passage ne retombe pas sur celui du texte entier.
List<int>? chunkStarts(List<String> passages) {
  final starts = <int>[];
  var n = 0;
  for (final p in passages) {
    starts.add(n);
    n += splitIntoSpeechChunks(p).length;
  }
  return n == splitIntoSpeechChunks(passages.join('\n')).length ? starts : null;
}

/// Passage contenant la phrase [chunkIndex].
int passageForChunk(List<int> starts, int chunkIndex) {
  var current = 0;
  for (var i = 0; i < starts.length; i++) {
    if (starts[i] <= chunkIndex) current = i;
  }
  return current;
}

/// Passage d'un audio : texte affiché à partir de [start].
class TimedPassage {
  const TimedPassage(this.text, this.start);
  final String text;
  final Duration start;
}

/// Longueur visée d'un passage quand la transcription n'a pas de paragraphes.
const int _kPassageLength = 260;

final _sentenceEnd = RegExp(r'(?<=[.!?…])\s+');

/// Paragraphes d'une transcription ; un très long paragraphe est regroupé en
/// passages de quelques phrases.
List<String> transcriptParagraphs(String transcript) {
  final out = <String>[];
  for (final raw in transcript.split(RegExp(r'\n+'))) {
    final p = raw.trim();
    if (p.isEmpty) continue;
    if (p.length <= _kPassageLength * 1.5) {
      out.add(p);
      continue;
    }
    var buffer = '';
    for (final sentence in p.split(_sentenceEnd)) {
      final s = sentence.trim();
      if (s.isEmpty) continue;
      buffer = buffer.isEmpty ? s : '$buffer $s';
      if (buffer.length >= _kPassageLength) {
        out.add(buffer);
        buffer = '';
      }
    }
    if (buffer.isNotEmpty) out.add(buffer);
  }
  return out;
}

/// Passages minutés d'un témoignage audio de durée [total].
List<TimedPassage> audioPassages(AudioTestimony t, Duration total) {
  if (t.transcriptSegments.isNotEmpty) {
    return [for (final s in t.transcriptSegments) TimedPassage(s.text, s.start)];
  }
  final paragraphs = transcriptParagraphs(t.transcript.isNotEmpty ? t.transcript : t.transcriptPreview);
  if (paragraphs.isEmpty) return const [];
  final chars = paragraphs.fold<int>(0, (sum, p) => sum + p.length);
  final out = <TimedPassage>[];
  var before = 0;
  for (final p in paragraphs) {
    final start = chars == 0 || total == Duration.zero
        ? Duration.zero
        : Duration(milliseconds: (total.inMilliseconds * before / chars).round());
    out.add(TimedPassage(p, start));
    before += p.length;
  }
  return out;
}

/// Passage en cours à la position [position].
int passageAt(List<TimedPassage> passages, Duration position) {
  var current = 0;
  for (var i = 0; i < passages.length; i++) {
    if (passages[i].start <= position) current = i;
  }
  return current;
}
