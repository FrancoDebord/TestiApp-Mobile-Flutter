import 'package:sqflite/sqflite.dart';

/// All CREATE TABLE statements and index definitions.
/// Version history is managed via onUpgrade.
abstract final class DatabaseSchema {
  static const int version = 4;

  // ── Table names ────────────────────────────────────────────────────────────
  static const tUsers              = 'users';
  static const tTestimonies        = 'testimonies';
  static const tComments           = 'comments';
  static const tReactions          = 'reactions';
  static const tNotifications      = 'notifications';
  static const tSavedTestimonies   = 'saved_testimonies';
  static const tCategories         = 'categories';
  static const tFollows            = 'follows';
  static const tDrafts             = 'drafts';
  static const tSyncCursors        = 'sync_cursors';
  static const tPendingOperations  = 'pending_operations';

  // ── Bible (v2) ─────────────────────────────────────────────────────────────
  static const tBibleTranslations = 'bible_translations';
  static const tBibleBooks        = 'bible_books';
  static const tBibleVerses       = 'bible_verses';
  static const tBibleHighlights   = 'bible_highlights';

  // ── onCreate ───────────────────────────────────────────────────────────────
  static Future<void> onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute(_createUsers);
    batch.execute(_createTestimonies);
    batch.execute(_createComments);
    batch.execute(_createReactions);
    batch.execute(_createNotifications);
    batch.execute(_createSavedTestimonies);
    batch.execute(_createCategories);
    batch.execute(_createFollows);
    batch.execute(_createDrafts);
    batch.execute(_createSyncCursors);
    batch.execute(_createPendingOperations);
    batch.execute(_createBibleTranslations);
    batch.execute(_createBibleBooks);
    batch.execute(_createBibleVerses);
    batch.execute(_createBibleHighlights);

    // Indexes
    batch.execute(_idxTestimoniesStatus);
    batch.execute(_idxTestimoniesCategory);
    batch.execute(_idxTestimoniesUpdated);
    batch.execute(_idxNotificationsRecipient);
    batch.execute(_idxCommentsTestimony);
    batch.execute(_idxPendingOpStatus);
    batch.execute(_idxBibleVersesLookup);

