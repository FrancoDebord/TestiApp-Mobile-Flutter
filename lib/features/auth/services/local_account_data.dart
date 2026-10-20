// Données du compte gardées sur le téléphone, effacées après la suppression du
// compte (DELETE /me) : session et profil en cache, identifiants de reconnexion,
// compte administré, préférences du verset, tables personnelles de la base
// locale, copie hors ligne du journal. La Bible téléchargée et les réglages de
// l'appareil (langue, lecture) sont gardés : ils ne concernent pas le compte.
// Serveur : docs/fonctionnalites/confidentialite-et-suppression.md

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/database_schema.dart';
import '../../../core/local_db/database_service.dart';
import '../../../services/api_service.dart' show secureStorageProvider;
import '../../daily_verse/design/verse_style_prefs.dart' show VerseStylePrefsNotifier;
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
    }
  }
}

final localAccountDataProvider = Provider<LocalAccountData>(LocalAccountData.new);
