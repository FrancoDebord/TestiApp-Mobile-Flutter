// lib/services/tts_service.dart
//
// Lecture vocale (synthèse vocale / TTS) des témoignages texte.
//
//   • [splitIntoSpeechChunks] découpe un long texte en phrases / morceaux
//     courts : le web (Chrome coupe au-delà de ~15 s) et Android (limite
//     de longueur par énoncé) ne lisent pas correctement un très long texte.
//   • [TtsEngine] : interface minimale (remplaçable dans les tests).
//   • [FlutterTtsEngine] : implémentation flutter_tts (Android, iOS, web).

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

// ── Découpage ────────────────────────────────────────────────────────────────

/// Longueur maximale d'un morceau lu d'une traite.
const int kTtsMaxChunkLength = 220;

final _sentenceEnd = RegExp(r'(?<=[.!?…;:])\s+|\n+');
final _spaces = RegExp(r'[ \t\r\f\v]+');

/// Découpe [text] en morceaux de [maxLength] caractères au plus, en
/// respectant autant que possible les phrases (puis les virgules, puis les
/// mots). Les morceaux vides sont ignorés ; l'ordre du texte est conservé.
List<String> splitIntoSpeechChunks(
  String text, {
  int maxLength = kTtsMaxChunkLength,
}) {
  assert(maxLength > 10);
  final chunks = <String>[];
  for (final raw in text.split(_sentenceEnd)) {
    final sentence = raw.replaceAll(_spaces, ' ').trim();
    if (sentence.isEmpty) continue;
    if (sentence.length <= maxLength) {
      chunks.add(sentence);
      continue;
    }
    // Phrase trop longue : couper aux virgules, puis aux espaces.
    var buffer = '';
    for (final part in _splitKeep(sentence, RegExp(r'(?<=[,،])\s+'))) {
      if (part.length > maxLength) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer);
          buffer = '';
        }
        chunks.addAll(_splitWords(part, maxLength));
        continue;
      }
      final candidate = buffer.isEmpty ? part : '$buffer $part';
      if (candidate.length <= maxLength) {
        buffer = candidate;
      } else {
        chunks.add(buffer);
        buffer = part;
      }
    }
    if (buffer.isNotEmpty) chunks.add(buffer);
  }
  return chunks;
}

List<String> _splitKeep(String s, RegExp sep) =>
    s.split(sep).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

List<String> _splitWords(String s, int maxLength) {
  final out = <String>[];
  var buffer = '';
  for (final word in s.split(' ')) {
    if (word.isEmpty) continue;
    if (word.length > maxLength) {
      // Mot démesuré (lien…) : coupe brute.
      if (buffer.isNotEmpty) {
        out.add(buffer);
        buffer = '';
      }
      for (var i = 0; i < word.length; i += maxLength) {
        out.add(word.substring(
            i, i + maxLength > word.length ? word.length : i + maxLength));
      }
      continue;
    }
    final candidate = buffer.isEmpty ? word : '$buffer $word';
    if (candidate.length <= maxLength) {
      buffer = candidate;
    } else {
      out.add(buffer);
      buffer = word;
    }
  }
  if (buffer.isNotEmpty) out.add(buffer);
  return out;
}

/// Code de langue de la voix à partir de la langue de l'application.
String ttsLanguageFor(String languageCode) =>
    languageCode.toLowerCase().startsWith('en') ? 'en-US' : 'fr-FR';

// ── Moteur ───────────────────────────────────────────────────────────────────

/// Moteur de synthèse vocale minimal.
abstract class TtsEngine {
  /// Prépare la langue et la vitesse ([rate] : multiplicateur, 1.0 = normal).
  /// Renvoie `false` si la synthèse vocale ou la langue n'est pas disponible.
  Future<bool> configure({required String language, required double rate});

  /// Lit [text] et se termine à la fin de la lecture : `true` si la lecture
  /// est allée au bout, `false` si elle a été interrompue ou a échoué.
  Future<bool> speak(String text);

  Future<void> stop();
}

/// Implémentation flutter_tts (Android, iOS, web).
class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine();

  FlutterTts? _tts;
  Completer<bool>? _pending;

  FlutterTts get _engine {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = FlutterTts();
    tts.setCompletionHandler(() => _finish(true));
    tts.setCancelHandler(() => _finish(false));
    tts.setErrorHandler((_) => _finish(false));
    _tts = tts;
    return tts;
  }

  void _finish(bool ok) {
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) p.complete(ok);
  }

  /// Vitesse « normale » de flutter_tts : 0.5 sur Android / iOS, 1.0 sur le web.
  static double get _baseRate => kIsWeb ? 1.0 : 0.5;

  @override
  Future<bool> configure({
    required String language,
    required double rate,
  }) async {
    try {
      final tts = _engine;
      if (!kIsWeb) {
        try {
          final available = await tts.isLanguageAvailable(language);
          if (available == false) return false;
        } catch (_) {/* méthode absente : on tente quand même */}
      }
      await tts.setLanguage(language);
      await tts.setSpeechRate((_baseRate * rate).clamp(0.1, 2.0));
      await tts.setPitch(1.0);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> speak(String text) async {
    try {
      _finish(false);
      final completer = Completer<bool>();
      _pending = completer;
      final result = await _engine.speak(text);
      // Android / iOS renvoient 1 si l'énoncé a été accepté.
      if (result is int && result != 1) _finish(false);
      return completer.future;
    } catch (_) {
      _finish(false);
      return false;
    }
  }

  @override
  Future<void> stop() async {
    _finish(false);
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
