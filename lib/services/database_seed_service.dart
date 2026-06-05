// lib/services/database_seed_service.dart
//
// Peuple SQLite avec des données de démonstration au premier lancement.

import '../core/local_db/database_schema.dart';
import '../core/local_db/database_service.dart';

class DatabaseSeedService {
  DatabaseSeedService(this._db);
  final DatabaseService _db;

  static const _seedKey = 'seed_v1';

  Future<void> seedIfEmpty() async {
    // Vérifier si déjà peuplé
    final existing = await _db.query(
      DatabaseSchema.tSyncCursors,
      where: 'entity = ?',
      whereArgs: [_seedKey],
    );
    if (existing.isNotEmpty) return;

    await _seedCategories();
    await _seedTestimonies();
    await _seedVerseOfDay();

    // Marquer la base comme peuplée
    await _db.insert(DatabaseSchema.tSyncCursors, {
      'entity': _seedKey,
      'last_sync_at': _now(),
    });
  }

  // ── Catégories ───────────────────────────────────────────────────────────────

  Future<void> _seedCategories() async {
    final categories = [
      {'id': 'c1',  'name': 'Guérison',         'slug': 'guerison',          'display_order': 1,  'testimony_count': 245, 'is_active': 1, 'updated_at': _now()},
      {'id': 'c2',  'name': 'Délivrance',        'slug': 'delivrance',        'display_order': 2,  'testimony_count': 189, 'is_active': 1, 'updated_at': _now()},
      {'id': 'c3',  'name': 'Conversion',        'slug': 'conversion',        'display_order': 3,  'testimony_count': 312, 'is_active': 1, 'updated_at': _now()},
      {'id': 'c4',  'name': 'Mariage',           'slug': 'mariage',           'display_order': 4,  'testimony_count': 98,  'is_active': 1, 'updated_at': _now()},
      {'id': 'c5',  'name': 'Famille',           'slug': 'famille',           'display_order': 5,  'testimony_count': 134, 'is_active': 1, 'updated_at': _now()},
      {'id': 'c6',  'name': 'Finances',          'slug': 'finances',          'display_order': 6,  'testimony_count': 76,  'is_active': 1, 'updated_at': _now()},
      {'id': 'c7',  'name': 'Miracles',          'slug': 'miracles',          'display_order': 7,  'testimony_count': 421, 'is_active': 1, 'updated_at': _now()},
      {'id': 'c8',  'name': 'Protection divine', 'slug': 'protection-divine', 'display_order': 8,  'testimony_count': 167, 'is_active': 1, 'updated_at': _now()},
      {'id': 'c9',  'name': 'Ministère',         'slug': 'ministere',         'display_order': 9,  'testimony_count': 55,  'is_active': 1, 'updated_at': _now()},
      {'id': 'c10', 'name': 'Salut',             'slug': 'salut',             'display_order': 10, 'testimony_count': 203, 'is_active': 1, 'updated_at': _now()},
    ];
    for (final row in categories) {
      await _db.insert(DatabaseSchema.tCategories, row);
    }
  }

  // ── Témoignages de démonstration ─────────────────────────────────────────────

