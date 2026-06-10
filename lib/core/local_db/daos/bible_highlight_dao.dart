import '../database_schema.dart';
import '../database_service.dart';

class BibleHighlightDao {
  const BibleHighlightDao(this._db);
  final DatabaseService _db;

  Future<Map<int, String>> getChapterHighlights(
    String translationCode,
    int bookNumber,
    int chapterNumber,
  ) async {
    final rows = await _db.query(
      DatabaseSchema.tBibleHighlights,
      where: 'translation_code = ? AND book_number = ? AND chapter_number = ?',
      whereArgs: [translationCode, bookNumber, chapterNumber],
    );
    return {for (final r in rows) r['verse_number'] as int: r['color'] as String};
  }

  Future<void> setHighlight({
    required String translationCode,
    required int bookNumber,
    required int chapterNumber,
    required int verseNumber,
    required String colorHex,
  }) async {
    await _db.insert(
      DatabaseSchema.tBibleHighlights,
      {
        'translation_code': translationCode,
        'book_number':      bookNumber,
        'chapter_number':   chapterNumber,
        'verse_number':     verseNumber,
        'color':            colorHex,
        'created_at':       DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> clearHighlight({
    required String translationCode,
    required int bookNumber,
    required int chapterNumber,
    required int verseNumber,
  }) async {
    await _db.delete(
      DatabaseSchema.tBibleHighlights,
      where: 'translation_code = ? AND book_number = ? AND chapter_number = ? AND verse_number = ?',
      whereArgs: [translationCode, bookNumber, chapterNumber, verseNumber],
    );
  }
}
