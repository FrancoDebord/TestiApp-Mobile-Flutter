// lib/features/testimony/providers/testimony_refresh.dart
//
// Rechargement d'un témoignage dont la vidéo vient de changer d'état
// (push video_ready / video_failed, re-vérification depuis l'écran de détail) :
//   • dernière version connue gardée dans [freshTestimoniesProvider], que les
//     cartes et écrans ouverts consultent ([LatestTestimony.latest]) ;
//   • fil d'accueil, « Mes témoignages » et file de modération mis à jour.
//
// Push reçu application en arrière-plan ou fermée : le gestionnaire FCM
// (isolat séparé, sans Riverpod) note l'identifiant ([rememberVideoPush]) ;
// il est rechargé au retour au premier plan ([TestimonyReloader.reloadPending]).

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart' show apiServiceProvider;
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart';
import '../../moderation/providers/moderation_provider.dart'
    show moderationNotifierProvider;
import '../../profile/providers/profile_provider.dart'
    show myTestimoniesNotifierProvider;

/// Types de push qui annoncent un changement d'état d'une vidéo.
const kVideoPushTypes = {'video_ready', 'video_failed'};

/// Identifiant du témoignage d'un push vidéo (`testimony_id`, repli `id`).
String? videoPushTestimonyId(Map<String, dynamic> data) {
  for (final k in const ['testimony_id', 'id']) {
    final v = data[k]?.toString();
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

// ── Dernière version connue ─────────────────────────────────────────────────

class FreshTestimoniesNotifier extends Notifier<Map<String, Testimony>> {
  @override
  Map<String, Testimony> build() => const {};

  void put(Testimony t) => state = {...state, t.id: t};
}

final freshTestimoniesProvider =
    NotifierProvider<FreshTestimoniesNotifier, Map<String, Testimony>>(
  FreshTestimoniesNotifier.new,
);

extension LatestTestimony on WidgetRef {
  /// Version rechargée de [t] si elle existe (même type), sinon [t].
  T latest<T extends Testimony>(T t) {
    final fresh = watch(freshTestimoniesProvider.select((m) => m[t.id]));
    return fresh is T ? fresh : t;
  }
}

// ── Rechargement ─────────────────────────────────────────────────────────────

class TestimonyReloader {
  TestimonyReloader(this._ref);
  final Ref _ref;

  static const _pendingKey = 'pending_video_refresh';

  /// GET /testimonies/{id}, puis mise à jour des écrans et caches ouverts.
  /// `null` si le témoignage est introuvable ou le réseau indisponible.
  Future<Testimony?> reload(String id) async {
    final Testimony? t;
    try {
      final res = await _ref
          .read(apiServiceProvider)
          .get<Map<String, dynamic>>(AppConstants.testimonyById(id));
      t = testimonyFromApiJson(res.data);
    } catch (e) {
      debugPrint('Rechargement du témoignage $id ✗ $e');
      return null;
    }
    if (t == null) return null;
    apply(t);
    return t;
  }

  /// Diffuse une version à jour : écrans ouverts, fil, « Mes témoignages »,
  /// file de modération (une vidéo prête peut y entrer).
  void apply(Testimony t) {
    _ref.read(freshTestimoniesProvider.notifier).put(t);
    _ref.read(feedNotifierProvider.notifier).replaceTestimony(t);
    _ref.invalidate(myTestimoniesNotifierProvider);
    _ref.invalidate(moderationNotifierProvider);
  }

  /// Push video_ready / video_failed reçu au premier plan ou touché.
  Future<void> onVideoPush(Map<String, dynamic> data) async {
    if (!kVideoPushTypes.contains(data['type']?.toString())) return;
    final id = videoPushTestimonyId(data);
    if (id != null) await reload(id);
  }

  /// Retour au premier plan : témoignages notés par le gestionnaire FCM
  /// d'arrière-plan, puis vidéos encore en traitement affichées (iOS ne
  /// réveille pas toujours l'application pour un push).
  Future<void> reloadPending() async {
    final ids = <String>{...await takePendingVideoPushes()};
    ids.addAll(_ref
        .read(freshTestimoniesProvider)
        .values
        .whereType<VideoTestimony>()
        .where((v) => v.isProcessing)
        .map((v) => v.id));
    ids.addAll(_ref
        .read(feedNotifierProvider)
        .whereType<VideoTestimony>()
        .where((v) => v.isProcessing)
        .map((v) => v.id));
    for (final id in ids) {
      await reload(id);
    }
  }

  /// Identifiants notés en arrière-plan (et oubliés une fois lus).
  static Future<List<String>> takePendingVideoPushes() async {
    if (kIsWeb) return const [];
    try {
      final prefs = SharedPreferencesAsync();
      final ids = await prefs.getStringList(_pendingKey) ?? const <String>[];
      if (ids.isNotEmpty) await prefs.remove(_pendingKey);
      return ids;
    } catch (_) {
      return const [];
    }
  }
}

/// Gestionnaire FCM d'arrière-plan (isolat sans Riverpod) : note le
/// témoignage d'un push video_ready / video_failed, rechargé au retour au
/// premier plan. Sans effet pour les autres types.
Future<void> rememberVideoPush(Map<String, dynamic> data) async {
  if (kIsWeb || !kVideoPushTypes.contains(data['type']?.toString())) return;
  final id = videoPushTestimonyId(data);
  if (id == null) return;
  try {
    final prefs = SharedPreferencesAsync();
    final ids = await prefs.getStringList(TestimonyReloader._pendingKey) ??
        const <String>[];
    if (!ids.contains(id)) {
      await prefs.setStringList(TestimonyReloader._pendingKey, [...ids, id]);
    }
  } catch (_) {}
}

final testimonyReloaderProvider =
    Provider<TestimonyReloader>(TestimonyReloader.new);

// ── Re-vérification d'une vidéo en traitement ────────────────────────────────

/// Re-vérifie l'état d'une vidéo toutes les [interval] (30 s), au plus
/// [maxAttempts] fois (10), puis s'arrête. [check] renvoie `true` quand il
/// n'y a plus rien à attendre (vidéo prête ou en échec).
class VideoStatusPoller {
  VideoStatusPoller({
    required this.check,
    this.interval = const Duration(seconds: 30),
    this.maxAttempts = 10,
  });

  final Future<bool> Function() check;
  final Duration interval;
  final int maxAttempts;

  Timer? _timer;
  int _attempts = 0;
  bool _busy = false;

  int get attempts => _attempts;
  bool get isActive => _timer != null;

  void start() {
    if (_timer != null || _attempts >= maxAttempts) return;
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    _attempts++;
    var done = false;
    try {
      done = await check();
    } catch (_) {}
    _busy = false;
    if (done || _attempts >= maxAttempts) stop();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