    await batch.commit(noResult: true);
  }

  static Future<void> onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute(_createBibleTranslations);
      await db.execute(_createBibleBooks);
      await db.execute(_createBibleVerses);
      await db.execute(_idxBibleVersesLookup);
    }
    if (oldV < 3) {
      // Recreate Bible tables with string code as primary key (was integer).
      await db.execute('DROP TABLE IF EXISTS $tBibleVerses');
      await db.execute('DROP TABLE IF EXISTS $tBibleBooks');
      await db.execute('DROP TABLE IF EXISTS $tBibleTranslations');
      await db.execute(_createBibleTranslations);
      await db.execute(_createBibleBooks);
      await db.execute(_createBibleVerses);
      await db.execute(_idxBibleVersesLookup);
    }
    if (oldV < 4) {
      await db.execute(_createBibleHighlights);
    }
  }

  // ── Tables ─────────────────────────────────────────────────────────────────

  static const _createUsers = '''
    CREATE TABLE $tUsers (
      id               TEXT PRIMARY KEY,
      display_name     TEXT NOT NULL,
      email            TEXT UNIQUE NOT NULL,
      avatar_url       TEXT,
      country          TEXT,
      role             TEXT NOT NULL DEFAULT 'utilisateur',
      is_verified      INTEGER NOT NULL DEFAULT 0,
      is_active        INTEGER NOT NULL DEFAULT 1,
      bio              TEXT,
      testimony_count  INTEGER DEFAULT 0,
      like_count       INTEGER DEFAULT 0,
      prayer_count     INTEGER DEFAULT 0,
      follower_count   INTEGER DEFAULT 0,
      following_count  INTEGER DEFAULT 0,
      created_at       TEXT NOT NULL,
      updated_at       TEXT NOT NULL
    )
  ''';

  static const _createTestimonies = '''
    CREATE TABLE $tTestimonies (
      id             TEXT PRIMARY KEY,
      user_id        TEXT NOT NULL,
      author_name    TEXT NOT NULL,
      author_avatar  TEXT,
      author_country TEXT,
      title          TEXT NOT NULL,
      type           TEXT NOT NULL,
      category       TEXT NOT NULL,
      body_text      TEXT,
      media_url      TEXT,
      cover_url      TEXT,
      duration_sec   INTEGER,
      bible_verse    TEXT,
      bible_ref      TEXT,
      visibility     TEXT NOT NULL DEFAULT 'public',
      status         TEXT NOT NULL DEFAULT 'published',
      views          INTEGER DEFAULT 0,
      like_count     INTEGER DEFAULT 0,
      prayer_count   INTEGER DEFAULT 0,
      comment_count  INTEGER DEFAULT 0,
      is_featured    INTEGER DEFAULT 0,
      user_liked     INTEGER DEFAULT 0,
      user_prayed    INTEGER DEFAULT 0,
      user_saved     INTEGER DEFAULT 0,
      created_at     TEXT NOT NULL,
      updated_at     TEXT NOT NULL,
      deleted_at     TEXT,
      synced_at      TEXT
    )
  ''';

  static const _createComments = '''
    CREATE TABLE $tComments (
      id             TEXT PRIMARY KEY,
      testimony_id   TEXT NOT NULL,
      user_id        TEXT NOT NULL,
      author_name    TEXT NOT NULL,
      author_avatar  TEXT,
      parent_id      TEXT,
      body           TEXT NOT NULL,
      likes          INTEGER DEFAULT 0,
      reply_count    INTEGER DEFAULT 0,
      created_at     TEXT NOT NULL,
      updated_at     TEXT NOT NULL,
      deleted_at     TEXT,
      synced_at      TEXT,
      FOREIGN KEY(testimony_id) REFERENCES $tTestimonies(id) ON DELETE CASCADE
    )
  ''';

  static const _createReactions = '''
    CREATE TABLE $tReactions (
      id             TEXT PRIMARY KEY,
      user_id        TEXT NOT NULL,
      testimony_id   TEXT NOT NULL,
      type           TEXT NOT NULL,
      created_at     TEXT NOT NULL,
      synced_at      TEXT,
      UNIQUE(user_id, testimony_id, type),
      FOREIGN KEY(testimony_id) REFERENCES $tTestimonies(id) ON DELETE CASCADE
    )
  ''';

  static const _createNotifications = '''
    CREATE TABLE $tNotifications (
      id             TEXT PRIMARY KEY,
      recipient_id   TEXT NOT NULL,
      actor_id       TEXT,
      actor_name     TEXT,
      actor_avatar   TEXT,
      type           TEXT NOT NULL,
      testimony_id   TEXT,
      testimony_title TEXT,
      comment_id     TEXT,
      is_read        INTEGER NOT NULL DEFAULT 0,
      payload        TEXT,
      created_at     TEXT NOT NULL,
      synced_at      TEXT
    )
  ''';

  static const _createSavedTestimonies = '''
    CREATE TABLE $tSavedTestimonies (
      user_id       TEXT NOT NULL,
      testimony_id  TEXT NOT NULL,
      saved_at      TEXT NOT NULL,
      synced_at     TEXT,
      PRIMARY KEY(user_id, testimony_id)
    )
  ''';

  static const _createCategories = '''
    CREATE TABLE $tCategories (
      id             TEXT PRIMARY KEY,
      name           TEXT NOT NULL,
      slug           TEXT UNIQUE NOT NULL,
      icon           TEXT,
      display_order  INTEGER DEFAULT 0,
      testimony_count INTEGER DEFAULT 0,
      is_active      INTEGER DEFAULT 1,
      updated_at     TEXT NOT NULL
    )
  ''';

  static const _createFollows = '''
    CREATE TABLE $tFollows (
      follower_id   TEXT NOT NULL,
      following_id  TEXT NOT NULL,
      followed_at   TEXT NOT NULL,
      synced_at     TEXT,
      PRIMARY KEY(follower_id, following_id)
    )
  ''';

  static const _createDrafts = '''
    CREATE TABLE $tDrafts (
      id              TEXT PRIMARY KEY,
      user_id         TEXT NOT NULL,
      type            TEXT NOT NULL,
      title           TEXT DEFAULT '',
      category        TEXT,
      body_text       TEXT DEFAULT '',
      audio_path      TEXT,
      video_path      TEXT,
      cover_path      TEXT,
      thumbnail_path  TEXT,
      bible_verse     TEXT,
      bible_ref       TEXT,
      visibility      TEXT DEFAULT 'public',
      consent_given   INTEGER DEFAULT 0,
      status          TEXT DEFAULT 'draft',
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL
    )
  ''';

  // ── Sync metadata ──────────────────────────────────────────────────────────

  static const _createSyncCursors = '''
    CREATE TABLE $tSyncCursors (
      entity       TEXT PRIMARY KEY,
      last_sync_at TEXT,
      next_cursor  TEXT
    )
  ''';

  // ── Offline queue ──────────────────────────────────────────────────────────

  static const _createPendingOperations = '''
    CREATE TABLE $tPendingOperations (
      id            TEXT PRIMARY KEY,
      type          TEXT NOT NULL,
      method        TEXT NOT NULL,
      endpoint      TEXT NOT NULL,
      body          TEXT,
      retry_count   INTEGER DEFAULT 0,
      status        TEXT DEFAULT 'pending',
      created_at    TEXT NOT NULL,
      last_tried_at TEXT
    )
  ''';

  // ── Bible tables (v3 — string code as PK) ────────────────────────────────

  static const _createBibleTranslations = '''
    CREATE TABLE $tBibleTranslations (
      code           TEXT PRIMARY KEY,
      name           TEXT NOT NULL,
      language       TEXT NOT NULL DEFAULT 'fr',
      verses_count   INTEGER DEFAULT 0,
      is_downloaded  INTEGER NOT NULL DEFAULT 0,
      downloaded_at  TEXT,
      updated_at     TEXT NOT NULL
    )
  ''';

  static const _createBibleBooks = '''
    CREATE TABLE $tBibleBooks (
      id                INTEGER PRIMARY KEY AUTOINCREMENT,
      translation_code  TEXT NOT NULL,
      book_number       INTEGER NOT NULL,
      name              TEXT NOT NULL,
      chapters_count    INTEGER DEFAULT 0,
      UNIQUE(translation_code, book_number),
      FOREIGN KEY(translation_code) REFERENCES $tBibleTranslations(code) ON DELETE CASCADE
    )
  ''';

  static const _createBibleVerses = '''
    CREATE TABLE $tBibleVerses (
      id                INTEGER PRIMARY KEY AUTOINCREMENT,
      translation_code  TEXT NOT NULL,
      book_number       INTEGER NOT NULL,
      chapter_number    INTEGER NOT NULL,
      verse_number      INTEGER NOT NULL,
      text              TEXT NOT NULL,
      UNIQUE(translation_code, book_number, chapter_number, verse_number),
      FOREIGN KEY(translation_code) REFERENCES $tBibleTranslations(code) ON DELETE CASCADE
    )
  ''';

  static const _createBibleHighlights = '''
    CREATE TABLE $tBibleHighlights (
      id                INTEGER PRIMARY KEY AUTOINCREMENT,
      translation_code  TEXT NOT NULL,
      book_number       INTEGER NOT NULL,
      chapter_number    INTEGER NOT NULL,
      verse_number      INTEGER NOT NULL,
      color             TEXT NOT NULL,
      created_at        TEXT NOT NULL,
      UNIQUE(translation_code, book_number, chapter_number, verse_number)
    )
  ''';

  // ── Indexes ────────────────────────────────────────────────────────────────

  static const _idxTestimoniesStatus =
      'CREATE INDEX idx_testimonies_status ON $tTestimonies(status, created_at DESC)';

  static const _idxTestimoniesCategory =
      'CREATE INDEX idx_testimonies_category ON $tTestimonies(category)';

  static const _idxTestimoniesUpdated =
      'CREATE INDEX idx_testimonies_updated ON $tTestimonies(updated_at)';

  static const _idxNotificationsRecipient =
      'CREATE INDEX idx_notifications_recipient ON $tNotifications(recipient_id, is_read, created_at DESC)';

  static const _idxCommentsTestimony =
      'CREATE INDEX idx_comments_testimony ON $tComments(testimony_id, created_at)';

  static const _idxPendingOpStatus =
      'CREATE INDEX idx_pending_op_status ON $tPendingOperations(status, created_at)';

  static const _idxBibleVersesLookup =
      'CREATE INDEX idx_bible_verses_lookup ON $tBibleVerses(translation_code, book_number, chapter_number)';
}
