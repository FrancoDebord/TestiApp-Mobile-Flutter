// Verset du jour en plein écran. Docs serveur : fonctionnalites/verset-du-jour.md

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_service.dart' show secureStorageProvider;
import '../../home/models/testimony_model.dart';
import '../../prayer/models/prayer_models.dart';
import '../data/daily_verse_repository.dart';
import '../models/daily_verse_models.dart';

/// Pas de nouvel essai automatique : l'écran propose « Réessayer » (hors connexion).
Duration? _noRetry(int retryCount, Object error) => null;

/// Clé stable d'un verset (les réactions changent l'objet DailyVerse).
typedef DailyVerseKey = ({int id, String reference, String text});

DailyVerseKey dailyVerseKey(DailyVerse v) => (id: v.id, reference: v.reference, text: v.text);

/// Versions du passage.
final dailyVerseVersionsProvider =
    FutureProvider.autoDispose.family<DailyVerseVersions, DailyVerseKey>(
  (ref, key) => ref.watch(dailyVerseRepositoryProvider).versions(
        DailyVerse(id: key.id, text: key.text, reference: key.reference),
      ),
  retry: _noRetry,
);

final dailyVerseCommentsProvider =
    FutureProvider.autoDispose.family<List<VerseComment>, int>(
  (ref, id) => ref.watch(dailyVerseRepositoryProvider).comments(id),
  retry: _noRetry,
);

final dailyVersePrayerRequestsProvider =
    FutureProvider.autoDispose.family<List<PrayerRequest>, int>(
  (ref, id) => ref.watch(dailyVerseRepositoryProvider).prayerRequests(id),
  retry: _noRetry,
);

final dailyVerseTestimoniesProvider =
    FutureProvider.autoDispose.family<List<Testimony>, int>(
  (ref, id) => ref.watch(dailyVerseRepositoryProvider).testimonies(id),
  retry: _noRetry,
);

/// Version préférée (code, ex. « KJV ») ; null = texte du jour. Mémorisée
/// sur l'appareil.
class PreferredVerseTranslationNotifier extends Notifier<String?> {
  static const storageKey = 'daily_verse_translation';

  @override
  String? build() {
    Future.microtask(_load);
    return null;
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(secureStorageProvider).read(key: storageKey);
      if (raw != null && raw.isNotEmpty) state = raw;
    } catch (_) {/* stockage indisponible (tests, web) */}
  }

  void select(String? code) {
    state = code;
    unawaited(() async {
      try {
        final storage = ref.read(secureStorageProvider);
        if (code == null) {
          await storage.delete(key: storageKey);
        } else {
          await storage.write(key: storageKey, value: code);
        }
      } catch (_) {}
    }());
  }
}

final preferredVerseTranslationProvider =
    NotifierProvider<PreferredVerseTranslationNotifier, String?>(
  PreferredVerseTranslationNotifier.new,
);
