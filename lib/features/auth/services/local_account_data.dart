// Données du compte gardées sur le téléphone, effacées après la suppression du
// compte (DELETE /me) : session et profil en cache, identifiants de reconnexion,
// compte administré, préférences du verset, tables personnelles de la base
// locale, copie hors ligne du journal. La Bible téléchargée et les réglages de
// l'appareil (langue, lecture) sont gardés : ils ne concernent pas le compte.
// Serveur : docs/fonctionnalites/confidentialite-et-suppression.md

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/local_db/database_schema.dart';
import '../../../core/local_db/database_service.dart';
import '../../../services/api_service.dart' show secureStorageProvider;
import '../../daily_verse/design/verse_style_prefs.dart' show VerseStylePrefsNotifier;
import '../../downloads/data/offline_testimonies_store.dart';
import '../../journal/data/journal_offline_controller.dart' show journalOfflineStoreProvider;

class LocalAccountData {
  LocalAccountData(this._ref);
  final Ref _ref;

  /// Tables de la base locale liées au compte (la Bible téléchargée est gardée).
  static const personalTables = [
    DatabaseSchema.tUsers,
    DatabaseSchema.tTestimonies,
    DatabaseSchema.tComments,
    DatabaseSchema.tReactions,
    DatabaseSchema.tNotifications,
    DatabaseSchema.tSavedTestimonies,
    DatabaseSchema.tFollows,
    DatabaseSchema.tDrafts,
    DatabaseSchema.tSyncCursors,
    DatabaseSchema.tPendingOperations,
    DatabaseSchema.tOutbox,
    DatabaseSchema.tOutboxIds,
    DatabaseSchema.tBibleHighlights,
  ];

  /// Efface tout ; chaque étape est indépendante (un échec n'arrête pas les autres).
  Future<void> wipe({String? userId}) async {
    Future<void> step(String name, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        if (kDebugMode) debugPrint('[LocalAccountData] $name ✗ $e');
      }
    }

    await step('secure storage', () => _ref.read(secureStorageProvider).deleteAll());
    await step('verse prefs', VerseStylePrefsNotifier.clearStored);
    await step('database', () async {
      final db = DatabaseService();
      for (final t in personalTables) {
        await db.execute('DELETE FROM $t');
      }
    });
    if (userId != null) {
      await step('journal', () => _ref.read(journalOfflineStoreProvider).wipe(userId));
      // Copie de « Mes témoignages » (les téléchargements, propres au téléphone, restent).
      await step('my testimonies copy', () => const OfflineTestimoniesStore().forgetUser(userId)); // i18n-ignore (journal)
    }
    // Copies hors connexion des événements (mes événements, organisations gérées).
    await step('events offline copies', () async { // i18n-ignore (journal)
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().where((k) => k.startsWith('events.'))) { // i18n-ignore
        await prefs.remove(k);
      }
    });
    // Copies des fichiers en attente d'envoi (file hors connexion).
    if (!kIsWeb) {
      await step('outbox files', () async { // i18n-ignore (journal)
        // File d'envoi et brouillons de témoignage (copies des fichiers choisis).
        for (final name in ['outbox', 'drafts']) {
          final dir = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}$name');
          if (await dir.exists()) await dir.delete(recursive: true);
        }
      });
    }
  }
}

final localAccountDataProvider = Provider<LocalAccountData>(LocalAccountData.new);
