// lib/features/testimony/providers/tts_provider.dart
//
// Lecture vocale d'un témoignage texte : état (arrêt / lecture / pause),
// morceau en cours, vitesse, et préférence « Lecture automatique »
// (enregistrée localement, désactivée par défaut).
//
// Un seul témoignage est lu à la fois : lancer la lecture d'un autre
// témoignage arrête la précédente.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_service.dart' show secureStorageProvider;
import '../../../services/tts_service.dart';

enum TtsStatus { idle, playing, paused }

/// Vitesses proposées dans le lecteur.
enum TtsSpeed {
  slow(0.75, '0,75×'),
  normal(1.0, '1×'),
  fast(1.25, '1,25×');

  const TtsSpeed(this.value, this.label);
  final double value;
  final String label;

  TtsSpeed get next => TtsSpeed.values[(index + 1) % TtsSpeed.values.length];
}

class TtsState {
  const TtsState({
    this.status = TtsStatus.idle,
    this.testimonyId,
    this.chunks = const [],
    this.index = 0,
    this.speed = TtsSpeed.normal,
    this.autoRead = false,
    this.prefsLoaded = false,
  });

  final TtsStatus status;

  /// Témoignage en cours de lecture (ou en pause).
  final String? testimonyId;
  final List<String> chunks;

  /// Morceau (phrase) en cours.
  final int index;
  final TtsSpeed speed;

  /// Lecture automatique à l'ouverture d'un témoignage texte.
  final bool autoRead;

  /// Préférences locales lues (la lecture automatique peut être décidée).
  final bool prefsLoaded;

  bool get isActive => status != TtsStatus.idle;

  String? get currentChunk =>
      isActive && index >= 0 && index < chunks.length ? chunks[index] : null;

  double get progress =>
      chunks.isEmpty ? 0 : (index / chunks.length).clamp(0.0, 1.0);

  bool isFor(String id) => testimonyId == id && isActive;

  TtsState copyWith({
    TtsStatus? status,
    String? testimonyId,
    List<String>? chunks,
    int? index,
    TtsSpeed? speed,
    bool? autoRead,
    bool? prefsLoaded,
  }) =>
      TtsState(
        status: status ?? this.status,
        testimonyId: testimonyId ?? this.testimonyId,
        chunks: chunks ?? this.chunks,
        index: index ?? this.index,
        speed: speed ?? this.speed,
        autoRead: autoRead ?? this.autoRead,
        prefsLoaded: prefsLoaded ?? this.prefsLoaded,
      );
}

/// Moteur de synthèse vocale (surchargé dans les tests).
final ttsEngineProvider = Provider<TtsEngine>((ref) {
  final engine = FlutterTtsEngine();
  ref.onDispose(engine.stop);
  return engine;
});

class TtsController extends Notifier<TtsState> {
  static const _kAutoReadKey = 'tts_auto_read';
  static const _kSpeedKey = 'tts_speed';

  /// Incrémenté à chaque démarrage / arrêt : une boucle de lecture obsolète
  /// s'arrête d'elle-même.
  int _generation = 0;
  String _language = 'fr-FR';
  late TtsEngine _engine;

  @override
  TtsState build() {
    _engine = ref.watch(ttsEngineProvider);
    ref.onDispose(() {
      _generation++;
      _engine.stop();
    });
    Future.microtask(_loadPrefs);
    return const TtsState();
  }

  /// Le fournisseur a pu être libéré pendant une attente.
  bool get _alive => ref.mounted;

  Future<void> _loadPrefs() async {
    if (!_alive) return;
    try {
      final storage = ref.read(secureStorageProvider);
      final auto = await storage.read(key: _kAutoReadKey);
      final speed = await storage.read(key: _kSpeedKey);
      if (!_alive) return;
      state = state.copyWith(
        autoRead: auto == 'true',
        speed: TtsSpeed.values
            .firstWhere((s) => s.name == speed, orElse: () => state.speed),
        prefsLoaded: true,
      );
    } catch (_) {
      if (_alive) state = state.copyWith(prefsLoaded: true);
    }
  }

