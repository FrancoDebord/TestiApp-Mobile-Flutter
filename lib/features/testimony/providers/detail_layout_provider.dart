// Affichage de la page d'un témoignage, au choix de l'utilisateur :
// classique (page complète) ou immersif (plein écran sombre, centré sur le
// témoignage, propice à la prière). Mémorisé sur l'appareil
// (stockage sécurisé, clé `testimony_detail_layout`).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart' show secureStorageProvider;

enum TestimonyDetailLayout {
  classic,
  immersive;

  String get label => switch (this) {
        TestimonyDetailLayout.classic => L10n.current.immersiveLayoutClassic,
        TestimonyDetailLayout.immersive => L10n.current.immersiveLayoutImmersive,
      };
}

class TestimonyDetailLayoutNotifier extends Notifier<TestimonyDetailLayout> {
  static const _key = 'testimony_detail_layout';

  @override
  TestimonyDetailLayout build() {
    Future.microtask(_load);
    return TestimonyDetailLayout.classic;
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(secureStorageProvider).read(key: _key);
      if (!ref.mounted) return;
      if (raw == TestimonyDetailLayout.immersive.name) state = TestimonyDetailLayout.immersive;
    } catch (_) {}
  }

  void set(TestimonyDetailLayout layout) {
    if (layout == state) return;
    state = layout;
    unawaited(() async {
      try {
        await ref.read(secureStorageProvider).write(key: _key, value: layout.name);
      } catch (_) {}
    }());
  }

  void toggle() => set(state == TestimonyDetailLayout.classic
      ? TestimonyDetailLayout.immersive
      : TestimonyDetailLayout.classic);
}

final testimonyDetailLayoutProvider =
    NotifierProvider<TestimonyDetailLayoutNotifier, TestimonyDetailLayout>(
        TestimonyDetailLayoutNotifier.new);
