// « Recevoir des notifications » (Paramètres) : enregistre ou retire le jeton FCM
// de cet appareil (POST / DELETE /devices/token). Voir PushService.setDeviceEnabled.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/push_service.dart';

/// Accès au réglage (remplacé dans les tests : Firebase n'y est pas initialisé).
abstract class PushDeviceControl {
  Future<bool> isEnabled();
  Future<void> setEnabled(bool enabled);
}

class _PushServiceControl implements PushDeviceControl {
  _PushServiceControl(this._ref);
  final Ref _ref;

  @override
  Future<bool> isEnabled() => _ref.read(pushServiceProvider).isDeviceEnabled();

  @override
  Future<void> setEnabled(bool enabled) => _ref.read(pushServiceProvider).setDeviceEnabled(enabled);
}

final pushDeviceControlProvider = Provider<PushDeviceControl>(_PushServiceControl.new);

class PushDeviceNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await ref.read(pushDeviceControlProvider).isEnabled();
    } catch (_) {
      return true;
    }
  }

  /// Change le réglage ; en cas d'échec, l'état précédent est rétabli et l'erreur remontée.
  Future<void> set(bool enabled) async {
    final previous = state.value ?? true;
    state = AsyncData(enabled);
    try {
      await ref.read(pushDeviceControlProvider).setEnabled(enabled);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final pushDeviceEnabledProvider = AsyncNotifierProvider<PushDeviceNotifier, bool>(PushDeviceNotifier.new);
