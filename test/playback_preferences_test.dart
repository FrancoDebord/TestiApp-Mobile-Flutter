import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/media/playback_preferences.dart';
import 'package:testi_app/services/api_service.dart';

/// Stockage en mémoire : seules `read` et `write` sont utilisées par
/// [PlaybackPreferencesNotifier].
class _MemoryStorage extends Fake implements FlutterSecureStorage {
  _MemoryStorage([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    if (invocation.memberName == #read) {
      return Future<String?>.value(data[key]);
    }
    if (invocation.memberName == #write) {
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        data.remove(key);
      } else {
        data[key!] = value;
      }
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

const _key = 'playback_preferences';

Future<(ProviderContainer, _MemoryStorage)> _setUp({
  Map<String, String>? stored,
}) async {
  final storage = _MemoryStorage(stored);
  final container = ProviderContainer(
    overrides: [secureStorageProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  container.read(playbackPreferencesProvider);
  // Laisse le chargement initial (microtâche) se terminer.
  await Future<void>.delayed(Duration.zero);
  return (container, storage);
}

void main() {
  group('PlaybackPreferencesNotifier — répétition / lecture auto', () {
    test('valeurs par défaut', () async {
      final (c, _) = await _setUp();
      final p = c.read(playbackPreferencesProvider);
      expect(p.repeatMode, RepeatMode.off);
      expect(p.autoplayNext, isTrue);
    });

    test('« Répéter la liste » active la lecture auto', () async {
      final (c, _) = await _setUp();
      final ctl = c.read(playbackPreferencesProvider.notifier);
      ctl.setAutoplayNext(false);
      expect(c.read(playbackPreferencesProvider).autoplayNext, isFalse);

      ctl.setRepeatMode(RepeatMode.all);
      final p = c.read(playbackPreferencesProvider);
      expect(p.repeatMode, RepeatMode.all);
      expect(p.autoplayNext, isTrue);
    });

    test('désactiver la lecture auto désactive « Répéter la liste »',
        () async {
      final (c, _) = await _setUp();
      final ctl = c.read(playbackPreferencesProvider.notifier);
      ctl.setRepeatMode(RepeatMode.all);
      ctl.setAutoplayNext(false);
      final p = c.read(playbackPreferencesProvider);
      expect(p.autoplayNext, isFalse);
      expect(p.repeatMode, RepeatMode.off);
    });

    test('désactiver la lecture auto conserve « Répéter ce témoignage »',
        () async {
      final (c, _) = await _setUp();
      final ctl = c.read(playbackPreferencesProvider.notifier);
      ctl.setRepeatMode(RepeatMode.one);
      ctl.setAutoplayNext(false);
      final p = c.read(playbackPreferencesProvider);
      expect(p.autoplayNext, isFalse);
      expect(p.repeatMode, RepeatMode.one);
    });

    test('« Répéter ce témoignage » ou « aucune » ne touchent pas la lecture '
        'auto', () async {
      final (c, _) = await _setUp();
      final ctl = c.read(playbackPreferencesProvider.notifier);
      ctl.setAutoplayNext(false);
      ctl.setRepeatMode(RepeatMode.one);
      expect(c.read(playbackPreferencesProvider).autoplayNext, isFalse);
      ctl.setRepeatMode(RepeatMode.off);
      expect(c.read(playbackPreferencesProvider).autoplayNext, isFalse);
    });

    test('cycleRepeatMode : off → one → all (lecture auto activée) → off',
        () async {
      final (c, _) = await _setUp();
      final ctl = c.read(playbackPreferencesProvider.notifier);
      ctl.setAutoplayNext(false);

      ctl.cycleRepeatMode();
      expect(c.read(playbackPreferencesProvider).repeatMode, RepeatMode.one);
      expect(c.read(playbackPreferencesProvider).autoplayNext, isFalse);

      ctl.cycleRepeatMode();
      expect(c.read(playbackPreferencesProvider).repeatMode, RepeatMode.all);
      expect(c.read(playbackPreferencesProvider).autoplayNext, isTrue);

      ctl.cycleRepeatMode();
      expect(c.read(playbackPreferencesProvider).repeatMode, RepeatMode.off);
      expect(c.read(playbackPreferencesProvider).autoplayNext, isTrue);
    });

    test('les changements sont persistés', () async {
      final (c, storage) = await _setUp();
      c
          .read(playbackPreferencesProvider.notifier)
          .setRepeatMode(RepeatMode.all);
      await Future<void>.delayed(Duration.zero);
      final saved =
          jsonDecode(storage.data[_key]!) as Map<String, dynamic>;
      expect(saved['repeat_mode'], 'all');
      expect(saved['autoplay_next'], isTrue);
    });

    test('préférences enregistrées incohérentes corrigées au chargement',
        () async {
      final (c, _) = await _setUp(stored: {
        _key: jsonEncode(const PlaybackPreferences(
          repeatMode: RepeatMode.all,
          autoplayNext: false,
        ).toJson()),
      });
      final p = c.read(playbackPreferencesProvider);
      expect(p.repeatMode, RepeatMode.all);
      expect(p.autoplayNext, isTrue);
    });

    test('erreur de stockage sans conséquence', () async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_ThrowingStorage()),
        ],
      );
      addTearDown(container.dispose);
      container.read(playbackPreferencesProvider);
      await Future<void>.delayed(Duration.zero);
      container
          .read(playbackPreferencesProvider.notifier)
          .setRepeatMode(RepeatMode.all);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(playbackPreferencesProvider).repeatMode,
          RepeatMode.all);
    });
  });
}

class _ThrowingStorage extends Fake implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw Exception('storage indisponible');
}
