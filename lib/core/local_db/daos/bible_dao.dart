import 'package:sqflite/sqflite.dart';

import '../database_schema.dart';
import '../database_service.dart';
import '../../../features/bible/models/bible_models.dart';

class BibleDao {
  const BibleDao(this._db);
  final DatabaseService _db;

  // ── Translations ───────────────────────────────────────────────────────────

  Future<List<BibleTranslation>> getLocalTranslations() async {
    final rows = await _db.query(
      DatabaseSchema.tBibleTranslations,
      orderBy: 'name ASC',
    );
    return rows.map(BibleTranslation.fromDb).toList();
  }

  Future<bool> isDownloaded(String translationCode) async {
    final rows = await _db.query(
      DatabaseSchema.tBibleTranslations,
      where: 'code = ? AND is_downloaded = 1',
      whereArgs: [translationCode],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> upsertTranslationMeta(BibleTranslation t) async {
    await _db.insert(DatabaseSchema.tBibleTranslations, {
      'code':         t.code,
      'name':         t.name,
      'language':     t.language,
      'verses_count': t.verseCount,
      'is_downloaded': 0,
      'downloaded_at': null,
      'updated_at':   DateTime.now().toIso8601String(),
    });
  }

  Future<void> markDownloaded(String translationCode) async {
    await _db.update(
      DatabaseSchema.tBibleTranslations,
      {
        'is_downloaded': 1,
        'downloaded_at': DateTime.now().toIso8601String(),
      },
      where: 'code = ?',
      whereArgs: [translationCode],
    );
  }

  Future<void> deleteTranslation(String translationCode) async {
    await _db.delete(
      DatabaseSchema.tBibleTranslations,
      where: 'code = ?',
      whereArgs: [translationCode],
    );
  }

  // ── Books ──────────────────────────────────────────────────────────────────

  Future<List<BibleBook>> getBooks(String translationCode) async {
    final rows = await _db.query(
      DatabaseSchema.tBibleBooks,
      where: 'translation_code = ?',
      whereArgs: [translationCode],
      orderBy: 'book_number ASC',
    );
    return rows.map(BibleBook.fromDb).toList();
  }

  // ── Verses ─────────────────────────────────────────────────────────────────

  Future<List<BibleVerse>> getVerses(
    String translationCode,
    int bookNumber,
    int chapterNumber,
  ) async {
    final rows = await _db.query(
      DatabaseSchema.tBibleVerses,
      where: 'translation_code = ? AND book_number = ? AND chapter_number = ?',
      whereArgs: [translationCode, bookNumber, chapterNumber],
      orderBy: 'verse_number ASC',
    );
    return rows.map(BibleVerse.fromDb).toList();
  }

  Future<List<String>> getDownloadedTranslationCodes() async {
    final db   = await _db.db;
    final rows = await db.rawQuery(
      'SELECT code FROM ${DatabaseSchema.tBibleTranslations} WHERE is_downloaded = 1',
    );
    return rows.map((r) => r['code'] as String).toList();
  }

  Future<Map<String, String>> getVerseAcrossTranslations(
    List<String> codes,
    int bookNumber,
    int chapterNumber,
    int verseNumber,
  ) async {
    if (codes.isEmpty) return {};
    final db           = await _db.db;
    final placeholders = List.filled(codes.length, '?').join(',');
    final rows         = await db.rawQuery(
      'SELECT translation_code, text FROM ${DatabaseSchema.tBibleVerses} '
      'WHERE translation_code IN ($placeholders) '
      'AND book_number = ? AND chapter_number = ? AND verse_number = ?',
      [...codes, bookNumber, chapterNumber, verseNumber],
    );
    return {for (final r in rows) r['translation_code'] as String: r['text'] as String};
  }

  Future<int> getChapterCount(String translationCode, int bookNumber) async {
    final database = await _db.db;
    final result = await database.rawQuery(
      'SELECT MAX(chapter_number) AS max_ch FROM ${DatabaseSchema.tBibleVerses} '
      'WHERE translation_code = ? AND book_number = ?',
      [translationCode, bookNumber],
    );
    return (result.first['max_ch'] as int?) ?? 0;
  }

  // ── Bulk insert (full translation download) ────────────────────────────────

  /// Parses the server JSON payload and inserts all books + verses in a single
  /// transaction, then marks the translation as downloaded.
  ///
  /// Expected [data] shape (from GET /bible/download/{code}):
  /// ```json
  /// {
  ///   "translation": "LSG",
  ///   "books": [
  ///     {
  ///       "number": 1,
  ///       "name": "Genèse",
  ///       "chapters": [
  ///         {
  ///           "chapter": 1,
  ///           "verses": [{"verse": 1, "text": "..."}, ...]
  ///         }
  ///       ]
  ///     }
  ///   ]
  /// }
  /// ```
  Future<void> insertFullTranslation(
    String translationCode,
    Map<String, dynamic> data,
  ) async {
    final rawBooks = data['books'] as List<dynamic>? ?? [];

    final database = await _db.db;
    await database.transaction((txn) async {
      // Remove any stale data first (in case of re-download).
      await txn.delete(
        DatabaseSchema.tBibleBooks,
        where: 'translation_code = ?',
        whereArgs: [translationCode],
      );
      await txn.delete(
        DatabaseSchema.tBibleVerses,
        where: 'translation_code = ?',
        whereArgs: [translationCode],
      );

      for (final rawBook in rawBooks) {
        final book        = rawBook as Map<String, dynamic>;
        final bookNumber  = book['number']   as int;
        final bookName    = book['name']     as String;
        final rawChapters = book['chapters'] as List<dynamic>? ?? [];

        await txn.insert(
          DatabaseSchema.tBibleBooks,
          {
            'translation_code': translationCode,
            'book_number':      bookNumber,
            'name':             bookName,
            'chapters_count':   rawChapters.length,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final verseBatch = txn.batch();
        for (final rawChapter in rawChapters) {
          final chapter       = rawChapter as Map<String, dynamic>;
          final chapterNumber = chapter['chapter'] as int;   // server key is "chapter"
          final rawVerses     = chapter['verses']  as List<dynamic>? ?? [];

          for (final rawVerse in rawVerses) {
            final verse = rawVerse as Map<String, dynamic>;
            verseBatch.insert(
              DatabaseSchema.tBibleVerses,
              {
                'translation_code': translationCode,
                'book_number':      bookNumber,
                'chapter_number':   chapterNumber,
                'verse_number':     verse['verse'] as int,   // server key is "verse"
                'text':             verse['text']  as String,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        await verseBatch.commit(noResult: true);
      }
    });

    await markDownloaded(translationCode);
  }
}