  Future<void> _save(String key, String value) async {
    if (!_alive) return;
    try {
      await ref.read(secureStorageProvider).write(key: key, value: value);
    } catch (_) {}
  }

  /// Lit [text] (déjà assemblé : titre, corps…) pour [testimonyId].
  /// Renvoie `false` si la synthèse vocale n'est pas disponible.
  Future<bool> play({
    required String testimonyId,
    required String text,
    required String languageCode,
  }) async {
    final chunks = splitIntoSpeechChunks(text);
    if (chunks.isEmpty || !_alive) return false;
    final gen = ++_generation;
    await _engine.stop();
    _language = ttsLanguageFor(languageCode);
    if (!_alive) return false;
    final ok =
        await _engine.configure(language: _language, rate: state.speed.value);
    if (!_alive) return false;
    if (gen != _generation) return true;
    if (!ok) {
      state = state.copyWith(status: TtsStatus.idle, chunks: const [], index: 0);
      return false;
    }
    state = state.copyWith(
      status: TtsStatus.playing,
      testimonyId: testimonyId,
      chunks: chunks,
      index: 0,
    );
    unawaited(_run(gen));
    return true;
  }

  Future<void> _run(int gen) async {
    while (_alive && gen == _generation && state.status == TtsStatus.playing) {
      final i = state.index;
      if (i >= state.chunks.length) {
        _generation++;
        state = state.copyWith(status: TtsStatus.idle, index: 0);
        return;
      }
      final done = await _engine.speak(state.chunks[i]);
      if (!_alive || gen != _generation || state.status != TtsStatus.playing) {
        return;
      }
      if (!done) {
        // Échec du moteur (pas d'arrêt demandé) : on arrête proprement.
        _generation++;
        state = state.copyWith(status: TtsStatus.idle, index: 0);
        return;
      }
      state = state.copyWith(index: i + 1);
    }
  }

  /// Pause : l'énoncé en cours est interrompu puis repris au début de la
  /// phrase (fonctionne de la même façon sur toutes les plateformes).
  Future<void> pause() async {
    if (!_alive || state.status != TtsStatus.playing) return;
    _generation++;
    state = state.copyWith(status: TtsStatus.paused);
    await _engine.stop();
  }

  Future<void> resume() async {
    if (!_alive || state.status != TtsStatus.paused) return;
    final gen = ++_generation;
    state = state.copyWith(status: TtsStatus.playing);
    // La vitesse a pu changer pendant la pause.
    await _engine.configure(language: _language, rate: state.speed.value);
    if (!_alive || gen != _generation) return;
    unawaited(_run(gen));
  }

  Future<void> stop() async {
    if (!_alive || !state.isActive) return;
    _generation++;
    state = state.copyWith(status: TtsStatus.idle, index: 0);
    await _engine.stop();
  }

  /// Arrête la lecture si elle concerne [testimonyId] (fermeture de l'écran).
  Future<void> stopFor(String testimonyId) async {
    if (_alive && state.testimonyId == testimonyId) await stop();
  }

  Future<void> setSpeed(TtsSpeed speed) async {
    if (!_alive) return;
    state = state.copyWith(speed: speed);
    unawaited(_save(_kSpeedKey, speed.name));
    if (state.status == TtsStatus.playing) {
      // Reprendre la phrase en cours à la nouvelle vitesse.
      final gen = ++_generation;
      await _engine.stop();
      await _engine.configure(language: _language, rate: speed.value);
      if (!_alive || gen != _generation) return;
      unawaited(_run(gen));
    }
  }

  Future<void> cycleSpeed() async {
    if (_alive) await setSpeed(state.speed.next);
  }

  void setAutoRead(bool value) {
    if (!_alive) return;
    state = state.copyWith(autoRead: value);
    unawaited(_save(_kAutoReadKey, '$value'));
  }
}

final ttsControllerProvider =
    NotifierProvider<TtsController, TtsState>(TtsController.new);
