// lib/features/testimony/providers/view_tracker.dart
//
// Vue comptée d'un témoignage : POST /testimonies/{id}/view (public), envoyé une
// seule fois par témoignage et par session de l'application, quand il est
// réellement consulté :
//   • page détail restée 3 s à l'écran ([kViewDwell]) ;
//   • lecture d'une vidéo démarrée.
// Le serveur dédoublonne aussi (une vue par personne sur 30 min) ; device_id
// l'aide à reconnaître un visiteur sans compte.
// docs serveur fonctionnalites/gestion-des-temoignages.md

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';

/// Temps passé sur la page détail avant de compter une vue.
const Duration kViewDwell = Duration(seconds: 3);

class TestimonyViewTracker extends Notifier<Set<String>> {
  static const _kDeviceId = 'device_id';

  @override
  Set<String> build() => const {};

  /// Compte la vue de [testimonyId] (sans effet si déjà envoyée pendant cette session).
  Future<void> record(String testimonyId) async {
    if (testimonyId.isEmpty || testimonyId.startsWith('local_') || state.contains(testimonyId)) return;
    state = {...state, testimonyId};
    try {
      await ref.read(apiServiceProvider).post<dynamic>(
        AppConstants.testimonyView(testimonyId),
        data: {'device_id': ?await _deviceId()},
      );
    } catch (e) {
      // Échec (réseau, ancien serveur) : on pourra réessayer lors d'une prochaine consultation.
      debugPrint('Vue ✗ $testimonyId : $e');
      state = {...state}..remove(testimonyId);
    }
  }

  /// Identifiant anonyme de l'appareil, créé une fois (shared_preferences).
  static Future<String?> _deviceId() async {
    try {
      final p = await SharedPreferences.getInstance();
      final existing = p.getString(_kDeviceId);
      if (existing != null && existing.isNotEmpty) return existing;
      final rnd = Random.secure();
      final id = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await p.setString(_kDeviceId, id);
      return id;
    } catch (_) {
      return null;
    }
  }
}

final testimonyViewTrackerProvider =
    NotifierProvider<TestimonyViewTracker, Set<String>>(TestimonyViewTracker.new);