  Future<void> _seedTestimonies() async {
    final rows = [
      {
        'id': 't1', 'user_id': 'u1', 'author_name': 'Marie Ndoumbé',
        'author_country': 'Cameroun',
        'title': "Guérie d'un cancer en phase terminale",
        'type': 'text', 'category': 'guerison',
        'body_text': "Après trois ans de combat contre un cancer du sein en phase 4, "
            "les médecins m'avaient donné six mois à vivre. C'est lors "
            "d'une réunion de prière que Dieu m'a touchée et guérie complètement.",
        'status': 'published', 'views': 1243, 'like_count': 89,
        'prayer_count': 156, 'comment_count': 34, 'is_featured': 1,
        'created_at': _daysAgo(2), 'updated_at': _daysAgo(2),
      },
      {
        'id': 't2', 'user_id': 'u2', 'author_name': 'Jean-Paul Essomba',
        'author_country': 'Cameroun',
        'title': "Ma délivrance d'une addiction de 15 ans",
        'type': 'audio', 'category': 'delivrance',
        'body_text': "Pendant quinze ans, j'étais esclave de l'alcool. "
            "Un soir lors d'une réunion de prière, Dieu a brisé les chaînes.",
        'duration_sec': 734, 'status': 'published', 'views': 876,
        'like_count': 63, 'prayer_count': 98, 'comment_count': 21, 'is_featured': 1,
        'created_at': _daysAgo(5), 'updated_at': _daysAgo(5),
      },
      {
        'id': 't3', 'user_id': 'u3', 'author_name': 'Esther Fokou',
        'author_country': "Côte d'Ivoire",
        'title': 'Comment Dieu a restauré mon mariage brisé',
        'type': 'video', 'category': 'mariage',
        'body_text': "Mon mari et moi étions séparés depuis deux ans. "
            "Dieu est intervenu de façon miraculeuse lors d'une nuit de prière.",
        'duration_sec': 1245, 'status': 'published', 'views': 2100,
        'like_count': 134, 'prayer_count': 210, 'comment_count': 47, 'is_featured': 1,
        'created_at': _daysAgo(8), 'updated_at': _daysAgo(8),
      },
      {
        'id': 't4', 'user_id': 'u4', 'author_name': 'Samuel Biya',
        'author_country': 'Cameroun',
        'title': 'Miracle financier : dette effacée en une nuit',
        'type': 'text', 'category': 'finances',
        'body_text': "Notre entreprise était au bord de la faillite. "
            "Après une nuit de jeûne, un partenaire inattendu a soldé toute la dette.",
        'status': 'published', 'views': 654, 'like_count': 45,
        'prayer_count': 77, 'comment_count': 18,
        'created_at': _daysAgo(12), 'updated_at': _daysAgo(12),
      },
      {
        'id': 't5', 'user_id': 'u5', 'author_name': 'Grace Mballa',
        'author_country': 'Ghana',
        'title': "Protection miraculeuse lors d'un accident",
        'type': 'audio', 'category': 'protection-divine',
        'body_text': "Le car a fait plusieurs tonneaux. Tous les passagers ont été "
            "blessés sauf moi. C'était clairement la main de Dieu.",
        'duration_sec': 412, 'status': 'published', 'views': 432,
        'like_count': 38, 'prayer_count': 55, 'comment_count': 9,
        'created_at': _daysAgo(18), 'updated_at': _daysAgo(18),
      },
      {
        'id': 't6', 'user_id': 'u6', 'author_name': 'Paul Nkeng',
        'author_country': 'Nigeria',
        'title': "Conversion radicale : d'imam à pasteur",
        'type': 'text', 'category': 'conversion',
        'body_text': "Pendant 30 ans, j'ai combattu le christianisme. "
            "Une nuit, Jésus m'est apparu en rêve et tout a changé.",
        'status': 'published', 'views': 3400, 'like_count': 287,
        'prayer_count': 401, 'comment_count': 89, 'is_featured': 1,
        'created_at': _daysAgo(25), 'updated_at': _daysAgo(25),
      },
    ];
    for (final row in rows) {
      await _db.insert(DatabaseSchema.tTestimonies, row);
    }
  }

  // ── Verset du jour ────────────────────────────────────────────────────────────

  Future<void> _seedVerseOfDay() async {
    await _db.insert(DatabaseSchema.tSyncCursors, {
      'entity': 'verse_of_day',
      'last_sync_at': _now(),
      'next_cursor': "« Car je connais les projets que j'ai formés sur vous, dit l'Éternel, "
          "projets de paix et non de malheur, afin de vous donner un avenir et de l'espérance. »"
          "|Jérémie 29:11",
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static String _now() => DateTime.now().toIso8601String();
  static String _daysAgo(int d) =>
      DateTime.now().subtract(Duration(days: d)).toIso8601String();
}
